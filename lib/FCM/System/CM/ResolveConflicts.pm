#-------------------------------------------------------------------------------
# Copyright (C) British Crown (Met Office) & Contributors.
#
# This file is part of FCM, tools for managing and building source code.
#
# FCM is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# FCM is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with FCM. If not, see <http://www.gnu.org/licenses/>.
#-------------------------------------------------------------------------------
use strict;
use warnings;

#-------------------------------------------------------------------------------
package FCM::System::CM::ResolveConflicts;
use base qw{Exporter};
our @EXPORT_OK = qw{_cm_resolve_conflicts};

use Cwd qw{cwd};
use FCM::Context::Event;
use FCM::System::Exception;
use File::Basename qw{basename dirname};
use File::Copy qw{copy};
use File::Spec::Functions qw{abs2rel catfile rel2abs};
use File::Temp;

# LxIy stands for local x, incoming y in the tree conflict description.
# The letters of x and y correspond to:
# A => add,
# D => delete,
# E => edit,
# M => missing,
# P => replace,
# R => rename,
# although the 'rename' has to be detected by our code below.

our %TREE_CONFLICT_GET_GRAPHIC_SOURCES_FUNC_FOR = (
    LEIR => \&_cm_tree_conflict_get_graphic_sources_for_leir,
    LRIE => \&_cm_tree_conflict_get_graphic_sources_for_lrie,
    LRIR => \&_cm_tree_conflict_get_graphic_sources_for_lrir,
);

# A tree conflict key must be present here for auto-resolving.
our %TREE_CONFLICT_GET_FINAL_ACTIONS_FUNC_FOR = (
    LAIA => \&_cm_tree_conflict_get_actions_for_laia,
    LDID => sub {},
    LDIE => \&_cm_tree_conflict_get_actions_for_ldie,
    LDIR => \&_cm_tree_conflict_get_actions_for_ldir,
    LEID => \&_cm_tree_conflict_get_actions_for_leid,
    LEIR => \&_cm_tree_conflict_get_actions_for_leir,
    LEIP => \&_cm_tree_conflict_get_actions_for_leip,
    LRID => \&_cm_tree_conflict_get_actions_for_lrid,
    LRIE => \&_cm_tree_conflict_get_actions_for_lrie,
    LRIR => \&_cm_tree_conflict_get_actions_for_lrir,
);

# Handle aliases for actions.
our %TREE_CONFLICT_GET_UNALIAS_FOR = (
    'obstruction' => 'add',
    'missing' => 'delete',
);

# Number of renamed files that triggers a time warning.
our $TREE_CONFLICT_WARN_FILES_THRESHOLD = 10;

my $E = 'FCM::System::Exception';
# Regular expressions
my %RE = (
    # determines if a file was copied, i.e. added with history from "svn status"
    ST_COPIED => qr{^A..\+....(.*)}msx,
);

# Resolve conflicts.
sub _cm_resolve_conflicts {
    my ($attrib_ref, $option_ref, @args) = @_;
    my $UTIL = $attrib_ref->{util};
    my $pwd = cwd();
    if (!@args) {
        push(@args, '.');
    }
    for my $arg (@args) {
        if (!-e $arg) {
            die("$arg: $!\n");
        }
        chdir($attrib_ref->{svn}->get_wc_root($arg)) || die("$arg: $!\n");
        my @command = qw{svn status};
        my %value_of = %{$UTIL->shell_simple(\@command)};
        if ($value_of{rc}) {
            return $E->throw($E->SHELL, {command_list => \@command, %value_of});
        }
        my @status_lines = grep {$_} split("\n", $value_of{o});
        local(%ENV) = %ENV;
        $ENV{FCM_GRAPHIC_MERGE} ||= $UTIL->external_cfg_get('graphic-merge');
        for my $path (map {($_ =~ qr{\AC.{6}\s(.*)\z}msx)} @status_lines) {
            _cm_resolve_text_conflict(
                $attrib_ref,
                $option_ref,
                $path,
                @status_lines,
            );
        }
        for my $path (map {($_ =~ qr{\A.{6}C\s(.*)\z}msx)} @status_lines) {
            _cm_resolve_tree_conflict(
                $attrib_ref,
                $option_ref,
                $path,
                @status_lines,
            );
        }
    }
    chdir($pwd);
}

