# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-14 Met Office.
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
package FCM::System::Make::Extract;
use base qw{FCM::Class::CODE};

use FCM::Context::ConfigEntry;
use FCM::Context::Event;
use FCM::Context::Make::Extract;
use FCM::Context::Locator;
use FCM::Context::Task;
use FCM::System::Exception;
use FCM::System::Make::Share::Subsystem;
use File::Basename qw{dirname};
use File::Compare qw{compare};
use File::Copy qw{copy};
use File::Path qw{mkpath rmtree};
use File::Spec::Functions qw{catfile tmpdir};
use File::Temp;
use List::Util qw{first};
use Storable qw{dclone};

# Aliases
our $UTIL;
my $E = 'FCM::System::Exception';

# Configuration parser map: label to action
our %CONFIG_PARSER_OF = (
    'location'  => \&_config_parse_location,
    'ns'        => \&_config_parse_ns_list,
    'path-excl' => _config_parse_path_func(
        sub {$_->get_path_excl()}, sub {$_->set_path_excl(@_)}, '@',
    ),
    'path-incl' => _config_parse_path_func(
        sub {$_->get_path_incl()}, sub {$_->set_path_incl(@_)}, '@',
    ),
    'path-root' => _config_parse_path_func(
        sub {$_->get_path_root()}, sub {$_->set_path_root(@_)},
    ),
);

# Properties from FCM::Util
our @UTIL_PROP_KEYS = qw{diff3 diff3.flags};

# Creates the class.
__PACKAGE__->class(
    {   config_parser_of => {isa => '%', default => {%CONFIG_PARSER_OF}},
        prop_of          => '%',
        shared_util_of   => '%',
        util             => '&',
    },
    {   init => \&_init,
        action_of => {
            config_parse              => \&_config_parse,
            config_parse_class_prop   => \&_config_parse_class_prop,
            config_parse_inherit_hook => \&_config_parse_inherit_hook,
            config_unparse            => \&_config_unparse,
            config_unparse_class_prop => \&_config_unparse_class_prop,
            ctx                       => \&_ctx,
            main                      => \&_main,
        },
    },
);

# Initialises the helpers of the class.
sub _init {
    my ($attrib_ref) = @_;
    for my $util_prop_key (@UTIL_PROP_KEYS) {
        my $prop = $attrib_ref->{util}->external_cfg_get($util_prop_key);
        $attrib_ref->{prop_of}{$util_prop_key} = [$prop];
    }
}

# Reads the extract.location declaration from a config entry.
sub _config_parse_location {
    my ($attrib_ref, $ctx, $entry) = @_;
    if (!@{$entry->get_ns_list()}) {
        return $E->throw($E->CONFIG_NS, $entry);
    }
    my %PARSER_OF = (
        'base'    => \&_config_parse_location_base,
        'diff'    => \&_config_parse_location_diff,
        'primary' => \&_config_parse_location_primary,
    );
    my %modifier_of = %{$entry->get_modifier_of()};
    if (!grep {exists($modifier_of{$_})} keys(%PARSER_OF)) {
        $modifier_of{'base'} = 1;
    }
    for my $key (grep {exists($modifier_of{$_})} keys(%PARSER_OF)) {
        $PARSER_OF{$key}->($attrib_ref, $ctx, $entry);
    }
}

# Reads the extract.location{base} declaration from a config entry.
sub _config_parse_location_base {
    my ($attrib_ref, $ctx, $entry) = @_;
    my %option;
    if (exists($entry->get_modifier_of()->{'type'})) {
        %option = ('type' => $entry->get_modifier_of()->{'type'});
    }
    for my $ns (@{$entry->get_ns_list()}) {
        if (!exists($ctx->get_project_of()->{$ns})) {
            $ctx->get_project_of()->{$ns} = $ctx->CTX_PROJECT->new({ns => $ns});
        }
        my $project = $ctx->get_project_of()->{$ns};
        if ($project->get_inherited()) {
            if (!$entry->get_value()) {
                return $E->throw($E->CONFIG_VALUE, $entry);
            }
            my $locator = FCM::Context::Locator->new(
                $entry->get_value(), \%option,
            );
            if ($project->get_locator()) {
                $attrib_ref->{util}->loc_rel2abs(
                    $locator,
                    $project->get_locator(),
                );
            }
            $attrib_ref->{util}->loc_as_invariant($locator);
            my $i_locator = $project->get_trees()->[0]->get_locator();
            if ($locator->get_value() ne $i_locator->get_value()) {
                return $E->throw($E->CONFIG_CONFLICT, $entry);
            }
        }
        else {
            if (    !exists($project->get_trees()->[0])
                ||  !defined($project->get_trees()->[0])
            ) {
                $project->get_trees()->[0]
                    = $ctx->CTX_TREE->new({key => 0, ns => $ns});
            }
            if ($entry->get_value()) {
                my $locator = FCM::Context::Locator->new(
                    $entry->get_value(), \%option,
                );
                $project->get_trees()->[0]->set_locator($locator);
            }
            else {
                $project->get_trees()->[0] = undef;
            }
        }
    }
}

