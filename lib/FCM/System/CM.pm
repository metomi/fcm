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
package FCM::System::CM;
use base qw{FCM::Class::CODE};

use Cwd qw{cwd};
use FCM1::Cm;
use FCM1::Interactive;
use FCM::Context::Event;
use FCM::Context::Locator;
use FCM::System::CM::CommitMessage;
use FCM::System::CM::Prompt;
use FCM::System::CM::ResolveConflicts qw{_cm_resolve_conflicts};
use FCM::System::CM::SVN;
use FCM::System::Exception;
use FCM::Util::Exception;
use File::Spec::Functions qw{catfile};
use List::Util qw{first};
use Storable qw{dclone};

# The (keys) named actions of this class and (values) their implementations.
our %ACTION_OF = (
    cm_branch_create     => \&_cm_branch_create,
    cm_branch_delete     => _fcm1_func(\&FCM1::Cm::cm_branch_delete),
    cm_branch_diff       => _fcm1_func(\&FCM1::Cm::cm_branch_diff),
    cm_branch_info       => _fcm1_func(\&FCM1::Cm::cm_branch_info),
    cm_branch_list       => \&_cm_branch_list,
    cm_commit            => _fcm1_func(\&FCM1::Cm::cm_commit),
    cm_checkout          => \&_cm_checkout,
    cm_check_missing     => _fcm1_func(
        \&FCM1::Cm::cm_check_missing,
        _opt_mod_st_check_handler_func('WC_STATUS_PATH'),
    ),
    cm_check_unknown     => _fcm1_func(
        \&FCM1::Cm::cm_check_unknown,
        _opt_mod_st_check_handler_func('WC_STATUS_PATH'),
    ),
    cm_diff              => \&_cm_diff,
    cm_loc_layout        => \&_cm_loc_layout,
    cm_merge             => _fcm1_func(\&FCM1::Cm::cm_merge),
    cm_mkpatch           => _fcm1_func(\&FCM1::Cm::cm_mkpatch),
    cm_project_create    => \&_cm_project_create,
    cm_resolve_conflicts => \&_cm_resolve_conflicts,
    cm_switch            => _fcm1_func(
        \&FCM1::Cm::cm_switch, _opt_mod_st_check_handler_func('WC_STATUS'),
    ),
    cm_update            => _fcm1_func(
        \&FCM1::Cm::cm_update, _opt_mod_st_check_handler_func('WC_STATUS'),
    ),
    svn                  => \&_svn,
);

# Alias
my $E = 'FCM::System::Exception';

# Creates the class.
__PACKAGE__->class(
    {   commit_message_util => '&',
        gui                 => '$',
        prompt              => '&',
        svn                 => '&',
        util                => '&',
    },
    {init => \&_init, action_of => \%ACTION_OF},
);

sub _init {
    my ($attrib_ref) = @_;
    if (!defined(FCM1::Keyword::get_util())) {
        FCM1::Keyword::set_util($attrib_ref->{util});
    }
    if ($attrib_ref->{'gui'}) {
        FCM1::Interactive::set_impl(
            'FCM1::Interactive::InputGetter::GUI',
            {geometry => $attrib_ref->{gui}},
        );
    }
    $attrib_ref->{prompt} = FCM::System::CM::Prompt->new({
        gui => $attrib_ref->{gui}, util => $attrib_ref->{util},
    });
    $attrib_ref->{commit_message_util} = FCM::System::CM::CommitMessage->new({
        gui  => $attrib_ref->{gui},
        util => $attrib_ref->{util},
    });
    $attrib_ref->{svn} = FCM::System::CM::SVN->new({util => $attrib_ref->{util}});
    FCM1::Cm::set_util($attrib_ref->{util});
    FCM1::Cm::set_commit_message_util($attrib_ref->{commit_message_util});
    FCM1::Cm::set_svn_util($attrib_ref->{svn});
}

