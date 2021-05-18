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
package FCM::System::Make::Build;
use base qw{FCM::Class::CODE};

use Cwd qw{cwd realpath};
use FCM::Context::ConfigEntry;
use FCM::Context::Event;
use FCM::Context::Make::Build;
use FCM::Context::Task;
use FCM::System::Exception;
use FCM::System::Make::Build::FileType::C;
use FCM::System::Make::Build::FileType::CXX;
use FCM::System::Make::Build::FileType::Data;
use FCM::System::Make::Build::FileType::Fortran;
use FCM::System::Make::Build::FileType::H;
use FCM::System::Make::Build::FileType::NS;
use FCM::System::Make::Build::FileType::Script;
use FCM::System::Make::Share::Subsystem;
use File::Basename qw{basename dirname fileparse};
use File::Find qw{find};
use File::Path qw{mkpath rmtree};
use File::Spec::Functions qw{abs2rel catfile rel2abs splitdir splitpath};
use Storable qw{dclone};
use Text::ParseWords qw{shellwords};

# Aliases
our ($EVENT, $UTIL);
my $E = 'FCM::System::Exception';
my $STATE = 'FCM::System::Make::Build::State';

# Classes for working with typed source files
our @FILE_TYPE_UTILS = (
    'FCM::System::Make::Build::FileType::C',
    'FCM::System::Make::Build::FileType::CXX',
    'FCM::System::Make::Build::FileType::Data',
    'FCM::System::Make::Build::FileType::Fortran',
    'FCM::System::Make::Build::FileType::H',
    'FCM::System::Make::Build::FileType::NS',
    'FCM::System::Make::Build::FileType::Script',
);

# Default target selection
our %TARGET_SELECT_BY = (
    'category' => {},
    'key'      => {},
    'task'     => {},
);

# Configuration parser label to action map
our %CONFIG_PARSER_OF = (
    'ns-excl' => _config_parse_ns_filter_func(sub {$_[0]->get_input_ns_excl()}),
    'ns-incl' => _config_parse_ns_filter_func(sub {$_[0]->get_input_ns_incl()}),
    'source'  => \&_config_parse_source,
    'target'  => \&_config_parse_target,
    'target-rename' => \&_config_parse_target_rename,
);

# Default properties
our %PROP_OF = (
    #                               [default       , ns-ok]
    'archive-ok-target-category' => [q{include o}  , undef],
    'checksum-method'            => [q{}           , undef],
    'ignore-missing-dep-ns'      => [q{}           , undef],
    'no-step-source'             => [q{}           , undef],
    'no-inherit-source'          => [q{}           , undef],
    'no-inherit-target-category' => [q{bin etc lib}, undef],
);

# Creates the class.
__PACKAGE__->class(
    {   config_parser_of  => {isa => '%', default => {%CONFIG_PARSER_OF}},
        file_type_utils   => {isa => '@', default => [@FILE_TYPE_UTILS]},
        file_type_util_of => '%',
        prop_of           => {isa => '%', default => {%PROP_OF}},
        target_select_by  => {isa => '%', default => {%TARGET_SELECT_BY}},
        util              => '&',
    },
    {   init => \&_init,
        action_of => {
            config_parse              => \&_config_parse,
            config_parse_class_prop   => \&_config_parse_class_prop,
            config_parse_inherit_hook => \&_config_parse_inherit_hook,
            config_unparse            => \&_config_unparse,
            config_unparse_class_prop => \&_config_unparse_class_prop,
            ctx                       => \&_ctx,
            ctx_load_hook             => \&_ctx_load_hook,
            main                      => \&_main,
        },
    },
);

# Initialises the helpers of the class.
sub _init {
    my ($attrib_ref) = @_;
    # Initialises file type utilities, if necessary
    for my $class (@{$attrib_ref->{file_type_utils}}) {
        $attrib_ref->{util}->class_load($class);
        my $file_type_util = $class->new({util => $attrib_ref->{util}});
        my $id = $file_type_util->id();
        if (!defined($attrib_ref->{file_type_util_of}{$id})) {
            $attrib_ref->{file_type_util_of}{$id} = $file_type_util;
        }
    }
    # Initialises properties derived from the file type utilities
    # TBD: warn if a property is already set and is different from previous?
    while (
        my ($id, $file_type_util) = each(%{$attrib_ref->{file_type_util_of}})
    ) {
        # File name extension, name pattern and she-bang pattern
        for my $key (qw{ext pat she}) {
            my $method = 'file_' . $key;
            if ($file_type_util->can($method)) {
                my $value = $file_type_util->$method();
                if (defined($value)) {
                    $attrib_ref->{prop_of}{"file-$key.$id"} = [$value];
                }
            }
        }
        # Dependency types
        if ($file_type_util->can('source_analyse_deps')) {
            for my $name ($file_type_util->source_analyse_deps()) {
                $attrib_ref->{prop_of}{"dep.$name"} = [q{}, 1];
                $attrib_ref->{prop_of}{"no-dep.$name"} = [q{}, 1];
            }
        }
        # Name-space dependency types
        if ($file_type_util->can('ns_targets_deps')) {
            for my $name ($file_type_util->ns_targets_deps()) {
                $attrib_ref->{prop_of}{"ns-dep.$name"} = [q{}, 1];
            }
        }
        # Target extensions
        if ($file_type_util->can('target_file_ext_of')) {
            while (my ($key, $value)
                = each(%{$file_type_util->target_file_ext_of()})
            ) {
                $attrib_ref->{prop_of}{"file-ext.$key"} = [$value, 1];
            }
        }
        # Target file naming options
        if ($file_type_util->can('target_file_name_option_of')) {
            while (my ($key, $value)
                = each(%{$file_type_util->target_file_name_option_of()})
            ) {
                $attrib_ref->{prop_of}{"file-name-option.$key"} = [$value, 1];
            }
        }
        # Task properties
        my %task_of = %{$file_type_util->task_of()};
        while (my ($name, $task) = each(%task_of)) {
            if ($task->can('prop_of')) {
                my %prop_of = %{$task->prop_of()};
                while (my ($key, $value) = each(%prop_of)) {
                    $attrib_ref->{prop_of}{$key} = [$value, 1];
                }
            }
        }
    }
}

# A hook command for the "inherit/use" declaration.
sub _config_parse_inherit_hook {
    my ($attrib_ref, $ctx, $i_ctx) = @_;
    push(@{$ctx->get_input_ns_excl()}, @{$i_ctx->get_input_ns_excl()});
    push(@{$ctx->get_input_ns_incl()}, @{$i_ctx->get_input_ns_incl()});
    while (my ($key, $value) = each(%{$i_ctx->get_target_key_of()})) {
        $ctx->get_target_key_of()->{$key} = $value;
    }
    while (my ($key, $item_ref) = each(%{$i_ctx->get_target_select_by()})) {
        while (my ($key2, $attr_set) = each(%{$item_ref})) {
            if (ref($attr_set)) {
                $ctx->get_target_select_by()->{$key}{$key2} = {%{$attr_set}};
            }
            else {
                # Backward compat, $key2 is an $attr
                $ctx->get_target_select_by()->{$key}{q{}}{$key2} = 1;
            }
        }
    }
    _config_parse_inherit_hook_prop($attrib_ref, $ctx, $i_ctx);
}

# Returns a function to parse a build/preprocess.ns-??cl declaration.
sub _config_parse_ns_filter_func {
    my ($getter) = @_;
    sub {
        my ($attrib_ref, $ctx, $entry) = @_;
        if (@{$entry->get_ns_list()}) {
            return $E->throw($E->CONFIG_NS, $entry);
        }
        @{$getter->($ctx)} = map {$_ eq q{/} ? q{} : $_} $entry->get_values();
    };
}

# Parses a build/preprocess.source declaration.
sub _config_parse_source {
    my ($attrib_ref, $ctx, $entry) = @_;
    my ($ns) = @{$entry->get_ns_list()};
    $ns ||= q{};
    $ctx->get_input_source_of()->{$ns} = [$entry->get_values()];
}