# Helper for _cm_resolve_conflicts, launch graphic merge tool.
sub _cm_graphic_merge {
    my $attrib_ref = shift();
    my @command = ('fcm_graphic_merge', @_);
    my $UTIL = $attrib_ref->{util};
    my %value_of = %{$UTIL->shell_simple(\@command)};
    # rc==0: all conflicts resovled
    # rc==1: some conflicts not resolved
    # rc==2: trouble
    if (!grep {$_ eq $value_of{rc}} (0, 1)) {
        return $E->throw(
            $E->SHELL, {command_list => \@command, %value_of}, $value_of{e},
        );
    }
    $UTIL->event(FCM::Context::Event->OUT, $value_of{o});
    $value_of{rc};
}

# Resolve a text conflict.
sub _cm_resolve_text_conflict {
    my ($attrib_ref, $option_ref, $path) = @_;
    my $PROMPT = $attrib_ref->{prompt};
    my $UTIL = $attrib_ref->{util};
    if (-B $path) {
        $UTIL->event(FCM::Context::Event->CM_CONFLICT_TEXT_SKIP, $path);
        return;
    }
    $UTIL->event(FCM::Context::Event->CM_CONFLICT_TEXT, $path);

    # Get conflicts markers files
    my %info = %{$attrib_ref->{svn}->get_info($path)->[0]};
    my @keys = map {"conflict:$_-file"} qw{prev-wc prev-base cur-base};
    # Subversion 1.6: conflict filenames are relative paths.
    # Subversion 1.8: conflict filenames are absolute paths.
    my ($mine, $older, $yours) = map {
        rel2abs($_, rel2abs(dirname($path)))
    } @info{@keys};

    # If $path is newer (by more than a second), it may contain saved changes.
    if (    -f $path && (stat($path))[9] > (stat($mine))[9] + 1
        &&  !$PROMPT->question('OVERWRITE', $path)
    ) {
        return;
    }

    # Launch graphic merge tool
    if (_cm_graphic_merge($attrib_ref, $path, $mine, $older, $yours)) {
        return; # rc==1, some conflicts not resolved
    }

    # Prompt user to run "svn resolve --accept working" on the file
    if ($PROMPT->question('RESOLVE', $path)) {
        $attrib_ref->{svn}->call(qw{resolve --accept working}, $path);
    }
}