# Create a branch in a project.
sub _cm_branch_create {
    my ($attrib_ref, $option_ref, @args) = @_;
    _parse_args($attrib_ref, $option_ref, \@args);
    my ($name, $source) = @args;
    # Check branch name
    if (!$name || $name !~ qr{\A[\w\.\-/]+\z}msx) {
        return $E->throw($E->CM_BRANCH_NAME, $name ? $name : q{});
    }
    # Determine ticket list with name
    if (!$option_ref->{ticket} && $name =~ qr{\A[1-9]\d*([_\-][1-9]\d*)*\z}msx) {
        $option_ref->{ticket} = [split(qr{[_\-]}msx, $name)];
    }
    # Check source
    $source ||= cwd() . '@HEAD';
    my $layout = $attrib_ref->{svn}->get_layout($source);
    my $root = $layout->get_root();
    my $source_rev = $layout->get_peg_rev();
    my $project = $layout->get_project();
    my $source_branch = $layout->get_branch();
    if (!defined($project)) {
        return $E->throw($E->CM_BRANCH_SOURCE, $source);
    }
    my @project_paths = split(qr{/}msx, $project);

    # Determine whether to create a branch of a branch
    if (!$option_ref->{'branch-of-branch'} || !$source_branch) {
        $source_branch = 'trunk';
    }
    $source = join('/', $root, @project_paths, $source_branch)
        . '@' . $source_rev;
    my $source_commit_rev
        = $attrib_ref->{svn}->get_info($source)->[0]->{'commit:revision'};
    $source = join('/', $root, @project_paths, $source_branch)
        . '@' . $source_commit_rev;
    $attrib_ref->{util}->event(
        FCM::Context::Event->CM_BRANCH_CREATE_SOURCE, $source, $source_rev,
    );

    # Handle multiple tickets
    $option_ref->{ticket} ||= [];
    $option_ref->{ticket} = [
        sort
            {$a <=> $b}
        map
            {s{\A#}{}msx; $_}
        split(qr{,}msx, join(q{,}, @{$option_ref->{ticket}}))
    ];

    # Determine the sub-directory names of the branch
    # FIXME: hard coded legacy!
    my %layout_config = %{$layout->get_config()};
    my @names;
    if ($layout_config{'template-branch'}) {
        my $template = $layout_config{'template-branch'};
        if (    index($template, '{category}') >= 0
            ||  index($template, '{owner}') >= 0
        ) {
            $option_ref->{type} ||= 'dev::user';
            $option_ref->{type} = lc($option_ref->{type});
            $option_ref->{type}
                = $option_ref->{type} eq 'user'   ? 'dev::user'
                : $option_ref->{type} eq 'share'  ? 'dev::share'
                : $option_ref->{type} eq 'config' ? 'pkg::config'
                : $option_ref->{type} eq 'rel'    ? 'pkg::rel'
                : $option_ref->{type} eq 'dev'    ? 'dev::user'
                : $option_ref->{type} eq 'test'   ? 'test::user'
                : $option_ref->{type} eq 'pkg'    ? 'pkg::user'
                :                                   $option_ref->{type}
                ;
            if (!grep {$option_ref->{type} eq $_} qw{
                dev::share dev::user test::share test::user
                pkg::config pkg::rel  pkg::share  pkg::user
            }) {
                return $E->throw($E->CM_OPT_ARG, ['type', $option_ref->{type}]);
            }
            my %set = map {$_ => 1} split('::', $option_ref->{type});
            if (index($template, '{category}') >= 0) {
                my $index = index($template, '{category}');
                my $category = first {exists($set{$_})} qw{dev test pkg};
                substr($template, $index, length('{category}'), $category);
            }
            if (index($template, '{owner}') >= 0) {
                my $index = index($template, '{owner}');
                my $owner = exists($set{user})
                    ? $attrib_ref->{svn}->get_username($root)
                    : first {exists($set{lc($_)})} qw{Share Config Rel};
                substr($template, $index, length('{owner}'), $owner);
            }
        }
        if (index($template, '{name_prefix}') >= 0) {
            my $index = index($template, '{name_prefix}');
            # Check revision flag is valid
            $option_ref->{'rev-flag'} ||= 'normal';
            $option_ref->{'rev-flag'} = lc($option_ref->{'rev-flag'});
            if (!grep {$_ eq $option_ref->{'rev-flag'}} qw{normal number none}) {
                return $E->throw(
                    $E->CM_OPT_ARG, ['rev-flag', $option_ref->{'rev-flag'}]);
            }
            my $name_prefix = q{};
            if ($option_ref->{'rev-flag'} ne 'none') {
                $name_prefix = 'r' . $source_commit_rev;
                if ($option_ref->{'rev-flag'} eq 'normal') {
                    # Attempt to replace revision number with a keyword
                    my $locator = FCM::Context::Locator->new($source);
                    my $as_keyword = $attrib_ref->{util}->loc_as_keyword($locator);
                    my ($u, $r) = $attrib_ref->{svn}->split_by_peg($as_keyword);
                    if ($source_commit_rev ne $r) {
                        $name_prefix = $r;
                    }
                }

                # Add an underscore
                $name_prefix .= '_';
            }
            substr($template, $index, length('{name_prefix}'), $name_prefix);
        }
        if (index($template, '{name}') >= 0) {
            my $index = index($template, '{name}');
            substr($template, $index, length('{name}'), $name);
        }
        push(@names, split(qr{/+}msx, $template));
    }
    else {
        push(@names, split(qr{/+}msx, $name));
    }
    if ($layout_config{'depth-branch'} != scalar(@names)) {
        return $E->throw($E->CM_BRANCH_NAME, join('/', @names));
    }
    if ($layout_config{'dir-branch'}) {
        unshift(@names, $layout_config{'dir-branch'});
    }
    # Check whether the branch already exists
    my $target = join('/', $root, @project_paths, @names);
    my $target_url = eval {$attrib_ref->{svn}->get_info($target)->[0]->{url}};
    $@ = undef;
    if ($target_url) {
        return $E->throw($E->CM_ALREADY_EXIST, $target_url);
    }

    # Message for the commit log
    my @tickets = @{$option_ref->{ticket}};
    my @message = sprintf('%sCreated %s from %s@%d.' . "\n",
        (@tickets ? join(q{,}, map {'#' . $_} @tickets) . q{: } : q{}),
        join('/', q{}, @project_paths, @names),
        join('/', q{}, @project_paths, $source_branch), $source_commit_rev,
    );

    # Create a temporary file for the commit log message
    my $commit_message_ctx = $attrib_ref->{commit_message_util}->ctx();
    $commit_message_ctx->set_auto_part(join(q{}, @message));
    $commit_message_ctx->set_info_part(sprintf("%s    %s\n", 'A', $target));
    if (!$option_ref->{'non-interactive'}) {
        $attrib_ref->{commit_message_util}->edit($commit_message_ctx);
    }
    $attrib_ref->{commit_message_util}->notify($commit_message_ctx);
    my $temp_handle
        = $attrib_ref->{commit_message_util}->temp($commit_message_ctx);

    # Check with the user to see if he/she wants to go ahead
    if (    !$option_ref->{'non-interactive'}
        &&  !$attrib_ref->{prompt}->question('BRANCH_CREATE')
    ) {
        return;
    }

    # Create the branch
    $attrib_ref->{svn}->call(
        'copy',
        '--file', $temp_handle->filename(),
        '--parents',
        ($option_ref->{'svn-non-interactive'} ? '--non-interactive' : ()),
        (   defined($option_ref->{'password'})
            ? ('--password', $option_ref->{'password'}) : ()
        ),
        $source,
        $target,
    );
    $attrib_ref->{util}->event(FCM::Context::Event->CM_CREATE_TARGET, $target);

    # Switch working copy to point to newly created branch
    if ($option_ref->{'switch'}) {
        $ACTION_OF{'cm_switch'}->($attrib_ref, $option_ref, $target);
    }

    $target;
}

# Filter lists branches in projects.
sub _cm_branch_list {
    my ($attrib_ref, $option_ref, @args) = @_;
    _parse_args($attrib_ref, $option_ref, \@args);
    if (!@args) {
        @args = cwd() . '@HEAD';
    }
    my %common_patterns_at;
    if ($option_ref->{'only'} && @{$option_ref->{'only'}}) {
        for (@{$option_ref->{'only'}}) {
            my ($depth, $pattern) = split(qr{:}msx, $_, 2);
            $common_patterns_at{$depth} ||= [];
            push(@{$common_patterns_at{$depth}}, $pattern);
        }
    }
    my $UTIL = $attrib_ref->{'util'};
    ARG:
    for my $arg (@args) {
        my %patterns_at = %{dclone(\%common_patterns_at)};
        my %info = eval {%{$attrib_ref->{svn}->get_info($arg)->[0]}};
        if ($@) {
            return $E->throw($E->CM_ARG, $arg);
        }
        my $url = $info{'url'} . '@' . $info{'revision'};
        my $layout = $attrib_ref->{svn}->get_layout($url);
        my $root = $layout->get_root();
        my $rev = $layout->get_peg_rev();
        my $project = $layout->get_project();
        if (!defined($project)) {
            next ARG;
        }
        my $url_project = $root . ($project ? '/' . $project : q{});
        my %layout_config = %{$layout->get_config()};
        if ($layout_config{'level-owner-branch'} && !$option_ref->{'show-all'}) {
            my $level = $layout_config{'level-owner-branch'};
            if ($option_ref->{'user'} && @{$option_ref->{'user'}}) {
                $patterns_at{$level} = [
                    map {'^' . $_ . '$'}
                    map {split(qr{[,:]}msx, $_)}
                    @{$option_ref->{'user'}}
                ];
            }
            elsif (!%patterns_at) {
                my $owner = $attrib_ref->{svn}->get_username($root);
                $patterns_at{$level} = ['^' . $owner . '$'];
            }
        }
        my $url0 = $url_project;
        if ($layout_config{'dir-branch'}) {
            $url0 .= '/' . $layout_config{'dir-branch'};
        }
        else {
            for my $key (qw{trunk tag}) {
                if ($layout_config{"dir-$key"}) {
                    $patterns_at{1} ||= [];
                    push(
                        @{$patterns_at{1}},
                        '^(?!' . $layout_config{"dir-$key"} .  '$)',
                    );
                }
            }
        }
        my @branches = $attrib_ref->{svn}->get_list(
            $url0 . '@' . $rev,
            sub {
                my ($this_url, $this_name, $is_dir, $depth) = @_;
                if (    exists($patterns_at{$depth})
                    &&  !grep {$this_name =~ /$_/} @{$patterns_at{$depth}}
                ) {
                    return (0, 0);
                }
                my $can_return = $depth >= $layout_config{'depth-branch'};
                ($can_return, ($is_dir && !$can_return));
            },
        );
        if ($option_ref->{'url'}) {
            $UTIL->event(
                FCM::Context::Event->CM_BRANCH_LIST,
                $url_project . '@' . $rev, @branches,
            );
        }
        else {
            $UTIL->event(
                FCM::Context::Event->CM_BRANCH_LIST,
                map {$UTIL->loc_as_keyword(FCM::Context::Locator->new($_))}
                    ($url_project . '@' . $rev, @branches),
            );
        }
    }
}

# Wraps "svn checkout".
sub _cm_checkout {
    my ($attrib_ref, $option_ref, @args) = @_;
    _parse_args($attrib_ref, $option_ref, \@args);
    my $target = @args && !$attrib_ref->{util}->uri_match($args[-1])
        ? $args[-1] : cwd();
    my $info_entry = eval {$attrib_ref->{svn}->get_info($target)->[0]};
    if ($@) {
        $@ = undef; # OK, not a working copy
    }
    elsif (grep {index($_, 'wc-info:') == 0} keys(%{$info_entry})) {
        return $E->throw($E->CM_CHECKOUT, [$target, $info_entry->{url}]);
    }
    $attrib_ref->{svn}->call('checkout', @args);
}

# Wraps "svn diff".
sub _cm_diff {
    my ($attrib_ref, $option_ref, @args) = @_;
    _parse_args($attrib_ref, $option_ref, \@args);
    local(%ENV) = %ENV;
    $ENV{FCM_GRAPHIC_DIFF}
        ||= $attrib_ref->{util}->external_cfg_get('graphic-diff');
    $attrib_ref->{svn}->call('diff', @args);
}

# Parse and print layout information of each target in @args.
sub _cm_loc_layout {
    my ($attrib_ref, $option_ref, @args) = @_;
    _parse_args($attrib_ref, $option_ref, \@args);
    if (!@args) {
        @args = qw{.};
    }
    my $OUT = sub {
        $attrib_ref->{util}->event(FCM::Context::Event->OUT, @_);
    };
    my $not_first;
    for my $arg (@args) {
        if ($not_first) {
            $OUT->("\n");
        }
        $not_first = 1;
        $OUT->("target: $arg\n");
        my $layout = $attrib_ref->{svn}->get_layout($arg);
        $OUT->($layout->as_string());
    }
}

# Create a new project in a repository.
sub _cm_project_create {
    my ($attrib_ref, $option_ref, @args) = @_;
    _parse_args($attrib_ref, $option_ref, \@args);
    my ($name, $root_arg) = @args;
    # Check project name
    if (!$name || $name !~ qr{\A[\w\.\-/]+\z}msx) {
        return $E->throw($E->CM_PROJECT_NAME, $name);
    }
    # Check root
    if (!$root_arg) {
        return $E->throw($E->CM_REPOSITORY, q{});
    }
    my $layout = $attrib_ref->{svn}->get_layout($root_arg);
    my $root = $layout->get_root();
    if (!$root) {
        return $E->throw($E->CM_REPOSITORY, $root_arg);
    }

    # Check whether the depth of the project name is valid
    my %layout_config = %{$layout->get_config()};
    my @names = split(qr{/+}msx, $name);
    my $depth_expected = $layout_config{'depth-project'};
    if (defined($depth_expected) && $depth_expected != scalar(@names)) {
        return $E->throw($E->CM_PROJECT_NAME, join('/', @names));
    }
    # Check whether the project (trunk) already exists
    my $target = join('/', $root, @names, $layout_config{'dir-trunk'});
    my $target_url = eval {$attrib_ref->{svn}->get_info($target)->[0]->{url}};
    $@ = undef;
    if ($target_url) {
        return $E->throw($E->CM_ALREADY_EXIST, $target_url);
    }

    # Message for the commit log
    my @message = sprintf("%s: new project.\n", join('/', @names));

    # Create a temporary file for the commit log message
    my $commit_message_ctx = $attrib_ref->{commit_message_util}->ctx();
    $commit_message_ctx->set_auto_part(join(q{}, @message));
    $commit_message_ctx->set_info_part(sprintf("%s    %s\n", 'A', $target));
    if (!$option_ref->{'non-interactive'}) {
        $attrib_ref->{commit_message_util}->edit($commit_message_ctx);
    }
    $attrib_ref->{commit_message_util}->notify($commit_message_ctx);
    my $temp_handle
        = $attrib_ref->{commit_message_util}->temp($commit_message_ctx);

    # Check with the user to see if he/she wants to go ahead
    if (    !$option_ref->{'non-interactive'}
        &&  !$attrib_ref->{prompt}->question('PROJECT_CREATE')
    ) {
        return;
    }

    # Create the branch
    $attrib_ref->{svn}->call(
        'mkdir',
        '--file', $temp_handle->filename(),
        '--parents',
        ($option_ref->{'svn-non-interactive'} ? '--non-interactive' : ()),
        (   defined($option_ref->{'password'})
            ? ('--password', $option_ref->{'password'}) : ()
        ),
        $target,
    );
    $attrib_ref->{util}->event(FCM::Context::Event->CM_CREATE_TARGET, $target);

    $target;
}

# Returns a simple wrapper to FCM 1 FCM1::Cm functions.
sub _fcm1_func {
    my ($action_ref, $opt_mod_ref) = @_;
    $opt_mod_ref ||= sub {};
    sub {
        my ($attrib_ref, $option_ref, @args) = @_;
        _parse_args($attrib_ref, $option_ref, \@args);
        local(@ARGV) = @args;
        $opt_mod_ref->($option_ref);
        eval {$action_ref->($option_ref, @args)};
        if ($@) {
            if (!FCM1::Cm::Abort->caught($@)) {
                die($@);
            }
            if (!($@->get_code() eq $@->NULL || $@->get_code() eq $@->USER)) {
                die($@);
            }
            $attrib_ref->{util}->event(
                FCM::Context::Event->CM_ABORT, lc($@->get_code()),
            );
            $@ = undef;
        }
        return;
    };
}

# Generate an option modifier to st_check_handler.
sub _opt_mod_st_check_handler_func {
    my $key = shift();
    sub {
        my $option_ref = shift();
        if (!$option_ref->{'non-interactive'}) {
            $option_ref->{st_check_handler} = $FCM1::Cm::CLI_HANDLER_OF{$key};
        }
    };
}

# Expands keywords in arguments.
sub _parse_args {
    my ($attrib_ref, $option_ref, $args_ref) = @_;
    # Location keywords
    my $UTIL = $attrib_ref->{util};
    my $url;
    for my $arg (@{$args_ref}) {
        eval {
            my $locator = FCM::Context::Locator->new($arg);
            if ($UTIL->loc_what_type($locator) eq 'svn') {
                my $new_arg = $UTIL->loc_as_normalised($locator);
                my $SVN = $attrib_ref->{svn};
                my ($new_arg_url, $new_arg_rev) = $SVN->split_by_peg($new_arg);
                my (    $arg_url,     $arg_rev) = $SVN->split_by_peg($arg);
                if (index($arg_url, $UTIL->loc_kw_prefix() . ':') == 0) {
                    $arg_url = $new_arg_url;
                }
                if ($arg_rev && $new_arg_rev && $arg_rev ne $new_arg_rev) {
                    $arg_rev = $new_arg_rev;
                }
                $arg = $arg_url . ($arg_rev ? '@' . $arg_rev : q{});
                $url ||= $new_arg_url;
            }
        };
        if (my $e = $@) {
            if (    !FCM::Util::Exception->caught($e)
                ||  index($e->get_code(), 'LOCATOR_') != 0
            ) {
                die($e);
            }
            $@ = undef;
        }
    }
    # Revision keywords
    $url ||= cwd();
    my $in_opt_rev;
    for my $arg (@{$args_ref}) {
        my ($opt, $opt_arg);
        if ($in_opt_rev) {
            $in_opt_rev = 0;
            ($opt, $opt_arg) = (q{}, $arg);
        }
        elsif (grep {$_ eq $arg} qw{-c --change -r --revision}) {
            $in_opt_rev = 1;
        }
        else {
            ($opt, $opt_arg)
                = $arg =~ qr{\A(-[cr]|--(?:change|revision)=)(.*)\z}msx;
        }
        if ($opt_arg) {
            $arg = $opt . _parse_args_rev($attrib_ref, $url, $opt_arg);
        }
    }
    for my $key (grep {exists($option_ref->{$_})} qw{change revision}) {
        $option_ref->{$key}
            = _parse_args_rev($attrib_ref, $url, $option_ref->{$key});
    }
}

# Expands revision keywords in an argument.
sub _parse_args_rev {
    my ($attrib_ref, $url, $arg) = @_;
    my $UTIL = $attrib_ref->{util};
    join(
        ':',
        map {
            my $rev = $_;
            my $locator = FCM::Context::Locator->new($url . '@' . $rev);
            local($@);
            my $value = eval{$UTIL->loc_as_normalised($locator)};
            if ($value) {
                (my $url, $rev) = $attrib_ref->{svn}->split_by_peg($value);
            }
            $rev;
        } split(qr{:}msx, $arg, 2)
    );
}

# Invokes a system "svn" call.
sub _svn {
    my ($attrib_ref, $app, $option_ref, @args) = @_;
    _parse_args($attrib_ref, $option_ref, \@args);
    $attrib_ref->{svn}->call($app, @args);
}

#-------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::CM

=head1 SYNOPSIS

    use FCM::System::CM;
    my $system = FCM::System::CM->new(\%attrib);
    my ($out, $err) = $system->svn({}, @args);

=head1 DESCRIPTION

The FCM code management sub-system. This is currently a thin adaptor of
L<FCM1::Cm|FCM1::Cm>.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Returns a new instance. This class should normally be initialised by
L<FCM::System|FCM::System>.

=item $system->cm_branch_create(\%option,@args)

Implement the C<fcm branch-create> command. On success, return the branch name
created.

=item $system->cm_branch_list(\%option,@args)

Implement the C<fcm branch-list> command.

=item $system->cm_checkout(\%option,@args)

Thin wrapper of the C<svn checkout> command. Ensure checkout to clean location.

=item $system->cm_diff(\%option,@args)

Thin wrapper of the C<svn diff> command. Allow --graphical option.

=item $system->cm_loc_layout(\%option,@args)

Implement the C<fcm loc-layout> command.

=item $system->cm_project_create(\%option,@args)

Implement the C<fcm project-create> command.

=item $system->cm_branch_delete(\%option,@args)
=item $system->cm_branch_info(\%option,@args)
=item $system->cm_commit(\%option,@args)
=item $system->cm_check_missing(\%option,@args)
=item $system->cm_check_unknown(\%option,@args)
=item $system->cm_merge(\%option,@args)
=item $system->cm_mkpatch(\%option,@args)
=item $system->cm_resolve_conflicts(\%option,@args)
=item $system->cm_switch(\%option,@args)
=item $system->cm_update(\%option,@args)

Thin adaptors for the corresponding code management functions in
L<FCM1::Cm|FCM1::Cm>.

=item $system->svn($app,\%option,@args)

Invokes a system call to L<svn|svn> $app with @args. %option is not currently
used, but is left in the argument list for compatibility with the other methods.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
