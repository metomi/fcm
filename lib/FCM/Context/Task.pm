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
package FCM::Context::Task;
use base qw{FCM::Class::HASH};

use constant {
    ST_FAILED  => 'ST_FAILED',
    ST_OK      => 'ST_OK',
    ST_WORKING => 'ST_WORKING',
};

__PACKAGE__->class({
    ctx      => {},
    error    => {},
    id       => '$',
    elapse   => {isa => '$', default => 0},
    state    => {isa => '$', default => ST_WORKING},
});
# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Context::Task

=head1 SYNOPSIS

    use FCM::Context::Task;
    my $task = FCM::Context::Task->new(\%attrib);

=head1 DESCRIPTION

An instance of this class represents the generic context for a task for the
L<FCM::Util->task_runner()|FCM::Util>. This class is a sub-class of
L<FCM::Class::HASH|FCM::Class::HASH>.

=head1 ATTRIBUTES

=over 4

=item ctx

The specific context of the task, such as the inputs and the outputs.

=item error

If the task failed, the error/exception will be returned in this attribute.

=item id

The ID of the task.

=item elapse

The amount of time (in seconds) taken to run the task.

=item state

The state of the task. See L</CONSTANTS> for possible variables.

=back

=head1 CONSTANTS

=over 4

=item FCM::Context::Task->ST_FAILED

A status to indicate that the task has failed.

=item FCM::Context::Task->ST_OK

A status to indicate that the task is completed successfully.

=item FCM::Context::Task->ST_WORKING

A status to indicate that the task is bing worked on.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