# Reads the extract.location{diff} declaration from a config entry.
sub _config_parse_location_diff {
    my ($attrib_ref, $ctx, $entry) = @_;
    my %option;
    if (exists($entry->get_modifier_of()->{'type'})) {
        %option = ('type' => $entry->get_modifier_of()->{'type'});
    }
    for my $ns (@{$entry->get_ns_list()}) {
        if (!exists($ctx->get_project_of()->{$ns})) {
            $ctx->get_project_of()->{$ns} = $ctx->CTX_PROJECT->new({ns => $ns});
        }
        my $project = $ctx->get_project_of()->{$ns};
        my ($base, @diffs) = @{$project->get_trees()};
        @diffs = grep {
                $_->get_inherited()
            ||      $option{type}
                &&  $_->get_locator()->get_type()
                &&  $option{type} ne $_->get_locator()->get_type()
        } @diffs;
        for my $value ($entry->get_values()) {
            if (!$value) {
                return $E->throw($E->CONFIG_VALUE, $entry);
            }
            push(
                @diffs,
                $ctx->CTX_TREE->new({
                    key     => scalar(@diffs) + 1,
                    locator => FCM::Context::Locator->new($value, \%option),
                    ns      => $ns,
                }),
            );
        }
        @{$project->get_trees()} = ($base, @diffs);
    }
}

# Reads the extract.location{primary} declaration from a config entry.
sub _config_parse_location_primary {
    my ($attrib_ref, $ctx, $entry) = @_;
    my %option;
    if (exists($entry->get_modifier_of()->{'type'})) {
        %option = ('type' => $entry->get_modifier_of()->{'type'});
    }
    for my $ns (@{$entry->get_ns_list()}) {
        if (!exists($ctx->get_project_of()->{$ns})) {
            $ctx->get_project_of()->{$ns} = $ctx->CTX_PROJECT->new({ns => $ns});
        }
        my $project = $ctx->get_project_of()->{$ns};
        if ($project->get_inherited()) {
            if ($project->get_locator()->get_value() ne $entry->get_value()) {
                return $E->throw($E->CONFIG_CONFLICT, $entry);
            }
        }
        elsif ($entry->get_value()) {
            $project->set_locator(
                FCM::Context::Locator->new($entry->get_value(), \%option),
            );
        }
        else {
            $project->set_locator(undef);
        }
    }
}

# Reads the extract.ns declaration from a config entry.
sub _config_parse_ns_list {
    my ($attrib_ref, $ctx, $entry) = @_;
    @{$ctx->get_ns_list()} = $entry->get_values();
}

# Returns a function to parse extract.path-*.
sub _config_parse_path_func {
    my ($getter, $setter, $isa) = @_;
    $isa ||= '$';
    sub {
        my ($attrib_ref, $ctx, $entry) = @_;
        my @ns_list
            = @{$entry->get_ns_list()} ? @{$entry->get_ns_list()}
            :                            @{$ctx->get_ns_list()}
            ;
        for my $ns (@ns_list) {
            if (!exists($ctx->get_project_of()->{$ns})) {
                $ctx->get_project_of()->{$ns}
                    = $ctx->CTX_PROJECT->new({ns => $ns});
            }
            my $project = $ctx->get_project_of()->{$ns};
            my $value = $entry->get_value();
            if ($isa eq '@') {
                $value = [map {$_ eq q{/} ? q{} : $_} $entry->get_values()];
            }
            local($_) = $project;
            if ($_->get_inherited()) {
                my $old = $getter->();
                my $new = $value;
                if ($isa eq '@') {
                    $old = _config_unparse_join(@{$old});
                    $new = _config_unparse_join(@{$new});
                }
                if ($old ne $new) {
                    return $E->throw($E->CONFIG_CONFLICT, $entry);
                }
            }
            else {
                $setter->($value);
            }
        }
    };
}

# A hook command for the "inherit/use" declaration.
sub _config_parse_inherit_hook {
    my ($attrib_ref, $ctx, $i_ctx) = @_;
    @{$ctx->get_ns_list()} = @{$i_ctx->get_ns_list()};
    while (my ($ns, $i_project) = each(%{$i_ctx->get_project_of()})) {
        my $project = dclone($i_project);
        $project->set_inherited(1);
        for my $tree (@{$project->get_trees()}) {
            $tree->set_inherited(1);
        }
        $ctx->get_project_of()->{$ns} = $project;
    }
    _config_parse_inherit_hook_prop($attrib_ref, $ctx, $i_ctx);
}

