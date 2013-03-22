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
package FCM::System::Make::Build::FileType::H;
use base qw{FCM::System::Make::Build::FileType};

use FCM::Context::Make::Build;    # for FCM::Context::Make::Build::Target
use FCM::System::Make::Build::Task::Install;
use File::Basename qw{basename};

# RE: file (base) name
my $RE_FILE = qr{[\w\-+.]+}imsx;

# Dependency types and CODE to extract them
my %SOURCE_ANALYSE_DEP_OF = (
    include => sub { $_[0] =~ qr{\A\#\s*include\s+"($RE_FILE)"}msx },

    # Note: handle ! as a comment, for *.h files containing Fortran source
    o => sub {
        $_[0] =~ qr{\A\s*(?:!|/\*)\s*depends\s*on\s*:\s*($RE_FILE)}imsx;
    },
);

# Alias
my $TARGET = 'FCM::Context::Make::Build::Target';

# Handler of tasks
my %TASK_CLASS_OF = (install => 'FCM::System::Make::Build::Task::Install');

# Property suffices of output file extensions
my %TARGET_EXT_OF = ('o' => '.o');

sub new {
    my ($class, $attrib_ref) = @_;
    bless(
        FCM::System::Make::Build::FileType->new({
            id                    => 'h',
            file_ext              => '.h',
            source_analyse_dep_of => {%SOURCE_ANALYSE_DEP_OF},
            source_to_targets     => \&_source_to_targets,
            target_file_ext_of    => {%TARGET_EXT_OF},
            task_class_of         => {%TASK_CLASS_OF},
            %{$attrib_ref},
        }),
        $class,
    );
}

# Returns a list of targets for a given build source.
sub _source_to_targets {
    my ($attrib_ref, $source, $prop_hash_ref) = @_;
    my %dot = %{$prop_hash_ref};
    my $key = basename($source->get_path());
    my @deps = map {
        my $ext = $attrib_ref->{util}->file_ext($_->[0]);
        $_->[1] eq 'o' && !$ext ? [lc($_->[0]) . $dot{o}, $_->[1]] : $_;
    } @{$source->get_deps()};
    $TARGET->new(
        {   category => $TARGET->CT_INCLUDE,
            deps     => [@deps],
            dep_policy_of => {'include' => $TARGET->POLICY_CAPTURE},
            key      => $key,
            status_of=> {'include' => $TARGET->ST_UNKNOWN},
            task     => 'install',
        }
    );
}

# ------------------------------------------------------------------------------
package FCM::System::Make::Build::FileType::HPP;
use base qw{FCM::System::Make::Build::FileType::H};

sub new {
    my ($class, $attrib_ref) = @_;
    bless(
        FCM::System::Make::Build::FileType::H->new({
            source_analyse_dep_of => {include => $SOURCE_ANALYSE_DEP_OF{include}},
            target_file_ext_of    => {},
            %{$attrib_ref},
        }),
        $class,
    );
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::FileType::H

=head1 SYNOPSIS

    use FCM::System::Make::Build::FileType::H;
    my $helper = FCM::System::Make::Build::FileType::H->new();
    $helper->source_analyse($handle);

    my $helper = FCM::System::Make::Build::FileType::HPP->new();
    $helper->source_analyse($handle);

=head1 DESCRIPTION

A wrapper of
L<FCM::System::Make::Build::FileType|FCM::System::Make::Build::FileType> with
configurations to work with C or Fortran preprocessor header files.

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
