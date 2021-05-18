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
package FCM::System::Make::Build::Task::Compile::CXX;
use base qw{FCM::System::Make::Build::Task::Compile};

our %PROP_OF = (
    'cxx'               => 'g++',
    'cxx.defs'          => '',
    'cxx.flags'         => '',
    'cxx.flag-compile'  => '-c',
    'cxx.flag-define'   => '-D%s',
    'cxx.flag-include'  => '-I%s',
    'cxx.flag-omp'      => '',
    'cxx.flag-output'   => '-o%s',
    'cxx.include-paths' => '',
);

sub new {
    my ($class, $attrib_ref) = @_;
    bless(
        $class->SUPER::new(
            {name => 'cxx', prop_of => sub {return {%PROP_OF}}, %{$attrib_ref}},
        ),
        $class,
    );
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::Task::Compile::CXX

=head1 SYNOPSIS

    use FCM::System::Make::Build::Task::Compile::CXX;
    my $task = FCM::System::Make::Build::Task::Compile::CXX->new(\%attrib);
    $task->main($target);

=head1 DESCRIPTION

Wraps L<FCM::System::Make::Build::Task::Compile> to compile a C++ source into an
object.

=head1 COPYRIGHT

Copyright (C) British Crown (Met Office) & Contributors..

=cut