# Turns a context into a list of configuration entries.
sub _config_unparse {
    my ($attrib_ref, $ctx) = @_;
    my %LABEL_OF
        = map {($_ => $ctx->get_id() . q{.} . $_)} keys(%CONFIG_PARSER_OF);
    my @entries = (
        FCM::Context::ConfigEntry->new({
            label => $LABEL_OF{ns},
            value => _config_unparse_join(@{$ctx->get_ns_list()}),
        }),
    );
    for my $p_ns (sort keys(%{$ctx->get_project_of()})) {
        my $project = $ctx->get_project_of($p_ns);
        my ($base, @diffs) = @{$project->get_trees()};
        if (!$project->get_inherited()) {
            if (defined($project->get_locator())) {
                my $locator = $project->get_locator();
                my %modifier_of = (primary => 1, type => $locator->get_type());
                push(
                    @entries,
                    FCM::Context::ConfigEntry->new({
                        label       => $LABEL_OF{location},
                        modifier_of => \%modifier_of,
                        ns_list     => [$p_ns],
                        value       => $locator->get_value(),
                    }),
                );
            }
            if (@{$project->get_path_excl()}) {
                my @values = map {$_ ? $_ : q{/}} @{$project->get_path_excl()};
                push(
                    @entries,
                    FCM::Context::ConfigEntry->new({
                        label       => $LABEL_OF{'path-excl'},
                        ns_list     => [$p_ns],
                        value       => _config_unparse_join(@values),
                    }),
                );
            }
            if (@{$project->get_path_incl()}) {
                my @values = map {$_ ? $_ : q{/}} @{$project->get_path_incl()};
                push(
                    @entries,
                    FCM::Context::ConfigEntry->new({
                        label       => $LABEL_OF{'path-incl'},
                        ns_list     => [$p_ns],
                        value       => _config_unparse_join(@values),
                    }),
                );
            }
            if ($project->get_path_root()) {
                push(
                    @entries,
                    FCM::Context::ConfigEntry->new({
                        label      => $LABEL_OF{'path-root'},
                        ns_list    => [$p_ns],
                        value      => $project->get_path_root(),
                    }),
                );
            }
            my $value = $base->get_locator()->get_value();
            push(
                @entries,
                FCM::Context::ConfigEntry->new({
                    label       => $LABEL_OF{'location'},
                    modifier_of => {type => $base->get_locator()->get_type()},
                    ns_list     => [$p_ns],
                    value       => $value,
                }),
            );
        }
        @diffs = grep {!$_->get_inherited()} @diffs;
        if (@diffs) {
            my %type_set = map {($_->get_locator()->get_type() => 1)} @diffs;
            for my $type (sort(keys(%type_set))) {
                my $value = _config_unparse_join(
                    map  {$_->get_locator()->get_value()}
                    grep {$_->get_locator()->get_type() eq $type}
                    @diffs
                );
                push(
                    @entries,
                    FCM::Context::ConfigEntry->new({
                        label       => $LABEL_OF{'location'},
                        modifier_of => {diff => 1, type => $type},
                        ns_list     => [$p_ns],
                        value       => $value,
                    }),
                );
            }
        }
    }
    push(@entries, _config_unparse_prop($attrib_ref, $ctx));
    return @entries;
}

# Returns a new context.
sub _ctx {
    my ($attrib_ref, $id_of_class, $id) = @_;
    FCM::Context::Make::Extract->new({id => $id, id_of_class => $id_of_class});
}

# The main function of this class.
sub _main {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    local($UTIL) = $attrib_ref->{util};
    for my $function (
        \&_elaborate_ctx_of_project,
        \&_elaborate_ctx_of_target,
        \&_extract_incremental,
        \&_project_tree_caches_update,
        \&_symlink_handle,
        \&_targets_update,
    ) {
        $function->($attrib_ref, $m_ctx, $ctx);
    }
}