# Resolve a tree conflict.
sub _cm_resolve_tree_conflict {
    my ($attrib_ref, $option_ref, $path, @status_lines) = @_;
    my $PROMPT = $attrib_ref->{prompt};
    my $UTIL = $attrib_ref->{util};

    # Skip directories - too complex for now.
    if (-d $path) {
        $UTIL->event(FCM::Context::Event->CM_CONFLICT_TREE_SKIP, $path);
        return;
    }

    # Get basic information about the tree conflict, and the filename.
    my %info = %{$attrib_ref->{svn}->get_info($path)->[0]};

    # Skip non-existent or unhandled tree conflicts.
    if (!exists($info{'tree-conflict:operation'})) {
        return
    }
    if ($info{'tree-conflict:operation'} ne 'merge') {
        $UTIL->event(FCM::Context::Event->CM_CONFLICT_TREE_SKIP, $path);
        return;
    }
    
    my $tree_reason = $info{'tree-conflict:reason'};
    if (grep {$tree_reason eq $_} keys(%TREE_CONFLICT_GET_UNALIAS_FOR)) {
        $tree_reason = $TREE_CONFLICT_GET_UNALIAS_FOR{$tree_reason};
    }
    my $tree_key = FCM::System::CM::TreeConflictKey->new(
        {   'local'    => $tree_reason,
            'incoming' => $info{'tree-conflict:action'},
            'type'     => $info{'tree-conflict:operation'},
        },
    );
    my $tree_filename = $info{'path'};

    my %wc_info = %{$attrib_ref->{svn}->get_info()->[0]};

    my $repos_root = $wc_info{'repository:root'};
    my $wc_branch = substr($wc_info{'url'}, length($repos_root) + 1);

    my $tree_full_filename = '/' . $wc_branch . '/' . $tree_filename;

    # Check for external renaming, by examining files added with history
    my $ext_renamed_file = '';
    my $ext_branch = '';
    COPIED_FILE:
    for my $copied_file (map {($_ =~ $RE{ST_COPIED})} @status_lines) {
        my %copy_info = %{$attrib_ref->{svn}->get_info($copied_file)->[0]};
        my $url = (
              $copy_info{'wc-info:copy-from-url'}
            . '@' . $copy_info{'wc-info:copy-from-rev'}
        );
        my $copy_log_ref = $attrib_ref->{svn}->get_log($url);
        if (!$ext_branch) {
            my $copy_full_path = substr(
                $copy_info{'wc-info:copy-from-url'},
                length($repos_root) + 1,
            );
            $ext_branch = substr(
                $copy_full_path,
                0,
                -length($copied_file) - 1,
            );
        }
        my $copied_full_filename = '/' . $ext_branch . '/' . $copied_file;
        my $tree_ext_name
            = ('/' . $info{'tree-conflict:source-right:path-in-repos'});
        my $search_name = $tree_ext_name;
        for my $log_entry_ref (reverse(@{$copy_log_ref})) {
            for my $path_entry (@{$log_entry_ref->{'paths'}}) {
                if (    exists $path_entry->{'copyfrom-path'}
                    &&  $path_entry->{'copyfrom-path'} eq $search_name
                ) {
                    $search_name = $path_entry->{'path'};
                    if ($search_name eq $copied_full_filename) {
                        $ext_renamed_file = $copied_file;
                        last COPIED_FILE;
                    }
                }
            }
        }
    }

    # Check for local renaming of the tree conflict file
    my $local_renamed_file = '';
    if ($tree_reason eq 'delete') {
        $local_renamed_file = _cm_tree_conflict_get_local_rename(
            $attrib_ref,
            $wc_branch,
            $tree_full_filename,
            $ext_renamed_file
        );
    }

    # The tree conflict identifier (tree_key) needs to be adjusted for reality
    if ($local_renamed_file) {
        $tree_key->set_local('rename');
    }
    if ($ext_renamed_file) {
        $tree_key->set_incoming('rename');
    }

    # Skip and return if the tree key does not match a key in final cmds.
    my $cmds_getter
        = $TREE_CONFLICT_GET_FINAL_ACTIONS_FUNC_FOR{$tree_key->as_string()};
    if (!$cmds_getter) {
        $UTIL->event(FCM::Context::Event->CM_CONFLICT_TREE_SKIP, $path);
        return;
    }

    # Print the tree conflict event message
    $UTIL->event(FCM::Context::Event->CM_CONFLICT_TREE, $path);

    # These are the relevant files for this tree conflict.
    my @file_args = grep {$_} ($path, $local_renamed_file, $ext_renamed_file);

    # Prompt which version of events to accept - local or incoming.
    my $keep_local = $PROMPT->question(
        'TC_' . $tree_key->as_string(),
        $tree_key, $local_renamed_file, $ext_renamed_file,
    );

    # Add any graphic merge commands
    my @cmds = _cm_tree_conflict_get_graphic_cmds(
        $attrib_ref, $tree_key->as_string(), $keep_local, \@file_args,
    );
    # Now load any miscellaneous actions or commands - for example 'svn delete'
    if ($tree_key->get_local() eq 'add' && $tree_key->get_incoming() eq 'add') {
        # We need to generate a new filename and a temporary one in this case.
        @file_args = ($path);
        my $tree_dir = dirname($path);
        my $newfile_handle = File::Temp->new(
            DIR => $tree_dir,
            TEMPLATE => basename($path) . '.XXXX',
            UNLINK => 0,
        );
        unlink("$newfile_handle");  # Delete it, or it will block the copy.
        push(@file_args, "$newfile_handle");
    }
    push(@cmds, $cmds_getter->($attrib_ref, $keep_local, \@file_args));

    # Run the actions, including any subroutine references.
    for my $cmd_ref (@cmds) {
        $cmd_ref->();
    }
    # svn resolve.
    $attrib_ref->{svn}->call(qw{resolve --accept working}, $path);
}

