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
package FCM::Context::Make::Mirror;
use base qw{FCM::Class::HASH};

use FCM::Context::Make;

use constant {ID_OF_CLASS => 'mirror'};

__PACKAGE__->class({
    dest           => '$',
    id             => {isa => '$', default => ID_OF_CLASS},
    id_of_class    => {isa => '$', default => ID_OF_CLASS},
    prop_of        => '%',
    status         => {isa => '$', default => FCM::Context::Make->ST_UNKNOWN},
    target_logname => '$',
    target_machine => '$',
    target_path    => '$',
});

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Context::Make::Mirror

=head1 SYNOPSIS

    use FCM::Context::Make::Mirror;
    my $ctx = FCM::Context::Make::Mirror->new();
    $ctx->set_dest_path($dest_path);
    $ctx->set_source_path($source_path);
    # ...

=head1 DESCRIPTION

Provides a context object for the mirror sub-system.

=head1 ATTRIBUTES

This class is based on L<FCM::Class::HASH|FCM::Class::HASH>. All attributes are
accessible via $ctx->get_$attrib() and $ctx->set_$attrib($value) methods.

=over 4

=item dest

The local working directory for the mirror sub-system.

=item id

The ID of the context. (default="mirror")

=item id_of_class

The class ID of the context. (default="mirror")

=item prop_of

A HASH containing the named properties (i.e. options and settings of named
external tools). Expects a value to be an instance of
L<FCM::Context::Make::Share::Property|FCM::Context::Make::Share::Property>.

=item status

The status of the context. See L<FCM::Context::Make|FCM::Context::Make> for the
status constants.

=item target_logname

The logname part of the authority of the mirror destination.

=item target_machine

The machine part of the authority of the mirror destination.

=item target_path

The container path of the mirror destination (without the authority).

=back

=head1 CONSTANTS

=over 4

=item ID_OF_CLASS

The default value of the "id" attribute (of an instance), and the ID of the
functional class. ("mirror")

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