# Parses a build/preprocess.target declaration.
sub _config_parse_target {
    my ($attrib_ref, $ctx, $entry) = @_;
    my %modifier_of = %{$entry->get_modifier_of()};
    if (!(%modifier_of)) {
        %modifier_of = (key => 1);
    }
    my @ns_list = map {$_ eq q{/} ? q{} : $_} @{$entry->get_ns_list()};
    if (exists($modifier_of{'key'}) && grep {$_} @ns_list) {
        return $E->throw($E->CONFIG_NS, $entry);
    }
    if (!@ns_list) {
        @ns_list = (q{});
    }
    while (my $name = each(%modifier_of)) {
        if (!grep {$_ eq $name} qw{category key task}) {
            return $E->throw($E->CONFIG_MODIFIER, $entry);
        }
        my %attr_set = map {($_ => 1)} $entry->get_values();
        for my $ns (@ns_list) {
            $ctx->get_target_select_by()->{$name}{$ns} = \%attr_set;
        }
    }
}

# Parses a build/preprocess.target-rename declaration.
sub _config_parse_target_rename {
    my ($attrib_ref, $ctx, $entry) = @_;
    $ctx->set_target_key_of({
        map {
            my ($old, $new) = split(qr{:}msx, $_, 2);
            if (!$old || !$new) {
                return $E->throw($E->CONFIG_VALUE, $entry);
            }
            ($old => $new);
        } ($entry->get_values()),
    });
}

# Turns a context into a list of configuration entries.
sub _config_unparse {
    my ($attrib_ref, $ctx) = @_;
    my %LABEL_OF
        = map {($_ => $ctx->get_id() . q{.} . $_)} keys(%CONFIG_PARSER_OF);
    (   (   @{$ctx->get_input_ns_excl()}
            ? FCM::Context::ConfigEntry->new({
                label => $LABEL_OF{'ns-excl'},
                value => _config_unparse_join(
                    map {$_ ? $_ : q{/}} @{$ctx->get_input_ns_excl()}
                ),
            })
            : ()
        ),
        (   @{$ctx->get_input_ns_incl()}
            ? FCM::Context::ConfigEntry->new({
                label => $LABEL_OF{'ns-incl'},
                value => _config_unparse_join(
                    map {$_ ? $_ : q{/}} @{$ctx->get_input_ns_incl()}
                ),
            })
            : ()
        ),
        (   map {
                FCM::Context::ConfigEntry->new({
                    label   => $LABEL_OF{source},
                    ns_list => [$_],
                    value   => _config_unparse_join(
                        sort(@{$ctx->get_input_source_of()->{$_}})
                    ),
                })
            }
            sort keys(%{$ctx->get_input_source_of()})
        ),
        (   keys(%{$ctx->get_target_key_of()})
            ? FCM::Context::ConfigEntry->new({
                label => $LABEL_OF{'target-rename'},
                value => _config_unparse_join(
                    map {$_ . ':' . $ctx->get_target_key_of()->{$_}}
                    sort keys(%{$ctx->get_target_key_of()})
                ),
            })
            : ()
        ),
        (   map {
                my $modifier = $_;
                map {
                    my $ns = $_;
                    my @values = sort(keys(
                        %{$ctx->get_target_select_by()->{$modifier}{$ns}}
                    ));
                    FCM::Context::ConfigEntry->new({
                        label       => $LABEL_OF{'target'},
                        modifier_of => {$modifier => 1},
                        ns_list     => [$ns],
                        value       => _config_unparse_join(@values),
                    });
                }
                sort keys(%{$ctx->get_target_select_by()->{$modifier}});
            }
            sort keys(%{$ctx->get_target_select_by()})
        ),
        _config_unparse_prop($attrib_ref, $ctx),
    );
}

# Returns a new context.
sub _ctx {
    my ($attrib_ref, $id_of_class, $id) = @_;
    FCM::Context::Make::Build->new({
        id               => $id,
        id_of_class      => $id_of_class,
        target_select_by => dclone($attrib_ref->{target_select_by}),
    });
}

# Hook when loading a previous ctx.
sub _ctx_load_hook {
    my ($attrib_ref, $old_m_ctx, $old_ctx, $old_m_dest, $old_dest) = @_;
    my $path_mod_func = sub {
        my ($get_func, $set_func) = @_;
        my $path = $get_func->();
        if (!defined($path)) {
            return;
        }
        my $rel_path = abs2rel($path, $old_m_dest);
        if (index($rel_path, '..') != 0) {
            $set_func->(catfile($old_m_ctx->get_dest(), $rel_path));
        }
    };
    if (@{$old_ctx->get_dests()}) {
        $old_ctx->get_dests()->[0] = $old_ctx->get_dest();
    }
    while (my ($ns, $source) = each(%{$old_ctx->get_source_of()})) {
        $path_mod_func->(
            sub {$source->get_path()},
            sub {$source->set_path(@_)},
        );
    }
    while (my ($key, $target) = each(%{$old_ctx->get_target_of()})) {
        $path_mod_func->(
            sub {$target->get_path()},
            sub {$target->set_path(@_)},
        );
        $path_mod_func->(
            sub {$target->get_path_of_prev()},
            sub {$target->set_path_of_prev(@_)},
        );
        $path_mod_func->(
            sub {$target->get_path_of_source()},
            sub {$target->set_path_of_source(@_)},
        );
    }
}

# The main function of the class.
sub _main {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    local($UTIL) = $attrib_ref->{util};
    local($EVENT) = sub {$UTIL->event(@_)};
    for my $function (
        \&_sources_locate,
        \&_sources_type,
        \&_sources_analyse,
        \&_targets_update,
    ) {
        $function->($attrib_ref, $m_ctx, $ctx);
    }
}

# Locates the actual source files, and determines their types.
sub _sources_locate {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    # From inherited
    my %NO_INHERIT_FROM
        = map {($_ => 1)} _props($attrib_ref, 'no-inherit-source', $ctx);
    if (!$NO_INHERIT_FROM{'*'}) {
        for my $i_ctx (_i_ctx_list($m_ctx, $ctx)) {
            while (my ($ns, $source) = each(%{$i_ctx->get_source_of()})) {
                if (!exists($NO_INHERIT_FROM{$ns})) { # exact name-spaces only
                    $ctx->get_source_of()->{$ns} = dclone($source);
                }
            }
        }
    }
    # From specified input
    while (my ($ns, $input_sources_ref) = each(%{$ctx->get_input_source_of()})) {
        for my $input_source (@{$input_sources_ref}) {
            my $path = realpath(rel2abs($input_source, $m_ctx->get_dest()));
            _sources_locate_by_find($attrib_ref, $m_ctx, $ctx, $ns, $path);
        }
    }
    # From completed make destinations
    my %NO_SOURCE_FROM
        = map {($_, 1)} _props($attrib_ref, 'no-step-source', $ctx);
    for my $step (@{$m_ctx->get_steps()}) {
        my $a_ctx = $m_ctx->get_ctx_of($step);
        if (    !exists($NO_SOURCE_FROM{$step})
            &&  defined($a_ctx)
            &&  $a_ctx->get_status() eq $m_ctx->ST_OK
            &&  $a_ctx->can('get_target_of')
        ) {
            my @target_list
                = grep {$_->can_be_source()} values(%{$a_ctx->get_target_of()});
            for my $target (@target_list) {
                if ($target->is_ok() && -e $target->get_path()) {
                    my $checksum;
                    if ($target->can('get_checksum')) {
                        $checksum = $target->get_checksum();
                    }
                    my $source = $ctx->CTX_SOURCE->new({
                        checksum => $checksum,
                        ns       => $target->get_ns(),
                        path     => $target->get_path(),
                    });
                    $ctx->get_source_of()->{$target->get_ns()} = $source;
                }
                elsif (exists($ctx->get_source_of()->{$target->get_ns()})) {
                    delete($ctx->get_source_of()->{$target->get_ns()});
                }
            }
        }
    }
    # Applies filter
    my %INPUT_NS_EXCL = map {($_, 1)} @{$ctx->get_input_ns_excl()};
    my %INPUT_NS_INCL = map {($_, 1)} @{$ctx->get_input_ns_incl()};
    if (keys(%INPUT_NS_EXCL) || keys(%INPUT_NS_INCL)) {
        while (my ($ns, $source) = each(%{$ctx->get_source_of()})) {
            my $ns_iter_ref = $UTIL->ns_iter($ns, $UTIL->NS_ITER_UP);
            NS:
            while (defined(my $head = $ns_iter_ref->())) {
                if (exists($INPUT_NS_INCL{$head})) {
                    last NS;
                }
                if (exists($INPUT_NS_EXCL{$head})) {
                    delete($ctx->get_source_of()->{$ns});
                    last NS;
                }
            }
        }
    }
}