# Elaborates the context: project and tree.
sub _elaborate_ctx_of_project {
    my ($attrib_ref, $m_ctx, $ctx) = @_;

    # Reports projects that are not used
    my @bad_ns_list;
    while (my ($p_ns, $project) = each(%{$ctx->get_project_of()})) {
        if (    !$project->get_inherited()
            &&  !grep {$_ eq $p_ns} @{$ctx->get_ns_list()}
        ) {
            push(@bad_ns_list, $p_ns);
        }
    }
    if (@bad_ns_list) {
        return $E->throw($E->EXTRACT_NS, \@bad_ns_list);
    }

    # Determines a list of new trees
    my $prev_m_ctx = $m_ctx->get_prev_ctx();
    my $prev_ctx
        = defined($prev_m_ctx) ? $prev_m_ctx->get_ctx_of($ctx->get_id())
        :                          undef
        ;
    my @trees; # list of new trees
    for my $p_ns (@{$ctx->get_ns_list()}) {
        # Ensures the project settings are defined
        if (!exists($ctx->get_project_of()->{$p_ns})) {
            $ctx->get_project_of()->{$p_ns}
                = $ctx->CTX_PROJECT->new({ns => $p_ns});
        }
        my $project = $ctx->get_project_of()->{$p_ns};
        
        # Determine the root location of the project, if possible
        if (defined($project->get_locator())) {
            $UTIL->loc_as_normalised($project->get_locator());
        }
        else {
            my $uri = $UTIL->loc_kw_prefix() . ':' . $p_ns;
            my $locator = FCM::Context::Locator->new($uri);
            local($@);
            eval {$UTIL->loc_as_normalised($locator)};
            if (!$@) {
                $project->set_locator($locator);
            }
        }
        # Ensures base tree is defined
        if (!@{$project->get_trees()} || !defined($project->get_trees()->[0])) {
            if (!defined($project->get_locator())) {
                return $E->throw($E->EXTRACT_LOC_BASE, $p_ns);
            }
            my $head_locator = $UTIL->loc_trunk_at_head($project->get_locator());
            my $locator
                = $head_locator ? $head_locator
                :                 dclone($project->get_locator())
                ;
            $project->get_trees()->[0] = $ctx->CTX_TREE->new(
                {key => 0, locator => $locator, ns => $p_ns},
            );
        }
        # Determine whether there is a usable previous extract
        my %path_excl = map {($_, 1)} @{$project->get_path_excl()};
        my %path_incl = map {($_, 1)} @{$project->get_path_incl()};
        my $path_root = $project->get_path_root();
        my ($can_use_prev, $prev_project);
        if (defined($prev_ctx) && defined($prev_ctx->get_project_of($p_ns))) {
            $prev_project = $prev_ctx->get_project_of($p_ns);
            my %prev_path_excl = map {($_, 1)} @{$prev_project->get_path_excl()};
            my %prev_path_incl = map {($_, 1)} @{$prev_project->get_path_incl()};
            my $prev_path_root = $prev_project->get_path_root();
            $can_use_prev
                =  $prev_ctx->get_status() eq $m_ctx->ST_OK
                && !$UTIL->hash_cmp(\%path_excl, \%prev_path_excl, 1)
                && !$UTIL->hash_cmp(\%path_incl, \%prev_path_incl, 1)
                && $path_root eq $prev_path_root
                ;
        }
        # Tree locators as invariant
        TREE:
        for my $tree (grep {!$_->get_inherited()} @{$project->get_trees()}) {
            my $tree_locator = $tree->get_locator();
            # Ensures that the tree locator is an absolute path
            if (defined($project->get_locator())) {
                $UTIL->loc_rel2abs($tree_locator, $project->get_locator());
            }
            # Determines invariant form of the locator of the project tree.
            $UTIL->loc_as_invariant($tree_locator);
        }
        # Remove diff trees that are the same as the base tree
        my ($base_tree, @old_diff_trees) = @{$project->get_trees()};
        my $base_value = $base_tree->get_locator()->get_value();
        my @new_diff_trees;
        TREE:
        for my $tree (@old_diff_trees) {
            if ($base_value ne $tree->get_locator()->get_value()) {
                push(@new_diff_trees, $tree);
                $tree->set_key(scalar(@new_diff_trees)); # reset key (index)
            }
        }
        $project->set_trees([$base_tree, @new_diff_trees]);
        # Determine the new trees
        TREE:
        for my $tree (grep {!$_->get_inherited()} @{$project->get_trees()}) {
            my $tree_locator = $tree->get_locator();
            if (    $can_use_prev
                &&  $tree_locator->get_value_level() >= $tree_locator->L_INVARIANT
            ) {
                my $prev_tree = first {
                    $tree_locator->get_value() eq $_->get_locator()->get_value()
                } @{$prev_project->get_trees()};
                if ($prev_tree) {
                    my $prev_tree_locator = $prev_tree->get_locator();
                    $tree->set_sources($prev_tree->get_sources());
                    if ($tree->get_key() || !$prev_tree->get_key()) {
                        # Only safe to re-use cache if both are base trees
                        # or for diff tree with an unchanged base tree
                        $tree->set_cache($prev_tree->get_cache());
                    }
                    next TREE;
                }
                if (!$tree->get_key()) { # base tree changed
                    $can_use_prev = 0;
                }
            }
            push(@trees, $tree); # new tree
        }
    }

    # Obtain source info for each new tree, using the task runner
    if (@trees) {
        my $timer = $UTIL->timer();
        my $n_jobs = $m_ctx->get_option_of('jobs');
        if ($n_jobs && $n_jobs > scalar(@trees)) {
            $n_jobs = scalar(@trees);
        }
        my $elapse_tasks = 0;
        my $runner = $UTIL->task_runner(
            sub {_elaborate_ctx_of_project_tree($attrib_ref, $m_ctx, $ctx, @_)},
            $n_jobs,
        );
        my $n = eval {
            $runner->main(
                # get
                sub {
                    if (!@trees) {
                        return;
                    }
                    my $tree = shift(@trees);
                    my $id = join(':', $tree->get_ns(), $tree->get_key());
                    FCM::Context::Task->new({ctx => $tree, id => $id});
                },
                # put
                sub {
                    my ($task) = @_;
                    if ($task->get_state() eq $task->ST_FAILED) {
                        die($task->get_error());
                    }
                    my $ns = $task->get_ctx()->get_ns();
                    my $key = $task->get_ctx()->get_key();
                    my $project = $ctx->get_project_of()->{$ns};
                    my $tree = $project->get_trees()->[$key];
                    $tree->set_locator($task->get_ctx()->get_locator());
                    $tree->set_sources($task->get_ctx()->get_sources());
                    $elapse_tasks += $task->get_elapse();
                },
            );
        };
        my $e = $@;
        $runner->destroy();
        if ($e) {
            die($e);
        }
        $UTIL->event(
            FCM::Context::Event->MAKE_EXTRACT_RUNNER_SUMMARY,
            'tree-sources-info-get', $n, $timer->(), $elapse_tasks,
        );
    }
    $UTIL->event(
        FCM::Context::Event->MAKE_EXTRACT_PROJECT_TREE,
        {   map {($_ => [
                map {$_->get_locator()}
                    @{$ctx->get_project_of()->{$_}->get_trees()}
            ])}
            sort keys(%{$ctx->get_project_of()})
        },
    );
}

