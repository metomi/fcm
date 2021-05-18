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
package FCM::System::Make::Build::FileType::CPP;
use base qw{FCM::System::Make::Build::FileType};

use FCM::Context::Make::Build; # for FCM::Context::Make::Build::Target
use FCM::System::Make::Build::Task::Preprocess::C;

# Dependency types and CODE to extract them
my %SOURCE_ANALYSE_DEP_OF
    = (include => sub { $_[0] =~ qr{\A\#\s*include\s+"([\w\-+.]+)"}msx });

# Handler of tasks
my %TASK_CLASS_OF
    = (process => 'FCM::System::Make::Build::Task::Preprocess::C');

sub new {
    my ($class, $attrib_ref) = @_;
    bless(
        FCM::System::Make::Build::FileType->new({
            id                    => 'cpp',
            file_ext              => '.c .m .cc .cp .cxx .cpp .CPP .c++ .C .mm .M',
            source_analyse_dep_of => {%SOURCE_ANALYSE_DEP_OF},
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
    my $TARGET = 'FCM::Context::Make::Build::Target';
    $TARGET->new(
        {   category      => $TARGET->CT_SRC,
            deps          => [@{$source->get_deps()}],
            dep_policy_of => {'include' => $TARGET->POLICY_CAPTURE},
            info_of       => {paths => []},
            key           => $source->get_ns(),
            task          => 'process',
        }
    );
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::FileType::CPP

=head1 SYNOPSIS

    use FCM::System::Make::Build::FileType::CPP;
    my $helper = FCM::System::Make::Build::FileType::CPP->new();
    $helper->source_analyse($handle);

=head1 DESCRIPTION

A wrapper of
L<FCM::System::Make::Build::FileType|FCM::System::Make::Build::FileType> with
configurations to work with C source files for preprocessing.

=head1 COPYRIGHT

Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.

=cut
