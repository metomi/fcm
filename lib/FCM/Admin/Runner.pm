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

package FCM::Admin::Runner;

use IO::Handle;
use POSIX qw{strftime};

# The default values of the attributes
my %DEFAULT = (
    exceptions     => [],
    max_attempts   => 3,
    retry_interval => 5,
    stderr_handle  => \*STDERR,
    stdout_handle  => \*STDOUT,
);

my $INSTANCE;

# ------------------------------------------------------------------------------
# Returns a unique instance of this class. Creates the instance on first call.
sub instance {
    my ($class) = @_;
    if (!defined($INSTANCE)) {
        $INSTANCE = bless({%DEFAULT}, $class);
    }
    return $INSTANCE;
}

# ------------------------------------------------------------------------------
# Adds a new exception to the list of exceptions.
sub _add_exception {
    my ($self, $exception) = @_;
    push(@{$self->get_exceptions()}, $exception);
}

# ------------------------------------------------------------------------------
# Returns the list of exceptions (or a reference to the list in scalar context).
sub get_exceptions {
    my ($self) = @_;
    return (wantarray() ? @{$self->{exceptions}} : $self->{exceptions});
}

# ------------------------------------------------------------------------------
# Returns the latest exception in the exception list.
sub get_latest_exception {
    my ($self) = @_;
    if (exists($self->get_exceptions()->[-1])) {
        return $self->get_exceptions()->[-1];
    }
    else {
        return;
    }
}

# ------------------------------------------------------------------------------
# Returns the maximum number of attempts for the "run_with_retries" method.
sub get_max_attempts {
    my ($self) = @_;
    return $self->{max_attempts};
}

# ------------------------------------------------------------------------------
# Returns the retry interval for the "run_with_retries" method.
sub get_retry_interval {
    my ($self) = @_;
    return $self->{retry_interval};
}

# ------------------------------------------------------------------------------
# Returns the file handle for STDERR.
sub get_stderr_handle {
    my ($self) = @_;
    if (!IO::Handle::opened($self->{stderr_handle})) {
        $self->{stderr_handle} = $DEFAULT{stderr_handle};
    }
    return $self->{stderr_handle};
}

# ------------------------------------------------------------------------------
# Returns the file handle for STDOUT.
sub get_stdout_handle {
    my ($self) = @_;
    if (!IO::Handle::opened($self->{stdout_handle})) {
        $self->{stdout_handle} = $DEFAULT{stdout_handle};
    }
    return $self->{stdout_handle};
}

# ------------------------------------------------------------------------------
# Runs $sub_ref->(@arguments) with a diagnostic $message. Dies on error.
sub run {
    my ($self, $message, $sub_ref, @arguments) = @_;
    printf(
        {$self->get_stdout_handle()}
        qq{%s: %s\n}, strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()), $message,
    );
    eval {
        if (!$sub_ref->(@arguments)) {
            die(qq{\n});
        }
    };
    if ($@) {
        my $e = $@;
        chomp($e);
        my $exception
            = sprintf(qq{ERROR %s%s\n}, $message, ($e ? qq{ - $e} : qq{}));
        $self->_add_exception($exception);
        die($exception);
    }
    return 1;
}

# ------------------------------------------------------------------------------
# Runs $sub_ref->(@arguments) with a diagnostic $message. Warns on error.
sub run_continue {
    my ($self, $message, $sub_ref, @arguments) = @_;
    my $rc;
    eval {
        $rc = $self->run($message, $sub_ref, @arguments);
    };
    if ($@) {
        print({$self->get_stderr_handle()} $@);
        return;
    }
    return $rc;
}

# ------------------------------------------------------------------------------
# Runs $sub_ref->(@arguments) with a diagnostic $message. Retries on error.
sub run_with_retries {
    my ($self, $message, $sub_ref, @arguments) = @_;
    for my $i_attempt (1 .. $self->get_max_attempts()) {
        my $attempt_message = sprintf(
            qq{%s, attempt %d of %d},
            $message, $i_attempt, $self->get_max_attempts(),
        );
        if ($i_attempt == $self->get_max_attempts()) {
            return $self->run($attempt_message, $sub_ref, @arguments);
        }
        else {
            if ($self->run_continue($attempt_message, $sub_ref, @arguments)) {
                return 1;
            }
            sleep($self->get_retry_interval());
        }
    }
}

