# ------------------------------------------------------------------------------
# Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.
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
package FCM::System::Make::Build::Task::Link::Fortran;
use base qw{FCM::System::Make::Build::Task::Link};

use FCM::System::Make::Build::Task::Compile::Fortran;

our %PROP_OF = (
    %FCM::System::Make::Build::Task::Link::PROP_OF,
    (   map {$_ => $FCM::System::Make::Build::Task::Compile::Fortran::PROP_OF{$_}}
        qw{fc fc.flag-omp fc.flag-output}
    ),
    'fc.flags-ld'      => '',
    'fc.flag-lib'      => '-l%s',
    'fc.flag-lib-path' => '-L%s',
    'fc.libs'          => '',
    'fc.lib-paths'     => '',
);

sub new {
    my ($class, $attrib_ref) = @_;
    bless(
        $class->SUPER::new(
            {name => 'fc', prop_of => {%PROP_OF}, %{$attrib_ref}},
        ),
        $class,
    );
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::Task::Link::Fortran

=head1 SYNOPSIS

    use FCM::System::Make::Build::Task::Link::Fortran;
    my $task = FCM::System::Make::Build::Task::Link::Fortran->new(\%attrib);
    $task->main($target);

=head1 DESCRIPTION

Wraps L<FCM::System::Make::Build::Task::Link> to link a Fortran object into an
executable.

=head1 COPYRIGHT

Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.

=cut
