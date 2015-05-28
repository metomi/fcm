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
package FCM::CLI::Parser;
use base qw{FCM::Class::CODE};

use FCM::CLI::Exception;
use Getopt::Long qw{GetOptions :config bundling};

use constant {
    OPT_INCR => q{+},   # no argument, but incremental
    OPT_BOOL => q{},    # no argument
    OPT_SCAL => q{=s},  # single argument
    OPT_LIST => q{=s@}, # multiple argument
};

# Option hash, key = preferred name of option, value = HASH reference where:
# arg     => argument flag
# letters => ARRAY reference of a list of option letters
# names   => ARRAY reference of a list of names
our %OPTION_OF = map {
    ($_->[0][0], {arg => $_->[2], letters => $_->[1], names => $_->[0]});
} (
    [['archive'            ,            ], ['a'], OPT_BOOL],
    [['auto-log'           ,            ], [   ], OPT_BOOL],
    [['branch'             ,            ], ['b'], OPT_BOOL],
    [['branch-of-branch'   ,            ], [   ], OPT_BOOL],
    [['browser'            ,            ], ['b'], OPT_SCAL],
    [['check'              ,            ], ['c'], OPT_BOOL],
    [['clean'              ,            ], [   ], OPT_BOOL],
    [['create'             ,            ], ['c'], OPT_BOOL],
    [['config-file'        , 'file'     ], ['f'], OPT_LIST],
    [['config-file-path'   ,            ], ['F'], OPT_LIST],
    [['custom'             ,            ], [   ], OPT_BOOL],
    [['delete'             ,            ], ['d'], OPT_BOOL],
    [['diff-cmd'           ,            ], [   ], OPT_SCAL],
    [['directory'          ,            ], ['C'], OPT_SCAL],
    [['dry-run'            ,            ], [   ], OPT_BOOL],
    [['exclude'            ,            ], [   ], OPT_LIST],
    [['extensions'         ,            ], ['x'], OPT_SCAL],
    [['graphical'          ,            ], ['g'], OPT_BOOL],
    [['fcm1'               ,            ], ['1'], OPT_BOOL],
    [['full'               ,            ], ['f'], OPT_BOOL],
    [['help'               , 'usage'    ], ['h'], OPT_BOOL],
    [['ignore-lock'        ,            ], [   ], OPT_BOOL],
    [['info'               ,            ], ['i'], OPT_BOOL],
    [['jobs'               ,            ], ['j'], OPT_SCAL],
    [['list'               ,            ], ['l'], OPT_BOOL],
    [['name'               ,            ], ['n'], OPT_SCAL],
    [['new'                ,            ], ['N'], OPT_BOOL],
    [['non-interactive'    ,            ], [   ], OPT_BOOL],
    [['only'               ,            ], [   ], OPT_LIST],
    [['organisation'       ,            ], [   ], OPT_SCAL],
    [['password'           ,            ], [   ], OPT_SCAL],
    [['quiet'              ,            ], ['q'], OPT_INCR],
    [['relocate'           ,            ], [   ], OPT_BOOL],
    [['reverse'            ,            ], [   ], OPT_BOOL],
    [['revision'           ,            ], ['r'], OPT_SCAL],
    [['rev-flag'           ,            ], [   ], OPT_SCAL],
    [['show-all'           ,            ], ['a'], OPT_BOOL],
    [['show-children'      ,            ], [   ], OPT_BOOL],
    [['show-other'         ,            ], [   ], OPT_BOOL],
    [['show-siblings'      ,            ], [   ], OPT_BOOL],
    [['stage'              ,            ], ['s'], OPT_SCAL],
    [['summarize'          , 'summarise'], [   ], OPT_BOOL],
    [['svn-non-interactive',            ], [   ], OPT_BOOL],
    [['switch'             ,            ], ['s'], OPT_BOOL],
    [['targets'            ,            ], ['t'], OPT_LIST],
    [['ticket'             ,            ], ['k'], OPT_LIST],
    [['trac'               ,            ], ['t'], OPT_BOOL],
    [['type'               ,            ], ['t'], OPT_SCAL],
    [['url'                ,            ], [   ], OPT_BOOL],
    [['user'               ,            ], ['u'], OPT_LIST],
    [['verbose'            ,            ], ['v'], OPT_INCR],
    [['verbosity'          ,            ], ['v'], OPT_SCAL],
    [['wiki'               ,            ], ['w'], OPT_BOOL],
    [['wiki-format'        , 'wiki'     ], ['w'], OPT_SCAL],
    [['xml'                ,            ], [   ], OPT_BOOL],
);
# Hook command before parsing the options
our %HOOK_BEFORE_FOR = (
    'add'    => _get_code_to_match($OPTION_OF{check}),
    'delete' => _get_code_to_match($OPTION_OF{check}),
    'diff'   => sub {
        _get_code_to_replace(
            $OPTION_OF{graphical}, [qw{
                --config-option config:working-copy:exclusive-locking-clients=
                --diff-cmd fcm_graphic_diff
            }]
        )->(@_);
        _get_code_to_replace($OPTION_OF{summarize}, ['--summarize'])->(@_);
        _get_code_to_match($OPTION_OF{branch})->(@_);
    },
    'switch' => sub {!_get_code_to_match($OPTION_OF{relocate})->(@_)},
);
our $HELP_APP = 'help';
# Options for known applications
our %OPTIONS_FOR = (
    'add'           => [$OPTION_OF{check}],
    'branch'        => [@OPTION_OF{
        qw{ branch-of-branch create delete info list name non-interactive
            password quiet revision rev-flag show-all show-children
            show-siblings svn-non-interactive ticket type user verbose
        }
    }],
    'branch-create' => [@OPTION_OF{
        qw{ branch-of-branch non-interactive password rev-flag
            svn-non-interactive switch ticket type
        }
    }],
    'branch-delete' => [@OPTION_OF{
        qw{ non-interactive password quiet show-all show-children show-siblings
            svn-non-interactive switch verbose
        }
    }],
    'branch-diff'   => [@OPTION_OF{
        qw{diff-cmd graphical extensions summarize trac wiki xml}
    }],
    'branch-info'   => [@OPTION_OF{
        qw{quiet show-all show-children show-siblings verbose}
    }],
    'branch-list'   => [@OPTION_OF{
        qw{only quiet show-all url user verbose}
    }],
    'browse'        => [$OPTION_OF{browser}],
    'build'         => [@OPTION_OF{
        qw{archive clean full ignore-lock jobs stage targets verbosity}
    }],
    'cfg-print'     => [$OPTION_OF{fcm1}],
    'cmp-ext-cfg'   => [@OPTION_OF{qw{quiet verbose wiki-format}}],
    'commit'        => [@OPTION_OF{
        qw{dry-run password svn-non-interactive}
    }],
    'conflicts'     => [],
    'delete'        => [$OPTION_OF{check}],
    'diff'          => [@OPTION_OF{
        qw{branch diff-cmd extensions summarize trac wiki}
    }],
    'export-items'  => [@OPTION_OF{qw{directory config-file new}}],
    'extract'       => [@OPTION_OF{qw{clean full ignore-lock verbosity}}],
    'gui'           => [],
    $HELP_APP       => [@OPTION_OF{qw{quiet verbose}}],
    'keyword-print' => [@OPTION_OF{qw{verbose}}],
    'loc-layout'    => [@OPTION_OF{qw{verbose}}],
    'make'          => [@OPTION_OF{
        qw{ archive directory ignore-lock jobs config-file config-file-path name
            new quiet verbose
        }
    }],
    'merge'         => [@OPTION_OF{
        qw{ auto-log custom dry-run non-interactive quiet reverse revision
            verbose}
    }],
    'mkpatch'       => [@OPTION_OF{qw{exclude organisation revision}}],
    'project-create'=> [@OPTION_OF{
        qw{non-interactive password svn-non-interactive}
    }],
    'switch'        => [@OPTION_OF{qw{non-interactive revision quiet verbose}}],
    'update'        => [@OPTION_OF{qw{non-interactive revision quiet verbose}}],
);
# Preferred names of known applications with aliases
our %PREF_NAME_OF = (
    'ann'      => 'blame',
    'annotate' => 'blame',
    'bcreate'  => 'branch-create',
    'bc'       => 'branch-create',
    'bdel'     => 'branch-delete',
    'bdelete'  => 'branch-delete',
    'bdi'      => 'branch-diff',
    'bdiff'    => 'branch-diff',
    'binfo'    => 'branch-info',
    'bld'      => 'build',
    'blist'    => 'branch-list',
    'bls'      => 'branch-list',
    'br'       => 'branch',
    'brm'      => 'branch-delete',
    'cfg'      => 'cfg-print',
    'ci'       => 'commit',
    'cf'       => 'conflicts',
    'co'       => 'checkout',
    'cp'       => 'copy',
    'del'      => 'delete',
    'di'       => 'diff',
    'ext'      => 'extract',
    'h'        => $HELP_APP,
    'kp'       => 'keyword-print',
    'ls'       => 'list',
    'mv'       => 'move',
    'pd'       => 'propdel',
    'pdel'     => 'propdel',
    'pe'       => 'propedit',
    'pedit'    => 'propedit',
    'pg'       => 'propget',
    'pget'     => 'propget',
    'pl'       => 'proplist',
    'plist'    => 'proplist',
    'praise'   => 'blame',
    'ps'       => 'propset',
    'pset'     => 'propset',
    'ren'      => 'move',
    'rename'   => 'move',
    'rm'       => 'delete',
    'remove'   => 'delete',
    'st'       => 'status',
    'sw'       => 'switch',
    'stat'     => 'status',
    'trac'     => 'browse',
    'up'       => 'update',
    'usage'    => $HELP_APP,
    'www'      => 'browse',
    '?'        => $HELP_APP,
    '-V'       => 'version',
    '--help'   => $HELP_APP,
    '--usage'  => $HELP_APP,
    '--version'=> 'version',
);

