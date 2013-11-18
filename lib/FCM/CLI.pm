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
package FCM::CLI;
use base qw{FCM::Class::CODE};

use FCM::CLI::Exception;
use FCM::CLI::Parser;
use FCM::Context::Event;
use FCM::System;
use FindBin;
use File::Basename        qw{dirname};
use File::Spec::Functions qw{catfile rel2abs};
use Pod::Usage            qw{pod2usage};

my $E = 'FCM::CLI::Exception';
our $EVENT;
our $S;
our %ACTION_OF = (
    # Commands handled by FCM
    'add'           => _opt_func('check', sub {$S->cm_check_unknown(@_)}),
    'branch'        => \&_branch,
    'branch-create' => _sys_func(sub {$S->cm_branch_create(@_)}),
    'branch-delete' => _sys_func(sub {$S->cm_branch_delete(@_)}),
    'branch-diff'   => _sys_func(sub {$S->cm_branch_diff(@_)}),
    'branch-info'   => _sys_func(sub {$S->cm_branch_info(@_)}),
    'branch-list'   => _sys_func(sub {$S->cm_branch_list(@_)}),
    'browse'        => _sys_func(sub {$S->browse(@_)}),
    'build'         => _sys_func(sub {$S->build(@_)}),
    'cfg-print'     => _sys_func(sub {$S->config_parse(@_)}),
    'checkout'      => _sys_func(sub {$S->cm_checkout(@_)}),
    'cmp-ext-cfg'   => _sys_func(sub {$S->config_compare(@_)}),
    'commit'        => _sys_func(sub {$S->cm_commit(@_)}),
    'conflicts'     => _sys_func(sub {$S->cm_resolve_conflicts(@_)}),
    'delete'        => _opt_func('check', sub {$S->cm_check_missing(@_)}),
    'diff'          => _opt_func(
        'branch', sub {$S->cm_branch_diff(@_)}, sub {$S->cm_diff(@_)},
    ),
    'export-items'  => _sys_func(sub {$S->export_items(@_)}),
    'extract'       => _sys_func(sub {$S->extract(@_)}),
    'gui'           => \&_gui,
    'help'          => \&_help,
    'keyword-print' => _sys_func(sub {$S->keyword_find(@_)}),
    'loc-layout'    => _sys_func(sub {$S->cm_loc_layout(@_)}),
    'merge'         => _sys_func(sub {$S->cm_merge(@_)}),
    'mkpatch'       => _sys_func(sub {$S->cm_mkpatch(@_)}),
    'make'          => _sys_func(sub {$S->make(@_)}),
    'project-create'=> _sys_func(sub {$S->cm_project_create(@_)}),
    'switch'        => _opt_func(
        'relocate', sub {$S->svn(@_)}, sub {$S->cm_switch(@_)},
    ),
    'test-battery'  => \&_test_battery,
    'update'        => _sys_func(sub {$S->cm_update(@_)}),
    'version'       => _sys_func(sub {$S->version(@_)}),
    # Commands passed directly to "svn"
    map {($_ => _sys_func())} qw{
        blame
        cat
        cleanup
        copy
        export
        import
        info
        list
        lock
        log
        mergeinfo
        mkdir
        move
        patch
        propdel
        propedit
        propget
        proplist
        propset
        resolve
        resolved
        revert
        status
        unlock
        upgrade
    },
);
# List of overridden subcommands that need to display "svn help"
our %CLI_MORE_HELP_FOR = map {($_, 1)} (qw{add delete diff switch update});

# Creates the class.
__PACKAGE__->class(
    {'gui' => '$', 'parser' => 'FCM::CLI::Parser', 'system' => 'FCM::System'},
    {   init => sub {
            my $attrib_ref = shift();
            $attrib_ref->{parser} ||= FCM::CLI::Parser->new();
            $attrib_ref->{system}
                ||= FCM::System->new({'gui' => $attrib_ref->{'gui'}});
        },
        action_of => {main => \&_main},
    },
);

# The main CLI action.
sub _main {
    my ($attrib_ref, @argv) = @_;
    local($EVENT) = sub {$attrib_ref->{system}->util()->event(@_)};
    my ($app, $option_ref, @args) = eval {$attrib_ref->{parser}->parse(@argv)};
    if (my $e = $@) {
        _err($attrib_ref, \@argv, $e);
    }
    if (!$app || $option_ref->{help}) {
        return _help($attrib_ref, $app);
    }
    $option_ref ||= {};
    my $q = $option_ref->{quiet}   || 0;
    my $v = $option_ref->{verbose} || 0;
    my $reporter = $attrib_ref->{system}->util()->util_of_report();
    my $verbosity = $reporter->DEFAULT + $v - $q;
    if (exists($ENV{FCM_DEBUG}) && $ENV{FCM_DEBUG} eq 'true') {
        $verbosity = $reporter->DEBUG;
    }
    $reporter->get_ctx_of_stderr()->set_verbosity($verbosity);
    $reporter->get_ctx_of_stdout()->set_verbosity($verbosity);
    my @context = eval {
        if (!exists($ACTION_OF{$app})) {
            return $E->throw($E->APP, \@argv);
        }
        $ACTION_OF{$app}->($attrib_ref, $app, $option_ref, @args);
    };
    if (my $e = $@) {
        return _err($attrib_ref, \@argv, $e);
    }
}

