# ------------------------------------------------------------------------------
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
# ------------------------------------------------------------------------------
use strict;
use warnings;

package FCM1::Exception;
use overload (q{""} => \&as_string);

use Scalar::Util qw{blessed};

# ------------------------------------------------------------------------------
# Returns true if $e is a blessed instance of this class.
sub caught {
    my ($class, $e) = @_;
    return (blessed($e) && $e->isa($class));
}

# ------------------------------------------------------------------------------
# Constructor
sub new {
    my ($class, $args_ref) = @_;
    return bless(
        {message => q{unknown problem}, ($args_ref ? %{$args_ref} : ())},
        $class,
    );
}

# ------------------------------------------------------------------------------
# Returns a string representation of this exception
sub as_string {
    my ($self) = @_;
    return sprintf("%s: %s\n", blessed($self), $self->get_message());
}

# ------------------------------------------------------------------------------
# Returns the message of this exception
sub get_message {
    my ($self) = @_;
    return $self->{message};
}

1;
__END__

=head1 NAME

FCM1::Exception

=head1 SYNOPSIS

    use FCM1::Exception;
    eval {
        croak(FCM1::Exception->new({message => $message}));
    };
    if ($@) {
        if (FCM1::Exception->caught($@)) {
            print({STDERR} $@);
        }
    }

=head1 DESCRIPTION

This exception is raised when there is a generic problem in FCM.

=head1 METHODS

=over 4

=item $class->caught($e)

Returns true if $e is a blessed instance of this class.

=item $class->new({message=E<gt>$message})

Returns a new instance of this exception. Its first argument must be a
reference to a hash containing the detailed I<message> of the exception.

=item $e->as_string()

Returns a string representation of this exception.

=item $e->get_message()

Returns the detailed message of this exception.

=back

=head1 COPYRIGHT

Copyright (C) British Crown (Met Office) & Contributors..

=cut
