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
package FCM::Util::Event;
use base qw{FCM::Class::CODE};

use Data::Dumper qw{Dumper};
use FCM::Context::Event;
use File::Basename qw{basename};
use List::Util qw{first};
use POSIX qw{strftime};
use Scalar::Util qw{blessed};

my $CTX = 'FCM::Context::Event';
my $IS_MULTI_LINE = 1;

# Event keys and their actions.
my %ACTION_OF = (
    $CTX->CM_ABORT                      => \&_event_cm_abort,
    $CTX->CM_BRANCH_CREATE_SOURCE       => _func('cm_branch_create_source'),
    $CTX->CM_BRANCH_LIST                => \&_event_cm_branch_list,
    $CTX->CM_COMMIT_MESSAGE             => \&_event_cm_commit_message,
    $CTX->CM_CONFLICT_TEXT              => _func('cm_conflict_text'),
    $CTX->CM_CONFLICT_TEXT_SKIP         => \&_event_cm_conflict_text_skip,
    $CTX->CM_CONFLICT_TREE              => _func('cm_conflict_tree'),
    $CTX->CM_CONFLICT_TREE_SKIP         => \&_event_cm_conflict_tree_skip,
    $CTX->CM_CONFLICT_TREE_TIME_WARN    => \&_event_cm_conflict_tree_time_warn,
    $CTX->CM_CREATE_TARGET              => _func('cm_create_target'),
    $CTX->CM_LOG_EDIT                   => _func('cm_log_edit'),
    $CTX->CONFIG_OPEN                   => \&_event_config_open,
    $CTX->CONFIG_ENTRY                  => \&_event_config_entry,
    $CTX->CONFIG_VAR_UNDEF              => \&_event_config_var_undef,
    $CTX->E                             => \&_event_e,
    $CTX->EXPORT_ITEM_CREATE            => _func('export_item_create'),
    $CTX->EXPORT_ITEM_DELETE            => _func('export_item_delete'),
    $CTX->FCM_VERSION                   => _func('fcm_version'),
    $CTX->KEYWORD_ENTRY                 => \&_event_keyword_entry,
    $CTX->MAKE_BUILD_SHELL_OUT          => \&_event_make_build_shell_out,
    $CTX->MAKE_BUILD_SOURCE_ANALYSE     => \&_event_make_build_source_analyse,
    $CTX->MAKE_BUILD_SOURCE_SUMMARY     => _func('make_build_source_summary'),
    $CTX->MAKE_BUILD_TARGET_DONE        => \&_event_make_build_target_done,
    $CTX->MAKE_BUILD_TARGET_FAIL        => \&_event_make_build_target_fail,
    $CTX->MAKE_BUILD_TARGET_FROM_NS     => \&_event_make_build_target_from_ns,
    $CTX->MAKE_BUILD_TARGET_SELECT      => \&_event_make_build_target_select,
    $CTX->MAKE_BUILD_TARGET_SELECT_TIMER=> _func('make_build_target_select_t'),
    $CTX->MAKE_BUILD_TARGET_MISSING_DEP => \&_event_make_build_target_missing_dep,
    $CTX->MAKE_BUILD_TARGET_STACK       => \&_event_make_build_target_stack,
    $CTX->MAKE_BUILD_TARGET_SUMMARY     => _func('make_build_target_sum'),
    $CTX->MAKE_BUILD_TARGET_TASK_SUMMARY=> _func('make_build_target_task_sum'),
    $CTX->MAKE_BUILD_TARGETS_FAIL       => \&_event_make_build_targets_fail,
    $CTX->MAKE_DEST                     => \&_event_make_dest,
    $CTX->MAKE_EXTRACT_PROJECT_TREE     => \&_event_make_extract_project_tree,
    $CTX->MAKE_EXTRACT_RUNNER_SUMMARY   => \&_event_make_extract_runner_summary,
    $CTX->MAKE_EXTRACT_SYMLINK          => \&_event_make_extract_symlink,
    $CTX->MAKE_EXTRACT_TARGET           => \&_event_make_extract_target,
    $CTX->MAKE_EXTRACT_TARGET_SUMMARY   => \&_event_make_extract_target_summary,
    $CTX->MAKE_MIRROR                   => \&_event_make_mirror,
    $CTX->OUT                           => \&_event_out,
    $CTX->SHELL                         => \&_event_shell,
    $CTX->TASK_WORKERS                  => \&_event_task_workers,
    $CTX->TIMER                         => \&_event_timer,
);
# Helper for "_event_e", list of exception classes and their formatters.
our @E_FORMATTERS = (
    ['FCM1::Cm::Exception'    , \&_format_e_cm            ],
    ['FCM1::CLI::Exception'   , sub {$_[0]->get_message()}],
    ['FCM::Class::Exception' , \&_format_e_class         ],
    ['FCM::CLI::Exception'   , \&_format_e_cli           ],
    ['FCM::System::Exception', \&_format_e_sys           ],
    ['FCM::Util::Exception'  , \&_format_e_util          ],
);
# Error format strings for FCM1::Cm::Exception.
our %E_CM_FORMAT_FOR = (
    DIFF_PROJECTS     => "%s (target) and %s (source) are not related.\n",
    INVALID_BRANCH    => "%s: not a valid URL of a standard FCM branch.\n",
    INVALID_PROJECT   => "%s: not a valid URL of a standard FCM project.\n",
    INVALID_TARGET    => "%s: not a valid working copy or URL.\n",
    INVALID_URL       => "%s: not a valid URL.\n",
    INVALID_WC        => "%s: not a valid working copy.\n",
    MERGE_REV_INVALID => "%s: not a revision in the available merge list.\n",
    MERGE_SELF        => "%s: cannot be merged to its own working copy: %s.\n",
    MERGE_UNRELATED   => "%s: target and %s: source not directly related.\n",
    MERGE_UNSAFE      => "%s: source contains changes outside the target"
                         . " sub-directory. Please merge with a full tree.\n",
    MKPATH            => "%s: cannot create directory.\n",
    NOT_EXIST         => "%s: does not exist.\n",
    PARENT_NOT_EXIST  => "%s: parent %s no longer exists.\n",
    RMTREE            => "%s: cannot remove.\n",
    ST_CONFLICT       => "File(s) in conflicts:\n%s",
    ST_MISSING        => "File(s) missing:\n%s",
    ST_OUT_OF_DATE    => "File(s) out of date:\n%s",
    SWITCH_UNSAFE     => "%s: merge template exists."
                         . " Please remove before retrying.\n",
    WC_INVALID_BRANCH => "%s: not a working copy of a standard FCM branch.\n",
    WC_URL_NOT_EXIST  => "%s: working copy URL does not exists at HEAD.\n",
);
# Helper for "_format_e_sys", formatters based on exception code.
our %E_SYS_FORMATTER_FOR = (
    BUILD_SOURCE     => _format_e_func('e_sys_build_source'),
    BUILD_SOURCE_SYN => _format_e_func('e_sys_build_source_syn'),
    BUILD_TARGET     => \&_format_e_sys_build_target,
    BUILD_TARGET_BAD => _format_e_func('e_sys_build_target_bad', $IS_MULTI_LINE),
    BUILD_TARGET_CYC => \&_format_e_sys_build_target_cyc,
    BUILD_TARGET_DEP => \&_format_e_sys_build_target_dep,
    BUILD_TARGET_DUP => \&_format_e_sys_build_target_dup,
    CACHE_LOAD       => _format_e_func('e_sys_cache_load'),
    CACHE_TYPE       => _format_e_func('e_sys_cache_type'),
    CM_ALREADY_EXIST => _format_e_func('e_sys_cm_already_exist'),
    CM_ARG           => _format_e_func('e_sys_cm_arg'),
    CM_BRANCH_NAME   => _format_e_func('e_sys_cm_branch_name'),
    CM_BRANCH_SOURCE => _format_e_func('e_sys_cm_branch_source'),
    CM_CHECKOUT      => _format_e_func('e_sys_cm_checkout'),
    CM_LOG_EDIT_NULL => _format_e_func('e_sys_cm_log_edit_null'),
    CM_LOG_EDIT_DELIMITER => _format_e_func('e_sys_cm_log_edit_delimiter'),
    CM_OPT_ARG       => _format_e_func('e_sys_cm_opt_arg'),
    CM_PROJECT_NAME  => _format_e_func('e_sys_cm_project_name'),
    CM_REPOSITORY    => _format_e_func('e_sys_cm_repository'),
    CONFIG_CONFLICT  => _format_e_sys_config_func('conflict'),
    CONFIG_INHERIT   => _format_e_sys_config_func('inherit'),
    CONFIG_MODIFIER  => _format_e_sys_config_func('modifier'),
    CONFIG_NS        => _format_e_sys_config_func('ns'),
    CONFIG_NS_VALUE  => _format_e_sys_config_func('ns_value'),
    CONFIG_UNKNOWN   => _format_e_sys_config_func('unknown'),
    CONFIG_VALUE     => _format_e_sys_config_func('value'),
    CONFIG_VERSION   => _format_e_sys_config_func('version'),
    COPY             => _format_e_func('e_sys_copy'),
    DEST_CLEAN       => _format_e_func('e_sys_dest_clean'),
    DEST_CREATE      => _format_e_func('e_sys_dest_create'),
    DEST_LOCK        => _format_e_func('e_sys_dest_lock'),
    DEST_LOCKED      => _format_e_func('e_sys_dest_locked'),
    EXPORT_ITEMS_SRC => _format_e_func('e_sys_export_items_src'),
    EXTRACT_LOC_BASE => _format_e_func('e_sys_extract_loc_base'),
    EXTRACT_MERGE    => \&_format_e_sys_extract_merge,
    EXTRACT_NS       => _format_e_func('e_sys_extract_ns', $IS_MULTI_LINE),
    MIRROR           => \&_format_e_sys_mirror,
    MIRROR_NULL      => _format_e_func('e_sys_mirror_null'),
    MIRROR_SOURCE    => _format_e_func('e_sys_mirror_source', $IS_MULTI_LINE),
    MIRROR_TARGET    => _format_e_func('e_sys_mirror_target'),
    MAKE             => _format_e_func('e_sys_make'),
    MAKE_ARG         => \&_format_e_sys_make_arg,
    MAKE_CFG         => _format_e_func('e_sys_make_cfg'),
    MAKE_CFG_FILE    => _format_e_func('e_sys_make_cfg_file'),
    MAKE_PROP_NS     => \&_format_e_sys_make_prop_ns,
    MAKE_PROP_VALUE  => \&_format_e_sys_make_prop_value,
    SHELL            => \&_format_e_sys_shell,
);
# Helper for "_format_e_util", formatters based on exception code.
our %E_UTIL_FORMATTER_FOR = (
    CLASS_LOADER         => _format_e_func('e_util_class_loader'),
    CONFIG_CONT_EOF      => _format_e_util_config_func('eof'),
    CONFIG_CYCLIC        => _format_e_util_config_stack_func('cyclic'),
    CONFIG_LOAD          => _format_e_util_config_stack_func('load'),
    CONFIG_SYNTAX        => _format_e_util_config_func('syntax'),
    CONFIG_USAGE         => _format_e_util_config_func('usage'),
    CONFIG_VAR_UNDEF     => _format_e_util_config_func('var_undef'),
    IO                   => _format_e_func('e_util_io'),
    LOCATOR_AS_INVARIANT => _format_e_util_locator_func(''),
    LOCATOR_BROWSER_URL  => _format_e_util_locator_func('_browser_url'),
    LOCATOR_FIND         => _format_e_util_locator_func(''),
    LOCATOR_KEYWORD_LOC  => _format_e_util_locator_func('_keyword_loc'),
    LOCATOR_KEYWORD_REV  => _format_e_util_locator_func('_keyword_rev'),
    LOCATOR_READER       => _format_e_util_locator_func('_reader'),
    LOCATOR_TYPE         => _format_e_util_locator_func('_type'),
    SHELL_OPEN3          => _format_e_util_shell_func('_open3'),
    SHELL_OS             => _format_e_util_shell_func('_os'),
    SHELL_SIGNAL         => _format_e_util_shell_func('_signal'),
    SHELL_WHICH          => _format_e_util_shell_func('_which'),
);
# Alias
our $R;
# Named diagnostic strings
our %S = (
    # ERROR DIAGNOSTICS
    e_class                      => '%s: %s => %s: internal error at %s:%d',
    e_cli_app                    => '%s: unknown command,'
                                    . ' type \'%s help\' for help',
    e_cli_opt                    => '%s: incorrect usage,'
                                    . ' type \'%s help %1$s\' for help',
    e_sys_build_source           => '%s: source does not exist',
    e_sys_build_source_syn       => '%s(%d): syntax error',
    e_sys_build_target           => '%s: target not found after an update:',
    e_sys_build_target_1         => '%s: expect target file',
    e_sys_build_target_bad       => '%s: don\'t know how to build specified'
                                    . ' target',
    e_sys_build_target_cyclic    => '%s: target depends on itself',
    e_sys_build_target_dep       => '%s: bad or missing dependency (type=%s)',
    e_sys_build_target_dup       => '%s: same target from [%s]',
    e_sys_build_target_stack     => '    required by: %s',
    e_sys_cache_load             => '%s: cannot retrieve cache',
    e_sys_cache_type             => '%s: unexpected cache type',
    e_sys_cm_already_exist       => '%s: already exists',
    e_sys_cm_arg                 => '%s: bad argument',
    e_sys_cm_branch_name         => '%s: invalid branch name',
    e_sys_cm_branch_source       => '%s: invalid branch source',
    e_sys_cm_checkout            => '%s: is already a working copy of %s',
    e_sys_cm_log_edit_delimiter  => '%sthe above log delimiter is altered',
    e_sys_cm_log_edit_null       => 'log message is empty',
    e_sys_cm_opt_arg             => '%s=%s: bad option argument',
    e_sys_cm_project_name        => '%s: invalid project name',
    e_sys_cm_repository          => '%s: invalid repository',
    e_sys_config_conflict        => '%s: cannot modify, value is inherited',
    e_sys_config_inherit         => '%s: cannot inherit from an incomplete make',
    e_sys_config_modifier        => '%s: incorrect modifier in declaration',
    e_sys_config_ns              => '%s: incorrect name-space declaration',
    e_sys_config_ns_value        => '%s: mismatch between name-space and value',
    e_sys_config_unknown         => '%s: unknown declaration',
    e_sys_config_value           => '%s: incorrect value in declaration',
    e_sys_config_version         => '%s: requested version mismatch',
    e_sys_copy                   => '%s -> %s: copy failed',
    e_sys_dest_clean             => '%s: cannot remove',
    e_sys_dest_create            => '%s: cannot create',
    e_sys_dest_locked            => '%s: lock exists at the destination',
    e_sys_export_items_src       => 'source location not specified',
    e_sys_extract_loc_base       => '%s: cannot determine base location',
    e_sys_extract_merge          => '%s: merge results in conflict',
    e_sys_extract_merge_output   => '    merge output: %s',
    e_sys_extract_merge_source   => '    source from location %2d: %s',
    e_sys_extract_merge_source_0 => '(none)',
    e_sys_extract_merge_source_x => '!!! source from location %2d: %s',
    e_sys_extract_ns             => '%s: name-spaces declared but not used',
    e_sys_mirror                 => '%s <- %s: mirror failed',
    e_sys_mirror_null            => 'mirror target not specified',
    e_sys_mirror_source          => '%s: cannot mirror this step',
    e_sys_mirror_target          => '%s: cannot create mirror target',
    e_sys_make                   => '%s: step is not implemented',
    e_sys_make_arg               => 'arg %d (%s): invalid config declaration',
    e_sys_make_arg_more          => 'did you mean "%s"?',
    e_sys_make_cfg               => 'no configuration specified or found',
    e_sys_make_cfg_file          => '%s: no such configuration file',
    e_sys_make_prop_ns           => '%s.prop{%s}[%s] = %s: bad name-space',
    e_sys_make_prop_value        => '%s.prop{%s}[%s] = %s: bad value',
    e_sys_shell                  => '%s # rc=%d',
    e_unknown                    => 'command failed',
    e_util_class_loader          => '%s: required package cannot be loaded',
    e_util_config                => '%s:%d: %s',
    e_util_config_eof            => 'continuation at eof',
    e_util_config_syntax         => 'syntax error',
    e_util_config_usage          => 'incorrect usage',
    e_util_config_var_undef      => 'reference to undefined variable',
    e_util_config_stack_cyclic   => '%s: cannot load config file,'
                                    . ' cyclic dependency',
    e_util_config_stack_load     => '%s: cannot load config file',
    e_util_io                    => '%s: I/O error',
    e_util_locator               => '%s: not found',
    e_util_locator_browser_url   => '%s: cannot determine browser URL',
    e_util_locator_keyword_loc   => '%s: location keyword not defined',
    e_util_locator_keyword_rev   => '%s: revision keyword not defined',
    e_util_locator_reader        => '%s: cannot be read',
    e_util_locator_type          => '%s: unsupported type of location',
    e_util_shell_open3           => '%s: command failed to invoke',
    e_util_shell_os              => '%s: command failed due to OS error',
    e_util_shell_signal          => '%s: command received a signal',
    e_util_shell_which           => '%s: command not found',

    # NORMAL DIAGNOSTICS
    cm_abort_null                => 'command will result in no change',
    cm_abort_user                => 'by user',
    cm_branch_create_source      => 'Source: %s (%d)',
    cm_branch_list               => '%s: %d match(es)',
    cm_commit_message            => 'Change summary:' . "\n"
                                    . '-' x 80 . "\n" . '%s'
                                    . '-' x 80 . "\n"
                                    . 'Commit message is as follows:' . "\n"
                                    . '-' x 80 . "\n" . '%s%s'
                                    . '-' x 80,
    cm_conflict_text             => '%s: in text conflict.',
    cm_conflict_text_skip        => '%s: skipped binary file in text conflict.',
    cm_conflict_tree             => '%s: in tree conflict.',
    cm_conflict_tree_skip        => '%s: skipped unhandled tree conflict.',
    cm_conflict_tree_time_warn   => '%s: looking for a rename operation,'
                                    . ' please wait...',
    cm_create_target             => 'Created: %s',
    cm_log_edit                  => '%s: starting commit message editor...',
    config_open                  => 'config-file=%s%s',
    config_var_undef             => '%s:%d: %s: variable not defined',
    event                        => '%s: event raised',
    export_item_create           => 'A %s@%s -> %s',
    export_item_delete           => 'D %s@%s -> %s',
    fcm_version                  => '%s',
    keyword_loc                  => 'location[%s] = %s',
    keyword_loc_primary          => 'location{primary}[%s] = %s',
    keyword_rev                  => 'revision[%s:%s] = %s',
    make_build_shell_out_1       => '[>>&1] ',
    make_build_shell_out_2       => '[>>&2] ',
    make_build_source_analyse    => 'analyse %4.1f %s',
    make_build_source_analyse_1  => '             -> (%9s) %s',
    make_build_source_summary    => 'sources: total=%d, analysed=%d,'
                                    . ' elapsed-time=%.1fs, total-time=%.1fs',
    make_build_target_done_0     => '%-9s ---- %s %-20s <- %s',
    make_build_target_done_1     => '%-9s %4.1f %s %-20s <- %s',
    make_build_target_from_ns    => 'source->target %s -> (%s) %s/ %s',
    make_build_target_select     => 'required-target: %-9s %-7s %s',
    make_build_target_select_t   => 'target-tree-analysis: elapsed-time=%.1fs',
    make_build_target_stack      => 'target %s%s%s',
    make_build_target_stack_more => ' (n-deps=%d)',
    make_build_target_missing_dep=> '%-30s: ignore-missing-dep: (%3$9s) %2$s',
    make_build_target_sum        => 'TOTAL     targets:'
                                    . ' modified=%d, unchanged=%d, failed=%d,'
                                    . ' elapsed-time=%.1fs',
    make_build_target_task_sum   => '%-9s targets:'
                                    . ' modified=%d, unchanged=%d, failed=%d,'
                                    . ' total-time=%.1fs',
    make_build_targets_fail_0    => '! %-20s: depends on failed target: %s',
    make_build_targets_fail_1    => '! %-20s: update task failed',
    make_dest                    => 'dest=%s',
    make_dest_use                => 'use=%s',
    make_extract_project_tree    => 'location %5s:%2d: %s%s',
    make_extract_project_tree_1  => ' (%s)',
    make_extract_runner_summary  => '%s: n-tasks=%d,'
                                    . ' elapsed-time=%.1fs, total-time=%.1fs',
    make_extract_target          => '%s%s %5s:%-6s %s',
    make_extract_target_base_yes => '0',
    make_extract_target_base_no  => '-',
    make_extract_symlink         => 'symlink ignored: %s',
    make_extract_target_summary_d=> '  dest: %4d [%1s %s]',
    make_extract_target_summary_s=> 'source: %4d [%1s %s]',
    make_mirror                  => '%s <- %s',
    make_mode                    => 'mode=%s',
    make_mode_new                => 'new',
    make_mode_incr               => 'incremental',
    shell                        => 'shell(%d %4.1f) %s',
    task_workers_destroy         => '%s worker processes destroyed',
    task_workers_init            => '%s worker processes started',
    timer_done                   => '%-20s# %.1fs',
    timer_init                   => '%-20s# %s',
);
# Symbols/Descriptions for a make extract target status.
my %MAKE_EXTRACT_TARGET_SYM_OF = (
    ST_ADDED     => ['A', 'added'                        ],
    ST_DELETED   => ['D', 'deleted'                      ],
    ST_MODIFIED  => ['M', 'modified'                     ],
    ST_O_ADDED   => ['a', 'added, overriding inherited'  ],
    ST_O_DELETED => ['d', 'deleted, overriding inherited'],
    ST_UNCHANGED => ['U', 'unchanged'                    ],
    ST_UNKNOWN   => ['?', 'unknown'                      ],
);
# Symbols/Descriptions for a make source status.
my %MAKE_EXTRACT_SOURCE_SYM_OF = (
    ST_ADDED     => ['A', 'added by a diff source tree'     ],
    ST_DELETED   => ['D', 'deleted by a diff source tree'   ],
    ST_MERGED    => ['G', 'merged from 2+ diff source trees'],
    ST_MODIFIED  => ['M', 'modified by a diff source tree'  ],
    ST_UNCHANGED => ['U', 'from base'                       ],
    ST_UNKNOWN   => ['?', 'unknown'                         ],
);

