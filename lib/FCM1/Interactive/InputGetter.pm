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

package FCM1::Interactive::InputGetter;

use Carp qw{croak};

################################################################################
# Constructor
sub new {
    my ($class, $args_ref) = @_;
    return bless({%{$args_ref}}, $class);
}

################################################################################
# Methods: get_*
for my $key (
    ############################################################################
    # Returns the title of the prompt
    'title',
    ############################################################################
    # Returns the message of the prompt
    'message',
    ############################################################################
    # Returns the of the prompt
    'type',
    ############################################################################
    # Returns the default return value
    'default',
) {
    no strict qw{refs};
    my $getter = "get_$key";
    *$getter = sub {
        my ($self) = @_;
        return $self->{$key};
    }
}

################################################################################
# Invokes the getter
sub invoke {
    my ($self) = @_;
    croak("FCM1::Interactive::InputGetter->invoke() not implemented.");
}

1;
__END__

=head1 NAME

FCM1::Interactive::TxtInputGetter

=head1 SYNOPSIS

    use FCM1::Interactive::TxtInputGetter;
    $answer = FCM1::Interactive::get_input(
        title   => 'My title',
        message => 'Would you like to ...?',
        type    => 'yn',
        default => 'n',
    );

=head1 DESCRIPTION

An object of this abstract class is used by
L<FCM1::Interactive|FCM1::Interactive> to get a user reply.

=head1 METHODS

=over 4

=item new($args_ref)

Constructor, normally invoked via L<FCM1::Interactive|FCM1::Interactive>.

Input options are: I<title>, for a short title of the prompt, I<message>, for
the message prompt, I<type> for the prompt type, and I<default> for the default
value of the return value.

Prompt type can be YN (yes or no), YNA (yes, no or all) or input (for an input
string).

=item get_title()

Returns the title of the prompt.

=item get_message()

Returns the message of the prompt.

=item get_type()

Returns the type of the prompt, can be YN (yes or no), YNA (yes, no or all) or
input (for an input string).

=item get_default()

Returns the default return value of invoke().

=item invoke()

Gets an input string from the user, and returns it. Sub-classes must override
this method.

=back

=head1 SEE ALSO

L<FCM1::Interactive|FCM1::Interactive>,
L<FCM1::Interactive::TxtInputGetter|FCM1::Interactive::TxtInputGetter>,
L<FCM1::Interactive::GUIInputGetter|FCM1::Interactive::GUIInputGetter>

=head1 COPYRIGHT

Copyright (C) British Crown (Met Office) & Contributors..

=cut
