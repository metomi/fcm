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

# Utility to manipulate FCM commit messages.
package FCM::System::CM::CommitMessage;
use base qw{FCM::Class::CODE};

use Cwd qw{cwd};
use FCM::Context::Event;
use FCM::System::Exception;
use File::Spec::Functions qw{catfile};
use File::Temp;
use Text::ParseWords qw{shellwords};

my $CTX = 'FCM::System::CM::CommitMessage::State';
my $E = 'FCM::System::Exception';

our $COMMIT_MESSAGE_BASE = '#commit_message#';
our $DELIMITER_USER
    = '--Add your commit message ABOVE - do not alter this line or those below--'
    . "\n";
our $DELIMITER_AUTO
    = '--FCM message (will be inserted automatically)--'
    . "\n";
our $DELIMITER_INFO
    = '--Change summary (not part of commit message)--'
    . "\n";
our $EDITOR = 'vi';
our $GEDITOR = 'gvim -f';
our $SUBVERSION_CONFIG_FILE = catfile((getpwuid($<))[7], qw{.subversion/config});

__PACKAGE__->class({gui => '$', util => '&'},
    {action_of => {
        'ctx'       => sub {$CTX->new()},
        'edit'      => \&_edit,
        'load'      => \&_load,
        'notify'    => \&_notify,
        'path'      => \&_path,
        'path_base' => sub {$COMMIT_MESSAGE_BASE},
        'save'      => \&_save,
        'temp'      => \&_temp,
    }},
);

# Invokes an editor to edit the commit message context.
sub _edit {
    my ($attrib_ref, $commit_message_ctx) = @_;
    my $UTIL = $attrib_ref->{'util'};
    my $temp = File::Temp->new();
    if ($commit_message_ctx->get_user_part()) {
        print($temp $commit_message_ctx->get_user_part());
    }
    else {
        print($temp "\n");
    }
    print($temp $DELIMITER_USER);
    if ($commit_message_ctx->get_auto_part()) {
        print($temp $DELIMITER_AUTO . $commit_message_ctx->get_auto_part());
    }
    print($temp $DELIMITER_INFO . $commit_message_ctx->get_info_part());
    close($temp) || die("$temp: $!\n");
    my $config_value;
    my $editor_command
        = $ENV{'SVN_EDITOR'} ? $ENV{'SVN_EDITOR'}
        : ($config_value = _svn_config_get($attrib_ref, 'helpers', 'editor-cmd'))
                             ? $config_value
        : $ENV{'VISUAL'}     ? $ENV{'VISUAL'}
        : $ENV{'EDITOR'}     ? $ENV{'EDITOR'}
        : $attrib_ref->{gui} ? $GEDITOR
        :                      $EDITOR
        ;
    $UTIL->event(FCM::Context::Event->CM_LOG_EDIT, $editor_command);
    my @command = (shellwords($editor_command), $temp->filename());
    !system(@command)
        || return $E->throw($E->SHELL, {command_list => \@command, rc => $?});
    # Note: cannot use FCM::Util->shell method for terminal based editor.
    #my %value_of = %{$attrib_ref->{'util'}->shell_simple(\@command)};
    #if ($value_of{'rc'}) {
    #    return $E->throw($E->SHELL, {command_list => \@command, %value_of});
    #}
    my $user_part = _parse(
        $attrib_ref,
        scalar($UTIL->file_load($temp->filename())),
        $DELIMITER_USER,
    );
    $commit_message_ctx->set_user_part($user_part);
    if (($user_part . $commit_message_ctx->get_auto_part()) =~ qr{\A\s*\z}msx) {
        return $E->throw($E->CM_LOG_EDIT_NULL);
    }
}

# Reads a commit message file from $path or the standard location. Returns a
# commit message context object.
sub _load {
    my ($attrib_ref, $path) = @_;
    $path ||= _path($attrib_ref);
    my ($user_part, $auto_part) = eval {
        _parse($attrib_ref, scalar($attrib_ref->{'util'}->file_load($path)));
    };
    if (my $e = $@) {
        $user_part = q{};
        $auto_part = q{};
        $@ = undef; # TODO: should raise a high verbosity event?
    }
    $CTX->new({'user_part' => $user_part, 'auto_part' => $auto_part});
}

# Raises an CM_COMMIT_MESSAGE event for the commit message.
sub _notify {
    my ($attrib_ref, $commit_message_ctx) = @_;
    $attrib_ref->{util}->event(
        FCM::Context::Event->CM_COMMIT_MESSAGE, $commit_message_ctx,
    );
}

