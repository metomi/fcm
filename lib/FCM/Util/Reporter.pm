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
package FCM::Util::Reporter;
use base qw{FCM::Class::CODE};

use Scalar::Util qw{reftype};

use constant {TYPE_OUT => 1, TYPE_ERR => 2};

use constant {  DEFAULT => 1,
    FAIL  => 0, WARN    => 1,
    QUIET => 0, LOW     => 1, MEDIUM => 2, HIGH => 3, DEBUG => 4,
};

use constant {
    PREFIX_DONE => q{[done] },
    PREFIX_FAIL => q{[FAIL] },
    PREFIX_INFO => q{[info] },
    PREFIX_INIT => q{[init] },
    PREFIX_NULL => q{},
    PREFIX_QUIT => q{[quit] },
    PREFIX_WARN => q{[WARN] },
};

# Creates the class.
__PACKAGE__->class(
    {ctx_of => '%'},
    {   init => sub {
            my ($attrib_ref) = @_;
            %{$attrib_ref->{ctx_of}} = (
                stderr => FCM::Util::Reporter::Context->new_err(),
                stdout => FCM::Util::Reporter::Context->new(),
            );
        },
        action_of => {
            add_ctx           => \&_add_ctx,
            del_ctx           => \&_del_ctx,
            get_ctx           => \&_get_ctx,
            get_ctx_of_stderr => sub {$_[0]->{ctx_of}->{stderr}},
            get_ctx_of_stdout => sub {$_[0]->{ctx_of}->{stdout}},
            report            => \&_report,
        }
    },
);

# Adds a named reporter context.
sub _add_ctx {
    my ($attrib_ref, $key, @args) = @_;
    if (exists($attrib_ref->{ctx_of}->{$key})) {
        return;
    }
    $attrib_ref->{ctx_of}->{$key} = FCM::Util::Reporter::Context->new(@args);
}

# Deletes a named reporter context.
sub _del_ctx {
    my ($attrib_ref, $key) = @_;
    if (!exists($attrib_ref->{ctx_of}->{$key})) {
        return;
    }
    delete($attrib_ref->{ctx_of}->{$key});
}

# Returns a named reporter context.
sub _get_ctx {
    my ($attrib_ref, $key) = @_;
    if (!exists($attrib_ref->{ctx_of}->{$key})) {
        return;
    }
    $attrib_ref->{ctx_of}->{$key};
}

# Reports message.
sub _report {
    my ($attrib_ref, @args) = @_;
    if (!@args) {
        return;
    }
    my %option = (
        delimiter => "\n",
        level     => DEFAULT,
        prefix    => undef,
        type      => TYPE_OUT,
    );
    if (ref($args[0]) && reftype($args[0]) eq 'HASH') {
        %option = (%option, %{shift(@args)});
    }
    # Auto remove ctx with closed file handle
    while (my ($key, $ctx) = each(%{$attrib_ref->{ctx_of}})) {
        if (!defined(fileno($ctx->get_handle()))) {
            delete($attrib_ref->{ctx_of}->{$key});
        }
    }
    # Selects handles
    my @ctx_and_prefix_list
        =   map  {
                my $prefix = defined($option{prefix})
                    ? $option{prefix} : $_->get_prefix();
                if (ref($prefix) && reftype($prefix) eq 'CODE') {
                    $prefix = $prefix->($option{level}, $option{type});
                }
                [$_, $prefix],
            }
            grep {  (!$_->get_type() || $_->get_type() eq $option{type})
                &&  $_->get_verbosity() >= $option{level}
            }
            values(%{$attrib_ref->{ctx_of}});
    if (!@ctx_and_prefix_list) {
        return;
    }
    for my $arg (@args) {
        for (@ctx_and_prefix_list) {
            my ($ctx, $prefix) = @{$_};
            my $handle = $ctx->get_handle();
            if ($option{delimiter}) {
                for my $item (
                    map {grep {$_ ne "\n"} split(qr{(\n)}msx)} (
                          !ref($arg)               ? ($arg)
                        : reftype($arg) eq 'ARRAY' ? @{$arg}
                        : reftype($arg) eq 'CODE'  ? $arg->($ctx->get_verbosity())
                        :                            ($arg)
                    )
                ) {
                    print({$handle} $prefix . $item . $option{delimiter});
                }
            }
            else {
                print({$handle} $arg);
            }
        }
    }
    1;
}

# ------------------------------------------------------------------------------
package FCM::Util::Reporter::Context;
use base qw{FCM::Class::HASH};

# Creates the class.
__PACKAGE__->class(
    {   handle    => {isa => '*', default => \*STDOUT                     },
        prefix    => {            default => sub {\&_prefix}              },
        type      => {isa => '$', default => FCM::Util::Reporter->TYPE_OUT},
        verbosity => {isa => '$', default => FCM::Util::Reporter->DEFAULT },
    },
);