# Creates the class.
__PACKAGE__->class(
    {   help_app        => {isa => '$', default => $HELP_APP            },
        help_option     => {isa => '%', default => {%{$OPTION_OF{help}}}},
        hook_before_for => {isa => '%', default => {%HOOK_BEFORE_FOR}   },
        options_for     => {isa => '%', default => {%OPTIONS_FOR}       },
        pref_name_of    => {isa => '%', default => {%PREF_NAME_OF}      },
    },
    {action_of => {parse => \&_parse}},
);

# Parses the options and arguments.
sub _parse {
    my ($attrib_ref, @argv) = @_;
    my @args = @argv;
    my $option_hash_ref = {};
    if (!@args) {
        return ($attrib_ref->{help_app}, $option_hash_ref);
    }
    my $app = shift(@args);
    if (exists($attrib_ref->{pref_name_of}{$app})) {
        $app = $attrib_ref->{pref_name_of}{$app};
    }
    if (_get_code_to_match($attrib_ref->{help_option})->(\@args)) {
        return ($attrib_ref->{help_app}, {}, $app);
    }
    if (exists($attrib_ref->{hook_before_for}{$app})) {
        if (!$attrib_ref->{hook_before_for}{$app}->(\@args)) {
            return ($app, $option_hash_ref, @args);
        }
    }
    if (!exists($attrib_ref->{options_for}{$app})) {
        return ($app, $option_hash_ref, @args);
    }
    my @option_strings = map {
        join('|', @{$_->{names}}, @{$_->{letters}}) . $_->{arg};
    } @{$attrib_ref->{options_for}{$app}};
    local(@ARGV) = @args;
    my @warnings;
    local($SIG{__WARN__}) = sub {push(@warnings, @_)};
    if (!GetOptions($option_hash_ref, @option_strings)) {
        my $E = 'FCM::CLI::Exception';
        for (@warnings) {
            chomp();
        }
        return $E->throw($E->OPT, \@argv, join('|', @warnings));
    }
    @args = @ARGV;
    return ($app, $option_hash_ref, @args);
}

