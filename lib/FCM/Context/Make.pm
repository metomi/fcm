# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-15 Met Office.
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
package FCM::Context::Make;
use base qw{FCM::Class::HASH};

use constant {
    ST_UNKNOWN =>  0,
    ST_INIT    =>  1,
    ST_OK      =>  2,
    ST_FAILED  => -1,
};

__PACKAGE__->class({
    ctx_of            => '%',
    dest              => '$',
    dest_lock         => '$',
    error             => {},
    inherit_ctx_list  => '@',
    option_of         => '%',
    prev_ctx          => __PACKAGE__,
    status            => {isa => '$', default => ST_UNKNOWN},
    steps             => '@',
});

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Context::Make

=head1 SYNOPSIS

    use FCM::Context::Make;
    my $ctx = FCM::Context::Make->new();

=head1 DESCRIPTION

Provides a context object for the FCM make system. It is a sub-class of
L<FCM::Class::HASH|FCM::Class::HASH>.

=head1 OBJECTS

=head2 FCM::Context::Make

An instance of this class represents a make. It has the following
attributes:

=over 4

=item ctx_of

A HASH containing the (keys) IDs and the (values) context objects of the make.

=item dest

The destination of this make.

=item dest_lock

The destination lock of this make.

=item error

This should be set to the value of the exception, if this make ends in one.

=item inherit_ctx_list

An ARRAY of contexts inherited by this make.

=item option_of

A HASH to store the options of this make. See L</OPTION> for detail.

=item status

The status of the make.

=item steps

The names of the steps to make.

=back

=head1 OPTION

The C<option_of> attribute of a FCM::Context::Make object may contain the
following elements:

=over 4

=item config-file

An ARRAY of configuration file names.

=item directory

The working directory of the make.

=item ignore-lock

Ignores lock file in the destination.

=item jobs

The number of (child) threads that can be run simultaneously.

=item new

Performs a make in "new" mode (as opposed to the "incremental" mode).

=back

=head1 CONSTANTS

=over 4

=item FCM::Context::Make->ST_UNKNOWN

The status of a make context or the context of a subsystem. Status is unknown.

=item FCM::Context::Make->ST_INIT

The status of a make context or the context of a subsystem. The make or the
subsystem has initialised, but not completed.

=item FCM::Context::Make->ST_OK

The status of a make context or the context of a subsystem. The make or the
subsystem has completed successfully.

=item FCM::Context::Make->ST_FAILED

The status of a make context or the context of a subsystem. The make or the
subsystem has failed.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