# Locates the actual source files in $path.
sub _sources_locate_by_find {
    my ($attrib_ref, $m_ctx, $ctx, $key, $path) = @_;
    if (!-e $path) {
        return $E->throw($E->BUILD_SOURCE, $path, $!);
    }
    find(
        sub {
            my $path_found = $File::Find::name;
            if (-d $path_found) {
                return;
            }
            my $ns = abs2rel($path_found, $path);
            if ($ns ne q{.}) {
                for my $name (split(q{/}, $ns)) {
                    if (index($name, q{.}) == 0) {
                        return; # ignore Unix hidden/system files
                    }
                }
            }
            if ($key) {
                $ns = $UTIL->ns_cat($key, $ns);
            }
            $ctx->get_source_of()->{$ns}
                = $ctx->CTX_SOURCE->new({ns => $ns, path => $path_found});
        },
        $path,
    );
}

# Determines source types.
sub _sources_type {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    my %INPUT_FILE_EXT_TO_TYPE_MAP;
    my %INPUT_FILE_PAT_TO_TYPE_MAP;
    my %INPUT_FILE_SHE_TO_TYPE_MAP;
    for (
        ['file-ext.', \%INPUT_FILE_EXT_TO_TYPE_MAP, 1],
        ['file-pat.', \%INPUT_FILE_PAT_TO_TYPE_MAP, 0],
        ['file-she.', \%INPUT_FILE_SHE_TO_TYPE_MAP, 0],
    ) {
        my ($prefix, $map_ref, $value_is_words) = @{$_};
        for my $id (keys(%{$attrib_ref->{file_type_util_of}})) {
            my $name = $prefix . $id;
            my $value = _prop($attrib_ref, $name, $ctx);
            if (defined($value)) {
                for my $key (($value_is_words ? shellwords($value) : ($value))) {
                    $map_ref->{$key} = $id;
                }
            }
        }
    }
    my $type_func = sub {
        my ($path) = @_;
        # Try file name extension
        my $extension = $UTIL->file_ext($path);
        $extension = $extension ? q{.} . $extension : undef;
        if ($extension && exists($INPUT_FILE_EXT_TO_TYPE_MAP{$extension})) {
            return $INPUT_FILE_EXT_TO_TYPE_MAP{$extension};
        }
        # Try she-bang line
        if (-T $path) {
            my $line = $UTIL->file_head($path);
            if ($line) {
                while (my ($pattern, $type) = each(%INPUT_FILE_SHE_TO_TYPE_MAP)) {
                    if (index($line, '#!') == 0) { # OK to hard code this
                        keys(%INPUT_FILE_SHE_TO_TYPE_MAP); # reset iterator
                        return $type;
                    }
                }
            }
        }
        # Try file name pattern
        my $base_name = basename($path);
        while (my ($pattern, $type) = each(%INPUT_FILE_PAT_TO_TYPE_MAP)) {
            if ($base_name =~ $pattern) {
                keys(%INPUT_FILE_PAT_TO_TYPE_MAP); # reset iterator
                return $type;
            }
        }
        return q{};
    };
    while (my ($ns, $source) = each(%{$ctx->get_source_of()})) {
        if (!defined($source->get_type())) {
            $source->set_type($type_func->($source->get_path()));
        }
    }
}

# Reads source files to gather dependency and other information.
sub _sources_analyse {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    my $timer = $UTIL->timer();
    my $checksum_method = _prop($attrib_ref, 'checksum-method', $ctx);
    my %FILE_TYPE_UTIL_OF = %{$attrib_ref->{file_type_util_of}};
    # Checksum
    while (my ($ns, $source) = each(%{$ctx->get_source_of()})) {
        if (    exists($FILE_TYPE_UTIL_OF{$source->get_type()})
            &&  !defined($source->get_checksum())
        ) {
            $source->set_checksum(
                $UTIL->file_checksum($source->get_path(), $checksum_method),
            );
        }
    }
    # Source information
    my $n_jobs = $m_ctx->get_option_of('jobs');
    my $runner = $UTIL->task_runner(
        sub {_source_analyse($attrib_ref, @_)},
        $n_jobs,
    );
    my $elapse_tasks = 0;
    my $n = eval {
        $runner->main(
            _source_analyse_get_func($attrib_ref, $m_ctx, $ctx),
            _source_analyse_put_func($attrib_ref, $m_ctx, $ctx, \$elapse_tasks),
        );
    };
    my $e = $@;
    $runner->destroy();
    if ($e) {
        die($e);
    }
    my $n_total = scalar(keys(%{$ctx->get_source_of()}));
    $EVENT->(
        FCM::Context::Event->MAKE_BUILD_SOURCE_SUMMARY,
        $n_total, $n, $timer->(), $elapse_tasks,
    );
}

# Reads a source to gather information.
sub _source_analyse {
    my ($attrib_ref, $source) = @_;
    my $FILE_TYPE_UTIL
        = $attrib_ref->{file_type_util_of}->{$source->get_type()};
    if (!$FILE_TYPE_UTIL->can('source_analyse')) {
        return;
    }
    $FILE_TYPE_UTIL->source_analyse($source);
}

# Generates an iterator for each source file requiring information gathering.
sub _source_analyse_get_func {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    my $P_SOURCE_GETTER
        = _prev_hash_item_getter($m_ctx, $ctx, sub {$_[0]->get_source_of()});
    my %FILE_TYPE_UTIL_OF = %{$attrib_ref->{file_type_util_of}};
    my $exhausted;
    sub {
        if ($exhausted) {
            return;
        }
        SOURCE:
        while (my ($ns, $source) = each(%{$ctx->get_source_of()})) {
            my $type = $source->get_type();
            if (!exists($FILE_TYPE_UTIL_OF{$type})) {
                next SOURCE;
            }
            # Stores the current properties relevant to the source
            for my $dep_type ($FILE_TYPE_UTIL_OF{$type}->source_analyse_deps()) {
                for my $n (map {$_ . q{.} . $dep_type} qw{dep no-dep}) {
                    $source->get_prop_of()->{$n}
                        = _prop($attrib_ref, $n, $ctx, $ns);
                }
            }
            # Compare with previous source, if possible
            my $p_source = $P_SOURCE_GETTER->($ns);
            if (defined($p_source)) {
                $source->set_up_to_date(
                    $p_source->get_checksum() eq $source->get_checksum());
                if (    $source->get_up_to_date()
                    &&  !$UTIL->hash_cmp(
                            map {$_->get_prop_of()} ($source, $p_source)
                        )
                ) {
                    $source->set_info_of(dclone($p_source->get_info_of()));
                    $source->set_deps(   dclone($p_source->get_deps()   ));
                    next SOURCE;
                }
            }
            return FCM::Context::Task->new({ctx => $source, id  => $ns});
        }
        $exhausted = 1;
        return;
    };
}

# Generates a callback when a source read completes.
sub _source_analyse_put_func {
    my ($attrib_ref, $m_ctx, $ctx, $elapse_tasks_ref) = @_;
    my %FILE_TYPE_UTIL_OF = %{$attrib_ref->{file_type_util_of}};
    sub {
        my ($task) = @_;
        if ($task->get_state() eq $task->ST_FAILED) {
            die($task->get_error());
        }
        my $ns = $task->get_id();
        my $source = $ctx->get_source_of()->{$ns} = $task->get_ctx();
        for my $type (
            $FILE_TYPE_UTIL_OF{$source->get_type()}->source_analyse_deps()
        ) {
            # Note: "dep" property: use name-space value only
            my $key = 'dep.' . $type;
            push(
                @{$source->get_deps()},
                (map {[$_, $type]} _props($attrib_ref, $key, $ctx, $ns)),
            );
        }
        ${$elapse_tasks_ref} += $task->get_elapse();
        $EVENT->(
            FCM::Context::Event->MAKE_BUILD_SOURCE_ANALYSE,
            $source, $task->get_elapse(),
        );
    }
}

