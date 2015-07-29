#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------

use strict;
use warnings;

package FCM::Admin::Commit;

use Exporter qw{import};
our @EXPORT_OK = qw{
    post_commit_notify_who
    pre_commit_perm
};

use File::Spec::Functions qw{catfile};
use File::Temp;
use Memoize qw{memoize};

use FCM::Admin::Config;
use FCM::Admin::System qw{get_users verify_users};
use FCM::Context::Locator;
use FCM::System::CM::SVN;

my $COMMIT_CONF_BASE = 'commit.cfg';
my $UTIL = $FCM::Admin::Config::UTIL;
my $CM_SYS = FCM::System::CM::SVN->new({'util' => $UTIL});
my %WARN_FMT_OF = (
    'CONF' => "\tINVALID CONFIGURATION\n",
    'CONF_NS' => "\tBAD NAMESPACE: %s\n",
    'CONF_VALUE' => "\tBAD VALUE: %s\n",
    'OWNER' => "\tBAD CONF: owner[] undefined with %s=repository|project\n",
    'PERM' => "PERMISSION DENIED: %s\n",
);

# Implement functionalities for "post-commit-notify-who"
sub post_commit_notify_who {
    my ($repos, $rev, $txn) = @_;

    my $commit_conf = _load_commit_conf($repos);
    if (!defined($commit_conf)) {
        return;
    }

    # Named repository owners can modify any path.
    my $author = _get_author($repos, $rev, $txn);
    $CM_SYS->load_layout_config('file://' . $repos);
    my %names = (); # {$name1 => 1, $name2 => 1, ...}
    LINE:
    for my $line ($CM_SYS->stdout(qw{svnlook changed -r}, $rev, $repos)) {
        my $status = substr($line, 0, 1);
        my $path = substr($line, 4);
        my $layout = $CM_SYS->get_layout_common(
            $repos,
            ($status eq 'D' ? $rev - 1 : $rev),
            "/$path",
            $CM_SYS->IS_LOCAL,
        );
        my $project = $layout->get_project();
        my $branch = $layout->get_branch();

        # Notify branch subscribers/owners
        if (    $commit_conf->get_notification_modes()->{'branch'}
            &&  $layout->is_branch()
            &&  defined($branch)
        ) {
            my $branch_path = join(q{/}, grep {$_} ($project, $branch));
            if (!exists($commit_conf->get_owners_of()->{"$branch_path/"})) {
                my $owner = $layout->is_shared()
                    ? _get_path_creator($repos, $rev, $project, $branch)
                    : $layout->get_branch_owner()
                    ;
                if ($owner) {
                    $commit_conf->get_owners_of()->{$branch_path} = [$owner];
                }
            }
            for my $user ($commit_conf->get_notifiables_of($branch_path)) {
                $names{$user} = 1;
            }
            next LINE;
        }

        # Notify project subscribers/owners
        if (    $commit_conf->get_notification_modes()->{'project'}
            &&  defined($project)
        ) {
            for my $user ($commit_conf->get_notifiables_of("$project/")) {
                $names{$user} = 1;
            }
            next LINE;
        }

        # Notify repository subscribers/owners
        if ($commit_conf->get_notification_modes()->{'repository'}) {
            for my $user ($commit_conf->get_notifiables_of(q{})) {
                $names{$user} = 1;
            }
            next LINE;
        }
    }

    # Don't notify author
    if (exists($names{$author})) {
        delete($names{$author});
    }
    # Return list of emails
    my @users = %names ? values(%{get_users(keys(%names))}) : ();
    return sort grep {$_} map {$_->get_email()} @users;
}