# Tree conflicts: check if a file was renamed locally.
sub _cm_tree_conflict_get_local_rename {
    my ($attrib_ref, $wc_branch, $tree_full_filename, $ext_renamed_file) = @_;
    my $UTIL = $attrib_ref->{util};

    # Get the verbose log for the working copy.
    # Find the revision where the file was deleted, and store any copied
    # filenames at that revision, and since that revision.
    my ($d_rev, @rev_copied_filenames, $found_delete);
    my @since_copied_filenames;
    my $wc_log_ref = $attrib_ref->{svn}->get_log();
    ENTRY:
    for my $log_entry_ref (@{$wc_log_ref}) {
        $d_rev = $log_entry_ref->{'revision'};
        @rev_copied_filenames = ();
        for my $path_entry (@{$log_entry_ref->{'paths'}}) {
            if ($path_entry->{'copyfrom-path'}) {
                push(@rev_copied_filenames, $path_entry->{'path'});
                push(@since_copied_filenames, $path_entry->{'path'});
            }
            if (    $path_entry->{'path'} eq $tree_full_filename
                &&  $path_entry->{'action'} eq 'D'
            ) {
                $found_delete = 1;
            }
        }
        if ($found_delete) {
            last ENTRY;
        }
    }

    # We need to detect a copy and a deletion of the file to continue.
    if (!$found_delete || !@rev_copied_filenames) {
        return;
    }

    # Get rid of the branch name in our copied files
    for my $copied_file (@rev_copied_filenames) {
        $copied_file =~ s{^/$wc_branch/}{}msx;
    }
    for my $copied_file (@since_copied_filenames) {
        $copied_file =~ s{^/$wc_branch/}{}msx;
    }

    # Get the pre-existing working copy files.
    my @wc_files
        = grep {$_ && $_ =~ qr{[^/]$}msx}
            $attrib_ref->{svn}->stdout(qw{svn ls -R});

    # Examine the files added with history at the revision log.
    # A single rename will be detected here.
    my @result;
    COPIED_AT_REV_FILE:
    for my $file (@rev_copied_filenames) {
        if (!grep {$_ eq $file} @wc_files) {
            next COPIED_AT_REV_FILE;
        }
        my @log_entry_refs
            = @{$attrib_ref->{svn}->get_log($file . '@' . $d_rev)};
        my $search_name = $tree_full_filename;
        my $full_potential_rename = '/' . $wc_branch . '/' . $file;
        for my $log_entry_ref (@log_entry_refs) {
            for my $path_entry (@{$log_entry_ref->{'paths'}}) {
                if (    exists($path_entry->{'copyfrom-path'})
                    &&  $path_entry->{'copyfrom-path'} eq $tree_full_filename
                    &&  $path_entry->{'action'} eq 'A'
                    &&  $path_entry->{'path'} eq $full_potential_rename
                ) {
                    return $file;
                }
            }
        }
    }

    # If no rename was detected, there may have been more than one.
    # Get the logs for all current filenames that match copied filenames
    # since the deletion, according to the working copy log.

    # Warn if the number of files to be examined > the threshold.
    if (    @wc_files > $TREE_CONFLICT_WARN_FILES_THRESHOLD
        &&  @since_copied_filenames > $TREE_CONFLICT_WARN_FILES_THRESHOLD
    ) {
        my $tree_path = substr($tree_full_filename, length($wc_branch) + 2);
        $UTIL->event(
            FCM::Context::Event->CM_CONFLICT_TREE_TIME_WARN,
            $tree_path,
        );
    }
    WC_FILE:
    for my $file (@wc_files) {
        if (!grep {$_ eq $file} @since_copied_filenames) {
            next WC_FILE;
        }
        my @log_entry_refs = @{$attrib_ref->{svn}->get_log($file)};
        my $search_name = $tree_full_filename;
        my $full_potential_rename = '/' . $wc_branch . '/' . $file;
        for my $log_entry_ref (reverse(@log_entry_refs)) {
            my $revision = $log_entry_ref->{'revision'};
            for my $path_entry (@{$log_entry_ref->{'paths'}}) {
                if (    exists($path_entry->{'copyfrom-path'})
                    &&  $path_entry->{'copyfrom-path'} eq $search_name
                    &&  $path_entry->{'action'} eq 'A'
                ) {
                    $search_name = $path_entry->{'path'};
                    if (   $search_name eq $full_potential_rename
                        && $revision >= $d_rev
                    ) {
                        return $file;
                    }
                }
            }
        }
    }
    return;
}