# Updates the targets.
sub _targets_update {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    my $timer = $UTIL->timer();
    # Creates and changes directory to the destination
    eval {mkpath($ctx->get_dest())};
    if ($@) {
        return $E->throw($E->DEST_CREATE, $ctx->get_dest());
    }
    my $old_cwd = cwd();
    chdir($ctx->get_dest()) || die(sprintf("%s: %s\n", $ctx->get_dest(), $!));
    # Extract any target category directories that are in .tar.gz
    opendir(my $handle, '.');
    while (my $name = readdir($handle)) {
        if ((fileparse($name, '.tar.gz'))[2] eq '.tar.gz') {
            my %value_of = %{$UTIL->shell_simple([qw{tar -x -z}, '-f', $name])};
            if ($value_of{'rc'} == 0) {
                unlink($name);
            }
        }
    }
    closedir($handle);
    # Determines the destination search path
    my $id = $ctx->get_id();
    @{$ctx->get_dests()} = (
        $ctx->get_dest(),
        map {$_->get_ctx_of($id) ? @{$_->get_ctx_of($id)->get_dests()} : ()}
            @{$m_ctx->get_inherit_ctx_list()}
        ,
    );
    # Performs targets update
    my $checksum_method = _prop($attrib_ref, 'checksum-method', $ctx);
    my %stat_of = ();
    eval {
        my $n_jobs = $m_ctx->get_option_of('jobs');
        my $runner = $UTIL->task_runner(
            sub {_target_update($attrib_ref, $checksum_method, @_)},
            $n_jobs,
        );
        eval {
            my ($get_ref, $put_ref) = _targets_manager_funcs(
                 $attrib_ref, $m_ctx, $ctx, \%stat_of,
            );
            $runner->main($get_ref, $put_ref);
        };
        my $e = $@;
        $runner->destroy();
        if ($e) {
            die($e);
        }
    };
    my $e = $@;
    # Back to original working directory
    chdir($old_cwd) || die(sprintf("%s: %s\n", $old_cwd, $!));
    if ($e) {
        _finally($attrib_ref, $m_ctx, $ctx);
        die($e);
    }
    # Finally
    my @targets = values(%{$ctx->get_target_of()});
    for my $key (sort(keys(%stat_of))) {
        $stat_of{$key}{n}{$ctx->CTX_TARGET->ST_MODIFIED} ||= 0;
        $stat_of{$key}{n}{$ctx->CTX_TARGET->ST_UNCHANGED} ||= 0;
        $stat_of{$key}{n}{$ctx->CTX_TARGET->ST_FAILED} ||= 0;
        $stat_of{$key}{t} ||= 0.0;
        $EVENT->(
            FCM::Context::Event->MAKE_BUILD_TARGET_TASK_SUMMARY,
            $key,
            $stat_of{$key}{n}{$ctx->CTX_TARGET->ST_MODIFIED},
            $stat_of{$key}{n}{$ctx->CTX_TARGET->ST_UNCHANGED},
            $stat_of{$key}{n}{$ctx->CTX_TARGET->ST_FAILED},
            $stat_of{$key}{t},
        );
    }
    $EVENT->(
        FCM::Context::Event->MAKE_BUILD_TARGET_SUMMARY,
        scalar(grep {$_->is_modified() } @targets),
        scalar(grep {$_->is_unchanged()} @targets),
        scalar(grep {$_->is_failed()   } @targets),
        $timer->(),
    );
    my @failed_targets = grep {$_->is_failed()} @targets;
    if (@failed_targets) {
        $EVENT->(
            FCM::Context::Event->MAKE_BUILD_TARGETS_FAIL,
            \@failed_targets
        );
        _finally($attrib_ref, $m_ctx, $ctx);
        die("\n");
    }
    _finally($attrib_ref, $m_ctx, $ctx);
}

# Updates a target.
sub _target_update {
    my ($attrib_ref, $checksum_method, $target) = @_;
    my $file_type_util = $attrib_ref->{file_type_util_of}{$target->get_type()};
    eval {$file_type_util->task_of()->{$target->get_task()}->main($target)};
    if ($@) {
        if ($target->get_path() && -e $target->get_path()) {
            unlink($target->get_path());
        }
        die($@);
    }
    if (! -e $target->get_path()) {
        return $E->throw($E->BUILD_TARGET, $target);
    }
    $target->set_status($target->ST_MODIFIED);
    my $checksum = $UTIL->file_checksum($target->get_path(), $checksum_method);
    if ($target->get_checksum() && $checksum eq $target->get_checksum()) {
        $target->set_status($target->ST_UNCHANGED);
        if ($target->get_path_of_prev()) {
            $target->set_path($target->get_path_of_prev());
        }
    }
    $target->set_checksum($checksum);
    $target->set_prop_of_prev_of({}); # unset
    $target->set_path_of_prev(undef); # unset
}

# Returns the get/put functions to send/receive targets to update.
sub _targets_manager_funcs {
    my ($attrib_ref, $m_ctx, $ctx, $stat_hash_ref) = @_;

    my @targets;
    _targets_from_sources($attrib_ref, $m_ctx, $ctx, \@targets);
    _targets_props_assign($attrib_ref, $m_ctx, $ctx, \@targets);

    my ($stack_ref, $state_hash_ref)
        = _targets_select($attrib_ref, $m_ctx, $ctx, \@targets);

    my $checksum_method = _prop($attrib_ref, 'checksum-method', $ctx);
    my $get_action_ref = sub {
        STATE:
        while (my $state = pop(@{$stack_ref})) {
            if (    !$state->is_ready()
                ||  !_target_deps_are_done($state, $state_hash_ref, $stack_ref)
            ) {
                next STATE;
            }
            my $target = $state->get_target();
            if (_target_check_failed_dep($state, $state_hash_ref)) {
                _target_update_failed(
                    $stat_hash_ref, $ctx, $target, $state_hash_ref, $stack_ref,
                );
            }
            elsif (_target_check_ood($state, $state_hash_ref, $checksum_method)) {
                _target_prep($state, $ctx);
                $state->set_value($STATE->PENDING);
                # Adds tasks that can be triggered by this task
                for my $key (sort @{$target->get_triggers()}) {
                    if (    exists($state_hash_ref->{$key})
                        &&  !$state_hash_ref->{$key}->is_done()
                        &&  !grep {$_->get_id() eq $key} @{$stack_ref}
                    ) {
                        my $trigger_target
                            = $state_hash_ref->{$key}->get_target();
                        $trigger_target->set_status($trigger_target->ST_OOD);
                        push(@{$stack_ref}, $state_hash_ref->{$key});
                    }
                }
                return FCM::Context::Task->new(
                    {ctx => $target, id => $state->get_id()},
                );
            }
            else {
                _target_update_ok(
                    $stat_hash_ref, $ctx, $target, $state_hash_ref, $stack_ref,
                );
            }
        }
        return;
    };
    my $put_action_ref = sub {
        my $task = shift();
        my $target = $task->get_ctx();
        if ($task->get_state() eq $task->ST_FAILED) {
            $EVENT->(FCM::Context::Event->E, $task->get_error());
            _target_update_failed(
                $stat_hash_ref, $ctx, $target, $state_hash_ref, $stack_ref,
                $task->get_elapse(),
            );
        }
        else {
            my $target = $task->get_ctx();
            _target_update_ok(
                $stat_hash_ref, $ctx, $target, $state_hash_ref, $stack_ref,
                $task->get_elapse(),
            );
        }
    };
    ($get_action_ref, $put_action_ref);
}

