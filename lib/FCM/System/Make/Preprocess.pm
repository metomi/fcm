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
package FCM::System::Make::Preprocess;
use base qw{FCM::System::Make::Build};

use FCM::System::Make::Build::FileType::CPP;
use FCM::System::Make::Build::FileType::FPP;
use FCM::System::Make::Build::FileType::H  ;

# Default target selection
our %TARGET_SELECT_BY = (task => {'process' => 1});

# Classes for working with typed source files
our @FILE_TYPE_UTILS = (
    'FCM::System::Make::Build::FileType::FPP',
    'FCM::System::Make::Build::FileType::CPP',
    'FCM::System::Make::Build::FileType::HPP',
);

# Default properties
my %PROP_OF = (
    'ignore-missing-dep-ns'      => [q{}, undef],
    'no-step-source'             => [q{}, undef],
    'no-inherit-source'          => [q{}, undef],
    'no-inherit-target-category' => [q{}, undef],
);

# Returns an instance of FCM::System::Make::Build;
sub new {
    my ($class, $attrib_ref) = @_;
    bless(
        FCM::System::Make::Build->new({
            target_select_by => {%TARGET_SELECT_BY},
            file_type_utils  => [@FILE_TYPE_UTILS],
            prop_of          => {%PROP_OF},
            %{$attrib_ref},
        }),
        $class,
    );
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Preprocess

=head1 SYNOPSIS

    use FCM::System::Make::Preprocess;
    my $system = FCM::System::Make::Preprocess->new(\%attrib);
    $system->main(\%option_of, @args);

=head1 DESCRIPTION

A wrapper of L<FCM::System::Make::Build|FCM::System::Make::Build> with
configuration to trigger the preprocessing of Fortran and C source files.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut

