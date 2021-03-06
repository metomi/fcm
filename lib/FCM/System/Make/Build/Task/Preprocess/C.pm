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
package FCM::System::Make::Build::Task::Preprocess::C;
use base qw{FCM::System::Make::Build::Task::Preprocess};

our %PROP_OF = (
    'cpp'               => 'cpp',
    'cpp.defs'          => '',
    'cpp.flags'         => '',
    'cpp.flag-define'   => '-D%s',
    'cpp.flag-include'  => '-I%s',
    'cpp.include-paths' => '',
);

sub new {
    my ($class, $attrib_ref) = @_;
    bless(
        $class->SUPER::new(
            {name => 'cpp', prop_of => {%PROP_OF}, %{$attrib_ref}},
        ),
        $class,
    );
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::Task::Preprocess::C

=head1 SYNOPSIS

    use FCM::System::Make::Build::Task::Preprocess::C;
    my $task = FCM::System::Make::Build::Task::Preprocess::C->new(\%attrib);
    $task->main($target);

=head1 DESCRIPTION

Wraps L<FCM::System::Make::Build::Task::Preprocess> to preprocess a C source.

=head1 COPYRIGHT

Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.

=cut