# Determines and returns the targets from the sources.
sub _targets_from_sources {
    my ($attrib_ref, $m_ctx, $ctx, $targets_ref) = @_;
    my %FILE_TYPE_UTIL_OF = %{$attrib_ref->{file_type_util_of}};
    my %FILE_EXT_OF;
    my %FILE_NAME_OPTION_OF;
    for my $FILE_TYPE_UTIL (values(%FILE_TYPE_UTIL_OF)) {
        while (my $key = each(%{$FILE_TYPE_UTIL->target_file_ext_of()})) {
            $FILE_EXT_OF{$key} ||= _prop($attrib_ref, 'file-ext.' . $key, $ctx);
        }
        while (my $key = each(%{$FILE_TYPE_UTIL->target_file_name_option_of()})) {
            $FILE_NAME_OPTION_OF{$key}
                ||= _prop($attrib_ref, 'file-name-option.' . $key, $ctx);
        }
    }
    # Determine the targets for each source
    my %reverse_deps_of = ();
    SOURCE:
    while (my ($ns, $source) = each(%{$ctx->get_source_of()})) {
        my $type = $source->get_type();
        $type ||= q{};
        if (!exists($FILE_TYPE_UTIL_OF{$type})) {
            next SOURCE;
        }
        my $FILE_TYPE_UTIL = $FILE_TYPE_UTIL_OF{$type};
        if (!$FILE_TYPE_UTIL->can('source_to_targets')) {
            next SOURCE;
        }
        for my $target (
            $FILE_TYPE_UTIL->source_to_targets(
                $source, \%FILE_EXT_OF, \%FILE_NAME_OPTION_OF)
        ) {
            my $key = $target->get_key();
            if (exists($ctx->get_target_key_of()->{$key})) {
                $key = $ctx->get_target_key_of()->{$key};
                $target->set_key($key);
            }
            push(@{$targets_ref}, $target);
            $target->set_ns($ns);
            $target->set_path(
                catfile($ctx->get_dest(), $target->get_category(), $key),
            );
            $target->set_path_of_source($source->get_path());
            $target->set_type($type);
            if (!$source->get_up_to_date()) {
                $target->set_status($target->ST_OOD);
            }
            if (exists($target->get_info_of()->{'parents'})) {
                for my $parent (@{$target->get_info_of()->{'parents'}}) {
                    if (!exists($reverse_deps_of{$parent})) {
                        $reverse_deps_of{$parent} = [];
                    }
                    push(
                        @{$reverse_deps_of{$parent}},
                        [$key, $target->get_category()],
                    );
                }
            }
        }
    }
    # Add reverse dependencies
    # E.g. Fortran module has link time dependency on its submodules
    for my $target (@{$targets_ref}) {
        if (exists($reverse_deps_of{$target->get_key()})) {
            push(@{$target->get_deps()}, @{$reverse_deps_of{$target->get_key()}});
        }
    }
    # Determines name-space dependencies
    my %deps_in_ns_in_cat_of; # $cat => {$ns => [$targets ...]}
    FILE_TYPE_UTIL:
    while (my ($type, $FILE_TYPE_UTIL) = each(%FILE_TYPE_UTIL_OF)) {
        if (!$FILE_TYPE_UTIL->can('ns_targets')) {
            next FILE_TYPE_UTIL;
        }
        for my $cat ($FILE_TYPE_UTIL->ns_targets_deps()) {
            $deps_in_ns_in_cat_of{$cat} = {};
        }
        for my $target (
            $FILE_TYPE_UTIL->ns_targets(
                $targets_ref, \%FILE_EXT_OF, \%FILE_NAME_OPTION_OF)
        ) {
            my $key = $target->get_key();
            if (exists($ctx->get_target_key_of()->{$key})) {
                $key = $ctx->get_target_key_of()->{$key};
                $target->set_key($key);
            }
            push(@{$targets_ref}, $target);
            $target->set_type($type);
            $target->set_path(
                catfile($ctx->get_dest(), $target->get_category(), $key),
            );
        }
    }
    for my $target (
        sort {
            $a->get_ns() cmp $b->get_ns() || $a->get_key() cmp $b->get_key();
        } @{$targets_ref}
    ) {
        $EVENT->(
            FCM::Context::Event->MAKE_BUILD_TARGET_FROM_NS,
            ($target->get_ns() ? $target->get_ns() : '/'),
            $target->get_task(),
            $target->get_category(),
            $target->get_key(),
        );
    }
    # Target categories and name-spaces.
    for my $target (@{$targets_ref}) {
        my $cat = $target->get_category();
        if ($cat && exists($deps_in_ns_in_cat_of{$cat})) {
            my $ns_iter = $UTIL->ns_iter($target->get_ns(), $UTIL->NS_ITER_UP);
            # $ns_iter->(); # discard
            while (defined(my $ns = $ns_iter->())) {
                $deps_in_ns_in_cat_of{$cat}{$ns} ||= [];
                push(@{$deps_in_ns_in_cat_of{$cat}{$ns}}, $target->get_key());
            }
        }
    }

    my %CTX_PROP_OF = %{$ctx->get_prop_of()};
    for my $target (@{$targets_ref}) {
        my $key = $target->get_key();
        # Adds categorised name-space dependencies.
        if (exists($target->get_info_of()->{'deps'})) {
            CATEGORY:
            while (my ($cat, $deps_in_ns_ref) = each(%deps_in_ns_in_cat_of)) {
                if (!exists($target->get_info_of()->{'deps'}{$cat})) {
                    next CATEGORY;
                }
                my $cfg_key = 'ns-dep.' . $cat;
                my @ns_list = map {$_ eq q{/} ? q{} : $_}
                    _props($attrib_ref, $cfg_key, $ctx, $target->get_ns());
                for my $ns (@ns_list) {
                    if (exists($deps_in_ns_ref->{$ns})) {
                        push(
                            @{$target->get_deps()},
                            (   map  {[$_, $cat]}
                                grep {$_ ne $key}
                                @{$deps_in_ns_ref->{$ns}}
                            ),
                        );
                    }
                    else {
                        # This will be reported later as missing dependency
                        push(@{$target->get_deps()}, [$ns, $cat, 'ns-dep']);
                    }
                }
            }
        }
        # Remove target dependencies, if necessary
        my @deps;
        DEP:
        for my $dep (@{$target->get_deps()}) {
            my ($dep_key, $dep_type) = @{$dep};
            my $cfg_key = 'no-dep.' . $dep_type;
            if (    !exists($CTX_PROP_OF{$cfg_key})
                ||  !exists($CTX_PROP_OF{$cfg_key}->get_ctx_of()->{$key})
            ) {
                push(@deps, $dep);
                next DEP;
            }
            my @no_dep_keys = shellwords(
                $CTX_PROP_OF{$cfg_key}->get_ctx_of()->{$key}->get_value());
            if (!grep {$_ eq $dep_key} @no_dep_keys) {
                push(@deps, $dep);
                next DEP;
            }
        }
        $target->set_deps(\@deps);
        # Add target dependencies, if necessary
        for my $dep_type (keys(%{$target->get_dep_policy_of()})) {
            my $cfg_key = 'dep.' . $dep_type;
            if (    exists($CTX_PROP_OF{$cfg_key})
                &&  exists($CTX_PROP_OF{$cfg_key}->get_ctx_of()->{$key})
            ) {
                my @dep_keys = shellwords(
                    $CTX_PROP_OF{$cfg_key}->get_ctx_of()->{$key}->get_value());
                for my $dep_key (@dep_keys) {
                    push(@{$target->get_deps()}, [$dep_key, $dep_type]);
                }
            }
        }
    }
}

# Stores the properties relevant to the target.
# Assigns previous checksum and properties, where appropriate.
sub _targets_props_assign {
    my ($attrib_ref, $m_ctx, $ctx, $targets_ref) = @_;
    my $P_TARGET_GETTER
        = _prev_hash_item_getter($m_ctx, $ctx, sub {$_[0]->get_target_of()});
    my %NO_INHERIT_CATEGORY_IN
        = map {$_ => 1} _props($attrib_ref, 'no-inherit-target-category', $ctx);
    my %CTX_PROP_OF = %{$ctx->get_prop_of()};
    for my $target (@{$targets_ref}) {
        my $key = $target->get_key();
        # Properties
        my $FILE_TYPE_UTIL
            = $attrib_ref->{file_type_util_of}->{$target->get_type()};
        my $task = $FILE_TYPE_UTIL->task_of()->{$target->get_task()};
        if ($task->can('prop_of')) {
            my %prop_of = %{$task->prop_of($target)};
            while (my $name = each(%prop_of)) {
                if (    exists($CTX_PROP_OF{$name})
                    &&  exists($CTX_PROP_OF{$name}->get_ctx_of()->{$key})
                ) {
                    $target->get_prop_of()->{$name}
                        = $CTX_PROP_OF{$name}->get_ctx_of()->{$key}->get_value();
                }
                else {
                    $target->get_prop_of()->{$name}
                        = _prop($attrib_ref, $name, $ctx, $target->get_ns());
                }
            }
        }
        if ($FILE_TYPE_UTIL->can('target_deps_filter')) {
            $FILE_TYPE_UTIL->target_deps_filter($target);
        }
        # Path, checksum and previous properties
        my $p_target = $P_TARGET_GETTER->($key);
        if (defined($p_target)) {
            $target->set_checksum($p_target->get_checksum());
            if ($p_target->is_ok()) {
                $target->set_path_of_prev($p_target->get_path());
                $target->set_prop_of_prev_of($p_target->get_prop_of());
            }
            else {
                $target->set_path_of_prev($p_target->get_path_of_prev());
                $target->set_prop_of_prev_of($p_target->get_prop_of_prev_of());
                $target->set_status($target->ST_OOD);
            }
            if (exists($NO_INHERIT_CATEGORY_IN{$target->get_category()})) {
                $target->set_path_of_prev($target->get_path());
            }
        }
    }
}