# "fcm branch".
sub _branch {
    my ($attrib_ref, $app, $option_ref, @args) = @_;
    my $method
        = exists($option_ref->{create}) ? 'cm_branch_create'
        : exists($option_ref->{delete}) ? 'cm_branch_delete'
        : exists($option_ref->{list})   ? 'cm_branch_list'
        :                                 'cm_branch_info'
        ;
    if ($option_ref->{create}) {
        if (!$option_ref->{name}) {
            return $E->throw($E->OPT, [$app, @args]);
        }
        my $name = delete($option_ref->{name});
        unshift(@args, $name);
    }
    $attrib_ref->{system}->($method, $option_ref, @args);
}

# Handles FCM::Exception.
sub _err {
    my ($attrib_ref, $argv_ref, $e) = @_;
    $EVENT->(FCM::Context::Event->E, $e) || die($e);
    die("\n");
}

# "fcm gui".
sub _gui {
    my ($attrib_ref, $app, $option_ref, @args) = @_;
    exec("$FindBin::Bin/fcm_gui", @args);
}

# Implements "fcm help" and usage.
sub _help {
    my ($attrib_ref, $app, $option_ref, @args) = @_;
    $app ||= 'help';
    my @keys = ($app eq 'help' && @args) ? @args : (q{});
    for my $key (@keys) {
        if (exists($FCM::CLI::Parser::PREF_NAME_OF{$key})) {
            $key = $FCM::CLI::Parser::PREF_NAME_OF{$key};
        }
        my $pod
            = $key ? catfile(dirname($INC{'FCM/CLI.pm'}), 'CLI', "fcm-$key.pod")
            :        $0
            ;
        if ($pod eq $0) {
            # Read fcm-version.js file
            my $version = $attrib_ref->{system}->util()->version();
            my $bin = rel2abs($0);
            $EVENT->(FCM::Context::Event->OUT, "$version ($bin)\n");
        }
        my $has_pod = -f $pod;
        if ($has_pod) {
            my $reporter = $attrib_ref->{system}->util()->util_of_report();
            my $verbosity = $reporter->get_ctx_of_stdout()->get_verbosity();
            pod2usage({
                '-exitval' => 'NOEXIT',
                '-input'   => $pod,
                '-verbose' => $verbosity,
            });
        }
        if (!$has_pod || exists($CLI_MORE_HELP_FOR{$key})) {
            $attrib_ref->{system}->svn('help', {}, $key ? $key : ())
        }
    }
    return;
}

# "fcm test-battery".
sub _test_battery {
    my ($attrib_ref, $app, $option_ref, @args) = @_;
    exec("$FindBin::Bin/fcm_test_battery", @args);
}

# Returns a function that select the alternate handler for the application. The
# handler is either $method_id (if $opt_id is set) or "svn".
sub _opt_func {
    my ($opt_id, $code0_ref, $code1_ref) = @_;
    $code0_ref = _sys_func($code0_ref);
    $code1_ref = _sys_func($code1_ref);
    sub {
        my ($attrib_ref, $app, $option_ref, @args) = @_;
        my $code_ref = exists($option_ref->{$opt_id}) ? $code0_ref : $code1_ref;
        $code_ref->($attrib_ref, $app, $option_ref, @args);
    };
}

# Invokes a system function.
sub _sys_func {
    my ($code_ref) = @_;
    sub {
        my ($attrib_ref, $app, @args) = @_;
        local($S) = $attrib_ref->{system};
        defined($code_ref) ? $code_ref->(@args) : $S->svn($app, @args);
    };
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::CLI

=head1 SYNOPSIS

    my $cli = FCM::CLI->new();
    $cli->(@ARGV);

=head1 DESCRIPTION

An implementation of the FCM command line interface.

=head1 METHODS

=over 4

=item $class->new()

Returns a new instance.

=item $cli->(@ARGV)

Determines the application using the first element in @ARGV, parses the options
and arguments according to the application, and invokes the application.

=back

=head1 DIAGNOSTICS

=head2 FCM::CLI::Exception

This exception is thrown when the CLI fails to invoke an application.

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