# Returns a new reporter context to STDERR.
sub new_err {
    my ($class, $attrib_ref) = @_;
    $class->new({
        handle => \*STDERR,
        type   => FCM::Util::Reporter->TYPE_ERR,
        (defined($attrib_ref) ? %{$attrib_ref} : ()),
    });
}

# The default prefix function.
sub _prefix {
    my ($level, $type) = @_;
      $type eq FCM::Util::Reporter->TYPE_OUT ? FCM::Util::Reporter->PREFIX_INFO
    : $level > FCM::Util::Reporter->FAIL     ? FCM::Util::Reporter->PREFIX_WARN
    :                                          FCM::Util::Reporter->PREFIX_FAIL
    ;
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Reporter

=head1 SYNOPSIS

    use FCM::Util::Reporter;
    $reporter = FCM::Util::Reporter->new({verbosity => $verbosity});
    $reporter->($message);
    $reporter->(\@messages);
    $reporter->(sub {return @some_strings});
    $reporter->({level => $reporter->MEDIUM}, $message);

=head1 DESCRIPTION

A simple message reporter.

This module is part of L<FCM::Util|FCM::Util>. See also the description of the
$u->report() method in L<FCM::Util|FCM::Util>.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Returns a new instance of this class, which is a CODE reference. %attrib can
contain the following:

=over 4

=item ctx_of

A HASH containing a map to the named reporter contexts. At initialisation, a new
ctx for "stdout" and a new ctx for "stderr" is created automatically.

=back

=item $reporter->add_ctx($key,%option)

Creates a new reporter context, and adds it to the ctx_of HASH, if a context
with the same $key does not already exist. The %option is given to the
constructir of L</FCM::Util::Reporter::Context>. Return the context on success.

=item $reporter->del_ctx($key)

Removes a new reporter context named $key. Return the context on success.

=item $reporter->get_ctx($key)

Returns a named reporter context L</FCM::Util::Reporter::Context>.

=item $reporter->get_ctx_of_stderr()

Shorthand for $reporter->get_ctx('stderr').

=item $reporter->get_ctx_of_stdout()

Shorthand for $reporter->get_ctx('stdout').

=item $reporter->report(\%option,$message)

Reports the message. If %option is not given, reports using the default options.
In the form, the following %options can be specified:

=over 4

=item delimiter

The delimiter of each message in the list. The default is "\n". If the delimiter
is set to the empty string, the items in $message will be treated as raw
strings, i.e. it will also ignore any "prefix" options.

=item level

The level of the current message. The default is DEFAULT.

=item prefix

The message prefix. It can be a string or a CODE reference. If it is a string,
it is simply preprended to the message. If it is a code reference, it is calls
as $prefix_ref->($option{level}, $option{type}), and its result (if defined) is
prepended to the message.

=item type

The message type. It can be REPORT_ERR or REPORT_OUT (default).

=back

=back

=head1 CONSTANTS

=over 4

=item $reporter->FAIL, $reporter->QUIET

The verbosity level 0.

=item $reporter->DEFAULT, $reporter->LOW, $reporter->WARN

The verbosity level 1.

=item $reporter->MEDIUM

The verbosity level 2.

=item $reporter->HIGH

The verbosity level 3.

=item $reporter->DEBUG

The verbosity level 4.

=item $reporter->PREFIX_DONE

The prefix for a task "done" message.

=item $reporter->PREFIX_FAIL

The prefix for a fatal error message.

=item $reporter->PREFIX_INFO

The prefix for an "info" message.

=item $reporter->PREFIX_INIT

The prefix for a task "init" message.

=item $reporter->PREFIX_NULL

An empty string.

=item $reporter->PREFIX_QUIT

The prefix for a quit/abort message.

=item $reporter->PREFIX_WARN

The prefix for a warning message.

=item $reporter->REPORT_ERR

The message type for exception message.

=item $reporter->REPORT_OUT

The message type for info message.

=back

=head1 FCM::Util::Reporter::Context

An instance of this class represents the context for a reporter for the
L<FCM::Util->report()|FCM::Util>. This class is a sub-class of
L<FCM::Class::HASH|FCM::Class::HASH>. It has the following attributes:

=over 4

=item handle

The file handle for info messages. (Default=\*STDOUT)

=item prefix

The message prefix. It can be a string or a CODE reference. If it is a string,
it is simply preprended to the message. If it is a code reference, it is calls
as $prefix_ref->($option{level}, $option{type}), and its result (if defined) is
prepended to the message. The default is a CODE that returns PREFIX_INFO for
TYPE_OUT messages, PREFIX_WARN for TYPE_ERR messages at WARN level or above or
PREFIX_FAIL for TYPE_ERR messages at FAIL level.

=item type

Reporter type. (Default=TYPE_OUT)

=item verbosity

The verbosity of the reporter. Only messages at a level above or equal to the
verbosity will be reported. The default is DEFAULT.

=back


=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