# ------------------------------------------------------------------------------
# Sets the maximum number of attempts for the "run_with_retries" method.
sub set_max_attempts {
    my ($self, $value) = @_;
    $self->{max_attempts} = $value;
}

# ------------------------------------------------------------------------------
# Sets the retry interval for the "run_with_retries" method.
sub set_retry_interval {
    my ($self, $value) = @_;
    $self->{retry_interval} = $value;
}

# ------------------------------------------------------------------------------
# Sets the file handle for STDERR.
sub set_stderr_handle {
    my ($self, $value) = @_;
    if (defined($value) && IO::Handle::opened($value)) {
        $self->{stderr_handle} = $value;
    }
}

# ------------------------------------------------------------------------------
# Sets the file handle for STDOUT.
sub set_stdout_handle {
    my ($self, $value) = @_;
    if (defined($value) && IO::Handle::opened($value)) {
        $self->{stdout_handle} = $value;
    }
}

1;
__END__

=head1 NAME

FCM::Admin::Runner

=head1 SYNOPSIS

    $runner = FCM::Admin::Runner->instance();
    $runner->run($message, sub { ... });

=head1 DESCRIPTION

Provides a simple way to run a piece of code with a time-stamped diagnostic
message.

=head1 METHODS

=over 4

=item FCM::Admin::Runner->instance()

Returns a unique instance of FCM::Admin::Runner.

=item $runner->get_exceptions()

Returns a list containing all the exceptions captured by the previous
invocations of the $runner->run() method. In SCALAR context, returns a reference
to the list.

=item $runner->get_latest_exception()

Returns the latest exception captured by the $runner->run() method. Returns
undef if there is no captured exception in the list.

=item $runner->get_max_attempts()

Returns the number of maximum retries for the
$runner->run_with_retries($message,$sub_ref,@arguments) method. (Default: 3)

=item $runner->get_retry_interval()

Returns the interval (in seconds) between retries for the
$runner->run_with_retries($message,$sub_ref,@arguments) method. (Default: 5)

=item $runner->get_stderr_handle()

Returns the file handle for standard error output. (Default: \*STDERR)

=item $runner->get_stdout_handle()

Returns the file handle for standard output. (Default: \*STDOUT)

=item $runner->run($message,$sub_ref,@arguments)

Prints the diagnostic $message and runs $sub_ref (with extra @arguments).
Returns true if $sub_ref returns true. die() with a message that looks like
"ERROR $message\n" if $sub_ref returns false or die().

=item $runner->run_continue($message,$sub_ref,@arguments)

Same as $runner->run($message,$sub_ref,@arguments), but only issue a warning
(and returns false) if $sub_ref returns false or die().

=item $runner->run_with_retries($message,$sub_ref,@arguments)

Attempts $runner->run($message,$sub_ref,@arguments) for a number of times up to
$runner->get_max_attempts(), with a delay of $runner->get_retry_interval()
between each attempt. die() if $sub_ref still returns false in the final
attempt. Returns true on success.

=item $runner->set_max_attempts($value)

Sets the maximum number of attempts in the
$runner->run_with_retries($message,$sub_ref,@arguments) method.

=item $runner->set_retry_interval($value)

Sets the interval (in seconds) between retries for the
$runner->run_with_retries($message,$sub_ref,@arguments) method.

=item $runner->set_stderr_handle($value)

Sets the file handle for standard error output to an alternate file handle. The
$value must be a valid file descriptor.

=item $runner->set_stdout_handle($value)

Sets the file handle for standard output to an alternate file handle. The $value
must be a valid file descriptor.

=back

=head1 COPYRIGHT

E<169> Crown copyright Met Office. All rights reserved.

=cut