# Elaborates the context: new tree in a project.
sub _elaborate_ctx_of_project_tree {
    my ($attrib_ref, $m_ctx, $ctx, $tree) = @_;
    my $project = $ctx->get_project_of()->{$tree->get_ns()};
    my $path_root = $project->get_path_root();
    # TODO: support regular expression or wildcards?
    my %path_incl = map {($_ => 1)} @{$project->get_path_incl()};
    my %path_excl = map {($_ => 1)} @{$project->get_path_excl()};
    $UTIL->loc_find(
        $tree->get_locator(),
        sub {
            my ($locator, $locator_attrib_ref) = @_;
            if ($locator_attrib_ref->{is_dir}) {
                return;
            }
            my $ns_in_tree = $locator_attrib_ref->{ns};
            my $ns = $ns_in_tree;
            if ($path_root) {
                if ($path_root ne $UTIL->ns_common($path_root, $ns)) {
                    return;
                }
                $ns = $ns eq $path_root ? q{}
                    :                     substr($ns, length($path_root) + 1)
                    ;
            }
            my $ns_iter_ref = $UTIL->ns_iter($ns, $UTIL->NS_ITER_UP);
            NS:
            while (defined(my $head = $ns_iter_ref->())) {
                if (exists($path_incl{$head})) {
                    last NS;
                }
                if (exists($path_excl{$head})) {
                    return;
                }
            }
            push(
                @{$tree->get_sources()},
                $ctx->CTX_SOURCE->new({
                    key_of_tree => $tree->get_key(),
                    locator     => $locator,
                    ns          => $UTIL->ns_cat($tree->get_ns(), $ns),
                    ns_in_tree  => $ns_in_tree,
                }),
            );
        },
    );
    $tree;
}

# Elaborates the context: target.
sub _elaborate_ctx_of_target {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    # Works out the extract sources and targets
    my $DEST = $attrib_ref->{shared_util_of}{dest};
    my $ns_sep = $UTIL->ns_sep();
    while (my ($p_ns, $project) = each(%{$ctx->get_project_of()})) {
        my ($tree_base, @trees) = @{$project->get_trees()};
        # Sources from the base tree
        for my $source (@{$tree_base->get_sources()}) {
            my $ns = $source->get_ns();
            my @paths = split($ns_sep, $ns);
            my $dest_list_ref = $DEST->paths(
                $m_ctx, 'target', $ctx->get_id(), @paths
            );
            $ctx->get_target_of()->{$ns} = $ctx->CTX_TARGET->new({
                dests     => $dest_list_ref,
                ns        => $ns,
                source_of => {$tree_base->get_key() => $source},
            });
        }
        my %sources_in_base
            = map {($_->get_ns() => $_)} @{$tree_base->get_sources()};
        # Sources from the diff trees
        for my $tree (@trees) {
            my $key = $tree->get_key();
            my %sources_deleted = %sources_in_base;
            # Handles new/modified sources
            for my $source (@{$tree->get_sources()}) {
                my $ns = $source->get_ns();
                delete($sources_deleted{$ns});
                if (exists($ctx->get_target_of()->{$ns})) {
                    my $target = $ctx->get_target_of()->{$ns};
                    my $base_source = $target->get_source_of()->{0};
                    if (    $base_source->get_locator()
                        &&  _source_eq($base_source, $source)
                    ) {
                        $source->set_status($source->ST_UNCHANGED);
                    }
                    else {
                        # Source modified by diff tree
                        $target->get_source_of()->{$key} = $source;
                    }
                }
                else {
                    # Source added by diff tree
                    my @paths = split($ns_sep, $ns);
                    my $dest_list_ref = $DEST->paths(
                        $m_ctx, 'target', $ctx->get_id(), @paths,
                    );
                    $ctx->get_target_of()->{$ns} = $ctx->CTX_TARGET->new({
                        dests     => $dest_list_ref,
                        ns        => $ns,
                        source_of => {
                            0 => $ctx->CTX_SOURCE->new({
                                key_of_tree => 0,
                                status      => $ctx->CTX_SOURCE->ST_MISSING,
                            }),
                            $key => $source,
                        },
                    });
                }
            }
            # Handle deleted sources
            while (my ($ns) = each(%sources_deleted)) {
                my $target = $ctx->get_target_of()->{$ns};
                $target->get_source_of()->{$key} = $ctx->CTX_SOURCE->new({
                    key_of_tree => $key,
                    ns          => $ns,
                    status      => $ctx->CTX_SOURCE->ST_MISSING,
                });
            }
        }
    }
}

# Extract: compare with previous extract.
sub _extract_incremental {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    my $prev_m_ctx = $m_ctx->get_prev_ctx();
    my $prev_ctx
        = defined($prev_m_ctx) ? $prev_m_ctx->get_ctx_of($ctx->get_id())
        :                          undef
        ;
    if (!defined($prev_ctx)) {
        return;
    }
    my %deleted = map {($_ => 1)} keys(%{$prev_ctx->get_target_of()});
    # Compares the sources in each target
    TARGET:
    while (my ($ns, $target) = each(%{$ctx->get_target_of()})) {
        delete($deleted{$ns});
        if (!exists($prev_ctx->get_target_of()->{$ns})) {
            next TARGET;
        }
        my $prev_target = $prev_ctx->get_target_of()->{$ns};
        my %prev_source_of = %{$prev_target->get_source_of()};
        my %source_of = %{$target->get_source_of()};
        if (keys(%prev_source_of) != keys(%source_of)) {
            next TARGET;
        }
        while (my ($key_of_tree, $source) = each(%source_of)) {
            if (!exists($prev_source_of{$key_of_tree})) {
                next TARGET;
            }
            my $prev_source = $prev_source_of{$key_of_tree};
            if (   $prev_source->get_status() ne $source->get_status()
                || !$source->is_missing() && !_source_eq($prev_source, $source)
            ) {
                next TARGET;
            }
        }
        $target->set_status_of_source($prev_target->get_status_of_source());
        if ($prev_target->is_ok()) {
            $target->set_path($prev_target->get_path());
            $target->set_status($target->ST_UNCHANGED);
        }
    }
    # Creates a dummy target for each deleted target
    my $ns_sep = $UTIL->ns_sep();
    while (my $ns = each(%deleted)) {
        my $target = $prev_ctx->get_target_of($ns);
        if ($target->get_status() ne $target->ST_DELETED) {
            my @paths = split($ns_sep, $ns);
            my $dest_list_ref = $attrib_ref->{shared_util_of}{dest}->paths(
                $m_ctx, 'target', $ctx->get_id(), @paths,
            );
            $ctx->get_target_of()->{$ns}
                = $ctx->CTX_TARGET->new({dests => $dest_list_ref, ns => $ns});
        }
    }
}

