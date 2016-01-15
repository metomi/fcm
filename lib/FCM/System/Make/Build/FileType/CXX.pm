# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-16 Met Office.
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
package FCM::System::Make::Build::FileType::CXX;
use base qw{FCM::System::Make::Build::FileType::C};

use FCM::System::Make::Build::Task::Compile::CXX;
use FCM::System::Make::Build::Task::Install;
use FCM::System::Make::Build::Task::Link::CXX;

my %TASK_CLASS_OF = (
    'compile' => 'FCM::System::Make::Build::Task::Compile::CXX',
    'install' => 'FCM::System::Make::Build::Task::Install',
    'link'    => 'FCM::System::Make::Build::Task::Link::CXX',
);

sub new {
    my ($class, $attrib_ref) = @_;
    bless(
        FCM::System::Make::Build::FileType::C->new({
            id            => 'cxx',
            file_ext      => '.cc .cp .cxx .cpp .CPP .c++ .C .mm .M .mii',
            task_class_of => {%TASK_CLASS_OF},
            %{$attrib_ref},
        }),
        $class,
    );
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::FileType::CXX

=head1 SYNOPSIS

    use FCM::System::Make::Build::FileType::CXX;
    my $helper = FCM::System::Make::Build::FileType::CXX->new();
    $helper->source_analyse($handle);

=head1 DESCRIPTION

A wrapper of
L<FCM::System::Make::Build::FileType::C|FCM::System::Make::Build::FileType::C>
with configurations to work with C++ source files.

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