# Selects targets to update.
sub _targets_select {
    my ($attrib_ref, $m_ctx, $ctx, $targets_ref) = @_;
    my $time = time();
    my $timer = $UTIL->timer();
    my %select_by = %{$ctx->get_target_select_by()};
    my %target_of;
    my %targets_of;
    my %target_set;
    my %has_ns_in; # available sets of name-spaces
    for my $target (@{$targets_ref}) {
        ATTR_NAME:
        for (
            #$attr_name, $attr_func
            ['key'     , sub {$_[0]->get_key()}],
            ['category', sub {$_[0]->get_category()}],
            ['task'    , sub {$_[0]->get_task()}],
        ) {
            my ($attr_name, $attr_func) = @{$_};
            for my $ns (sort keys(%{$select_by{$attr_name}})) {
                my %attr_set = %{$select_by{$attr_name}->{$ns}};
                if (    exists($attr_set{$attr_func->($target)})
                    &&  (!$ns || $UTIL->ns_in_set($target->get_ns(), {$ns => 1}))
                ) {
                    $target_set{$target->get_key()} = 1;
                    last ATTR_NAME;
                }
            }
        }
        if (exists($target_of{$target->get_key()})) {
            if (!exists($targets_of{$target->get_key()})) {
                $targets_of{$target->get_key()}
                    = [delete($target_of{$target->get_key()})];
            }
            push(@{$targets_of{$target->get_key()}}, $target);
        }
        else {
            $target_of{$target->get_key()} = $target;
        }
        # Name-spaces
        my $ns_iter = $UTIL->ns_iter($target->get_ns(), $UTIL->NS_ITER_UP);
        NS:
        while (defined(my $ns = $ns_iter->())) {
            if (exists($has_ns_in{$ns})) {
                last NS;
            }
            $has_ns_in{$ns} = 1;
        }
    }
    my @target_keys = sort keys(%target_set);

    # Wraps each relevant target with a state object.
    # Walks the target dependency tree to build a state dependency tree.
    # Checks for missing dependencies.
    # Checks for duplicated target.
    my @items = map {[[$_, undef]]} @target_keys;
    my %state_of;
    my %dup_in;
    my %cyc_in;
    my %missing_deps_in;
    ITEM:
    while (my $item = pop(@items)) {
        my ($unit, @up_units) = @{$item};
        my ($key, $type) = @{$unit};
        my @up_keys = map {$_->[0]} @up_units;
        if (   exists($cyc_in{$key})
            || exists($dup_in{$key})
            || exists($missing_deps_in{$key})
        ) {
            next ITEM;
        }
        if (exists($state_of{$key})) {
            # Already visited this ITEM
            # Detect cyclic dependency
            if (    !$state_of{$key}->get_cyclic_ok()
                &&  grep {$_->[0] eq $key} @up_units
            ) {
                my @_up_units = (@up_units, $unit);
                my $_up_unit_last = pop(@_up_units);
                DEP_UP_KEY:
                while (my $_up_unit = pop(@_up_units)) {
                    my ($_up_key, $_up_type) = @{$_up_unit};
                    my @dep_up_deps = @{$state_of{$_up_key}->get_deps()};
                    # If parent of $_up_unit_last does not depend on
                    # $_up_unit_last, chain is broken, and we are OK.
                    my ($_up_key_last, $_up_type_last) = @{$_up_unit_last};
                    if (!grep {     $_->[0]->get_key() eq $_up_key_last
                                ||  $_->[1] eq $_up_type_last
                        } @dep_up_deps
                    ) {
                        last DEP_UP_KEY;
                    }
                    if ($type && $key eq $_up_key && $type eq $_up_type) {
                        $cyc_in{$key} = {'keys' => [@up_keys, $key]};
                        next ITEM;
                    }
                    $_up_unit_last = $_up_unit;
                }
            }
            $state_of{$key}->set_cyclic_ok(1);
            # Float current target up dependency chain
            my $is_directly_related = 1;
            UP_KEY:
            for my $up_key (reverse(@up_keys)) {
                if ($state_of{$up_key}->add_visitor(
                        $state_of{$key}->get_target(),
                        $type,
                        $is_directly_related,
                )) {
                    last UP_KEY;
                }
                $is_directly_related = 0;
            }
            # Add floatable dependencies up the dependency chain
            for my $visitor (values(%{$state_of{$key}->get_floatables()})) {
                UP_KEY:
                for my $up_key (reverse(@up_keys)) {
                    if ($state_of{$up_key}->add_visitor(@{$visitor})) {
                        last UP_KEY;
                    }
                }
            }
            next ITEM;
        }

        # First visit to this ITEM
        # Checks for duplicated target
        if (exists($targets_of{$key})) {
            $dup_in{$key} = {
                'keys' => [@up_keys, $key],
                'values' => [map {$_->get_ns()} @{$targets_of{$key}}],
            };
            next ITEM;
        }
        # Wraps all required targets with a STATE object
        $state_of{$key} = $STATE->new(
            {id => $key, target => $target_of{$key}},
        );
        my $target = $target_of{$key};
        DEP:
        for (
            grep {$_->[0] ne $key}
            sort {$a->[0] cmp $b->[0]}
            @{$target->get_deps()}
        ) {
            my ($dep_key, $dep_type, $dep_remark) = @{$_};
            # Duplicated targets
            if (exists($targets_of{$dep_key})) {
                $dup_in{$dep_key} = {
                    'keys' => [@up_keys, $key, $dep_key],
                    'values' => [map {$_->get_ns()} @{$targets_of{$dep_key}}],
                };
                next DEP;
            }
            # Missing dependency
            if (!exists($target_of{$dep_key})) {
                if (!exists($missing_deps_in{$key})) {
                    $missing_deps_in{$key} = {
                        'keys'   => [@up_keys, $key, $dep_key],
                        'values' => [],
                    };
                }
                push(
                    @{$missing_deps_in{$key}{'values'}},
                    [$dep_key, $dep_type, $dep_remark],
                );
                next DEP;
            }
            # OK
            push(@items, [[$dep_key, $dep_type], @up_units, [$key, $type]]);
            # add_visitor, is_directly_related=1
            $state_of{$key}->add_visitor($target_of{$dep_key}, $dep_type, 1)
        }
        # Float current target up dependency chain
        my $is_directly_related = 1;
        UP_KEY:
        for my $up_key (reverse(@up_keys)) {
            if ($state_of{$up_key}->add_visitor(
                    $target, $type, $is_directly_related,
            )) {
                last UP_KEY;
            }
            $is_directly_related = 0;
        }
        # Adds triggers
        for my $trigger_key (@{$target->get_triggers()}) {
            if (!exists($state_of{$trigger_key})) {
                unshift(@items, [[$trigger_key, undef]]);
            }
        }
    }
    # Visitors no longer used
    for my $state (values(%state_of)) {
        $state->free_visitors();
    }
    # Assigns targets to build context
    %{$ctx->get_target_of()}
        = map {($_->get_id() => $_->get_target())} values(%state_of);

    # Report cyclic dependencies
    # Report duplicated targets
    # Report missing dependencies
    # Report bad keys in target select
    if (keys(%cyc_in)) {
        return $E->throw($E->BUILD_TARGET_CYC, \%cyc_in);
    }
    if (keys(%dup_in)) {
        return $E->throw($E->BUILD_TARGET_DUP, \%dup_in);
    }
    my @ignore_missing_dep_ns_list = map {$_ eq q{/} ? q{} : $_} (
        _props($attrib_ref, 'ignore-missing-dep-ns', $ctx)
    );
    KEY:
    for my $key (sort(keys(%missing_deps_in))) {
        my $target = $target_of{$key};
        for my $ns (@ignore_missing_dep_ns_list) {
            if ($UTIL->ns_common($ns, $target->get_ns()) eq $ns) { # target in ns
                my $hash_ref = delete($missing_deps_in{$key});
                my @deps = @{$hash_ref->{"values"}};
                for my $dep (@deps) {
                    $EVENT->(
                        FCM::Context::Event->MAKE_BUILD_TARGET_MISSING_DEP,
                        $key, @{$dep},
                    );
                }
                next KEY;
            }
        }
    }
    if (keys(%missing_deps_in)) {
        return $E->throw($E->BUILD_TARGET_DEP, \%missing_deps_in);
    }
    if (exists($select_by{key}{q{}})) {
        my @bad_keys = grep {!exists($state_of{$_})} keys(%{$select_by{key}{q{}}});
        if (@bad_keys) {
            return $E->throw($E->BUILD_TARGET_BAD, \@bad_keys);
        }
    }
    # Walk the tree and report it
    my @report_items = map {[$_]} sort @target_keys;
    my %reported;
    ITEM:
    while (my $item = pop(@report_items)) {
        my ($key, @stack) = @{$item};
        my @deps = sort {$a->[0]->get_key() cmp $b->[0]->get_key()}
            @{$state_of{$key}->get_deps()};
        my @more_items = reverse(map {[$_->[0]->get_key(), @stack, $key]} @deps);
        my $n_more_items;
        if (exists($reported{$key})) {
            $n_more_items = scalar(@more_items);
        }
        else {
            push(@report_items, @more_items);
        }
        $attrib_ref->{util}->event(
            FCM::Context::Event->MAKE_BUILD_TARGET_STACK,
            $key, scalar(@stack), $n_more_items,
        );
        $reported{$key} = 1;
    }
    $EVENT->(
        FCM::Context::Event->MAKE_BUILD_TARGET_SELECT,
        {map {$_ => $target_of{$_}} @target_keys},
    );
    # TODO: error if nothing to build?

    # Checks whether properties with name-spaces are valid.
    my @invalid_prop_ns_list;
    while (my ($name, $prop) = each(%{$ctx->get_prop_of()})) {
        while (my ($ns, $prop_ctx) = each(%{$prop->get_ctx_of()})) {
            if (    !$prop_ctx->get_inherited()
                &&  !exists($target_of{$ns})
                &&  !exists($has_ns_in{$ns})
            ) {
                push(
                    @invalid_prop_ns_list,
                    [$ctx->get_id(), $name, $ns, $prop_ctx->get_value()],
                );
            }
        }
    }
    if (@invalid_prop_ns_list) {
        return $E->throw($E->MAKE_PROP_NS, \@invalid_prop_ns_list);
    }

    $EVENT->(FCM::Context::Event->MAKE_BUILD_TARGET_SELECT_TIMER, $timer->());

    # Returns list of keys of top targets, and the states
    ([map {$state_of{$_}} reverse(@target_keys)], \%state_of);
}

