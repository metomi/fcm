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
package FCM::System::Make::Build::FileType::Script;
use base qw{FCM::System::Make::Build::FileType};

use FCM::Context::Make::Build;    # for FCM::Context::Make::Build::Target
use FCM::System::Make::Build::Task::Install;
use File::Basename qw{basename};

# RE: file (base) name
my $RE_FILE = qr{[\w\-+.]+}imsx;

# Dependency types and CODE to extract them
my %SOURCE_ANALYSE_DEP_OF
    = (bin => sub { $_[0] =~ qr{\A\s*(?:\#|;)\s*calls\s*:\s*($RE_FILE)}imsx });

# Alias
my $TARGET = 'FCM::Context::Make::Build::Target';

# Handler of tasks
my %TASK_CLASS_OF = (install => 'FCM::System::Make::Build::Task::Install');

sub new {
    my ($class, $attrib_ref) = @_;
    $attrib_ref->{dest_keys} ||= [$TARGET->CT_INCLUDE, 'o', 'o.special'];
    my $SOURCE_TO_TARGETS
        = sub {_source_to_targets($attrib_ref->{dest_keys}, @_)};
    bless(
        FCM::System::Make::Build::FileType->new({
            id                    => 'script',
            file_she              => q{}, # Value not used, for file type match
            file_ext              => q{},
            source_analyse_dep_of => {%SOURCE_ANALYSE_DEP_OF},
            source_to_targets     => \&_source_to_targets,
            task_class_of         => {%TASK_CLASS_OF},
            %{$attrib_ref},
        }),
        $class,
    );
}

# Returns a list of targets for a given build source.
sub _source_to_targets {
    my ($attrib_ref, $source, $prop_hash_ref) = @_;
    my $key = basename($source->get_path());
    $TARGET->new(
        {   category      => $TARGET->CT_BIN,
            deps          => [@{$source->get_deps()}],
            dep_policy_of => {'bin', $TARGET->POLICY_CAPTURE},
            key           => $key,
            task          => 'install',
        }
    );
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::FileType::Script

=head1 SYNOPSIS

    use FCM::System::Make::Build::FileType::Script;
    my $helper = FCM::System::Make::Build::FileType::Script->new();
    $helper->source_analyse($handle);

=head1 DESCRIPTION

A wrapper of
L<FCM::System::Make::Build::FileType|FCM::System::Make::Build::FileType>
with configurations to work with some UKMO script files.

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
