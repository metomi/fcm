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
# ------------------------------------------------------------------------------
package FCM::System::Make::Build::Task::Install;
use base qw{FCM::Class::CODE};

use FCM::System::Exception;
use File::Copy qw{copy};

my $E = 'FCM::System::Exception';

__PACKAGE__->class({util => '&'}, {action_of => {main => \&_main}});

sub _main {
    my ($attrib_ref, $target) = @_;
    my ($source, $dest) = ($target->get_path_of_source(), $target->get_path());
    if ($source) {
        copy($source, $dest) || return $E->throw($E->COPY, [$source, $dest], $!);
        chmod((stat($source))[2] & oct(7777), $dest)
            || return $E->throw($E->DEST_CREATE, $dest, $!);
    }
    else {
        $attrib_ref->{util}->file_save($dest, q{});
    }
    $target;
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::Task::Install

=head1 SYNOPSIS

    use FCM::System::Make::Build::Task::Install;
    my $build_task = FCM::System::Make::Build::Task::Install->new(\%attrib);
    $build_task->main( $target);

=head1 DESCRIPTION

Copies the source of the target to its path.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Creates and returns a new instance. %attrib should contain:

=over 4

=item {util}

An instance of L<FCM::Util|FCM::Util>.

=back

=item $instance->main($target)

Copies the source of the target to its path.

=back

=head1 COPYRIGHT

Copyright (C) British Crown (Met Office) & Contributors..

=cut
