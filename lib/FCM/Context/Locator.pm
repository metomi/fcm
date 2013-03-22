# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-2013 Met Office.
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
package FCM::Context::Locator;
use base qw{FCM::Class::HASH};

use constant {
    L_INIT       => -1,
    L_PARSED     =>  0,
    L_NORMALISED =>  1,
    L_INVARIANT  =>  2,
};

__PACKAGE__->class(
    {   last_mod_rev  => '$',
        last_mod_time => '$',
        type          => '$',
        value         => '$',
        value_at_init => {isa => '$', i => 1, w => 0},
        value_level   => {isa => '$', default => L_INIT},
    },
    {   init_attrib => sub {
            my ($value, $attrib_ref) = @_;
            return {
                (defined($attrib_ref) ? %{$attrib_ref} : ()),
                value         => $value,
                value_at_init => $value,
            };
        },
    }
);

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Context::Locator

=head1 SYNOPSIS

    use FCM::Context::Locator;
    $locator = FCM::Context::Locator->new($value_at_init, {type => $type});
    $locator->set_value($value);
    $locator->set_value_level($locator->L_INVARIANT);
    print($locator->get_value(), "\n");

=head1 DESCRIPTION

A simple structure for storing the values of a FCM locator. It is based on
L<FCM::Class::HASH|FCM::Class::HASH>.

=head1 ATTRIBUTES

An instance has the following attributes, all of which can be initialised and
accessed via an $instance->get_$attrib() method:

=over 4

=item last_mod_rev

The last modified revision.

=item last_mod_time

The last modified time (seconds since epoch).

=item type

The locator type.

=item value

The current value of the locator.

=item value_at_init

The value of the locator when the object is initialised.

=item value_level

The value level of the locator. It can be one of the L_* constants. A higher
level indicates that the value is more processed.

=back

=head1 METHODS

=over 4

=item $class->new($value,\%attrib)

Returns a new instance.

=head1 CONSTANTS

=over 4

=item FCM::Context::Locator->L_INIT

The lowest value level, i.e. the value has not been processed. (default)

=item FCM::Context::Locator->L_PARSED

The value level is between L_INIT and L_NORMALISED, i.e. where necessary, the
FCM location keyword is substituted.

=item FCM::Context::Locator->L_NORMALISED

The value level is between L_PARSED and L_INVARIANT, i.e. where necessary, the
FCM location and revision keywords are substituted and the value has been tidied
(e.g. extra slashes in the path removed).

=item FCM::Context::Locator->L_INVARIANT

The highest value level, i.e. if the locator points to a version control
resource, the value is expected to be tagged with a specific revision.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