# Creates the class.
__PACKAGE__->class({util => '&'}, {action_of => {main => \&_main}});

sub _main {
    my ($attrib_ref, $event) = @_;
    local($R) = $attrib_ref->{util}->util_of_report();
    if (!exists($ACTION_OF{$event->get_code()})) {
        return $R->report(
            {level => $R->HIGH}, sprintf($S{event}, $event->get_code()),
        );
    }
    $ACTION_OF{$event->get_code()}->(@{$event->get_args()});
}

# Formats a stack of configuration files.
sub _format_config_stack {
    my ($config_stack_ref) = @_;
    my @config_stack = @{$config_stack_ref};
    my $indent_char = q{};
    my $return = q{};
    my $i = 0;
    for my $item (@config_stack) {
        my ($locator, $line) = @{$item};
        my $indent = q{ - } x $i++;
        $return .= sprintf(
            $S{'config_open'} . "\n",
            $indent, ($locator->get_value() . ($line ? ':' . $line : q{})),
        );
    }
    return $return;
}

# Formats a CM exception.
sub _format_e_cm {
    my ($e) = @_;
    sprintf($E_CM_FORMAT_FOR{$e->get_code()}, $e->get_targets());
}

# Formats a class exception.
sub _format_e_class {
    my ($e) = @_;
    sprintf(
        $S{e_class},
        $e->get_package(),
        $e->get_key(),
        (defined($e->get_value()) ? $e->get_value() : 'undef'),
        @{$e->get_caller()}[1, 2],
    );
}