# Updates the project tree caches.
sub _project_tree_caches_update {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    my $timer = $UTIL->timer();
    my $n_jobs = $m_ctx->get_option_of('jobs');
    my $n_trees = scalar(
        grep {!$_->get_cache()}
        map {@{$_->get_trees()}}
        values(%{$ctx->get_project_of()})
    );
    if ($n_trees == 0) {
        return;
    }
    if ($n_jobs && $n_jobs > $n_trees) {
        $n_jobs = $n_trees;
    }
    my $elapse_tasks = 0;
    my @args = ($attrib_ref, $m_ctx, $ctx);
    my $runner = $UTIL->task_runner(
        sub {_project_tree_cache_update_by_export(@args, @_)},
        $n_jobs,
    );
    my $n = eval {
        $runner->main(
            _project_tree_cache_update_get_func(@args),
            _project_tree_cache_update_put_func(@args, \$elapse_tasks),
        );
    };
    my $e = $@;
    $runner->destroy();
    if ($e) {
        die($e);
    }
    $UTIL->event(
        FCM::Context::Event->MAKE_EXTRACT_RUNNER_SUMMARY,
        'tree-cache-export', $n, $timer->(), $elapse_tasks,
    );
}

# Updates the source cache for a project tree by exporting it.
sub _project_tree_cache_update_by_export {
    my ($attrib_ref, $m_ctx, $ctx, $tree) = @_;
    my $cache = $tree->get_cache();
    # Exports the smallest common tree
    my $root_ns;
    SOURCE:
    for my $source (@{$tree->get_sources()}) {
        if ($source->is_unchanged()) {
            next SOURCE;
        }
        if (!defined($root_ns)) {
            $root_ns = $source->get_ns_in_tree();
            next SOURCE;
        }
        $root_ns = $UTIL->ns_common(
            $root_ns, $source->get_ns_in_tree(),
        );
        if (!$root_ns) {
            last SOURCE;
        }
    }
    if (!defined($root_ns)) {
        return;
    }
    my $cache_ns = $root_ns ? catfile($cache, $root_ns) : $cache;
    my $locator_ns = $UTIL->loc_cat(
        $tree->get_locator(), split($UTIL->ns_sep(), $root_ns),
    );
    eval{
        mkpath(dirname($cache_ns));
        $UTIL->loc_export($locator_ns, $cache_ns);
    };
    if (my $e = $@ || !-e $cache_ns && !-l $cache_ns) {
        return $E->throw($E->DEST_CREATE, $cache_ns, $e);
    }
}

# Generates an iterator for each tree requiring cache update.
sub _project_tree_cache_update_get_func {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    my @trees = map {@{$_->get_trees()}} values(%{$ctx->get_project_of()});
    sub {
        while (my $tree = shift(@trees)) {
            if (!$tree->get_cache()) {
                if ($UTIL->loc_export_ok($tree->get_locator())) {
                    my $cache = $attrib_ref->{shared_util_of}{dest}->path(
                        $m_ctx,
                        'sys-cache',
                        $ctx->get_id(),
                        $tree->get_ns(),
                        $tree->get_key(),
                    );
                    $tree->set_cache($cache);
                    rmtree($cache);
                    mkpath(dirname($cache));
                    my $id = $tree->get_ns() . '/' . $tree->get_key();
                    return FCM::Context::Task->new({ctx => $tree, id  => $id});
                }
                else {
                    $tree->set_cache($tree->get_locator()->get_value());
                    _project_tree_cache_update_sources(
                        $attrib_ref, $m_ctx, $ctx, $tree,
                    );
                }
            }
        }
        return;
    };
}

# Generates a callback when a tree has a cache.
sub _project_tree_cache_update_put_func {
    my ($attrib_ref, $m_ctx, $ctx, $elapse_tasks_ref) = @_;
    sub {
        my ($task) = @_;
        if ($task->get_state() eq $task->ST_FAILED) {
            die($task->get_error());
        }
        my $ns = $task->get_ctx()->get_ns();
        my $key = $task->get_ctx()->get_key();
        my $tree = $ctx->get_project_of()->{$ns}->get_trees()->[$key];
        _project_tree_cache_update_sources($attrib_ref, $m_ctx, $ctx, $tree);
        ${$elapse_tasks_ref} += $task->get_elapse();
    };
}

# Sets the caches of individual project tree sources.
sub _project_tree_cache_update_sources {
    my ($attrib_ref, $m_ctx, $ctx, $tree) = @_;
    for my $source (@{$tree->get_sources()}) {
        my $cache = catfile(
            $tree->get_cache(),
            split($UTIL->ns_sep(), $source->get_ns_in_tree()),
        );
        $source->set_cache($cache);
    }
}

