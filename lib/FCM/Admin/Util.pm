# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-17 Met Office.
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
# ------------------------------------------------------------------------------

use strict;
use warnings;

package FCM::Admin::Util;

use Exporter qw{import};
use FCM::Admin::Config;
use FCM::Admin::Runner;
use File::Basename qw{dirname};
use File::Copy qw{copy};
use File::Path qw{mkpath rmtree};
use IO::File;
use SVN::Client;

our @EXPORT_OK = qw{
    option2config
    read_file
    run_copy
    run_create_archive
    run_extract_archive
    run_mkpath
    run_rename
    run_rmtree
    run_rsync
    run_svn_info
    run_svn_update
    run_symlink
    sed_file
    write_file
};

my @HTML2PS = qw{html2ps -n -U -W b};
my @PS2PDF  = qw{
    ps2pdf
    -dMaxSubsetPct=100
    -dCompatibilityLevel=1.3
    -dSubsetFonts=true
    -dEmbedAllFonts=true
    -dAutoFilterColorImages=false
    -dAutoFilterGrayImages=false
    -dColorImageFilter=/FlateEncode
    -dGrayImageFilter=/FlateEncode
    -dMonoImageFilter=/FlateEncode
    -sPAPERSIZE=a4
};

# ------------------------------------------------------------------------------
# Loads values of an option hash into the configuration.
sub option2config {
    my ($option_ref) = @_;
    my $config = FCM::Admin::Config->instance();
    for my $key (keys(%{$option_ref})) {
        my $method = $key;
        $method =~ s{-}{_}gxms;
        $method = "set_$method";
        if ($config->can($method)) {
            $config->$method($option_ref->{$key});
        }
    }
    return 1;
}

# ------------------------------------------------------------------------------
# Reads lines from a file.
sub read_file {
    my ($path, $sub_ref) = @_;
    my $file = IO::File->new($path);
    if (!defined($file)) {
        die("$path: cannot open for reading ($!).\n");
    }
    while (my $line = $file->getline()) {
        $sub_ref->($line);
    }
    $file->close() || die("$path: cannot close for reading ($!).\n");
    return 1;
}

# ------------------------------------------------------------------------------
# Runs copy with checks and diagnostics.
sub run_copy {
    my ($source_path, $dest_path) = @_;
    FCM::Admin::Runner->instance()->run(
        "copy $source_path to $dest_path",
        sub {
            my $mode = (stat($source_path))[2];
            my $rc = copy($source_path, $dest_path) && chmod($mode, $dest_path);
            if (!$rc) {
                die($!);
            }
            return $rc;
        },
    );
}

# ------------------------------------------------------------------------------
# Creates a TAR-GZIP archive.
sub run_create_archive {
    my ($archive_path, $work_dir, @base_names) = @_;
    FCM::Admin::Runner->instance()->run(
        "creating archive $archive_path",
        sub {
            my $command
                = qq{tar -c -z -C '$work_dir' -f -}
                . q{ } . join(q{ }, map {qq{'$_'}} @base_names)
                . qq{ | dd 'conv=fsync' 'of=$archive_path'};
            return !system($command);
            # Note: can use Archive::Tar, but "tar" is much faster.
        },
    );
}

# ------------------------------------------------------------------------------
# Extracts from a TAR-GZIP archive.
sub run_extract_archive {
    my ($archive_path, $work_dir) = @_;
    FCM::Admin::Runner->instance()->run(
        "extracting archive $archive_path",
        sub {
            return !system(
                qw{tar -x -z},
                q{-C} => $work_dir,
                q{-f} => $archive_path,
            );
            # Note: can use Archive::Tar, but "tar" is much faster.
        },
    );
}

# ------------------------------------------------------------------------------
# Runs mkpath with checks and diagnostics.
sub run_mkpath {
    my ($path) = @_;
    if (!-d $path) {
        FCM::Admin::Runner->instance()->run(
            "creating $path",
            sub {return mkpath($path)},
        );
    }
    return 1;
}

# ------------------------------------------------------------------------------
# Runs rename with checks and diagnostics.
sub run_rename {
    my ($source_path, $dest_path) = @_;
    FCM::Admin::Runner->instance()->run(
        "renaming $source_path to $dest_path",
        sub {
            run_mkpath(dirname($dest_path));
            my $rc = rename($source_path, $dest_path);
            if (!$rc) {
                die($!);
            }
            return $rc;
        },
    );
    return 1;
}

# ------------------------------------------------------------------------------
# Runs rmtree with checks and diagnostics.
sub run_rmtree {
    my ($path) = @_;
    if (-e $path) {
        FCM::Admin::Runner->instance()->run(
            "removing $path",
            sub {
                rmtree($path);
                return !-e $path;
            },
        );
    }
    return 1;
}