# Returns a CODE reference for matching a simple option to a string.
sub _get_option_matcher {
    my ($option_ref) = @_;
    return sub {
        grep {$_[0] eq $_} (
            (map {"--$_"} @{$option_ref->{names}  }),
            (map { "-$_"} @{$option_ref->{letters}}),
        );
    };
}

# Returns a CODE reference for matching a simple option to a string.
sub _get_code_to_match {
    my ($option_ref) = @_;
    my $grepper = _get_option_matcher($option_ref);
    return sub {grep {$grepper->($_)} @{$_[0]}};
}

# Returns a CODE reference to replace a simple option in the argument list.
sub _get_code_to_replace {
    my ($option_ref, $replacement) = @_;
    my @replacements = ref($replacement) ? @{$replacement} : $replacement;
    my $grepper = _get_option_matcher($option_ref);
    return sub {
        @{$_[0]} = map {($grepper->($_) ? @replacements : $_)} @{$_[0]};
        return 1;
    };
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::CLI::Parser

=head1 SYNOPSIS

    use FCM::CLI::Parser;
    my $cli = FCM::CLI::Parser->new(\%attrib);
    my ($app, $opt_hash_ref, @args) = $cli->(@ARGV);

=head1 DESCRIPTION

This class provides an option/argument parser for the FCM command line
interface. The parser, when called with some arguments, returns a list. The 1st
element is the name of the application, the 2nd element is a HASH reference
containing the option names and their values. The remaining elements are the
remaining arguments.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Returns a new instance. The %attrib HASH may contain the following elements:

=over 4

=item help_app

The name of the I<help> application. Default = $FCM::CLI::Parser::HELP_APP. 

=item help_option

An option that represents I<help>. If this option is encountered in the command
line, the CODE reference returns (help_app, {}, $app) regardless of the other
command line options and arguments. Default =
$FCM::CLI::Parser::OPTIONS_FOR{help}.

=item hook_before_for

Hook commands for the applications, which are executed before the option parser.
See the L</CONFIGURATIONS> section for detail. Default =
$FCM::CLI::Parser::HOOK_BEFORE_FOR.

=item options_for

The options for each application. See the L</CONFIGURATIONS> section for detail.
Default = $FCM::CLI::Parser::OPTIONS_FOR.

=item pref_name_of

The preferred names for the applications. See the L</CONFIGURATIONS> section for
detail. Default = $FCM::CLI::Parser::PREF_NAME_OF.

=back

=item $instance->(@args)

=back

=head1 CONFIGURATIONS

The following should only be used as read-only variables. The
$class->new(\%attrib) method should be used to configure a parser.

=over 4

=item $FCM::CLI::Parser::HELP_APP

The name of the I<help> application.

=item %FCM::CLI::Parser::HOOK_BEFORE_FOR

A hash containing the hook commands, which are invoked before calling the option
parser. The hash keys are names of the applications, and the values are CODE
references to invoke. If a hook exists for an application, it is called as
$hook->(\@args) where @args is the current command line arguments (with the
first argument, i.e. the application name removed). If the hook returns a false
value, the parser will return immediately.

=item %FCM::CLI::Parser::OPTION_OF

A hash containing the known options. The key is the preferred name of the
option, and the value is a HASH reference, where C<names> (=> ARRAY reference)
are the long names of the option, C<letters> (=> ARRAY reference) are the
option letters, C<arg> (=> integer) is a flag. (See L</CONSTANTS> section for
detail.)

=item %FCM::CLI::Parser::OPTIONS_FOR

A hash containing the known applications. The keys are the names of the
applications and the values are ARRAY references, each pointing to
a list of options (as described in %FCM::CLIParser::OPTION_OF) for the
application.

=item %FCM::CLI::Parser::PREF_NAME_OF

A hash containing the preferred names of an application. The keys are the
aliases and the values are the preferred names.

=back

=head1 CONSTANTS

=over 4

=item FCM::CLI::Parser->OPT_BOOL

Option flag. Option is a boolean with no argument.

=item FCM::CLI::Parser->OPT_INCR

Option flag. Option has no argument but is incremental.

=item FCM::CLI::Parser->OPT_LIST

Option flag. Option has one or more arguments.

=item FCM::CLI::Parser->OPT_SCAL

Option flag. Option has a single argument.

=back

=head1 DIAGNOSTICS

=over 4

=item FCM::CLI::Parser::Exception

This exception is raised if an invalid command option is given. It inherits from
L<FCM::Exception>. There is no error code associated with this exception. The
$e->get_ctx() method returns an ARRAY reference containing the original
arguments.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
