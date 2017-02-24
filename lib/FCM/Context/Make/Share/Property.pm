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
# ------------------------------------------------------------------------------
package FCM::Context::Make::Share::Property;
use base qw{FCM::Class::HASH};

use constant {
    CTX_VALUE  => 'FCM::Context::Make::Share::Property::Value',
    NS_OF_ROOT => q{},
};

__PACKAGE__->class({ctx_of => '%', id => '$'});

sub get_ctx {
    $_[0]->get_ctx_of(NS_OF_ROOT);
}

sub set_ctx {
    $_[0]->get_ctx_of()->{$_[0]->NS_OF_ROOT} = $_[1];
}

# ------------------------------------------------------------------------------
package FCM::Context::Make::Share::Property::Value;
use base qw{FCM::Class::HASH};

__PACKAGE__->class({inherited => '$', value => '$'});

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Context::Make::Share::Property

=head1 SYNOPSIS

    use FCM::Context::Make::Share::Property;
    $prop = FCM::Context::Make::Share::Property->new(\%attrib);

=head1 DESCRIPTION

Provides a context object to store the property of a named shell command.

=head1 OBJECTS

The classes described below are all sub-classes of
L<FCM::Class::HASH|FCM::Class::HASH>.

=head2 FCM::Context::Make::Share::Property

This class represents a property. It has the following attributes:

=over 4

=item ctx_of

A HASH to map (keys) the name-spaces to (values) the contexts of this property.
Expects each context to be an instance of
L</FCM::Context::Make::Share::Property::Value>.

The context of a simple property is stored in the root (i.e. the empty string)
name-space.

=item id

The ID of this property.

=back

An instance of FCM::Context::Make::Share::Property has 2 additional methods:

=over 4

=item $instance->get_ctx()

Shorthand for:

    $instance->get_ctx_of(q{}).

=item $instance->set_ctx($ctx)

Shorthand for:

    $instance->get_ctx_of()->{q{}} = $ctx.

=back

=head2 FCM::Context::Make::Share::Property::Value

This class represents a property value (associated with a name-space). It has
the following attributes:

=over 4

=item inherited

A flag, if true, indicates that this value is inherited.

=item value

The value.

=back

=head1 CONSTANTS

=over 4

=item FCM::Context::Make::Share::Property->NS_OF_ROOT

The root name-space, an empty string.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