# Handles symbolic links.
sub _symlink_handle {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    TARGET:
    while (my ($ns, $target) = each(%{$ctx->get_target_of()})) {
        if ($target->is_unchanged()) {
            next TARGET;
        }
        my $source_hash_ref = $target->get_source_of();
        # Remove sources that are symbolic links
        while (my ($key, $source) = each(%{$source_hash_ref})) {
            if ($source->get_cache() && -l $source->get_cache()) {
                delete($source_hash_ref->{$key});
                $UTIL->event(
                    FCM::Context::Event->MAKE_EXTRACT_SYMLINK, $source,
                );
            }
        }
        # It is OK to have a target with no sources, but a target must have a
        # base source if it has at least one diff source.
        if (    keys(%{$source_hash_ref})
            &&  !exists($source_hash_ref->{0})
        ) {
            $source_hash_ref->{0} = $ctx->CTX_SOURCE->new(
                {key_of_tree => 0, status => $ctx->CTX_SOURCE->ST_MISSING},
            );
        }
    }
}

# Updates the targets.
sub _targets_update {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    my %basket_of = (status => {}, status_of_source => {});
    while (my ($ns, $target) = each(%{$ctx->get_target_of()})) {
        if ($target->get_status() eq $target->ST_UNKNOWN) {
            my %source_of = %{$target->get_source_of()};
            my $handler
                = keys(%source_of) ? \&_target_update
                :                    \&_target_delete
                ;
            $handler->($attrib_ref, $m_ctx, $ctx, $target);
            my $base = delete($source_of{0});
            my @diffs = grep {!$_->is_unchanged()} values(%source_of);
            $target->set_status_of_source(
                  !keys(%{$target->get_source_of()}) ? $target->ST_UNKNOWN
                : $base->is_missing()                ? $target->ST_ADDED
                : (grep {$_->is_missing()} @diffs)   ? $target->ST_DELETED
                : scalar(@diffs) > 1                 ? $target->ST_MERGED
                : scalar(@diffs)                     ? $target->ST_MODIFIED
                :                                      $target->ST_UNCHANGED
            );
            $UTIL->event(
                FCM::Context::Event->MAKE_EXTRACT_TARGET, $target,
            );
        }
        $basket_of{status}{$target->get_status()}++;
        $basket_of{status_of_source}{$target->get_status_of_source()}++;
    }
    $UTIL->event(
        FCM::Context::Event->MAKE_EXTRACT_TARGET_SUMMARY, \%basket_of,
    );
}

# Updates a deleted target.
sub _target_delete {
    my ($attrib_ref, $m_ctx, $ctx, $target) = @_;
    my ($dest, @inherited_dests) = @{$target->get_dests()};
    if (-f $dest) {
        unlink($dest) || return $E->throw($E->DEST_CLEAN, $dest, $!);
        $target->set_status($target->ST_DELETED);
    }
    for my $inherited_dest (@inherited_dests) {
        if (-f $inherited_dest) {
            $target->set_status($target->ST_O_DELETED);
            return;
        }
    }
}

# Updates a normal target.
sub _target_update {
    my ($attrib_ref, $m_ctx, $ctx, $target) = @_;
    my %source_of = %{$target->get_source_of()};
    my $source_of_base = delete($source_of{0});
    # Either missing source in a diff-tree
    # Or     missing source in base-tree and no diff-trees
    if (    (grep {$_->is_missing()} values(%source_of))
        ||  $source_of_base->is_missing() && !keys(%source_of)
    ) {
        return _target_delete($attrib_ref, $m_ctx, $ctx, $target);
    }
    $target->set_status($target->ST_UNCHANGED);
    my $path = _target_update_source($attrib_ref, $m_ctx, $ctx, $target);
    # Note: $path may be a File::Temp object.
    my ($is_diff, $is_diff_in_perms, $is_in_prev, $rc) = (1, 1, undef, 1);
    DEST:
    for my $i (0 .. @{$target->get_dests()} - 1) {
        my $dest = $target->get_dests()->[$i];
        if (-f $dest) {
            $is_in_prev = $i;
            ($is_diff_in_perms, $is_diff) = _compare("$path", $dest);
            last DEST;
        }
    }
    if (!$is_diff && !$is_diff_in_perms) {
        $target->set_path($target->get_dests()->[$is_in_prev]);
        return; # up to date
    }
    my $dest = $target->get_dests()->[0];
    if ($is_diff) {
        my $dest_dir = dirname($dest);
        if (!-d $dest_dir) {
            eval {mkpath($dest_dir)};
            if (my $e = $@) {
                return $E->throw($E->DEST_CREATE, $dest_dir, $e);
            }
        }
        copy("$path", $dest)
            || return $E->throw($E->COPY, ["$path", $dest], $!);
    }
    chmod((stat("$path"))[2] & oct(7777), $dest)
        || return $E->throw($E->DEST_CREATE, $dest, $!);
    $target->set_path($target->get_dests()->[0]);
    $target->set_status(
          $is_in_prev          ? $target->ST_O_ADDED
        : defined($is_in_prev) ? $target->ST_MODIFIED
        :                        $target->ST_ADDED
    );
}

