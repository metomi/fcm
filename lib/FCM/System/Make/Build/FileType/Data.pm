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
package FCM::System::Make::Build::FileType::Data;
use base qw{FCM::System::Make::Build::FileType};

use FCM::Context::Make::Build;    # for FCM::Context::Make::Build::Target
use FCM::System::Make::Build::Task::Install;

# Handler of tasks
my %TASK_CLASS_OF = (install => 'FCM::System::Make::Build::Task::Install');

sub new {
    my ($class, $attrib_ref) = @_;
    bless(
        FCM::System::Make::Build::FileType->new({
            id                    => q{},
            source_analyse_dep_of => {},
            source_to_targets     => \&_source_to_targets,
            target_file_ext_of    => {},
            task_class_of         => {%TASK_CLASS_OF},
            %{$attrib_ref},
        }),
        $class,
    );
}

# Returns a list of targets for a given build source.
sub _source_to_targets {
    my ($attrib_ref, $source) = @_;
    FCM::Context::Make::Build::Target->new(
        {   category => FCM::Context::Make::Build::Target->CT_ETC,
            key      => $source->get_ns(),
            task     => 'install',
        }
    );
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::FileType::Data

=head1 SYNOPSIS

    use FCM::System::Make::Build::FileType::Data;
    my $helper = FCM::System::Make::Build::FileType::Data->new();
    $helper->source_analyse($handle);

=head1 DESCRIPTION

A class based on
L<FCM::System::Make::Build::FileType|FCM::System::Make::Build::FileType>
with configurations to install data files to the etc/ sub-directory of a build.

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