# Implement functionalities for "pre-commit-perm"
sub pre_commit_perm {
    my ($repos, $txn) = @_;

    my $commit_conf = _load_commit_conf($repos);

    # Check permission:
    my $author = _get_author($repos, undef, $txn);
    $CM_SYS->load_layout_config('file://' . $repos);
    my %line_of_unknown_path;
    my @bads;
    LINE:
    for my $line ($CM_SYS->stdout(qw{svnlook changed -t}, $txn, $repos)) {
        my $status = substr($line, 0, 1);
        my $path = substr($line, 4);
        # Ensure values for changes in "commit.cfg" are valid
        if ($status ne 'D' && $path eq $COMMIT_CONF_BASE) {
            my @problems = _check_commit_conf($commit_conf, $repos, $txn);
            if (@problems) {
                push(@bads, [$line, @problems]);
            }
            next LINE;
        }
        # Allow addition of intermediate directories on creation of projects
        if ($status eq 'A') {
            while (my $unknown_path = each(%line_of_unknown_path)) {
                if (index($path, $unknown_path) == 0) {
                    delete($line_of_unknown_path{$unknown_path});
                }
            }
        }
        my $layout = $CM_SYS->get_layout_common(
            $repos, $txn, "/$path", $CM_SYS->IS_LOCAL);
        my $project = $layout->get_project();
        my $branch = $layout->get_branch();
        # Branch owner perm mode
        if (    $commit_conf->get_permission_modes()->{'branch'}
            &&  $layout->is_branch()
            &&  defined($branch)
        ) {
            my $branch_path = join(q{/}, grep {$_} ($project, $branch));
            if (!exists($commit_conf->get_owners_of()->{$branch_path})) {
                # Anyone can create a shared branch
                if (    $layout->is_shared()
                    &&  $status eq 'A'
                    &&  $path eq "$branch_path/"
                ) {
                    next LINE;
                }
                my $owner = $layout->is_shared()
                    ? _get_path_creator($repos, undef, $project, $branch)
                    : $layout->get_branch_owner()
                    ;
                if ($owner) {
                    $commit_conf->get_owners_of()->{$branch_path} = [$owner];
                }
            }
            # Create branch with user ID in branch name: can only be done by
            # author of the same user ID.
            # For all other changes, check permission as usual.
            if (    (       !$layout->is_shared()
                        &&  $status eq 'A'
                        &&  $path eq "$branch_path/"
                        &&  $author ne $layout->get_branch_owner()
                    )
                ||  !_perm_ok($commit_conf, $author, $project, $branch)
            ) {
                push(@bads, [$line]);
            }
            next LINE;
        }
        # Project owner can do anything to paths at or under the project
        if (    $commit_conf->get_permission_modes()->{'project'}
            &&  defined($project)
        ) {
            if (!_perm_ok($commit_conf, $author, $project)) {
                # An author who is not a project owner can add paths under the
                # project as part of a branch creation, etc.
                # "$line_of_unknown_path{$path}" may be deleted if it is a part
                # of a valid branch creation by an author who is not a project
                # owner.
                if ($status eq 'A' && !$branch) {
                    $line_of_unknown_path{$path} = $line;
                }
                # Permission denied for everything else under the project.
                else {
                    push(@bads, [$line]);
                }
            }
            next LINE;
        }
        # Repository owner can do anything
        if ($commit_conf->get_permission_modes()->{'repository'}) {
            if (!_perm_ok($commit_conf, $author)) {
                # An author who is not a repository owner can add paths under a
                # project as part of a branch creation, project creation, etc.
                # "$line_of_unknown_path{$path}" may be deleted if it is a part
                # of a valid branch creation, project creation, etc. by an
                # author who is not a repository owner.
                if ($status eq 'A' && !$project) {
                    $line_of_unknown_path{$path} = $line;
                }
                # Permission denied for everything else.
                else {
                    push(@bads, [$line]);
                }
            }
            next LINE;
        }
    }
    # Report all bad lines
    for my $line (values(%line_of_unknown_path)) {
        push(@bads, [$line]);
    }
    for (sort {substr($a->[0], 4) cmp substr($b->[0], 4)} @bads) {
        my ($line, @problems) = @{$_};
        warn(sprintf($WARN_FMT_OF{'PERM'}, $line));
        for my $problem (@problems) {
            warn($problem);
        }
    }

    return (@bads != 0);
}