# Formats a CLI exception.
sub _format_e_cli {
    my ($e) = @_;
    my $format
        = $e->get_code() eq $e->APP ? $S{e_cli_app}
        :                             $S{e_cli_opt}
        ;
    sprintf($format, $e->get_ctx()->[0], basename($0));
}

# Formats a system exception.
sub _format_e_sys {
    my ($e) = @_;
    if (exists($E_SYS_FORMATTER_FOR{$e->get_code()})) {
        return $E_SYS_FORMATTER_FOR{$e->get_code()}->($e);
    }
    $e;
}

# Formats a system exception - CONFIG_*.
sub _format_e_sys_config_func {
    my ($suffix) = @_;
    my $key = 'e_sys_config_' . $suffix;
    sub {
        my ($e) = @_;
        my @ctx_list
            = ref($e->get_ctx()) eq 'ARRAY' ? @{$e->get_ctx()}
            :                                 ($e->get_ctx())
            ;
        map {(
            sprintf($S{$key}, $_->as_string()),
            _format_config_stack($_->get_stack()),
        )} @ctx_list;
    }
}

# Formats a system exception - BUILD_TARGET.
sub _format_e_sys_build_target {
    my ($e) = @_;
    my $ctx = $e->get_ctx();
    (   sprintf($S{e_sys_build_target}, $ctx->get_key()),
        sprintf($S{e_sys_build_target_1}, $ctx->get_path()),
    );
}