# Returns the source path that is to be used to update a target.
sub _target_update_source {
    my ($attrib_ref, $m_ctx, $ctx, $target) = @_;
    my %source_of = %{$target->get_source_of()};
    my $path_of_base = delete($source_of{0})->get_cache();
    my @keys_and_paths;
    while (my ($key, $source) = each(%source_of)) {
        my $path = $source->get_cache();
        if (!$path_of_base || _compare($path_of_base, $path)) {
            if (!grep {!_compare($_->[1], $path)} @keys_and_paths) {
                push(@keys_and_paths, [$key, $path]);
            }
        }
        else {
            $source->set_status($source->ST_UNCHANGED);
        }
    }
    my @args = (
        $m_ctx, $ctx, $target, $path_of_base,
        (sort {$a->[0] <=> $b->[0]} @keys_and_paths),
    );
    return (
          @keys_and_paths == 0 ? $path_of_base
        : @keys_and_paths == 1 ? $keys_and_paths[0][1]
        :                        _target_update_source_merge($attrib_ref, @args)
    );
}

# Merges changes in contents of paths in @keys_and_paths against content in
# $path_of_base.
sub _target_update_source_merge {
    my ($attrib_ref, $m_ctx, $ctx, $target, $path_of_base, @keys_and_paths) = @_;
    if (!$path_of_base) {
        $path_of_base = File::Temp->new();
        if (!defined($path_of_base) || !close($path_of_base)) {
            return $E->throw($E->DEST_CREATE, tmpdir(), $!);
        }
    }
    my ($key_of_mine, $path_of_mine) = @{shift(@keys_and_paths)};
    my @keys_done = ($key_of_mine);
    while (my $key_and_path = shift(@keys_and_paths)) {
        my ($key, $path) = @{$key_and_path};
        my @command = (
            (map {_props($attrib_ref, $_, $ctx)} qw{diff3 diff3.flags}),
            "$path_of_mine", "$path_of_base", $path,
        );
        my %value_of = %{$UTIL->shell_simple(\@command)};
        if ($value_of{rc} && $value_of{rc} == 1) {
            # Write conflict output to .fcm-make/extract/conflict/$NS
            my $file = $attrib_ref->{shared_util_of}{dest}->path(
                $m_ctx, 'sys', $ctx->get_id(), 'merge',
                $target->get_ns() . '.diff',
            );
            $UTIL->file_save($file, $value_of{o});
            return $E->throw($E->EXTRACT_MERGE, {
                'target'    => $target,
                'output'    => $file,
                'keys_done' => \@keys_done,
                'key'       => $key,
                'keys_left' => [map {$_->[0]} @keys_and_paths],
            });
        }
        elsif ($value_of{rc}) {
            return $E->throw(
                $E->SHELL, {command_list => \@command, %value_of}, $value_of{e},
            );
        }
        my $perm = (stat("$path_of_mine"))[2] & 07777 | (stat($path))[2] & 07777;
        for my $action (
            sub {$path_of_mine = File::Temp->new()},
            sub {print({$path_of_mine} $value_of{o})},
            sub {close($path_of_mine)},
            sub {chmod($perm, "$path_of_mine")},
        ) {
            $action->() || return $E->throw($E->DEST_CREATE, "$path_of_mine", $!);
        }
        push(@keys_done, $key);
    }
    return $path_of_mine;
}

# In scalar context, returns true if the contents or permissions of 2 paths
# differ. In array context, returns ($is_diff_in_perms, $is_diff_in_content).
sub _compare {
    my ($path1, $path2) = @_;
    my $is_diff_in_perms = (stat($path1))[2] != (stat($path2))[2];
    wantarray()
        ? ($is_diff_in_perms, compare($path1, $path2))
        : ($is_diff_in_perms || compare($path1, $path2))
    ;
}

# Returns true if two sources are the same or if their latest modified revisions
# are the same.
sub _source_eq {
    my ($source1, $source2) = @_;
    my ($locator1, $locator2) = map {$_->get_locator()} ($source1, $source2);
    # Compares their value + mtime or their last modified revision
            $locator1->get_value() eq $locator2->get_value()
        &&  defined($locator1->get_last_mod_time())
        &&  defined($locator2->get_last_mod_time())
        &&  $locator1->get_last_mod_time() eq $locator2->get_last_mod_time()
    ||      defined($locator1->get_last_mod_rev())
        &&  defined($locator2->get_last_mod_rev())
        &&  $locator1->get_last_mod_rev() eq $locator2->get_last_mod_rev()
    ;
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Extract

=head1 SYNOPSIS

    use FCM::System::Make::Extract;
    my $extract = FCM::System::Make::Extract->new(\%attrib);
    $extract->($m_ctx, $ctx);

=head1 DESCRIPTION

Implements the extract sub-system. An instance of this class is expected to be
initialised and called by L<FCM::System::Make|FCM::System::Make>.

=head1 METHODS

See L<FCM::System::Make|FCM::System::Make> for detail.

=head1 ATTRIBUTES

The $class->new(\%attrib) method of this class supports the following
attributes:

=over 4

=item config_parser_of

A HASH to map the labels in a configuration file to their parsers. (default =
%FCM::System::Make::Extract::CONFIG_PARSER_OF)

=item prop_of

A HASH to map the names of the properties to their settings. Each setting
is a 2-element ARRAY reference, where element [0] is the default setting
and element [1] is a flag to indicate whether the property accepts a name-space
or not. (default = %FCM::System::Make::Extract::PROP_OF)

=item shared_util_of

See L<FCM::System::Make|FCM::System::Make> for detail.

=item util

See L<FCM::System::Make|FCM::System::Make> for detail.

=back

=head1 TODO

Handle alternate method of merge (e.g. Algorithm::Merge).

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
