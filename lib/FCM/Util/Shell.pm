# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-14 Met Office.
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

# ------------------------------------------------------------------------------
package FCM::Util::Shell;
use base qw{FCM::Class::CODE};

use FCM::Context::Event;
use FCM::Util::Exception;
use File::Spec::Functions qw{catfile file_name_is_absolute path};
use IPC::Open3 qw{open3};
use List::Util qw{first};
use Scalar::Util qw{reftype};
use Text::ParseWords qw{shellwords};

our $BUFFER_SIZE = 4096;  # default buffer size
our $TIME_OUT    = 0.005; # default time out for selecting a file handle

my $E = 'FCM::Util::Exception';
my %FUNCTION_OF = (e => \&_do_r, i => \&_do_w, o => \&_do_r);
my @IOE = qw{i o e};
my %ACTION_FUNC_FOR
    = (e => \&_action_func_r, i => \&_action_func_w, o => \&_action_func_r);

# Creates the class.
__PACKAGE__->class(
    {   buffer_size => {isa => '$', default => $BUFFER_SIZE},
        time_out    => {isa => '$', default => $TIME_OUT},
        util        => '&',
    },
    {   action_of => {
            invoke        => \&_invoke,
            invoke_simple => \&_invoke_simple,
            which         => \&_which,
        },
    },
);

# Returns a CODE to deal with non-CODE read action.
sub _action_func_r {
    my ($arg_ref) = @_;
    ${$arg_ref} ||= q{};
    sub {${$arg_ref} .= $_[0]};
}

# Returns a CODE to deal with non-CODE write action.
sub _action_func_w {
    my ($arg_ref) = @_;
    my @inputs
        = ref($arg_ref) && reftype($arg_ref) eq 'ARRAY'  ? @{$arg_ref}
        : ref($arg_ref) && reftype($arg_ref) eq 'SCALAR' ? (${$arg_ref})
        :                                                  ()
        ;
    sub {shift(@inputs)};
}

# Gets output $value from a selected handle, and invokes $action->($value).
sub _do_r {
    my ($attrib_ref, $ctx) = @_;
    my $n_bytes;
    while (
        my @handles = $ctx->get_select()->can_read($attrib_ref->{time_out})
    ) {
        my ($handle) = @handles;
        my $buffer = q{};
        my $n = sysread($handle, $buffer, $attrib_ref->{buffer_size});
        if (!defined($n)) {
            return;
        }
        $n_bytes += $n;
        if ($n == 0) {
            close($handle) || return;
            return 0;
        }
        $ctx->get_action()->($buffer);
    }
    defined($n_bytes) ? $n_bytes : -1;
}

# Gets input from $action->() and writes to a selected handle if possible.
# Handles buffering of STDIN to the command.
sub _do_w {
    my ($attrib_ref, $ctx) = @_;
    my $n_bytes;
    while (
        my @handles = $ctx->get_select()->can_write($attrib_ref->{time_out})
    ) {
        my ($handle) = @handles;
        if (!$ctx->get_buf()) {
            $ctx->set_buf($ctx->get_action()->());
            if (!defined($ctx->get_buf())) {
                close($handle) || return;
                return 0;
            };
            $ctx->set_buf_length(length($ctx->get_buf()));
            $ctx->set_buf_offset(0);
        }
        my $n = syswrite(
            $handle,
            $ctx->get_buf(),
            $attrib_ref->{buffer_size},
            $ctx->get_buf_offset(),
        );
        if (!defined($n)) {
            return;
        }
        $n_bytes += $n;
        $ctx->set_buf_offset($ctx->get_buf_offset() + $n);
        if ($ctx->get_buf_offset() >= $ctx->get_buf_length()) {
            $ctx->set_buf(undef);
            $ctx->set_buf_length(0);
            $ctx->set_buf_offset(0);
        }
    }
    defined($n_bytes) ? $n_bytes : -1;
}