# Formats a system exception - BUILD_TARGET_CYC.
sub _format_e_sys_build_target_cyc {
    my ($e) = @_;
    my @messages;
    while (my ($key, $hash_ref) = each(%{$e->get_ctx()})) {
        my ($head, @stack) = reverse(@{$hash_ref->{'keys'}});
        push(@messages, sprintf($S{e_sys_build_target_cyclic}, $head));
        push(@messages, map {sprintf($S{e_sys_build_target_stack}, $_)} @stack);
    }
    @messages;
}

# Formats a system exception - BUILD_TARGET_DEP.
sub _format_e_sys_build_target_dep {
    my ($e) = @_;
    my @messages;
    while (my ($key, $hash_ref) = each(%{$e->get_ctx()})) {
        my ($head, @stack) = reverse(@{$hash_ref->{'keys'}});
        for (@{$hash_ref->{'values'}}) { # [$dep_key, $dep_type]
            my ($dep_name, $dep_type, $dep_remark) = @{$_};
            if ($dep_remark) {
                $dep_type = $dep_remark . '.' . $dep_type;
            }
            push(
                @messages,
                sprintf($S{e_sys_build_target_dep}, $dep_name, $dep_type),
            );
        }
        push(@messages, map {sprintf($S{e_sys_build_target_stack}, $_)} @stack);
    }
    @messages;
}