# Returns true if $target dependencies are done.
sub _target_deps_are_done {
    my ($state, $state_hash_ref, $stack_ref) = @_;
    my @deps = map {[$_->[0]->get_key(), $_->[1]]} @{$state->get_deps()};
    for my $k (sort grep {$state_hash_ref->{$_}->is_ready()} map {$_->[0]} @deps) {
        if (!grep {$_->get_id() eq $k} @{$stack_ref}) {
            push(@{$stack_ref}, $state_hash_ref->{$k});
        }
    }
    my %not_done
        = map  {@{$_}}
          grep {!$_->[1]->is_done()}
          map  {[$_->[0], $state_hash_ref->{$_->[0]}]}
          @deps;
    if (keys(%not_done)) {
        $state->set_value($STATE->PENDING);
        while (my ($k, $s) = each(%not_done)) {
            $state->get_pending_for()->{$k} = $s;
            $s->get_needed_by()->{$state->get_id()} = $state;
        }
        return 0;
    }
    return 1;
}

# Returns true if $target has failed dependencies.
sub _target_check_failed_dep {
    my ($state, $state_hash_ref) = @_;
    my $target = $state->get_target();
    for my $dep (@{$state->get_deps()}) {
        my ($target_of_dep, $type_of_dep) = @{$dep};
        if ($target_of_dep->is_failed()) {
            return 1;
        }
        if (    exists($target_of_dep->get_status_of()->{$type_of_dep})
            &&  $target_of_dep->get_status_of()->{$type_of_dep}
                    eq $target->ST_FAILED
        ) {
            return 1;
        }
    }
    return 0;
}

# Returns true if $target is out of date.
sub _target_check_ood {
    my ($state, $state_hash_ref, $checksum_method) = @_;
    my $target = $state->get_target();
    # Dependencies
    my $rc;
    for my $dep (@{$state->get_deps()}) {
        my ($target_of_dep, $type_of_dep) = @{$dep};
        if (    $target_of_dep->is_modified()
            ||  exists($target_of_dep->get_status_of()->{$type_of_dep})
                &&  $target_of_dep->get_status_of()->{$type_of_dep}
                    eq $target->ST_MODIFIED
        ) {
            if (exists($target->get_status_of()->{$type_of_dep})) {
                $target->get_status_of()->{$type_of_dep} = $target->ST_MODIFIED;
                if (    $target->get_path_of_prev()
                    &&  $target->get_path() ne $target->get_path_of_prev()
                ) {
                    # Inherited build, cannot just pass on a status
                    $rc = 1;
                }
            }
            else {
                $rc = 1;
            }
        }
    }
    if ($rc || $target->get_status() eq $target->ST_OOD) {
        return 1;
    }
    # Dest and properties
    my $path_of_prev = $target->get_path_of_prev();
    my $checksum = $target->get_checksum();
    my $prop_hash_ref = $target->get_prop_of();
    my $prop_of_prev_hash_ref = $target->get_prop_of_prev_of();
    (       !$path_of_prev
        ||  !-e $path_of_prev
        ||  $UTIL->file_checksum($path_of_prev, $checksum_method) ne $checksum
        ||  $UTIL->hash_cmp($prop_hash_ref, $prop_of_prev_hash_ref)
    );
}

# Callback to prepare the target for the task.
sub _target_prep {
    my ($state, $ctx) = @_;
    my $target = $state->get_target();
    # Creates the container directory, where necessary
    my %paths_of_dirs_set;
    for my $t (
        $target,
        map {$ctx->get_target_of($_)} @{$target->get_triggers()},
    ) {
        $paths_of_dirs_set{dirname($t->get_path())} = 1;
    }
    for my $path_of_dir (keys(%paths_of_dirs_set)) {
        if (!-d $path_of_dir) {
            eval {mkpath($path_of_dir)};
            if ($@) {
                return $E->throw($E->DEST_CREATE, $path_of_dir);
            }
        }
    }
    # Put in required info
    if ($target->get_info_of('paths')) {
        @{$target->get_info_of('paths')} = @{$ctx->get_dests()};
    }
    if ($target->get_info_of('deps')) {
        my $info_deps_ref = $target->get_info_of('deps');
        my %set_of = map {$_ => {}} keys(%{$info_deps_ref});
        for my $dep (@{$state->get_deps()}) {
            my ($target_of_dep, $type) = @{$dep};
            my $key = $target_of_dep->get_key();
            if (exists($set_of{$type}) && !$set_of{$type}{$key}) {
                if ($target_of_dep->get_ns() eq $target->get_ns()) {
                    # E.g. main *.o of *.exe
                    unshift(@{$info_deps_ref->{$type}}, $key);
                }
                else {
                    push(@{$info_deps_ref->{$type}}, $key);
                }
                $set_of{$type}{$key} = 1;
            }
        }
    }
}

# Sets state and stack when a $target has failed to update or cannot be updated
# due to failed dependencies.
sub _target_update_failed {
    my ($stat_hash_ref,
        $ctx,
        $target,
        $state_hash_ref,
        $stack_ref,
        $elapsed_time, # only defined if target update action is done
    ) = @_;
    my $key = $target->get_key();
    my $state = $state_hash_ref->{$key};
    $state->set_value($STATE->DONE);
    # If this target is needed by other targets...
    while (my ($k, $s) = each(%{$state->get_needed_by()})) {
        my $pending_for_ref = $s->get_pending_for();
        delete($pending_for_ref->{$key});
        if (!keys(%{$pending_for_ref})) {
            $s->set_value($STATE->DONE);
            # Remove from stack
            @{$stack_ref} = grep {$_->get_id() ne $k} @{$stack_ref};
            $s->get_target()->set_status($target->ST_FAILED);
            push(@{$s->get_target()->get_failed_by()}, $key);
        }
    }
    if (defined($elapsed_time)) { # Done target update
        my $target0 = $ctx->get_target_of()->{$target->get_key()};
        $target0->set_info_of({}); # unset
        $target0->set_checksum(undef);
        $target0->set_path(undef);
        $target0->set_prop_of_prev_of({}); # unset
        $target0->set_path_of_prev(undef); # unset
        $target0->set_status($target->ST_FAILED);
        push(@{$target0->get_failed_by()}, $target->get_key());
        ++$stat_hash_ref->{$target->get_task()}{n}{$target->ST_FAILED};
        $stat_hash_ref->{$target->get_task()}{t} += $elapsed_time;
    }
    else { # No target update required
        $target->set_path(undef);
        $target->set_prop_of_prev_of({}); # unset
        $target->set_path_of_prev(undef); # unset
        $target->set_status($target->ST_FAILED);
        for my $dep (@{$state->get_deps()}) {
            my ($dep_target, $dep_type) = @{$dep};
            my $dep_key = $dep_target->get_key();
            if (    $dep_target->is_failed()
                &&  !grep {$_ eq $dep_key} @{$target->get_failed_by()}
            ) {
                push(@{$target->get_failed_by()}, $dep_key);
            }
        }
        ++$stat_hash_ref->{$target->get_task()}{n}{$target->ST_FAILED};
    }
    $EVENT->(
        FCM::Context::Event->MAKE_BUILD_TARGET_FAIL, $target, $elapsed_time,
    );
}