# Invokes a command.
sub _invoke {
    my ($attrib_ref, $command_ref, $action_ref) = @_;
    # Ensure that the command is an ARRAY
    if (!ref($command_ref)) {
        $command_ref = [shellwords($command_ref)];
    }
    # Check that the command exists in the PATH
    if (!_which($attrib_ref, $command_ref->[0])) {
        return $E->throw($E->SHELL_WHICH, $command_ref);
    }
    # Sets up the STDIN, STDOUT and STDERR to the command
    my %ctx_of = map {($_, FCM::Util::Shell::Context->new())} @IOE;
    $action_ref ||= {};
    while (my ($key, $action) = each(%{$action_ref})) {
        if (exists($ctx_of{$key})) {
            if (reftype($action) eq 'CODE') {
                $ctx_of{$key}->set_action($action);
            }
            else {
                $ctx_of{$key}->set_action($ACTION_FUNC_FOR{$key}->($action));
            }
        }
    }
    # Calls the command with open3
    my $timer = $attrib_ref->{util}->timer();
    my $pid = eval {
        open3((map {$ctx_of{$_}->get_handle()} @IOE), @{$command_ref});
    };
    if (my $e = $@) {
        return $E->throw($E->SHELL_OPEN3, $command_ref, $e);
    }
    # Handles input/output of the command
    for my $ctx (values(%ctx_of)) {
        $ctx->get_select()->add($ctx->get_handle());
    }
    while (keys(%ctx_of)) {
        while (my ($key, $ctx) = each(%ctx_of)) {
            my $status = $FUNCTION_OF{$key}->($attrib_ref, $ctx);
            if (!defined($status)) {
                return $E->throw($E->SHELL_OS, $command_ref, $!);
            }
            if (!$status) {
                delete($ctx_of{$key});
            }
        }
    }
    # Wait for command to finish
    waitpid($pid, 0);
    my $rc = $?;
    $attrib_ref->{util}->event(
        FCM::Context::Event->SHELL, $command_ref, $rc, $timer->(),
    );
    # Handles exceptions and signals
    if ($rc) {
        if ($rc == -1) {
            return $E->throw($E->SHELL_OS, $command_ref, $!);
        }
        if ($rc & 127) {
            return $E->throw($E->SHELL_SIGNAL, $command_ref, $rc & 127);
        }
    }
    return $rc >> 8;
}

# Wraps _invoke.
sub _invoke_simple {
    my ($attrib_ref, $command_ref) = @_;
    my ($e, $o);
    my $rc = _invoke($attrib_ref, $command_ref, {e => \$e, o => \$o});
    return {e => $e, o => $o, rc => $rc};
}

# Returns the full path to the command $name, if it exists in the PATH.
sub _which {
    my ($attrib_ref, $name) = @_;
    if (file_name_is_absolute($name)) {
        return $name;
    }
    first {-f $_ && -x _} map {catfile($_, $name)} path();
}

# ------------------------------------------------------------------------------
package FCM::Util::Shell::Context;
use base qw{FCM::Class::HASH};

use IO::Select;
use Symbol qw{gensym};

# A context to hold the information for the command's STDIN, STDOUT or STDERR.
# action => CODE to call to get more STDIN for the command or to send
#           STDOUT/STDERR to when possible.
# buf*   => A buffer (and its length and the current offset) to hold the STDIN
#           that is yet to be written to the command.
# handle => The command STDIN, STDOUT or STDERR.
# select => The IO::Select object that tells us whether the handle is ready for
#           I/O or not.
__PACKAGE__->class(
    {   action     => {isa => '&'},
        buf        => {isa => '$'},
        buf_length => {isa => '$'},
        buf_offset => {isa => '$'},
        handle     => {isa => '*', default => \&gensym},
        'select'   => {isa => 'IO::Select', default => sub {IO::Select->new()}},
    },
);

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Util::Shell

=head1 SYNOPSIS

    use FCM::Util;
    $util = FCM::Util->new(\%attrib);
    %action_of = {e => \&e_handler, i => \&i_handler, o => \&o_handler};
    $rc = $util->shell(\@command, \%action_of);
    %value_of = %{$util->shell_simple(\@command)};

=head1 DESCRIPTION

Wraps L<IPC::Open3|IPC::Open3> to provide an interface driven by callbacks.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Returns a new instance. The attributes that can be specified in %attrib are:

=over 4

=item {buffer_size}

The size of the read buffer for reading from the standard output and standard
error output of the command. The default is 4096.

=item {time_out}

The time to wait when selecting a file handle. The default is 0.001.

=item {util}

A CODE reference. The L<FCM::Util|FCM::Util> object that initialised this
instance.

=back

=back

See the description of the shell(), shell_simpl() and shell_which() methods in
L<FCM::Util|FCM::Util> for detail.

=head1 SEE ALSO

L<IPC::Open3|IPC::Open3>

Inspired by the CPAN module L<IPC::Cmd|IPC::Cmd> and friends.

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