# Formats a system exception - BUILD_TARGET_DUP.
sub _format_e_sys_build_target_dup {
    my ($e) = @_;
    my @messages;
    while (my ($key, $hash_ref) = each(%{$e->get_ctx()})) {
        my ($head, @stack) = reverse(@{$hash_ref->{'keys'}});
        my @ns_list = @{$hash_ref->{'values'}};
        my $ns = _format_shell_words({'delimiter' => q{, }}, sort(@ns_list));
        push(@messages, sprintf($S{e_sys_build_target_dup}, $key, $ns));
        push(@messages, map {sprintf($S{e_sys_build_target_stack}, $_)} @stack);
    }
    @messages;
}

# Formats a system exception - EXTRACT_MERGE.
sub _format_e_sys_extract_merge {
    my ($e) = @_;
    my $target = $e->get_ctx()->{'target'};
    my $source0 = $target->get_source_of()->{0};
    my $location_of_0 = $S{e_sys_extract_merge_source_0};
    if ($source0->get_locator()) {
        $location_of_0 = $source0->get_locator()->get_value();
    }
    my $key = $e->get_ctx()->{'key'};
    my $location_of_key
        = $target->get_source_of()->{$key}->get_locator()->get_value();
    (   sprintf($S{e_sys_extract_merge}, $target->get_ns()),
        sprintf($S{e_sys_extract_merge_output}, $e->get_ctx()->{'output'}),
        sprintf($S{e_sys_extract_merge_source}, 0, $location_of_0),
        (   map {sprintf(
                $S{e_sys_extract_merge_source},
                $_,
                $target->get_source_of()->{$_}->get_locator()->get_value(),
            )} @{$e->get_ctx()->{'keys_done'}}
        ),
        sprintf($S{e_sys_extract_merge_source_x}, $key, $location_of_key),
        (   map {sprintf(
                $S{e_sys_extract_merge_source},
                $_,
                $target->get_source_of()->{$_}->get_locator()->get_value(),
            )} @{$e->get_ctx()->{'keys_left'}}
        ),
    );
}

# Formats a system exception - MIRROR.
sub _format_e_sys_mirror {
    my ($e) = @_;
    my ($target, @sources) = @{$e->get_ctx()};
    sprintf($S{e_sys_mirror}, $target, _format_shell_words(@sources));
}

# Formats a system exception - MAKE_ARG
sub _format_e_sys_make_arg {
    my ($e) = @_;
    my @return;
    for (@{$e->get_ctx()}) {
        my ($arg_index, $arg_value) = @{$_};
        push(@return, sprintf($S{e_sys_make_arg}, $arg_index, $arg_value));
        my $advice
            = $arg_value =~ qr{\.cfg\z}msx ? '-f ' . $arg_value
            : $arg_value eq '0'            ? '-q'
            : $arg_value eq '2'            ? '-v'
            : $arg_value eq '3'            ? '-v -v'
            :                                undef;
        if (defined($advice)) {
            push(@return, sprintf($S{e_sys_make_arg_more}, $advice));
        }
    }
    return @return;
}

# Formats a system exception - MAKE_PROP_NS
sub _format_e_sys_make_prop_ns {
    my ($e) = @_;
    map {sprintf($S{e_sys_make_prop_ns}, @{$_})} @{$e->get_ctx()};
}

# Formats a system exception - MAKE_PROP_VALUE
sub _format_e_sys_make_prop_value {
    my ($e) = @_;
    map {sprintf($S{e_sys_make_prop_value}, @{$_})} @{$e->get_ctx()};
}

# Formats a system exception - SHELL.
sub _format_e_sys_shell {
    my ($e) = @_;
    my $command = _format_shell_words(@{$e->get_ctx()->{command_list}});
    my %value_of = (out => q{}, rc => '?', %{$e->get_ctx()});
    return (
        #(map {sprintf($S{e_sys_shell_err}, $_)} split("\n", $value_of{err})),
        #(map {sprintf($S{e_sys_shell_out}, $_)} split("\n", $value_of{out})),
        sprintf($S{e_sys_shell}, $command, $value_of{rc}),
    );
}

# Formats a util exception.
sub _format_e_util {
    my ($e) = @_;
    if (exists($E_UTIL_FORMATTER_FOR{$e->get_code()})) {
        return $E_UTIL_FORMATTER_FOR{$e->get_code()}->($e);
    }
    $e;
}