# Return the tree conflict command related to fcm_graphic_merge.
sub _cm_tree_conflict_get_graphic_cmds {
    my ($attrib_ref, $key, $keep_local, $files_ref) = @_;
    my ($cfile, @rename_args) = @{$files_ref};
    if (!@rename_args) {
        return;
    }
    # Get the source argument subroutine reference, if it exists.
    my $get_srcs_func_ref = $TREE_CONFLICT_GET_GRAPHIC_SOURCES_FUNC_FOR{$key};
    if (!$get_srcs_func_ref) {
        return;
    }
    # Get the sources for the graphic merge files.
    my ($older_src, $merge_src, $working_src, $base)
        = $get_srcs_func_ref->($cfile, $keep_local, \@rename_args);

    # Set up the filenames.
    my ($older_url, $older_peg)
        = _cm_tree_conflict_source($attrib_ref, 'left', $older_src);
    my $mine = $base . '.working';
    my $older = $base . '.merge-left.r' . $older_peg;
    my ($merge_url, $merge_peg)
        = _cm_tree_conflict_source($attrib_ref, 'right', $merge_src);
    my $yours = $base . '.merge-right.r' . $merge_peg;
    # Set up the conflict files as in a text conflict.
    sub {
        $attrib_ref->{svn}->call(qw{export -q}, $older_url, $older);
        $attrib_ref->{svn}->call(qw{export -q}, $merge_url, $yours);
        copy($working_src, $mine);
        _cm_graphic_merge($attrib_ref, $base, $mine, $older, $yours);
        unlink($mine, $older, $yours);
    };
}

# Return the source-left or source-right url from svn info.
sub _cm_tree_conflict_source {
    my ($attrib_ref, $direction, $info_filename) = @_;
    my %info = %{$attrib_ref->{svn}->get_info($info_filename)->[0]};
    my ($source_url, $source_peg);
    if ($info{"tree-conflict:source-$direction:repos-url"}) {
        $source_url
            = $info{"tree-conflict:source-$direction:repos-url"}
            . '/'
            . $info{"tree-conflict:source-$direction:path-in-repos"};
        $source_peg = $info{"tree-conflict:source-$direction:revision"};
    }
    elsif ($direction eq 'right') {
        $source_url = $info{'wc-info:copy-from-url'};
        $source_peg = $info{'wc-info:copy-from-rev'};
    }
    ($source_url . '@' . $source_peg, $source_peg);
}

# Select the files needed for the xxdiff (local edit, incoming rename)
sub _cm_tree_conflict_get_graphic_sources_for_leir {
    my ($cfile, $keep_local, $renames) = @_;
    my $ext_rename = shift(@{$renames});
    (   $cfile,
        $ext_rename,
        $cfile,
        ($keep_local ? $cfile : $ext_rename),
    );
}

# Select the files needed for the xxdiff (local rename, incoming edit)
sub _cm_tree_conflict_get_graphic_sources_for_lrie {
    my ($cfile, $keep_local, $renames) = @_;
    my $local_rename = shift(@{$renames});
    (   $cfile,
        $cfile,
        $local_rename,
        $local_rename,
    );
}

# Select the files needed for the xxdiff (local rename, incoming rename)
sub _cm_tree_conflict_get_graphic_sources_for_lrir {
    my ($cfile, $keep_local, $renames) = @_;
    my ($local_rename, $ext_rename) = @{$renames};
    (   $cfile,
        $ext_rename,
        $local_rename,
        ($keep_local ? $local_rename : $ext_rename),
    );
}

# Return the actions needed to resolve 'local add, incoming add'
sub _cm_tree_conflict_get_actions_for_laia {
    my ($attrib_ref, $keep_local, $files_ref) = @_;
    my ($cfile, $new_name) = @{$files_ref};
    my ($url, $url_peg) = _cm_tree_conflict_source($attrib_ref, 'right', $cfile);
    my ($basename) = basename($cfile);
    my $cdir = dirname($cfile);
    sub {
        if (!$keep_local) {
            my $content = $attrib_ref->{svn}->stdout(qw{svn cat}, $url);
            $attrib_ref->{util}->file_save($cfile, $content);
        }
    };
}


# Return the actions needed to resolve 'local missing, incoming edit'
sub _cm_tree_conflict_get_actions_for_ldie {
    my ($attrib_ref, $keep_local, $files_ref) = @_;
    my ($cfile) = @{$files_ref};
    my ($url, $url_peg) = _cm_tree_conflict_source($attrib_ref, 'right', $cfile);
    my $cdir = dirname($cfile);
    sub {
        if (!$keep_local) {
            $attrib_ref->{svn}->call('copy', $url, "$cdir/");
        }
    };
}