# ------------------------------------------------------------------------------
# Runs rsync.
sub run_rsync {
    my ($sources_ref, $dest_path, $option_list_ref) = @_;
    FCM::Admin::Runner->instance()->run(
        sprintf('mirroring %s <- %s', $dest_path, join(q{ }, @{$sources_ref})),
        sub {return !system(
            q{rsync},
            ($option_list_ref ? @{$option_list_ref} : ()),
            @{$sources_ref},
            $dest_path,
        )},
    );
    return 1;
}

# ------------------------------------------------------------------------------
# Runs "svn info".
sub run_svn_info {
    my ($path) = @_;
    my $return;
    my $ctx = SVN::Client->new();
    $ctx->info($path, undef, 'WORKING', sub {$return = $_[1]}, 0);
    return $return;
}

# ------------------------------------------------------------------------------
# Runs "svn update".
sub run_svn_update {
    my ($path) = @_;
    my @return;
    my $ctx = SVN::Client->new(
        notify => sub {
            if ($path ne $_[0]) {
                push(@return, $_[0]);
            }
        }
    );
    $ctx->update($path, 'HEAD', 1);
    return @return;
}

# ------------------------------------------------------------------------------
# Runs symlink with checks and diagnostics.
sub run_symlink {
    my ($source_path, $dest_path) = @_;
    FCM::Admin::Runner->instance()->run(
        "creating symlink: $source_path -> $dest_path",
        sub {
            my $rc = symlink($source_path, $dest_path);
            if (!$rc) {
                die($!);
            }
            return $rc;
        },
    );
    return 1;
}

# ------------------------------------------------------------------------------
# Edits content of a file.
sub sed_file {
    my ($path, $sub_ref) = @_;
    my @lines;
    read_file(
        $path,
        sub {
            my ($line) = @_;
            $line = $sub_ref->($line);
            push(@lines, $line);
        },
    );
    write_file($path, @lines);
}

# ------------------------------------------------------------------------------
# Writes content to a file.
sub write_file {
    my ($path, @contents) = @_;
    mkpath(dirname($path));
    my $file = IO::File->new($path, q{w});
    if (!defined($file)) {
        die("$path: cannot open for writing ($!).\n");
    }
    for my $content (@contents) {
        $file->print($content);
    }
    $file->close() || die("$path: cannot close for writing ($!).\n");
    return 1;
}

1;
__END__

=head1 NAME

FCM::Admin::Util

=head1 SYNOPSIS

    use FCM::Admin::Util qw{ ... };
    # ... see descriptions of individual functions for detail

=head1 DESCRIPTION

This module contains utility functions for the administration of Subversion
repositories and Trac environments hosted by the FCM team.

=head1 FUNCTIONS

=over 4

=item option2config($option_ref)

Loads the values of an option hash into
L<FCM::Admin::Config|FCM::Admin::Config>.

=item read_file($path,$sub_ref)

Reads from $path. For each $line the file, calls $sub_ref->($line).

=item run_copy($source_path,$dest_path)

Copies $source_path to $dest_path, with diagnostic.

=item run_create_archive($archive_path,$work_dir,@base_names)

Creates a TAR-GZIP archive at $archive_path using $work_dir as the working
directory and @base_names as members of the archive. Depends on GNU "tar" or
compatible.

=item run_extract_archive($archive_path,$work_dir)

Extracts a TAR-GZIP archive at $archive_path using $work_dir as the working
directory. Depends on GNU "tar" or compatible.

=item run_mkpath($path)

Creates $path if it does not already exist, with diagnostic.

=item run_rename($source_path,$dest_path)

Same as the core I<rename>, but with diagnostic.

=item run_rmtree($path)

Removes $path, with diagnostic.

=item run_rsync(\@sources,$dest_path,$option_list_ref)

Invokes the "rsync" shell command with diagnostics to mirror the paths in
@sources to $dest_path. Command line options can be specified in a list with
$option_list_ref. Depends on "rsync".

=item run_svn_info($path)

Wrapper of the info() method of L<SVN::Client|SVN::Client>. Expects $path to be
a Subversion working copy. Returns the C<svn_info_t> object as described by the
info() method of L<SVN::Client|SVN::Client>.

=item run_svn_update($path)

Wrapper of the update() method of L<SVN::Client|SVN::Client>. Expects $path to be
a Subversion working copy. Returns a list of updated paths.

=item run_symlink($source_path,$dest_path)

Same as the core I<symlink>, but with diagnostic.

=item sed_file($path,$sub_ref)

For each $line in $path, runs $line = $sub_ref->($line). Writes results back to
$path.

=item write_file($path,$content)

Writes $content to $path.

=back

=head1 SEE ALSO

L<FCM::Admin::Config|FCM::Admin::Config>,
L<FCM::Admin::Runner|FCM::Admin::Runner>,
L<SVN::Client|SVN::Client>

=head1 COPYRIGHT

E<169> Crown copyright Met Office. All rights reserved.

=cut