# Returns a CODE to format a util config-reader exception.
sub _format_e_util_config_func {
    my ($id) = @_;
    sub {
        my ($e) = @_;
        (   sprintf(
                $S{'e_util_config'},
                $e->get_ctx()->get_stack()->[-1][0]->get_value(),
                $e->get_ctx()->get_stack()->[-1][1],
                $S{'e_util_config_' . $id},
            ),
            $e->get_ctx()->as_string(),
        );
    };
}

# Returns a CODE to format a util config-reader exception where the ctx is the
# locator stack.
sub _format_e_util_config_stack_func {
    my ($id) = @_;
    sub {
        my ($e) = @_;
        my @return = (
            _format_config_stack($e->get_ctx()),
            sprintf(
                $S{'e_util_config_stack_' . $id},
                $e->get_ctx()->[-1][0]->get_value(),
            ),
        );
        @return;
    };
}

# Formats a locator exception.
sub _format_e_util_locator_func {
    my ($id) = @_;
    sub {sprintf($S{'e_util_locator' . $id}, $_[0]->get_ctx()->get_value())};
}

# Formats a shell exception.
sub _format_e_util_shell_func {
    my ($id) = @_;
    sub {
        sprintf(
            $S{'e_util_shell' . $id},
            _format_shell_words(@{$_[0]->get_ctx()})
        );
    };
}

# Returns a CODE to format a exception context in a single/multi line.
sub _format_e_func {
    my ($id, $is_multi_line) = @_;
    sub {
        my ($e) = @_;
        my @args;
        if (defined($e->get_ctx())) {
            @args = (ref($e->get_ctx()) || ref($e->get_ctx()) eq 'ARRAY')
                ? @{$e->get_ctx()} : $e->get_ctx();
        }
        $is_multi_line
            ? (map {sprintf($S{$id}, $_)} @args) : (sprintf($S{$id}, @args));
    };
}

# Formats a simple reference.
sub _format_ref {
    my ($hash_ref) = @_;
    local($Data::Dumper::Terse) = 1;
    local($Data::Dumper::Indent) = 0;
    Dumper($hash_ref);
}