# Return the actions needed to resolve 'local delete, incoming rename'
sub _cm_tree_conflict_get_actions_for_ldir {
    my ($attrib_ref, $keep_local, $files_ref) = @_;
    my ($cfile, $ext_rename) = @{$files_ref};
    sub {
        if ($keep_local) {
            $attrib_ref->{svn}->call('revert', $ext_rename);
            unlink($ext_rename);
        }
    };
}

# Return the actions needed to resolve 'local edit, incoming delete'
sub _cm_tree_conflict_get_actions_for_leid {
    my ($attrib_ref, $keep_local, $files_ref) = @_;
    my ($cfile) = @{$files_ref};
    sub {
        if (!$keep_local) {
            $attrib_ref->{svn}->call('delete', $cfile);
        }
    };
}

# Return the actions needed to resolve 'local edit, incoming replace'
sub _cm_tree_conflict_get_actions_for_leip {
    my ($attrib_ref, $keep_local, $files_ref) = @_;
    my ($cfile) = @{$files_ref};
    my ($url, $url_peg) = _cm_tree_conflict_source($attrib_ref, 'right', $cfile);
    my $cdir = dirname($cfile);
    sub {
        if (!$keep_local) {
            $attrib_ref->{svn}->call('delete', $cfile);
            $attrib_ref->{svn}->call('copy', $url, "$cdir/");
        }
    };
}

# Return the actions needed to resolve 'local edit, incoming rename'
sub _cm_tree_conflict_get_actions_for_leir {
    my ($attrib_ref, $keep_local, $files_ref) = @_;
    my ($cfile, $ext_rename) = @{$files_ref};
    sub {
        if ($keep_local) {
            $attrib_ref->{svn}->call('revert', $ext_rename);
            unlink($ext_rename);
        }
        else {
            $attrib_ref->{svn}->call('delete', $cfile);
        }
    };
}

# Return the actions needed to resolve 'local rename, incoming delete'
sub _cm_tree_conflict_get_actions_for_lrid {
    my ($attrib_ref, $keep_local, $files_ref) = @_;
    my ($cfile, $lcl_rename) = @{$files_ref};
    sub {
        if (!$keep_local) {
            $attrib_ref->{svn}->call('delete', $lcl_rename);
        }
    };
}

# Return the actions needed to resolve 'local rename, incoming edit'
sub _cm_tree_conflict_get_actions_for_lrie {
    my ($attrib_ref, $keep_local, $files_ref) = @_;
    my ($cfile, $lcl_rename) = @{$files_ref};
    sub {
        if (!$keep_local) {
            $attrib_ref->{svn}->call('rename', $lcl_rename, $cfile)
        }
    };
}

# Return the actions needed to resolve 'local rename, incoming rename'
sub _cm_tree_conflict_get_actions_for_lrir {
    my ($attrib_ref, $keep_local, $files_ref) = @_;
    my ($cfile, $lcl_rename, $ext_rename) = @{$files_ref};
    sub {
        if ($keep_local) {
            $attrib_ref->{svn}->call('revert', $ext_rename);
            unlink($ext_rename);
        }
        else {
            $attrib_ref->{svn}->call('delete', $lcl_rename);
        }
    };
}

# -----------------------------------------------------------------------------
# Stores the identifier of the type of tree conflict.
package FCM::System::CM::TreeConflictKey;
use base qw{FCM::Class::HASH};

# Creates the class.
# 'local' is the local change (e.g. edit or delete),
# 'incoming' is the external change (e.g. add or rename),
# 'type' is one of merge, switch, or update.
__PACKAGE__->class({'local' => '$', 'incoming' => '$', 'type' => '$'});

# Returns a label string of the form LXIY e.g. LEID for local edit,
# incoming delete.
sub as_string {
    my ($self) = shift();
    my $local = $self->get_local() eq 'replace'
        ? 'P' : uc(substr($self->get_local(), 0, 1));
    my $incoming = $self->get_incoming() eq 'replace'
        ? 'P' : uc(substr($self->get_incoming(), 0, 1));
    sprintf('L%sI%s', $local, $incoming);
}

1;
__END__

=head1 NAME

FCM::System::CM::ResolveConflicts

=head1 DESCRIPTION

Part of L<FCM::System::CM|FCM::System::CM>.

=head1 COPYRIGHT

Copyright (C) British Crown (Met Office) & Contributors..

=cut
