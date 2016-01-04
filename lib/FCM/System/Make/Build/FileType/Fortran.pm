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
package FCM::System::Make::Build::FileType::Fortran;
use base qw{FCM::System::Make::Build::FileType};

use FCM::Context::Make::Build;    # for FCM::Context::Make::Build::Target
use FCM::System::Make::Build::Task::Compile::Fortran;
use FCM::System::Make::Build::Task::ExtractInterface;
use FCM::System::Make::Build::Task::Install;
use FCM::System::Make::Build::Task::Link::Fortran;
use File::Basename qw{basename};
use Text::Balanced qw{extract_bracketed extract_delimited};

# Recommended file extensions of this utility
our $FILE_EXT = '.F .F90 .F95 .FOR .FTN .f .f90 .f95 .for .ftn .inc';

# List of Fortran intrinsic modules
our @INTRINSIC_MODULES = qw{
    ieee_arithmetic
    ieee_exceptions
    ieee_features
    iso_c_binding
    iso_fortran_env
    omp_lib
    omp_lib_kinds
};

# Prefix for dependency name that is only applicable under OMP
our $OMP_PREFIX = '!$';

# Regular expressions
my $RE_FILE = qr{[\w\-+.]+}imsx;
my $RE_NAME = qr{[A-Za-z]\w*}imsx;
my $RE_SPEC = qr{
    character|class|complex|double\s*complex|double\s*precision|integer|
    logical|procedure|real|type
}imsx;
my $RE_UNIT_BASE = qr{block\s*data|module|program|submodule}imsx;
my $RE_UNIT_CALL = qr{subroutine|function}imsx;
my %RE           = (
    DEP_O     => qr{\A\s*!\s*depends\s*on\s*:\s*($RE_FILE)}imsx,
    DEP_USE   => qr{\A\s*use\s+($RE_NAME)}imsx,
    DEP_SUBM  => qr{\A\s*submodule\s+\(($RE_NAME)\)}imsx,
    INCLUDE   => qr{\#?\s*include\s*}imsx,
    OMP_SENT  => qr{\A(\s*!\$\s+)?(.*)\z}imsx,
    UNIT_ATTR => qr{\A\s*(?:(?:(?:impure\s+)?elemental|recursive|pure)\s+)+(.*)\z}imsx,
    UNIT_BASE => qr{\A\s*($RE_UNIT_BASE)\s+($RE_NAME)\s*\z}imsx,
    UNIT_CALL => qr{\A\s*($RE_UNIT_CALL)\s+($RE_NAME)\b}imsx,
    UNIT_END  => qr{\A\s*(end)(?:\s+($RE_NAME)(?:\s+($RE_NAME))?)?\s*\z}imsx,
    UNIT_SPEC => qr{\A\s*$RE_SPEC\b(.*)\z}imsx,
);

# Dependency types and extractors
my %SOURCE_ANALYSE_DEP_OF = (
    'f.module'  => \&_source_analyse_dep_module,
    'include'   => \&_source_analyse_dep_include,
    'o'         => sub { lc($_[0]) =~ $RE{DEP_O} }, # lc required for legacy
    'o.special' => sub {},
);
# Alias
my $TARGET = 'FCM::Context::Make::Build::Target';
# Classes for tasks used by targets of this file type
my %TASK_CLASS_OF = (
    'compile'   => 'FCM::System::Make::Build::Task::Compile::Fortran',
    'compile+'  => 'FCM::System::Make::Build::Task::Compile::Fortran::Extra',
    'ext-iface' => 'FCM::System::Make::Build::Task::ExtractInterface',
    'install'   => 'FCM::System::Make::Build::Task::Install',
    'link'      => 'FCM::System::Make::Build::Task::Link::Fortran',
);
# Property suffices of output file extensions
my %TARGET_EXT_OF = (
    'bin'           => '.exe',
    'f90-interface' => '.interface',
    'f90-mod'       => '.mod',
    'o'             => '.o',
);

sub new {
    my ($class, $attrib_ref) = @_;
    bless(
        FCM::System::Make::Build::FileType->new({
            id                         => 'fortran',
            file_ext                   => $FILE_EXT,
            source_analyse_always      => 1,
            source_analyse_dep_of      => {%SOURCE_ANALYSE_DEP_OF},
            source_analyse_more        => \&_source_analyse_more,
            source_analyse_more_init   => \&_source_analyse_more_init,
            source_to_targets          => \&_source_to_targets,
            target_deps_filter         => \&_target_deps_filter,
            target_file_ext_of         => {%TARGET_EXT_OF},
            target_file_name_option_of => {'f90-mod' => q{}},
            task_class_of              => {%TASK_CLASS_OF},
            %{$attrib_ref},
        }),
        $class,
    );
}

sub _source_analyse_more {
    my ($line, $info_hash_ref, $state) = @_;

    # End Interface
    if ($state->{in_interface}) {
        if ($line =~ qr{\A\s*end\s*interface\b}imsx) {
            $state->{in_interface} = 0;
        }
        return 1;
    }

    # End Program Unit
    if (@{$state->{stack}} && $line =~ qr{\A\s*end\b}imsx) {
        my ($end, $type, $symbol) = lc($line) =~ $RE{UNIT_END};
        if (!$end) {
            return 1;
        }
        my ($top_type, $top_symbol) = @{$state->{stack}->[-1]};
        if (!$type
            || $top_type eq $type && (!$symbol || $top_symbol eq $symbol))
        {
            pop(@{$state->{stack}});
            if ($state->{in_contains} && !@{$state->{stack}}) {
                $state->{in_contains} = 0;
            }
        }
        return 1;
    }

    # Interface/Contains
    if ($line =~ qr{\A\s*contains\b}imsx) {
        $state->{'in_contains'} = 1;
        return 1;
    }
    if ($line =~ qr{\A\s*(?:abstract\s+)?interface\b}imsx) {
        $state->{'in_interface'} = 1;
        return 1;
    }

    # Program Unit
    my ($type, $symbol) = _process_prog_unit($line);
    if ($type) {
        if (!@{$state->{stack}}) {
            if ($type eq 'program') {
                $info_hash_ref->{main} = 1;
            }
            $info_hash_ref->{symbols} ||= [];
            push(@{$info_hash_ref->{symbols}}, [$type, $symbol]);
        }
        push(@{$state->{stack}}, [$type, $symbol]);
        return 1;
    }
    return;
}

sub _source_analyse_more_init {
    my ($info_ref, $state) = @_;
    %{$info_ref} = (main => 0, symbols => []);
    %{$state} = (in_contains => undef, in_interface => undef, stack => []);
}

# Reads information: extract an include dependency.
sub _source_analyse_dep_include {
    my ($line) = @_;
    my ($omp_sentinel, $extracted);
    ($omp_sentinel, $line) = $line =~ $RE{OMP_SENT};
    ($extracted) = extract_delimited($line, q{'"}, $RE{INCLUDE});
    if (!$extracted) {
        return;
    }
    $extracted = substr($extracted, 1, length($extracted) - 2);
    if ($omp_sentinel) {
        $extracted = $OMP_PREFIX . $extracted;
    }
    $extracted;
}

# Reads information: extract a module dependency.
sub _source_analyse_dep_module {
    my ($line) = @_;
    my ($omp_sentinel, $extracted, $can_analyse_more);
    ($omp_sentinel, $line) = $line =~ $RE{OMP_SENT};
    ($extracted) = lc($line) =~ $RE{DEP_USE};
    if (!$extracted) {
        ($extracted) = lc($line) =~ $RE{DEP_SUBM};
        $can_analyse_more = 1;
    }
    if (!$extracted || grep {$_ eq $extracted} @INTRINSIC_MODULES) {
        return;
    }
    if ($omp_sentinel) {
        $extracted = $OMP_PREFIX . $extracted;
    }
    ($extracted, $can_analyse_more);
}

# Parse a statement for program unit header. Returns a list containing the type,
# the symbol and the signature tokens of the program unit.
sub _process_prog_unit {
    my ($string) = @_;
    my ($type, $symbol, @args) = (q{}, q{});
    ($type, $symbol) = lc($string) =~ $RE{UNIT_BASE};
    if ($type) {
        $type = lc($type);
        $type =~ s{\s*}{}gmsx;
        return ($type, $symbol);
    }
    $string =~ s/$RE{UNIT_ATTR}/$1/;
    my ($match) = $string =~ $RE{UNIT_SPEC};
    if ($match) {
        $string = $match;
        if ($string =~ qr{\A \s* \(}msx) {
            extract_bracketed($string);
        }
        elsif ($string =~ qr{\A \s* \*}msx) {
            $string =~ s{\A \s* \* \d+ \s*}{}msx;
        }
    }
    ($type, $symbol) = lc($string) =~ $RE{UNIT_CALL};
    if (!$type) {
        return;
    }
    return (lc($type), lc($symbol));
}

# Returns a list of targets for a given build source.
sub _source_to_targets {
    my ($attrib_ref, $source, $ext_hash_ref, $option_hash_ref) = @_;
    my $key = basename($source->get_path());
    my $TARGET_OF = sub {
        my ($symbol, $type) = @_;
        if (exists($option_hash_ref->{$type})) {
            my $is_upper = index($option_hash_ref->{$type}, 'case=upper') >= 0;
            $symbol = $is_upper ? uc($symbol) : lc($symbol);
        }
        $symbol . $ext_hash_ref->{$type};
    };
    my @deps = map {
        my ($k, $type) = @{$_};
        my $ext = $attrib_ref->{util}->file_ext($k);
          $type eq 'f.module'   ? [$TARGET_OF->($k, 'f90-mod'), 'include', 1]
        : $type eq 'o' && !$ext ? [$TARGET_OF->($k, 'o'), $type]
        :                         [$k, $type]
    } @{$source->get_deps()};
    # All source files can be used as include files
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
    );
    my ($ext, $root) = $attrib_ref->{util}->file_ext($key);
    my $symbols_ref = $source->get_info_of()->{symbols};
    # FIXME: hard code the handling of "*.inc" files as include files
    if (!defined($symbols_ref) || !@{$symbols_ref} || $ext eq 'inc') {
        return @targets;
    }
    my $key_of_o = $TARGET_OF->($symbols_ref->[0][1], 'o');
    my @keys_of_mod;
    for (grep {$_->[0] eq 'module'} @{$symbols_ref}) {
        my ($type, $symbol) = @{$_};
        my $key_of_mod = $TARGET_OF->($symbol, 'f90-mod');
        my @include_deps = grep {$_->[1] eq 'include'} @deps;
        push(
            @targets,
            $TARGET->new(
                {   category      => $TARGET->CT_INCLUDE,
                    deps          => [[$key_of_o, 'o']],
                    dep_policy_of => {
                        'include' => $TARGET->POLICY_CAPTURE,
                        'o'       => $TARGET->POLICY_FILTER_IMMEDIATE,
                    },
                    key         => $key_of_mod,
                    task        => 'compile+',
                }
            )
        );
        push(@keys_of_mod, $key_of_mod);
    }
    push(
        @targets,
        $TARGET->new(
            {   category      => $TARGET->CT_O,
                deps          => [@deps],
                dep_policy_of => {'include' => $TARGET->POLICY_CAPTURE},
                info_of       => {paths => []},
                key           => $key_of_o,
                task          => 'compile',
                triggers      => \@keys_of_mod,
            }
        ),
    );
    if (grep {$_->[0] eq 'subroutine' || $_->[0] eq 'function'} @{$symbols_ref}) {
        my $target_key = $root . $ext_hash_ref->{'f90-interface'};
        push(
            @targets,
            $TARGET->new(
                {   category      => $TARGET->CT_INCLUDE,
                    deps          => [[$key_of_o, 'o'], grep {exists($_->[2])} @deps],
                    dep_policy_of => {
                        'include' => $TARGET->POLICY_FILTER_IMMEDIATE,
                    },
                    key           => $target_key,
                    task          => 'ext-iface',
                }
            )
        );
    }
    if ($source->get_info_of()->{main}) {
        my @link_deps = grep {$_->[1] eq 'o' || $_->[1] eq 'o.special'} @deps;
        push(
            @targets,
            $TARGET->new(
                {   category      => $TARGET->CT_BIN,
                    deps          => [[$key_of_o, 'o'], @link_deps],
                    dep_policy_of => {
                        'o'         => $TARGET->POLICY_CAPTURE,
                        'o.special' => $TARGET->POLICY_CAPTURE,
                    },
                    info_of       => {
                        paths => [], deps => {o => [], 'o.special' => []},
                    },
                    key           => $root . $ext_hash_ref->{bin},
                    task          => 'link',
                }
            )
        );
    }
    return @targets;
}

# If target's fc.flag-omp property is empty, remove !$OMP dependencies.
# Otherwise, remove !$OMP sentinels from the dependencies.
sub _target_deps_filter {
    my ($attrib_ref, $target) = @_;
    if ($target->get_prop_of()->{'fc.flag-omp'}) {
        for my $dep_ref (@{$target->get_deps()}) {
            if (index($dep_ref->[0], $OMP_PREFIX) == 0) {
                substr($dep_ref->[0], 0, length($OMP_PREFIX), q{});
            }
        }
    }
    else {
        $target->set_deps(
            [grep {index($_->[0], $OMP_PREFIX) == -1} @{$target->get_deps()}],
        );
    }
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::FileType::Fortran

=head1 SYNOPSIS

    use FCM::System::Make::Build::FileType::Fortran;
    my $file_type_util = FCM::System::Make::Build::FileType::Fortran->new();

    $file_type_util->source_analyse($source);

    my @targets = $file_type_util->source_to_targets($m_ctx, $ctx, $source);

=head1 DESCRIPTION

A wrapper of
L<FCM::System::Make::Build::FileType|FCM::System::Make::Build::FileType> with
configurations to work with Fortran source files.

=head1 TODO

Combine the code with FCM::System::Make::Build::Task::ExtractInterface.

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