# Check changes to "commit.cfg" are valid. Return list of problems.
sub _check_commit_conf {
    my ($commit_conf, $repos, $txn) = @_;
    my $conf_str = $CM_SYS->stdout(
        qw{svnlook cat -t}, $txn, $repos, $COMMIT_CONF_BASE);
    my $conf_handle = File::Temp->new();
    $conf_handle->print($conf_str);
    $conf_handle->seek(0, 0);
    my $conf_locator = FCM::Context::Locator->new($conf_handle->filename());
    my $conf_reader = $UTIL->config_reader($conf_locator);
    my $owner_conf_entry;
    my @problems;
    CONF_ENTRY:
    while (1) {
        my $conf_entry = eval {$conf_reader->()};
        if ($@) {
            my $problem = $WARN_FMT_OF{'CONF'};
            push(@problems, $problem);
            last CONF_ENTRY;
        }
        if (!defined($conf_entry)) {
            last CONF_ENTRY;
        }
        for (
            ['owner', $commit_conf->get_owners_of()],
            ['subscriber', $commit_conf->get_subscribers_of()],
        ) {
            my ($label, $users_map_ref) = @{$_};
            if ($conf_entry->get_label() eq $label) {
                # Owners must be real users
                my @bad_users = verify_users($conf_entry->get_values());
                if (!$conf_entry->get_value() || @bad_users) {
                    my $problem = sprintf(
                        $WARN_FMT_OF{'CONF_VALUE'}, $conf_entry->as_string());
                    push(@problems, $problem);
                }
                # Check NS of each owner[NS] setting
                for my $ns (@{$conf_entry->get_ns_list()}) {
                    eval {
                        $CM_SYS->stdout(qw{svnlook tree -N -t}, $txn, $repos, $ns);
                    };
                    if ($@) {
                        my $problem = sprintf(
                            $WARN_FMT_OF{'CONF_NS'}, $conf_entry->get_lhs());
                        push(@problems, $problem);
                    }
                }
                if ($label eq 'owner' && !@{$conf_entry->get_ns_list()}) {
                    $owner_conf_entry = $conf_entry;
                }
                next CONF_ENTRY;
            }
        }
        for (
            ['permission-modes', $commit_conf->get_permission_modes()],
            ['notification-modes', $commit_conf->get_notification_modes()],
        ) {
            my ($label, $modes_ref) = @{$_};
            if ($conf_entry->get_label() eq $label) {
                # Permission mode values must be one of predefined
                if (grep {!exists($modes_ref->{$_})}
                        $conf_entry->get_values()
                ) {
                    my $problem = sprintf(
                        $WARN_FMT_OF{'CONF_VALUE'}, $conf_entry->as_string());
                    push(@problems, $problem);
                }
                for my $value ($conf_entry->get_values()) {
                    if (exists($modes_ref->{$value})) {
                        $modes_ref->{$value} = 1;
                    }
                }
                next CONF_ENTRY;
            }
        }
    }
    $conf_handle->close();
    # owner[] must be set if mode has "repository"
    # owner[] must be set if mode has "project"
    for (
        ['permission-modes', $commit_conf->get_permission_modes()],
        ['notification-modes', $commit_conf->get_notification_modes()],
    ) {
        my ($label, $modes_ref) = @{$_};
        if (    !defined($owner_conf_entry)
            &&  ($modes_ref->{'repository'} || $modes_ref->{'project'})
        ) {
            push(@problems, sprintf($WARN_FMT_OF{'OWNER'}, $label));
        }
    }
    return @problems;
}

# Get and return the author of $txn or $rev of $repos
memoize('_get_author');
sub _get_author {
    my ($repos, $rev, $txn) = @_;
    my @opts = $rev ? ('-r', $rev) : ('-t', $txn);
    return ($CM_SYS->stdout(qw{svnlook author}, @opts, $repos))[0];
}

# Get and return creator of a path
memoize('_get_path_creator');
sub _get_path_creator {
    my ($repos, $rev, @paths) = @_;
    my $path = join(q{/}, grep {$_} @paths);
    if (!defined($rev)) {
        $rev = _get_youngest_rev($repos);
    }
    my @log_lines = eval {$CM_SYS->stdout(
        qw{svn log -q --incremental --stop-on-copy --limit 1},
        '-r1:' . $rev, "file://$repos/$path\@$rev",
    )};
    if ($@) {
        $@ = undef;
        @log_lines = ();
    }
    # The output looks like this:
    # ------------------------------------------------------------------------
    # r15 | who | 2038-01-19 03:14:01 +0000 (Tue, 19 Jan 2038)
    LOG_LINE:
    for my $log_line (@log_lines) {
        my ($owner) = $log_line =~ qr{\Ar\d+\s\|\s([^\|]+)\s\|}msx;
        if ($owner) {
            return $owner;
        }
    }
    return;
}

# Get and return the youngest revision of $repos
memoize('_get_youngest_rev');
sub _get_youngest_rev {
    my ($repos) = @_;
    return $CM_SYS->stdout(qw{svnlook youngest}, $repos);
}

# Load "commit.cfg"
sub _load_commit_conf {
    my ($repos) = @_;
    my $commit_conf_path = catfile($repos, 'hooks', $COMMIT_CONF_BASE);
    if (!-f $commit_conf_path) {
        return FCM::Admin::Commit::Conf->new();
    }
    my $config_reader = $UTIL->config_reader(
        FCM::Context::Locator->new($commit_conf_path));
    my $commit_conf = FCM::Admin::Commit::Conf->new();
    CONF_ENTRY:
    while (defined(my $config_entry = $config_reader->())) {
        for (
            ['owner', $commit_conf->get_owners_of()],
            ['subscriber', $commit_conf->get_subscribers_of()],
        ) {
            my ($label, $users_map_ref) = @{$_};
            if ($config_entry->get_label() eq $label) {
                my @users = $config_entry->get_values();
                my @ns_list = @{$config_entry->get_ns_list()};
                if (!@ns_list) {
                    @ns_list = (q{});
                }
                for my $ns (@ns_list) {
                    $users_map_ref->{$ns} = \@users;
                }
                next CONF_ENTRY;
            }
        }
        for (
            ['permission-modes', $commit_conf->get_permission_modes()],
            ['notification-modes', $commit_conf->get_notification_modes()],
        ) {
            my ($label, $modes_ref) = @{$_};
            if ($config_entry->get_label() eq $label) {
                for my $word ($config_entry->get_values()) {
                    if (exists($modes_ref->{$word})) {
                        $modes_ref->{$word} = 1;
                    }
                }
                next CONF_ENTRY;
            }
        }
    }
    return $commit_conf;
}

