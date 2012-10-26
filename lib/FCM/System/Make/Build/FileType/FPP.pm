# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-2012 Met Office.
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
package FCM::System::Make::Build::FileType::FPP;
use base qw{FCM::System::Make::Build::FileType::CPP};

use FCM::System::Make::Build::Task::Preprocess::Fortran;

my %TASK_CLASS_OF
    = (process => 'FCM::System::Make::Build::Task::Preprocess::Fortran');

sub new {
    my ($class, $attrib_ref) = @_;
    bless(
        FCM::System::Make::Build::FileType::CPP->new({
            id            => 'fpp',
            file_ext      => '.F90 .F95 .F .FTN .FOR',
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

FCM::System::Make::Build::FileType::FPP

=head1 SYNOPSIS

    use FCM::System::Make::Build::FileType::FPP;
    my $helper = FCM::System::Make::Build::FileType::FPP->new();
    $helper->source_analyse($handle);

=head1 DESCRIPTION

A wrapper of
L<FCM::System::Make::Build::FileType::CPP|FCM::System::Make::Build::FileType::CPP>
with configurations to work with Fortran source files for preprocessing.

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