# Sets state and stack when a $target is up to date or updated successfully.
sub _target_update_ok {
    my ($stat_hash_ref,
        $ctx,
        $target,
        $state_hash_ref,
        $stack_ref,
        $elapsed_time, # only defined if target update action is done
    ) = @_;
    my $key = $target->get_key();
    my $state = $state_hash_ref->{$key};
    $state->set_value($STATE->DONE);
    # If this target is needed by other targets...
    my @released_pending_states;
    while (my ($k, $s) = each(%{$state->get_needed_by()})) {
        my $pending_for_ref = $s->get_pending_for();
        delete($pending_for_ref->{$key});
        if ($s->is_pending() && !keys(%{$pending_for_ref})) {
            $s->set_value($STATE->READY);
            if (!grep {$_->get_id() eq $k} @{$stack_ref}) {
                push(@released_pending_states, $s);
            }
        }
    }
    push(
        @{$stack_ref},
        sort {$a->get_id() cmp $b->get_id()} @released_pending_states,
    );
    if (defined($elapsed_time)) { # Done target update
        my $target0 = $ctx->get_target_of()->{$target->get_key()};
        $target0->set_info_of({}); # unset
        $target0->set_checksum($target->get_checksum());
        $target0->set_path($target->get_path());
        $target0->set_prop_of_prev_of({}); # unset
        $target0->set_path_of_prev(undef); # unset
        $target0->set_status($target->get_status());
        ++$stat_hash_ref->{$target->get_task()}{n}{$target->get_status()};
        $stat_hash_ref->{$target->get_task()}{t} += $elapsed_time;
    }
    else { # No target update required
        if ($target->get_path_of_prev()) {
            $target->set_path($target->get_path_of_prev());
        }
        $target->set_prop_of_prev_of({}); # unset
        $target->set_path_of_prev(undef); # unset
        $target->set_status($target->ST_UNCHANGED);
        ++$stat_hash_ref->{$target->get_task()}{n}{$target->ST_UNCHANGED};
    }
    $EVENT->(
        FCM::Context::Event->MAKE_BUILD_TARGET_DONE, $target, $elapsed_time,
    );
}

# Returns a list containing the inherited contexts with the same ID as $ctx.
sub _i_ctx_list {
    my ($m_ctx, $ctx) = @_;
    grep
        {defined()}
    map
        {$_->get_ctx_of($ctx->get_id())}
    @{$m_ctx->get_inherit_ctx_list()};
}

# Returns a function that returns the previous source/target of a specified key.
sub _prev_hash_item_getter {
    my ($m_ctx, $ctx, $getter_ref) = @_;
    my $p_m_ctx = $m_ctx->get_prev_ctx();
    my %p_item_of;
    my $ctx_id = $ctx->get_id();
    if (defined($p_m_ctx) && defined($p_m_ctx->get_ctx_of($ctx_id))) {
        %p_item_of = %{$getter_ref->($p_m_ctx->get_ctx_of($ctx_id))};
    }
    else {
        for my $i_ctx (_i_ctx_list($m_ctx, $ctx)) {
            %p_item_of = (%p_item_of, %{$getter_ref->($i_ctx)});
        }
    }
    sub {exists($p_item_of{$_[0]}) ? $p_item_of{$_[0]} : undef};
}

# Perform final actions.
# Archive intermediate target directories if necessary.
sub _finally {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    if (!$m_ctx->get_option_of('archive')) {
        return;
    }
    my %can_archive = map {($_ => 1)} _props(
        $attrib_ref, 'archive-ok-target-category', $ctx);
    opendir(my $handle, $ctx->get_dest());
    while (my $name = readdir($handle)) {
        if ($can_archive{$name}) {
            my @command = (
                qw{tar -c -z}, '-C', $ctx->get_dest(),
                '-f', catfile($ctx->get_dest(), $name . '.tar.gz'),
                $name,
            );
            my %value_of = %{$UTIL->shell_simple(\@command)};
            if ($value_of{'rc'} == 0) {
                rmtree(catfile($ctx->get_dest(), $name));
            }
        }
    }
    closedir($handle);
}

# ------------------------------------------------------------------------------
package FCM::System::Make::Build::State;
use base qw{FCM::Class::HASH};

use constant {
    DONE       => 'DONE',       # state value
    READY      => 'READY',      # state value
    PENDING    => 'PENDING',    # state value
};

__PACKAGE__->class({
    cyclic_ok   => '$',
    deps        => '@',
    floatables  => '%',
    id          => '$',
    needed_by   => '%',
    pending_for => '%',
    target      => 'FCM::Context::Make::Build::Target',
    value       => {isa => '$', default => READY},
    visited_by  => '%',
});

sub add_visitor {
    my ($self, $dep_target, $dep_type, $is_directly_related) = @_;
    my $dep_key = $dep_target->get_key();
    my $dep_str = join(':', $dep_key, $dep_type);
    # Dependency has already visited me, return cached return value
    if (exists($self->get_visited_by()->{$dep_str})) {
        return $self->get_visited_by()->{$dep_str};
    }
    # Adopt dep_target as my dependency if there is a policy to do so
    my $target = $self->get_target();
    my $policy = $target->get_dep_policy_of($dep_type);
    if (    $policy
        &&  ($policy ne $target->POLICY_FILTER_IMMEDIATE || $is_directly_related)
        &&  (!grep {$_->[0]->get_key() eq $dep_key} @{$self->get_deps()})
        &&  (!grep {$_ eq $dep_key} @{$target->get_triggers()})
    ) {
        push(@{$self->get_deps()}, [$dep_target, $dep_type]);
    }
    # If target is captured by me, return true.
    # Otherwise, return false, and the target is a floatable.
    $self->get_visited_by()->{$dep_str}
        = ($policy && $policy eq $target->POLICY_CAPTURE);
    if (    !$self->get_visited_by()->{$dep_str}
        &&  !exists($self->get_floatables()->{$dep_str})
    ) {
        $self->get_floatables()->{$dep_str} = [$dep_target, $dep_type];
    }
    return $self->get_visited_by()->{$dep_str};
}

sub free_visitors {
    my ($self) = @_;
    %{$self->get_floatables()} = ();
    %{$self->get_visited_by()} = ();
}

sub is_done {
    $_[0]->{value} eq DONE;
}

sub is_pending {
    $_[0]->{value} eq PENDING;
}

sub is_ready {
    $_[0]->{value} eq READY;
}
#-------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build

=head1 SYNOPSIS

    use FCM::System::Make::Build;

=head1 DESCRIPTION

Implements the build sub-system. An instance of this class is expected to be
initialised and called by L<FCM::System::Make|FCM::System::Make>.

=head1 METHODS

See L<FCM::System::Make|FCM::System::Make> for detail.

=head1 ATTRIBUTES

The $class->new(\%attrib) method of this class supports the following
attributes:

=over 4

=item config_parser_of

A HASH to map the labels in a configuration file to their parsers. (default =
%FCM::System::Make::Build::CONFIG_PARSER_OF)

=item target_select_by

A HASH to map the default target selector. The keys should be "category", "key",
"ns", or "task". (default = %FCM::System::Make::Build::TARGET_SELECT_by)

=item file_type_utils

An ARRAY of file type utility classes to be loaded into the file_type_util_of
HASH. (default = @FCM::System::Make::Build::FILE_TYPE_UTILS)

=item file_type_util_of

A HASH to map the file type names to the utilities to manipulate the given file
types. An values in this HASH overrides the classes in I<file_type_utils>.
(default = determined by I<file_type_utils>)

=item prop_of

A HASH to map the names of the properties to their settings. Each setting
is a 2-element ARRAY reference, where element [0] is the default setting
and element [1] is a flag to indicate whether the property accepts a name-space
or not. (default = %FCM::System::Make::Build::PROP_OF + values loaded from the
file type utilities)

=item util

See L<FCM::System::Make|FCM::System::Make> for detail.

=back

=head1 COPYRIGHT

Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.

=cut