# Returns true if author can commit to @paths
memoize('_perm_ok');
sub _perm_ok {
    my ($commit_conf, $author, @paths) = @_;
    my $is_first_try = 1;
    while ($is_first_try || @paths) {
        my $path = join(q{/}, grep {$_} @paths);
        my %owners_of = %{$commit_conf->get_owners_of()};
        if (    exists($owners_of{$path})
            &&  grep {$_ eq '*' || $_ eq $author} @{$owners_of{$path}}
        ) {
            return 1;
        }
        $is_first_try = 0;
        pop(@paths);
    }
    return !exists($commit_conf->get_owners_of()->{q{}});
}

#-------------------------------------------------------------------------------
# Data structure to represent the commit configuration
package FCM::Admin::Commit::Conf;
use base qw{FCM::Class::HASH};

my %MODES = (
    'repository' => undef,
    'project'    => undef,
    'branch'     => undef,
);

__PACKAGE__->class({
    'notification_modes' => {'isa' => '%', default => {%MODES}},
    'owners_of'          => '%',
    'permission_modes'   => {'isa' => '%', default => {%MODES}},
    'subscribers_of'     => '%',
});

# Return a list of subscribers/owners of a given path
sub get_notifiables_of {
    my ($self, $path) = @_;
    if (exists($self->get_subscribers_of()->{$path})) {
        return @{$self->get_subscribers_of()->{$path}};
    }
    elsif (exists($self->get_owners_of()->{$path})) {
        return @{$self->get_owners_of()->{$path}};
    }
}

1;
__END__

=head1 NAME

FCM::Admin::Commit

=head1 SYNOPSIS

    use FCM::Admin::Commit qw{ ... };
    # ... see descriptions of individual functions for detail

=head1 DESCRIPTION

This module implements functionalities used by our pre-commit and post-commit
hooks.

=head1 FUNCTIONS

=over 4

=item post_commit_notify_who($repos, $rev, $txn)

Return a list of email addresses who should be notified of the commit.
The author of the commit will normally be excluded.

=item pre_commit_perm($repos, $txn)

Check if the author has the permission to commit $txn to $repos or not.
Return a non-zero return code if author does not have permission.

=back

=head1 CONFIGURATION

The rules used by the functions of this modules are defined in the repository's
"commit.cfg". The settings are:

=over 4

=item notification-modes=C<ITEM> ...

A list of items that requires commit notifications. An C<ITEM> can be
C<repository>, C<project> or C<branch>.

=item owner=C<USER1> ...
=item owner[C<project>]=C<USER1> ...
=item owner[C<project/branches/dev/Share/whatever>]=C<USER1> ...

In the absence of a name-space, specify the user IDs of the owners of the
repository in a space delimited list. This setting is compulsory if
C<repository> or C<project> is in C<permission-modes>. Owners of the repository
can change any path in the repository. If C<repository> is in
C<notification-modes>, owners will be informed of all changes that are outside
of a project.

With a name-space, specify the user IDs of the owners of a project (or a shared
topic branches of). The owners of a project can make changes to the trunk and
any branches in the project. The owners of a named shared branch can make
changes to the shared branch. If C<project> is in C<notification-modes>, project
owners will be informed of all changes that are within a project but outside of
its topic branches. If C<branch> is in C<notification-modes>, branch owners will
be informed of all changes that are within the branch.

Finally, the program always removes the change author from the notification
list.

=item permission-modes=C<ITEM> ...

A list of items that require permission checking. An C<ITEM> can be
C<repository>, C<project> or C<branch>.

=item subscriber=C<USER1> ...
=item subscriber[C<project>]=C<USER1> ...
=item subscriber[C<project/branches/dev/Share/whatever>]=C<USER1> ...

A space delimited list of user IDs of the notification subscribers of the
repository, a project or a shared topic branch. If not specified, the owners
of a given level are the notification subscribers. If an empty list is
specified for a given level, then there will be no notification email for
changes under that.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
