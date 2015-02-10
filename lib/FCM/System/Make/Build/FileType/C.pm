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
package FCM::System::Make::Build::FileType::C;
use base qw{FCM::System::Make::Build::FileType};

use FCM::Context::Make::Build; # for FCM::Context::Make::Build::Target
use FCM::System::Make::Build::Task::Compile::C;
use FCM::System::Make::Build::Task::Install;
use FCM::System::Make::Build::Task::Link::C;
use File::Basename qw{basename};

# RE: file (base) name
my $RE_FILE = qr{[\w\-+.]+}imsx;

# RE: main program
my $RE_MAIN = qr{int\s*main\b}msx;

my %SOURCE_ANALYSE_DEP_OF = (
    include => sub { $_[0] =~ qr{\A\#\s*include\s+"($RE_FILE)"}msx },
    o => sub { lc($_[0]) =~ qr{\A\s*/\*\s*depends\s*on\s*:\s*($RE_FILE)}imsx },
);
my $TARGET = 'FCM::Context::Make::Build::Target';
my %TASK_CLASS_OF = (
    'compile' => 'FCM::System::Make::Build::Task::Compile::C',
    'install' => 'FCM::System::Make::Build::Task::Install',
    'link'    => 'FCM::System::Make::Build::Task::Link::C',
);

sub new {
    my ($class, $attrib_ref) = @_;
    bless(
        FCM::System::Make::Build::FileType->new({
            id                       => 'c',
            file_ext                 => '.c .i .m .mi',
            source_analyse_always    => 1,
            source_analyse_dep_of    => {%SOURCE_ANALYSE_DEP_OF},
            source_analyse_more      => \&_source_analyse_more,
            source_analyse_more_init => \&_source_analyse_more_init,
            source_to_targets        => \&_source_to_targets,
            target_file_ext_of       => {bin => '.exe', o => '.o'},
            task_class_of            => {%TASK_CLASS_OF},
            %{$attrib_ref},
        }),
        $class,
    );
}

sub _source_analyse_more {
    my ($line, $info_hash_ref) = @_;
    if (!$info_hash_ref->{main} && $line =~ $RE_MAIN) {
        return $info_hash_ref->{main} = 1;
    }
    return;
}

sub _source_analyse_more_init {
    my ($info_hash_ref) = @_;
    $info_hash_ref->{main} = 0;
}

# Returns a list of targets for a given build source.
sub _source_to_targets {
    my ($attrib_ref, $source, $prop_hash_ref) = @_;
    my $key = basename($source->get_path());
    my ($ext, $root) = $attrib_ref->{util}->file_ext($key);
    my %dot = %{$prop_hash_ref};
    my @deps = @{$source->get_deps()};
    my $key_o = lc($root) . $dot{o}; # lc for legacy
    my @targets = (
        $TARGET->new(
            {   category  => $TARGET->CT_INCLUDE,
                deps      => [@deps],
                dep_policy_of => {'include' => $TARGET->POLICY_CAPTURE},
                key       => $key,
                status_of => {'include' => $TARGET->ST_UNKNOWN},
                task      => 'install',
            }
        ),
        $TARGET->new(
            {   category      => $TARGET->CT_O,
                deps          => [@deps],
                dep_policy_of => {'include' => $TARGET->POLICY_CAPTURE},
                info_of       => {paths => []},
                key           => $key_o,
                task          => 'compile',
            }
        ),
    );

    if ($source->get_info_of()->{'main'}) {
        my @link_deps = grep {$_->[1] eq 'o'} @deps;
        push(
            @targets,
            $TARGET->new(
                {   category   => $TARGET->CT_BIN,
                    deps       => [[$key_o, 'o'], @link_deps],
                    dep_policy_of => {
                        map {($_ => $TARGET->POLICY_CAPTURE)} qw{o o.special},
                    },
                    info_of    => {
                        paths => [], deps => {o => [], 'o.special' => []},
                    },
                    key        => $root . $dot{bin},
                    task       => 'link',
                }
            )
        );
    }
    return @targets;
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::FileType::C

=head1 SYNOPSIS

    use FCM::System::Make::Build::FileType::C;
    my $helper = FCM::System::Make::Build::FileType::C->new();
    $helper->source_analyse($handle);

=head1 DESCRIPTION

A wrapper of
L<FCM::System::Make::Build::FileType|FCM::System::Make::Build::FileType> with
configurations to work with C source files.

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