# Formats words into a string suitable for used in a shell command.
sub _format_shell_words {
    my %option = ('delimiter' => q{ });
    if (@_ && ref($_[0]) && ref($_[0]) eq 'HASH') {
        %option = (%option, %{$_[0]});
        shift();
    }
    my (@words) = @_;
    join(
        $option{'delimiter'},
        map {my $s = $_; $s =~ s{(['"\s])}{\\$1}gmsx; $s} @words,
    );
}

# Notification on abort of a CM command.
sub _event_cm_abort {
    my ($id) = @_;
    $R->report(
        {level => $R->QUIET, prefix => $R->PREFIX_QUIT, type => $R->TYPE_ERR},
        $S{'cm_abort_' . $id},
    );
}

# Notification on a project branch listing.
sub _event_cm_branch_list {
    my ($project, @branches) = @_;
    $R->report(sprintf($S{'cm_branch_list'}, $project, scalar(@branches)));
    for my $branch (@branches) {
        $R->report({level => $R->QUIET, prefix => $R->PREFIX_NULL}, $branch);
    }
}

# Notification on a log message to be used by a commit.
sub _event_cm_commit_message {
    my ($ctx) = @_;
    $R->report(
        {prefix => $R->PREFIX_NULL},
        sprintf(
            $S{'cm_commit_message'},
            $ctx->get_info_part(), $ctx->get_user_part(), $ctx->get_auto_part(),
        ),
    );
}

# Notification on a skipped file in text conflict.
sub _event_cm_conflict_text_skip {
    my ($ctx) = @_;
    $R->report({type => $R->TYPE_ERR}, sprintf($S{'cm_conflict_text_skip'}, $ctx));
}

# Notification for an unhandled type of tree conflict.
sub _event_cm_conflict_tree_skip {
    my ($ctx) = @_;
    $R->report({type => $R->TYPE_ERR}, sprintf($S{'cm_conflict_tree_skip'}, $ctx));
}

# Warning that the tree conflict operation search may take some time.
sub _event_cm_conflict_tree_time_warn {
    my ($ctx) = @_;
    $R->report({type => $R->TYPE_ERR}, sprintf($S{'cm_conflict_tree_time_warn'}, $ctx));
}

# Notification when a config entry is found.
sub _event_config_entry {
    my ($entry, $in_fcm1) = @_;
    $R->report(
        {level => $R->QUIET, prefix => $R->PREFIX_NULL},
        $entry->as_string($in_fcm1),
    );
}

# Notification for a configuration file open.
sub _event_config_open {
    my ($config_stack_ref, $level) = @_;
    $R->report(
        {level => (defined($level) ? $level : $R->DEBUG)},
        sub {
            my $value = $config_stack_ref->[-1][0]->get_value();
            my $indent = q{ - } x (scalar(@{$config_stack_ref}) - 1);
            sprintf($S{config_open}, $indent, $value);
        },
    );
}

# Notification when a config variable is undefined.
sub _event_config_var_undef {
    my ($entry, $symbol) = @_;
    $R->report(
        {type => $R->TYPE_ERR},
        sprintf(
            $S{'config_var_undef'},
            $entry->get_stack()->[-1][0]->get_value(),
            $entry->get_stack()->[-1][1],
            $symbol,
        ),
    );
}

# Notification for an exception.
sub _event_e {
    my ($exception) = @_;
    my @e_stack = ($exception);
    while ( blessed($e_stack[-1])
        &&  $e_stack[-1]->can('get_exception')
        &&  (my $e = $e_stack[-1]->get_exception())
    ) {
        push(@e_stack, $e);
    }
    while (my $e = shift(@e_stack)) {
        my $formatter;
        if (blessed($e)) {
            my $item = first {$e->isa($_->[0])} @E_FORMATTERS;
            if ($item) {
                $formatter = $item->[1];
            }
            if (!$formatter && $e->can('as_string')) {
                $formatter = sub {$e->as_string()};
            }
        }
        elsif (ref($e)) {
            $formatter = \&_format_ref;
        }
        elsif ($e eq "\n") {
            chomp($e);
        }
        $R->report(
            {level => $R->FAIL, type => $R->TYPE_ERR},
            (defined($formatter) ? $formatter->($e) : $e),
        );
    }
    1;
}

# Notification when a keyword entry is found.
sub _event_keyword_entry {
    my ($entry) = @_;
    if ($entry->is_implied()) {
        return;
    }
    my @implied_entry_list
        = values(%{$entry->get_ctx_of_implied()->get_entry_by_key()});
    if (@implied_entry_list) {
        $R->report(
            {level => $R->QUIET, prefix => $R->PREFIX_NULL},
            sprintf(
                $S{keyword_loc_primary},
                $entry->get_key(),
                $entry->get_value(),
            ),
        );
        for my $implied_entry (
            sort {$a->get_key() cmp $b->get_key()} @implied_entry_list
        ) {
            $R->report(
                {level => $R->MEDIUM, prefix => $R->PREFIX_NULL},
                sprintf(
                    $S{keyword_loc},
                    $implied_entry->get_key(),
                    $implied_entry->get_value(),
                ),
            );
        }
    }
    else {
        $R->report(
            {level => $R->QUIET, prefix => $R->PREFIX_NULL},
            sprintf($S{keyword_loc}, $entry->get_key(), $entry->get_value()),
        );
    }
    my @revision_entry_list
        = values(%{$entry->get_ctx_of_rev()->get_entry_by_key()});
    for my $revision_entry (
        sort {$a->get_key() cmp $b->get_key()} @revision_entry_list
    ) {
        $R->report(
            {level => $R->QUIET, prefix => $R->PREFIX_NULL},
            sprintf(
                $S{keyword_rev},
                $entry->get_key(),
                $revision_entry->get_key(),
                $revision_entry->get_value(),
            ),
        );
    }
    1;
}

# Notification of the output from a command.
sub _event_out {
    my ($out, $err) = @_;
    my %option = (delimiter => q{}, prefix => $R->PREFIX_NULL);
    if ($err) {
        $R->report({level => $R->WARN, type => $R->TYPE_ERR, %option}, $err);
    }
    if ($out) {
        $R->report({level => $R->QUIET, %option}, $out);
    }
}

# Notification of the output from a command invoked by make/build.
sub _event_make_build_shell_out {
    my ($out, $err) = @_;
    if ($err) {
        $R->report(
            {   level => $R->HIGH,
                prefix => $S{'make_build_shell_out_2'},
                type => $R->TYPE_ERR,
            },
            $err,
        );
    }
    if ($out) {
        $R->report(
            {level => $R->HIGH, prefix => $S{'make_build_shell_out_1'}},
            $out,
        );
    }
}

# Notification when a make destination is being set up.
sub _event_make_dest {
    my ($m_ctx, $authority) = @_;
    $R->report(sprintf($S{make_dest}, $authority . ':' . $m_ctx->get_dest()));
    $R->report(sprintf(
        $S{make_mode},
        $S{'make_mode_' . ($m_ctx->get_prev_ctx() ? 'incr' : 'new')},
    ));
    for my $i_ctx (@{$m_ctx->get_inherit_ctx_list()}) {
        $R->report(sprintf($S{make_dest_use}, $i_ctx->get_dest()));
    }
}

# Notification when performing a mirroring.
sub _event_make_mirror {
    my ($target, @sources) = @_;
    $R->report(sprintf($S{make_mirror}, $target, _format_shell_words(@sources)));
}

# Notification when the multi-thread task runner initiates its workers.
sub _event_task_workers {
    my ($id, $n_workers) = @_;
    my $key = 'task_workers_' . $id;
    if (exists($S{$key})) {
        $R->report({level => $R->HIGH}, sprintf($S{$key}, $n_workers));
    }
}

# Notification when invoking a shell command.
sub _event_shell {
    my ($names_ref, $rc, $elapsed) = @_;
    my $name = _format_shell_words(@{$names_ref});
    my $message = sprintf($S{shell}, $rc, $elapsed, $name);
    $R->report({level => $R->HIGH}, $message);
}

# Notification when a timer starts/ends.
sub _event_timer {
    my ($name, $start, $elapsed, $failed) = @_;
    my $message;
    if (defined($elapsed)) {
        $message = sprintf($S{timer_done}, $name, $elapsed);
    }
    else {
        my $format = '%Y-%m-%dT%H:%M:%SZ';
        $message = sprintf(
            $S{timer_init}, $name, strftime($format, gmtime($start)));
    }
    my $prefix
        = $failed           ? $R->PREFIX_FAIL
        : defined($elapsed) ? $R->PREFIX_DONE
        :                     $R->PREFIX_INIT
        ;
    $R->report({prefix => $prefix}, $message);
}

# Notification when make-build analyse a source.
sub _event_make_build_source_analyse {
    my ($source, $elapse) = @_;
    $R->report(
        {level => $R->MEDIUM},
        sprintf($S{make_build_source_analyse}, $elapse, $source->get_ns()),
    );
    for my $dep (@{$source->get_deps()}) {
        $R->report(
            {level => $R->HIGH},
            sprintf($S{make_build_source_analyse_1}, reverse(@{$dep})),
        );
    }
}

# Notification when make-build has updated or does not need to update a target.
sub _event_make_build_target_done {
    my ($target, $elapsed_time) = @_;
    my $tmpl = defined($elapsed_time)
        ? $S{make_build_target_done_1} : $S{make_build_target_done_0};
    $R->report(
        {level => $R->MEDIUM},
        sprintf(
            $tmpl,
            $target->get_task(),
            (defined($elapsed_time) ? ($elapsed_time) : ()),
            $MAKE_EXTRACT_TARGET_SYM_OF{$target->get_status()}[0],
            $target->get_key(),
            $target->get_ns(),
        ),
    );
}

# Notification when make-build a target fails to update or is failed by
# dependencies.
sub _event_make_build_target_fail {
    my ($target, $elapsed_time) = @_;
    my $tmpl = defined($elapsed_time)
        ? $S{make_build_target_done_1} : $S{make_build_target_done_0};
    $R->report(
        {level => $R->FAIL, type => $R->TYPE_ERR},
        sprintf(
            $tmpl,
            $target->get_task(),
            (defined($elapsed_time) ? ($elapsed_time) : ()),
            '!',
            $target->get_key(),
            $target->get_ns(),
        ),
    );
}

# Notification when make-build ignores a missing dependency from a target.
sub _event_make_build_target_missing_dep {
    $R->report(
        {level => $R->WARN, type => $R->TYPE_ERR},
        sprintf($S{make_build_target_missing_dep}, @_),
    );
}

# Notification when make-build generates a target from source.
sub _event_make_build_target_from_ns {
    $R->report(
        {level => $R->HIGH},
        sprintf($S{make_build_target_from_ns}, @_),
    );
}

# Notification when make-build chooses a list of targets to build.
sub _event_make_build_target_select {
    my ($target_set_ref) = @_;
    $R->report(
        {level => $R->HIGH},
        sub {
            map {
                my $key = $_;
                my $target = $target_set_ref->{$key};
                sprintf(
                    $S{make_build_target_select},
                    $target->get_task(), $target->get_category(), $key,
                );
            }
            sort keys(%{$target_set_ref});
        },
    );
}

# Notification when make-build checks a target for cyclic dependency.
sub _event_make_build_target_stack {
    my ($key, $rank, $n_deps) = @_;
    $R->report(
        {level => $R->HIGH},
        sub {
            my $indent = q{ - } x $rank;
            my $more
                = $n_deps ? sprintf($S{make_build_target_stack_more}, $n_deps)
                :           q{}
                ;
            sprintf($S{make_build_target_stack}, $indent, $key, $more),
        },
    );
}

# Notification when make-build fails to update some targets.
sub _event_make_build_targets_fail {
    my ($targets_ref) = @_;
    $R->report(
        {type => $R->TYPE_ERR, level => $R->FAIL},
        (map {
            my $target = $_;
            my @failed_by = @{$target->get_failed_by()};
            my @lines;
            if (grep {$_ eq $target->get_key()} @failed_by) {
                push(
                    @lines,
                    sprintf($S{make_build_targets_fail_1}, $target->get_key()),
                );
            }
            for my $failed_by_key (grep {$_ ne $target->get_key()} @failed_by) {
                push(
                    @lines,
                    sprintf(
                        $S{make_build_targets_fail_0},
                        $target->get_key(),
                        $failed_by_key,
                    ),
                );
            }
            @lines;
        } sort {$a->get_key() cmp $b->get_key()} @{$targets_ref}),
    );
}

# Notification when make-extract finished gathering information for its project
# source trees.
sub _event_make_extract_project_tree {
    my %locators_of = %{$_[0]};
    for my $ns (sort(keys(%locators_of))) {
        my $i = 0;
        for my $locator (@{$locators_of{$ns}}) {
            my $format_last_mod_rev = q{};
            if ($locator->get_last_mod_rev()) {
                $format_last_mod_rev = sprintf(
                    $S{'make_extract_project_tree_1'},
                    $locator->get_last_mod_rev(),
                );
            }
            $R->report(
                sprintf(
                    $S{'make_extract_project_tree'},
                    $ns, $i++, $locator->get_value(), $format_last_mod_rev
                ),
            );
        }
    }
}

# Notification when make-extract used the task runner to perform tasks.
sub _event_make_extract_runner_summary {
    $R->report(
        {level => $R->HIGH},
        sprintf($S{'make_extract_runner_summary'}, @_),
    );
}

# Notification when make-extract completes updating its targets.
sub _event_make_extract_target_summary {
    my ($basket) = @_;
    for (
        [   'status',
            'make_extract_target_summary_d',
            \%MAKE_EXTRACT_TARGET_SYM_OF,
        ],
        [   'status_of_source',
            'make_extract_target_summary_s',
            \%MAKE_EXTRACT_SOURCE_SYM_OF,
        ],
    ) {
        my ($name, $format_name, $sym_hash_ref) = @{$_};
        for my $key (sort keys(%{$basket->{$name}})) {
            $R->report(sprintf(
                $S{$format_name},
                $basket->{$name}{$key},
                $sym_hash_ref->{$key}[0],
                $sym_hash_ref->{$key}[1],
            ));
        }
    }
}

# Notification when make-extract ignores a symlink.
sub _event_make_extract_symlink {
    my ($source) = @_;
    $R->report(
        {type => $R->TYPE_ERR},
        sprintf($S{make_extract_symlink}, $source->get_locator()->get_value()),
    );
}

# Notification when make-extract updates a target.
sub _event_make_extract_target {
    my ($target) = @_;
    if (!exists($MAKE_EXTRACT_TARGET_SYM_OF{$target->get_status()})) {
        return;
    }
    $R->report(
        {level => $R->MEDIUM},
        sub {
            my ($verbosity) = @_;
            if ($verbosity < $R->DEBUG && $target->is_unchanged()) {
                return;
            }
            my ($ns, $path) = split(qr{/}msx, $target->get_ns(), 2);
            my %source_of = %{$target->get_source_of()};
            my $base = delete($source_of{0});
            my @diff_keys
                = grep {!$source_of{$_}->is_unchanged()} keys(%source_of);
            my @st_missing_diff_keys
                = grep {$source_of{$_}->is_missing()} @diff_keys;
            if (@st_missing_diff_keys) {
                @diff_keys = @st_missing_diff_keys;
            }
            sprintf(
                $S{make_extract_target},
                $MAKE_EXTRACT_TARGET_SYM_OF{$target->get_status()}[0],
                $MAKE_EXTRACT_SOURCE_SYM_OF{$target->get_status_of_source()}[0],
                $ns,
                join(
                q{,},
                    (   defined($base) && defined($base->get_locator())
                            ? ($S{make_extract_target_base_yes})
                            : ($S{make_extract_target_base_no})
                    ),
                    sort({$a <=> $b} @diff_keys),
                ),
                $path,
            );
        },
    );
}

# Returns a CODE to perform a simple notification with sprintf format.
sub _func {
    my ($id) = @_;
    sub {$R->report(sprintf($S{$id}, @_))};
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Util::Event

=head1 SYNOPSIS

    use FCM::Util::Event;
    $event_handler = FCM::Util::Event->new(\%attrib);
    $event_handler->($event);

=head1 DESCRIPTION

Handles events wrapped as L<FCM::Context::Event|FCM::Context::Event> objects by
stringifying and reporting them.

This module is part of L<FCM::Util|FCM::Util>. See also the description of the
$u->report() method in L<FCM::Util|FCM::Util>.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Returns a new instance. The %attrib HASH can have the following elements:

=over 4

=item util

The parent L<FCM::Util|FCM::Util> object.

=back

=item $util->event($event_ctx)

Notification of an $event_ctx, which should be a blessed reference of
L<FCM::Context::Event|FCM::Context::Event>.

=back

=head1 TODO

Modularise?

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