# Parses a commit message into the user and auto parts. Returns the user part in
# scalar context. Returns (user_part, auto_part) in list context.
sub _parse {
    my ($attrib_ref, $message, $no_delimiter_user) = @_;
    my @parts = (q{}, q{});
    my $state = 0;
    LINE:
    for my $line (split("\n", $message)) {
        if ($state && !wantarray()) {
            last LINE;
        }
        $line .= "\n";
        if ($line eq $DELIMITER_INFO) {
            last LINE;
        }
        elsif ($line eq $DELIMITER_AUTO) {
            $state = 1;
            next LINE;
        }
        elsif ($line eq $DELIMITER_USER) {
            $no_delimiter_user = undef;
            $state = -1;
            next LINE;
        }
        if ($state >= 0) {
            $parts[$state] .= $line;
        }
    }
    if ($no_delimiter_user) {
        return $E->throw($E->CM_LOG_EDIT_DELIMITER, $DELIMITER_USER);
    }
    for my $part (@parts) {
        $part =~ s{\A\s*(.*?)\s*\z}{$1}msx;
        if ($part) {
            $part .= "\n";
        }
    }
    wantarray() ? @parts : $parts[0];
}

# Returns the path to the commit message file in the current working directory
# or the commit message file in $dir if $dir is set.
sub _path {
    my ($attrib_ref, $dir) = @_;
    catfile(($dir ? $dir : cwd()), $COMMIT_MESSAGE_BASE);
}

# Saves the commit message to $path or the standard location for later
# retrieval.
sub _save {
    my ($attrib_ref, $commit_message_ctx, $path) = @_;
    $path ||= _path($attrib_ref);
    my $string = $commit_message_ctx->get_user_part();
    if ($commit_message_ctx->get_auto_part()) {
        $string .= $DELIMITER_AUTO . $commit_message_ctx->get_auto_part();
    }
    $attrib_ref->{'util'}->file_save($path, $string);
}

# Returns a File::Temp object containing a commit message ready for the VCS.
sub _temp {
    my ($attrib_ref, $commit_message_ctx) = @_;
    my $temp = File::Temp->new();
    print($temp $commit_message_ctx->get_user_part());
    print($temp $commit_message_ctx->get_auto_part());
    close($temp) || die("$temp: $!\n");
    $temp;
}

# Loads a setting from $HOME/.subversion/config, and returns its value.
sub _svn_config_get {
    my ($attrib_ref, $section, $key) = @_;
    # Note: can use Config::IniFiles, but best to avoid another dependency.
    # Note: not very efficient logic here, but should not yet matter.
    my $handle = $attrib_ref->{'util'}->file_load_handle($SUBVERSION_CONFIG_FILE);
    my $is_in_section;
    my $value;
    LINE:
    while (my $line = readline($handle)) {
        chomp($line);
        if ($line =~ qr{\A\s*(?:[#;]|\z)}msx) {
            next LINE;
        }
        if ($line =~ qr{\A\s*\[\s*$section\s*\]\s*\z}msx) {
            $is_in_section = 1;
        }
        elsif ($line =~ qr{\A\s*\[}msx) {
            $is_in_section = 0;
        }
        elsif ($is_in_section) {
            my ($rhs) = $line =~ qr{\A\s*$key\s*=\s*(.*)\z}msx;
            if (defined($rhs)) {
                $value = $rhs;
            }
        }
    }
    close($handle);
    $value;
}

#-------------------------------------------------------------------------------
package FCM::System::CM::CommitMessage::State;
use base qw{FCM::Class::HASH};

__PACKAGE__->class({
    (map {($_ . '_part' => {isa => '$', default => q{}})} qw{auto info user}),
});

#-------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::CM::CommitMessage

=head1 SYNOPSIS

    use FCM::System::CM::CommitMessage;
    my $commit_message_util = FCM::System::CM::CommitMessage->new(\%attrib);
    my $commit_message_ctx = $commit_message_util->ctx();
    $commit_message_util->edit($ctx);

=head1 DESCRIPTION

The commit message dumper, editor, loader, parser, etc for the FCM code
management sub-system.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Return a new instance. This class should normally be initialised by
L<FCM::System::CM|FCM::System::CM>.

=item $commit_message_util->ctx()

Return a new and empty commit message context.

=item $commit_message_util->edit($commit_message_ctx)

Invoke an editor to edit the commit message context.

=item $commit_message_util->load($path)

Load the content of a commit message file in $path, and return the result in a
new commit message context.

=item $commit_message_util->notify($commit_message_ctx)

Raise a CM_COMMIT_MESSAGE event with the $commit_message_ctx.

=item $commit_message_util->path($dir)

Return the path to the commit message file in $dir or the current working
directory if $dir is not specified.

=item $commit_message_util->path($dir)

Return the base name of the commit message file.

=item $commit_message_util->save($commit_message_ctx, $path)

Save the commit message to $path (or the standard location if $path is not
specified).

=item $commit_message_util->temp()

Return a File::Temp object containing a commit message ready for the VCS.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
