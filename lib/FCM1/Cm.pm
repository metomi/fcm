# ------------------------------------------------------------------------------
# Copyright (C) British Crown (Met Office) & Contributors.
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
# NAME
#   FCM1::Cm
#
# DESCRIPTION
#   This module contains the FCM code management functionalities and wrappers
#   to Subversion commands.
#
# ------------------------------------------------------------------------------
use strict;
use warnings;

package FCM1::Cm;
use base qw{Exporter};

our @EXPORT_OK = qw(cm_check_missing cm_check_unknown cm_switch cm_update);

use Cwd qw{cwd};
use FCM::System::Exception;
use FCM1::Config;
use FCM1::CmBranch;
use FCM1::CmUrl;
use FCM1::Keyword;
use FCM1::Util      qw{
    get_url_of_wc
    get_url_peg_of_wc
    is_url
    is_wc
    tidy_url
};
use File::Basename qw{basename dirname};
use File::Path qw{mkpath rmtree};
use File::Spec;
use Text::ParseWords qw{shellwords};

# ------------------------------------------------------------------------------

# CLI message handler
our $CLI_MESSAGE = \&_cli_message;

# List of CLI messages
our %CLI_MESSAGE_FOR = (
    q{}           => "%s",
    BRANCH_LIST   => "%s at %s: %d branch(es) found for %s.\n",
    CHDIR_WCT     => "%s: working directory changed to top of working copy.\n",
    CF            => "Conflicts in: %s\n",
    MERGE_ACTUAL  => "-" x 74 . "actual\n%s" . "-" x 74 . "actual\n",
    MERGE_COMPARE => "Merge: %s\n c.f.: %s\n",
    MERGE_OK      => "Merge succeeded.\n",
    MERGE_DRYRUN  => "-" x 73 . "dry-run\n%s" . "-" x 73 . "dry-run\n",
    MERGE_REVS    => "Eligible merge(s) from %s: %s\n",
    OUT_DIR       => "Output directory: %s\n",
    PATCH_DONE    => "%s: patch generated.\n",
    PATCH_REV     => "Patch created for changeset %s\n",
    SEPARATOR     => q{-} x 80 . "\n",
    STATUS        => "%s: status of %s:\n%s\n",
);

# CLI abort and error messages
our %CLI_MESSAGE_FOR_ABORT = (
    FAIL => "%s: command failed.\n",
    NULL => "%s: command will result in no change.\n",
    USER => "%s: abort by user.\n",
);

# CLI abort and error messages
our %CLI_MESSAGE_FOR_ERROR = (
    CHDIR               => "%s: cannot change to directory.\n",
    CLI                 => "%s",
    CLI_HELP            => "Type 'fcm help %s' for usage.\n",
    CLI_MERGE_ARG1      => "Arg 1 must be the source in auto/custom mode.\n",
    CLI_MERGE_ARG2      => "Arg 2 must be the source in custom mode"
                           . " if --revision not set.\n",
    CLI_OPT_ARG         => "--%s: invalid argument [%s].\n",
    CLI_OPT_WITH_OPT    => "--%s: must be specified with --%s.\n",
    CLI_USAGE           => "incorrect value for the %s argument",
    DIFF_PROJECTS       => "%s (target) and %s (source) are not related.\n",
    INVALID_BRANCH      => "%s: not a valid URL of a standard FCM branch.\n",
    INVALID_PROJECT     => "%s: not a valid URL of a standard FCM project.\n",
    INVALID_TARGET      => "%s: not a valid working copy or URL.\n",
    INVALID_URL         => "%s: not a valid URL.\n",
    INVALID_WC          => "%s: not a valid working copy.\n",
    MERGE_REV_INVALID   => "%s: not a revision in the available merge list.\n",
    MERGE_SELF          => "%s: cannot be merged to its own working copy: %s.\n",
    MERGE_UNRELATED     => "%s: target and %s: source not directly related.\n",
    MERGE_UNSAFE        => "%s: source contains changes outside the target"
                           . " sub-directory. Please merge with a full tree.\n",
    MKPATH              => "%s: cannot create directory.\n",
    NOT_EXIST           => "%s: does not exist.\n",
    PARENT_NOT_EXIST    => "%s: parent %s no longer exists.\n",
    RMTREE              => "%s: cannot remove.\n",
    ST_CI_MESG_FILE     => "Attempt to add commit message file:\n%s",
    ST_CONFLICT         => "File(s) in conflicts:\n%s",
    ST_MISSING          => "File(s) missing:\n%s",
    ST_OOD              => "File(s) out of date:\n%s",
    SWITCH_UNSAFE       => "%s: merge template exists."
                           . " Please remove before retrying.\n",
    WC_INVALID_BRANCH   => "%s: not a working copy of a standard FCM branch.\n",
    WC_URL_NOT_EXIST    => "%s: working copy URL does not exists at HEAD.\n",
);

# List of CLI prompt messages
our %CLI_MESSAGE_FOR_PROMPT = (
    CF_OVERWRITE      => qq{%s: existing changes will be overwritten.\n}
                         . qq{ Do you wish to continue?},
    CI                => qq{Would you like to commit this change?},
    CI_BRANCH_SHARED  => qq{\n}
                         . qq{*** WARNING: YOU ARE COMMITTING TO A %s BRANCH.\n}
                         . qq{*** Please ensure that you have the}
                         . qq{ owner's permission.\n\n}
                         . qq{Would you like to commit this change?},
    CI_BRANCH_USER    => qq{\n}
                         . qq{*** WARNING: YOU ARE COMMITTING TO A BRANCH}
                         . qq{ NOT OWNED BY YOU.\n}
                         . qq{*** Please ensure that you have the}
                         . qq{ owner's permission.\n\n}
                         . qq{Would you like to commit this change?},
    CI_TRUNK          => qq{\n}
                         . qq{*** WARNING: YOU ARE COMMITTING TO THE TRUNK.\n}
                         . qq{*** Please ensure that your change conforms to}
                         . qq{ your project's working practices.\n\n}
                         . qq{Would you like to commit this change?},
    CONTINUE          => qq{%s: continue?},
    MERGE             => qq{Would you like to go ahead with the merge?},
    MERGE_REV         => qq{Enter a revision},
    MKPATCH_OVERWRITE => qq{%s: output location exists. OK to overwrite?},
    RUN_SVN_COMMAND   => qq{Would you like to run "svn %s"?},
);

# List of CLI warning messages
our %CLI_MESSAGE_FOR_WARNING = (
    BRANCH_SUBDIR   => "%s: is a sub-directory of a branch in a FCM project.\n",
    CF_BINARY       => "%s: ignoring binary file, please resolve manually.\n",
    INVALID_BRANCH  => $CLI_MESSAGE_FOR_ERROR{INVALID_BRANCH},
    ST_IN_TRAC_DIFF => "%s: local changes cannot be displayed in Trac.\n"
);

# CLI prompt handler and title prefix
our $CLI_PROMPT = \&_cli_prompt;
our $CLI_PROMPT_PREFIX = q{fcm };

# Event handlers
our %CLI_HANDLER_OF = (
    'WC_STATUS'      => \&_cli_handler_of_wc_status,
    'WC_STATUS_PATH' => \&_cli_handler_of_wc_status_path,
);

# Common patterns
our %PATTERN_OF = (
    # A CLI option
    CLI_OPT => qr{
        \A            (?# beginning)
        (--\w[\w-]*=) (?# capture 1, a long option label)
        (.*)          (?# capture 2, the value of the option)
        \z            (?# end)
    }xms,
    # A CLI revision option
    CLI_OPT_REV => qr{
        \A                      (?# beginning)
        (--revision(?:=|\z)|-r) (?# capture 1, --revision, --revision= or -r)
        (.*)                    (?# capture 2, trailing value)
        \z                      (?# end)
    }xms,
    # A CLI revision option range
    CLI_OPT_REV_RANGE => qr{
        \A                  (?# beginning)
        (                   (?# capture 1, begin)
            (?:\{[^\}]+\}+) (?# a date in curly braces)
            |               (?# or)
            [^:]+           (?# anything but a colon)
        )                   (?# capture 1, end)
        (?::(.*))?          (?# colon, and capture 2 til the end)
        \z                  (?# end)
    }xms,
    # A FCM branch path look-alike, should be configurable in the future
    FCM_BRANCH_PATH => qr{
        \A                            (?# beginning)
        /*                            (?# some slashes)
        (?:                           (?# group 1, begin)
            (?:trunk/*(?:@\d+)?\z)    (?# trunk at a revision)
            |                         (?# or)
            (?:trunk|branches|tags)/+ (?# trunk, branch or tags)
        )                             (?# group 1, end)
    }xms,
    # Last line of output from "svn status -u"
    ST_AGAINST_REV => qr{
        \A                           (?# beginning)
        Status\sagainst\srevision:.* (?# output of svn status -u)
        \z                           (?# end)
    }xms,
    # Extract path from "svn status"
    ST_PATH => qr{
        \A   (?# beginning)
        .{6} (?# 6 columns)
        \s+  (?# spaces)
        (.+) (?# capture 1, target path)
        \z   (?# end)
    }xms,
    # A legitimate "svn" revision
    SVN_REV => qr{
        \A                                      (?# beginning)
        (?:\d+|HEAD|BASE|COMMITTED|PREV|\{.+\}) (?# digit, reserved words, date)
        \z                                      (?# end)
    }ixms,
);

# Status matchers
our %ST_MATCHER_FOR = (
    CONFLICT => sub {substr($_[0], 0, 1) eq 'C' || substr($_[0], 6, 1) eq 'C'},
    MISSING  => sub {substr($_[0], 0, 1) eq '!'},
    MODIFIED => sub {substr($_[0], 0, 7) =~ qr{\S}xms},
    OOD      => sub {substr($_[0], 8, 1) eq '*'},
    UNKNOWN  => sub {substr($_[0], 0, 1) eq '?'},
);

# Set the FCM::Util object by FCM::System::CM.
our $UTIL;
sub set_util {
    $UTIL = shift();
}

# Set the commit message utility provided by FCM::System::CM.
our $COMMIT_MESSAGE_UTIL;
sub set_commit_message_util {
    $COMMIT_MESSAGE_UTIL = shift();
    FCM1::CmBranch::set_commit_message_util($COMMIT_MESSAGE_UTIL);
}

# Set the SVN utility provided by FCM::System::CM.
our $SVN;
sub set_svn_util {
    $SVN = shift();
    FCM1::CmUrl::set_svn_util($SVN);
    FCM1::CmBranch::set_svn_util($SVN);
}

# Returns the branch URL as an instance of FCM1::CmUrl.
sub _branch_url {
    my $arg = shift();
    my $url
        = $arg && is_url($arg) ? FCM1::CmUrl->new(URL => $arg)
        : $arg && is_wc($arg)  ? FCM1::CmUrl->new(URL => get_url_of_wc($arg))
        : !$arg && is_wc()     ? FCM1::CmUrl->new(URL => get_url_of_wc())
        :                        undef
        ;
    if (!$url) {
        return _cm_err(FCM1::Cm::Exception->INVALID_TARGET, $arg ? $arg : q{.});
    }
    $url;
}

# Branch delete.
sub cm_branch_delete {
    my ($option_ref, $arg) = @_;
    my $branch = cm_branch_info($option_ref, $arg);
    $branch->del(
        PASSWORD            => $option_ref->{password},
        NON_INTERACTIVE     => $option_ref->{'non-interactive'},
        SVN_NON_INTERACTIVE => $option_ref->{'svn-non-interactive'},
    );
    if (!$arg && $option_ref->{'switch'}) {
        cm_switch($option_ref, $branch->layout()->get_config()->{'dir-trunk'});
    }
}

# Branch diff.
sub cm_branch_diff {
    my ($option_ref, $target) = @_;
    local(%ENV) = %ENV;
    $ENV{FCM_GRAPHIC_DIFF} ||= $UTIL->external_cfg_get('graphic-diff');
    my @diff_cmd
        = $option_ref->{graphical}  ? (qw{
            --config-option config:working-copy:exclusive-locking-clients=
            --diff-cmd fcm_graphic_diff
        })
        : $option_ref->{'diff-cmd'} ? ('--diff-cmd', $option_ref->{'diff-cmd'})
        :                             ()
        ;
    if ($option_ref->{extensions}) {
        push(@diff_cmd, '--extensions', shellwords($option_ref->{extensions}));
    }

    # Target can be a URL/path, default to $PWD.
    $target ||= q{.};
    my $target_is_path = !is_url($target);

    # Get repository and branch information
    my $url = bless(_branch_url($target), 'FCM1::CmBranch');

    # Check that URL is a standard FCM branch
    if (!$url->is_branch()) {
        return _cm_err(FCM1::Cm::Exception->INVALID_BRANCH, $url->url_peg());
    }

    # Save and remove sub-directory part of the URL
    my $subdir = $url->subdir();
    $url->url_peg($url->branch_url_peg());

    # Check that $url exists
    if (!$url->url_exists()) {
        return _cm_err(FCM1::Cm::Exception->INVALID_URL, $url->url_peg());
    }

    # Compare current branch with its parent
    my $parent = FCM1::CmBranch->new(URL => $url->parent()->url());
    if ($url->pegrev()) {
      $parent->url_peg($parent->url() . '@' . $url->pegrev());
    }

    if (!$parent->url_exists()) {
        return _cm_err(
            FCM1::Cm::Exception->PARENT_NOT_EXIST, $url->url_peg(), $parent->url(),
        );
    }

    my $base = $parent->base_of_merge_from($url);

    # Ensure the correct diff (syntax) is displayed
    # Reinstate the sub-tree part into the URL
    if ($subdir) {
      $url->url_peg($url->branch_url() . '/' . $subdir . '@' . $url->pegrev());
      $base->url_peg($base->branch_url() . '/' . $subdir . '@' . $base->pegrev());
    }

    if ($option_ref->{trac} || $option_ref->{wiki}) {
        if ($target_is_path && _svn_status_get([$target])) {
            $CLI_MESSAGE->('ST_IN_TRAC_DIFF', $target);
        }

        # Trac wiki syntax
        my $wiki_syntax = 'diff:' . $base->path_peg() . '//' . $url->path_peg();

        if ($option_ref->{wiki}) {
            $CLI_MESSAGE->(q{}, "$wiki_syntax\n");
        }
        else { # if $option_ref->{trac}
            my $browser = $UTIL->external_cfg_get('browser');
            my $trac_url = FCM1::Keyword::get_browser_url($url->project_url());
            # FIXME: assuming that the browser URL uses the InterTrac syntax
            $trac_url =~ s{/intertrac/.*$}{/search?q=$wiki_syntax}xms;
            my %value_of = %{$UTIL->shell_simple([$browser, $trac_url])};
            if ($value_of{rc}) {
                return FCM::System::Exception->throw(
                    FCM::System::Exception->SHELL,
                    {command_list => [$browser, $trac_url], %value_of},
                    $value_of{e},
                );
            }
        }
    }
    else {
        $SVN->call(
            'diff', @diff_cmd,
            ($option_ref->{summarize} ? ('--summarize') : ()),
		    ($option_ref->{xml} ? ('--xml') : ()),
            '--old', $base->url_peg(),
            '--new', ($target_is_path ? $target : $url->url_peg()),
        );
    }
}

# Branch info.
sub cm_branch_info {
    my ($option_ref, $arg) = @_;
    my $url = _branch_url($arg);
    FCM1::Config->instance()->verbose($option_ref->{verbose} ? 1 : 0);
    my $branch = FCM1::CmBranch->new(URL => $url->url_peg());
    if (!$branch->branch()) {
        return _cm_err(FCM1::Cm::Exception->INVALID_BRANCH, $branch->url_peg());
    }
    if (!$branch->url_exists()) {
        return _cm_err(FCM1::Cm::Exception->NOT_EXIST, $branch->url_peg());
    }
    $branch->url_peg($branch->branch_url_peg());
    $option_ref->{'show-children'} ||= $option_ref->{'show-all'};
    $option_ref->{'show-other'   } ||= $option_ref->{'show-all'};
    $option_ref->{'show-siblings'} ||= $option_ref->{'show-all'};
    $branch->display_info(
        SHOW_CHILDREN => $option_ref->{'show-children'},
        SHOW_OTHER    => $option_ref->{'show-other'   },
        SHOW_SIBLINGS => $option_ref->{'show-siblings'},
    );
    $branch;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   &FCM1::Cm::cm_commit ();
#
# DESCRIPTION
#   This is a FCM wrapper to the "svn commit" command.
# ------------------------------------------------------------------------------

sub cm_commit {
  my ($option_ref, $path) = @_;
  $path ||= cwd();
  if (!-e $path) {
    return _cm_err(FCM1::Cm::Exception->NOT_EXIST, $path);
  }

  # Make sure we are in a working copy
  if (!is_wc($path)) {
    return _cm_err(FCM1::Cm::Exception->INVALID_WC, $path);
  }

  # Make sure we are at the top level of the working copy
  # (otherwise we might miss any template commit message)
  my $dir = $SVN->get_wc_root($path);

  if ($dir ne cwd ()) {
    chdir($dir) || return _cm_err(FCM1::Cm::Exception->CHDIR, $dir);
    $CLI_MESSAGE->('CHDIR_WCT', $dir);
  }

  # Get update status of working copy
  # Check working copy files are not in conflict, missing, or out of date
  my @status = _svn_status_get([], 1);
  if (!defined($option_ref->{'dry-run'})) {
    my %st_lines_of = (CONFLICT => [], MISSING => [], OOD => []);

    LINE:
    for my $line (@status) {
      for my $key (keys(%st_lines_of)) {
        if ($line && $ST_MATCHER_FOR{$key}->($line)) {
          push(@{$st_lines_of{$key}}, $line);
          next LINE;
        }
      }
      # Check that all files which have been added have the svn:executable
      # property set correctly (in case the developer adds a script before they
      # remember to set the execute bit)
      my ($file) = $line =~ qr/\AA.{8}\s*\d+\s+(.*)/msx;
      if (!$file || !-f $file) {
        next LINE;
      }
      my ($command, @arguments)
        = (-x $file && !-l $file) ? ('propset', '*') : ('propdel');
      $SVN->call($command, qw{-q svn:executable}, @arguments, $file);
    }

    # Abort commit if files are in conflict, missing, or out of date
    my @keys = grep {@{$st_lines_of{$_}}} keys(%st_lines_of);
    if (@keys) {
      for my $key (sort(@keys)) {
        my @lines = map {"$_\n"} @{$st_lines_of{$key}};
        $CLI_MESSAGE->('ST_' . $key, join(q{}, @lines));
      }
      return _cm_abort(FCM1::Cm::Abort->FAIL);
    }
  }

  # Read in any existing message
  my $commit_message_ctx = $COMMIT_MESSAGE_UTIL->load();

  # Execute "svn status" for a list of changed items
  @status = map {$_ . "\n"} grep {$_ =~ qr/\A[^\?]/msx} _svn_status_get();

  # Abort if there is no change in the working copy
  if (!@status) {
    return _cm_abort(FCM1::Cm::Abort->NULL);
  }

  # Abort if attempt to add commit message file
  my $ci_mesg_file_base = $COMMIT_MESSAGE_UTIL->path_base();
  my @bad_status = grep {$_ =~ qr{^A.*?\s$ci_mesg_file_base\n}m} @status;
  if (@bad_status) {
    for my $bad_status (@bad_status) {
      $CLI_MESSAGE->('ST_CI_MESG_FILE', $bad_status);
    }
    return _cm_abort(FCM1::Cm::Abort->FAIL);
  }

  # Get associated URL of current working copy
  my $layout = $SVN->get_layout($SVN->get_info()->[0]->{url});

  # Include URL, or project, branch and sub-directory info in @status
  unshift @status, "\n";

  if ($layout->get_branch()) {
    unshift(@status,
      map {sprintf("[%-7s: %s]\n", @{$_})} (
        ['Root'   , $layout->get_root()    ],
        ['Project', $layout->get_project() ],
        ['Branch' , $layout->get_branch()  ],
        ['Sub-dir', $layout->get_sub_tree()],
      ),
    );
  }
  else {
    unshift(@status,
      map {sprintf("[%s: %s]\n", @{$_})} (
        ['Root', $layout->get_root()],
        ['Path', $layout->get_path()],
      ),
    );
  }

  # Use a temporary file to store the final commit log message
  $commit_message_ctx->set_info_part(join(q{}, @status));
  $COMMIT_MESSAGE_UTIL->edit($commit_message_ctx);
  $COMMIT_MESSAGE_UTIL->notify($commit_message_ctx);

  # Check with the user to see if he/she wants to go ahead
  my $reply = 'n';
  if (!defined($option_ref->{'dry-run'})) {
    $reply = $CLI_PROMPT->('commit', (
        $layout->is_trunk()         ? ('CI_TRUNK')
      : !$layout->get_branch_owner()? ('CI')
      : $layout->is_owned_by_user() ? ('CI')
      : $layout->is_shared()        ? ('CI_BRANCH_SHARED',
                                       $layout->get_branch_owner())
      :                               ('CI_BRANCH_USER')
    ));
  }

  if ($reply eq 'y') {
    # Commit the change if user replies "y" for "yes"
    my $temp = $COMMIT_MESSAGE_UTIL->temp($commit_message_ctx);
    eval {$SVN->call(
      qw{commit -F}, "$temp",
      ($option_ref->{'svn-non-interactive'} ? '--non-interactive' : ()),
      (   defined($option_ref->{password})
          ? ('--password', $option_ref->{password}) : ()
      ),
    )};
    if ($@) {
      $COMMIT_MESSAGE_UTIL->save($commit_message_ctx);
      die($@);
    }

    # Remove commit message file
    unlink($COMMIT_MESSAGE_UTIL->path());

    # Update the working copy
    _svn_update();

  } else {
    $COMMIT_MESSAGE_UTIL->save($commit_message_ctx);
    if (!$option_ref->{'dry-run'}) {
      return _cm_abort();
    }
  }

  return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   &FCM1::Cm::cm_merge ();
#
# DESCRIPTION
#   This is a wrapper to "svn merge".
# ------------------------------------------------------------------------------

sub cm_merge {
  my ($option_ref, @args) = @_;
  # Find out the URL of the working copy
  if (!is_wc()) {
    return _cm_err(FCM1::Cm::Exception->INVALID_WC, '.');
  }
  my $wct = $SVN->get_wc_root();
  if ($wct ne cwd()) {
    chdir($wct) || return _cm_err(FCM1::Cm::Exception->CHDIR, $wct);
    $CLI_MESSAGE->('CHDIR_WCT', $wct);
  }
  my $target = FCM1::CmBranch->new(URL => get_url_of_wc($wct));
  if (!$target->url_exists()) {
    return _cm_err(FCM1::Cm::Exception->WC_URL_NOT_EXIST, '.');
  }

  # The target must be at the top of a branch
  # $subdir will be used later to determine whether the merge is allowed or not
  my $subdir = $target->subdir();
  if ($subdir) {
    $target->url_peg($target->branch_url_peg());
  }

  # Check for any local modifications
  # ----------------------------------------------------------------------------
  if (!$option_ref->{'dry-run'} && !$option_ref->{'non-interactive'}) {
    _svn_status_checker('merge', 'MODIFIED', $CLI_HANDLER_OF{WC_STATUS})->();
  }

  # Determine the SOURCE URL
  # ----------------------------------------------------------------------------
  my $source;

  if ($option_ref->{reverse}) {
    # Reverse merge, the SOURCE is the working copy URL
    $source = FCM1::CmBranch->new (URL => $target->url);

  } else {
    # Automatic/custom merge, argument 1 is the SOURCE of the merge
    my $source_url = shift (@args);
    if (!$source_url) {
      _cli_err('CLI_MERGE_ARG1');
    }

    $source = _cm_get_source($source_url, $target);
  }

  # Parse the revision option
  # ----------------------------------------------------------------------------
  my @revs
    = (grep {$option_ref->{$_}} qw{reverse custom}) && $option_ref->{revision}
    ? split(qr{:}xms, $option_ref->{revision})
    : ();

  # Determine the merge delta and the commit log message
  # ----------------------------------------------------------------------------
  my (@delta, $mesg, @logs);
  my $separator = '-' x 80 . "\n";

  if ($option_ref->{reverse}) {
    # Reverse merge
    # --------------------------------------------------------------------------
    if (@revs == 0) {
      my $last_commit_rev = $source->svninfo('FLAG' => 'commit:revision');
      @revs = ($last_commit_rev, $last_commit_rev - 1);
    }
    elsif (@revs == 1) {
      $revs[1] = ($revs[0] - 1);
    }
    else {
      @revs = sort {$b <=> $a} @revs;
    }

    # "Delta" of the "svn merge" command
    @delta = ('-r' . $revs[0] . ':' . $revs[1], $source->url_peg);

    # Template message
    $mesg = 'Reversed r' . $revs[0];
    if ($revs[1] < $revs[0] - 1) {
      $mesg .= ':' . $revs[1];
    }
    if ($source->path()) {
      $mesg .= ' of ' . $source->path();
    }
    $mesg .= "\n";

  } elsif ($option_ref->{custom}) {
    # Custom merge
    # --------------------------------------------------------------------------
    if (@revs) {
      # Revision specified
      # ------------------------------------------------------------------------
      # Only one revision N specified, use (N - 1):N as the delta
      unshift @revs, ($revs[0] - 1) if @revs == 1;
      $source->url_peg(
        $source->branch_url() . '/' . $subdir . '@' . $source->pegrev(),
      );
      $target->url_peg(
        $target->branch_url() . '/' . $subdir . '@' . $target->pegrev(),
      );

      # "Delta" of the "svn merge" command
      @delta = ('-r' . $revs[0] . ':' . $revs[1], $source->url_peg);

      # Template message
      $mesg = 'Custom merge into ' . $target->path . ': r' . $revs[1] .
              ' cf. r' . $revs[0] . ' of ' . $source->path_peg . "\n";

    } else {
      # Revision not specified
      # ------------------------------------------------------------------------
      # Get second source URL
      my $source2_url = shift (@args);
      if (!$source2_url) {
        _cli_err('CLI_MERGE_ARG2');
      }

      my $source2 = _cm_get_source($source2_url, $target);
      for my $item ($source, $source2, $target) {
        $item->url_peg($item->branch_url() . '/' . $subdir . '@' . $item->pegrev());
      }

      # "Delta" of the "svn merge" command
      @delta = ($source->url_peg, $source2->url_peg);

      # Template message
      $mesg = 'Custom merge into ' . $target->path . ': ' . $source->path_peg .
              ' cf. ' . $source2->path_peg . "\n";
    }

  } else {
    # Automatic merge
    # --------------------------------------------------------------------------
    # Check to ensure source branch is not the same as the target branch
    if (!$target->branch()) {
      return _cm_err(FCM1::Cm::Exception->WC_INVALID_BRANCH, $wct);
    }
    if ($source->branch() eq $target->branch()) {
      return _cm_err(FCM1::Cm::Exception->MERGE_SELF, $target->url_peg(), $wct);
    }

    # Only allow the merge if the source and target are "directly related"
    # --------------------------------------------------------------------------
    my $anc = $target->ancestor ($source);
    return _cm_err(
      FCM1::Cm::Exception->MERGE_UNRELATED, $target->url_peg(), $source->url_peg
    ) unless
      ($anc->url eq $target->url and $anc->url_peg eq $source->parent->url_peg)
      or
      ($anc->url eq $source->url and $anc->url_peg eq $target->parent->url_peg)
      or
      ($anc->url eq $source->parent->url and $anc->url eq $target->parent->url);

    # Check for available merges from the source
    # --------------------------------------------------------------------------
    my @revs = $target->avail_merge_from ($source, 1);

    if (@revs) {
      if ($option_ref->{verbose}) {
        # Verbose mode, print log messages of available merges
        $CLI_MESSAGE->('MERGE_REVS', $source->path_peg(), q{});
        for (@revs) {
          $CLI_MESSAGE->('SEPARATOR');
          $CLI_MESSAGE->(q{}, $source->display_svnlog($_));
        }
        $CLI_MESSAGE->('SEPARATOR');
      }
      else {
        # Normal mode, list revisions of available merges
        $CLI_MESSAGE->('MERGE_REVS', $source->path_peg(), join(q{ }, @revs));
      }

    } else {
      return _cm_abort(FCM1::Cm::Abort->NULL);
    }

    # If more than one merge available, prompt user to enter a revision number
    # to merge from, default to $revs [0]
    # --------------------------------------------------------------------------
    if ($option_ref->{'non-interactive'} || @revs == 1) {
      $source->url_peg($source->url() . '@' . $revs[0]);
    }
    else {
      my $reply = $CLI_PROMPT->(
        {type => q{}, default => $revs[0]}, 'merge', 'MERGE_REV',
      );
      if (!defined($reply)) {
        return _cm_abort();
      }
      # Expand revision keyword if necessary
      if ($reply) {
        $reply = (FCM1::Keyword::expand($target->project_url(), $reply))[1];
      }
      # Check that the reply is a number in the available merges list
      if (!grep {$_ eq $reply} @revs) {
        return _cm_err(FCM1::Cm::Exception->MERGE_REV_INVALID, $reply)
      }
      $source->url_peg($source->url() . '@' . $reply);
    }

    # If the working copy top is pointing to a sub-directory of a branch,
    # we need to check whether the merge will result in losing changes made in
    # other sub-directories of the source.
    if ($subdir and not $target->allow_subdir_merge_from ($source, $subdir)) {
      return _cm_err(FCM1::Cm::Exception->MERGE_UNSAFE, $source->url_peg());
    }

    # Calculate the base of the merge
    my $base = $target->base_of_merge_from ($source);

    # $source and $base must take into account the sub-directory
    my $source_full = FCM1::CmBranch->new (URL => $source->url_peg);
    my $base_full = FCM1::CmBranch->new (URL => $base->url_peg);

    if ($subdir) {
      $source_full->url_peg(
        $source_full->branch_url() . '/' . $subdir . '@' . $source_full->pegrev()
      );
      $base_full->url_peg(
        $base_full->branch_url() . '/' . $subdir . '@' . $base_full->pegrev()
      );
    }

    # Diagnostic
    $CLI_MESSAGE->('SEPARATOR'); 
    $CLI_MESSAGE->('MERGE_COMPARE', $source->path_peg(), $base->path_peg()); 
    # Delta of the "svn merge" command
    @delta = ($base_full->url_peg, $source_full->url_peg);

    # Template message
    $mesg = sprintf(
      "Merged into %s: %s cf. %s",
      $target->path(), $source->path_peg(), $base->path_peg(),
    );

    if (exists($option_ref->{'auto-log'})) {
      my $last_merge_from_source = ($target->last_merge_from($source))[1];
      if (!defined($last_merge_from_source)) {
        $last_merge_from_source = $target->ancestor($source);
      }
      my %log_entries = $source->svnlog(
        REV => [$last_merge_from_source->pegrev() + 1, $source->pegrev()],
      );
      @logs = sort {$b->{'revision'} <=> $a->{'revision'}} values(%log_entries);
    }
  }

  # Run "svn merge" in "--dry-run" mode to see the result
  # ----------------------------------------------------------------------------
  my $dry_run_output
    = $SVN->stdout(qw{svn merge --dry-run --non-interactive}, @delta);

  # Abort merge if it will result in no change
  if (!$dry_run_output) {
    return _cm_abort(FCM1::Cm::Abort->NULL);
  }

  # Report result of "svn merge --dry-run"
  if ($option_ref->{'dry-run'} || !$option_ref->{'non-interactive'}) {
    $CLI_MESSAGE->('MERGE_DRYRUN', $dry_run_output);
  }

  return if $option_ref->{'dry-run'};

  # Prompt the user to see if (s)he would like to go ahead
  # ----------------------------------------------------------------------------
  # Go ahead with merge only if user replies "y"
  if (
    !$option_ref->{'non-interactive'} && $CLI_PROMPT->('merge', 'MERGE') ne 'y'
  ) {
    return _cm_abort();
  }
  $SVN->call('cleanup');
  my $output = $SVN->stdout(qw{svn merge --non-interactive}, @delta);
  $CLI_MESSAGE->('MERGE_OK');
  if ($output ne $dry_run_output) {
    $CLI_MESSAGE->('MERGE_ACTUAL', $output);
  }

  # Prepare the commit log
  # ----------------------------------------------------------------------------
  my $commit_message_ctx = $COMMIT_MESSAGE_UTIL->load();
  my @auto_log = map {
    my $log_entry = $_;
    my @msg_list = (
      map  {q{> } . $_}
      grep {
            $_
        &&  $_ !~ qr{\AMerged\sinto\s\S+:\s(?:\S+)\scf\.\s(?:\S+)\z}msx
        &&  $_ !~ qr{\A(?:\#\d+(?:,\#\d+)*:\s)?Created\s\S+\sfrom\s\S+\.\z}msx
        &&  $_ !~ qr{\Ar\d+:\z}msx
        &&  $_ !~ qr{\A>\s.+\z}msx
      }
      split("\n", $log_entry->{'msg'})
    );
    @msg_list ? ('----', 'r' . $log_entry->{'revision'} . ':', @msg_list) : ();
  } @logs;
  my @messages = (
    $mesg,
    (@auto_log ? (@auto_log, '----'): ()),
    $commit_message_ctx->get_auto_part()
  );
  $commit_message_ctx->set_auto_part(join("\n", @messages));
  $COMMIT_MESSAGE_UTIL->save($commit_message_ctx);

  return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   &FCM1::Cm::cm_mkpatch ();
#
# DESCRIPTION
#   This is a FCM command to create a patching script from particular revisions
#   of a URL.
# ------------------------------------------------------------------------------

sub cm_mkpatch {
  my ($option_ref, $u, $outdir) = @_;
  # Process command line options and arguments
  my @exclude = $option_ref->{exclude} ? @{$option_ref->{exclude}} : ();
  my $organisation = $option_ref->{organisation};
  my $revision = $option_ref->{revision};

  # Excluded paths, convert glob into regular patterns
  @exclude = split (/:/, join (':', @exclude));
  for (@exclude) {
    s#\*#[^/]*#; # match any number of non-slash character
    s#\?#[^/]#;  # match a non-slash character
    s#/*$##;     # remove trailing slash
  }

  # Organisation prefix
  $organisation ||= 'original';

  # Make sure revision option is set correctly
  my @revs = $revision ? split (/:/, $revision) : ();
  @revs    = @revs [0, 1] if @revs > 2;

  if (!$u) {
    _cli_err('CLI_USAGE', 'URL');
  }

  my $url = FCM1::CmUrl->new (URL => $u);
  if (!$url->is_url()) {
    return _cm_err(FCM1::Cm::Exception->INVALID_URL, $u);
  }
  if (!$url->url_exists()) {
    return _cm_err(FCM1::Cm::Exception->NOT_EXIST, $u);
  }
  if (!$url->branch()) {
    $CLI_MESSAGE->('INVALID_BRANCH', $u);
  }
  elsif ($url->subdir()) {
    $CLI_MESSAGE->('BRANCH_SUBDIR', $u);
  }

  if (@revs) {
    # If HEAD revision is given, convert it into a number
    # --------------------------------------------------------------------------
    for my $rev (@revs) {
      $rev = $url->svninfo(FLAG => 'revision') if uc ($rev) eq 'HEAD';
    }

  } else {
    # If no revision is given, use the HEAD
    # --------------------------------------------------------------------------
    $revs[0] = $url->svninfo(FLAG => 'revision');
  }

  $revs[1] = $revs[0] if @revs == 1;

  # Check that output directory is set
  # ----------------------------------------------------------------------------
  $outdir = File::Spec->catfile (cwd (), 'fcm-mkpatch-out') if not $outdir;

  if (-e $outdir) {
    # Ask user to confirm removal of old output directory if it exists
    if ($CLI_PROMPT->('mkpatch', 'MKPATCH_OVERWRITE', $outdir) ne 'y') {
      return _cm_abort();
    }

    rmtree($outdir) || return _cm_err(FCM1::Cm::Exception->RMTREE, $outdir);
  }

  # (Re-)create output directory
  mkpath($outdir) || return _cm_err(FCM1::Cm::Exception->MKPATH, $outdir);
  $CLI_MESSAGE->('OUT_DIR', $outdir);

  # Get and process log of URL
  # ----------------------------------------------------------------------------
  my @script   = (); # main output script
  my %log      = $url->svnlog (REV => \@revs);
  my $url_path = $url->path;

  for my $rev (sort {$a <=> $b} keys %log) {
    # Look at the changed paths for each revision
    my $use_patch     = 1; # OK to use a patch file?
    my $only_modified = 1; # Change only contains modifications?
    my @paths;
    PATH: for my $path (sort keys %{ $log{$rev}{paths} }) {
      my $file = $path;

      # Skip paths outside of the branch
      next PATH unless $file =~ s#^$url_path/##;

      # Skip excluded paths
      for my $exclude (@exclude) {
        if ($file =~ m#^$exclude(?:/|$)#) {
          # Can't use a patch file if any files have been excluded
          $use_patch = 0;
          next PATH;
        }
      }

      # Can't use a patch file if any files have been added or replaced
      $use_patch = 0 if $log{$rev}{paths}{$path}{action} eq 'A' or
                        $log{$rev}{paths}{$path}{action} eq 'R';

      $only_modified = 0 unless $log{$rev}{paths}{$path}{action} eq 'M';

      push @paths, $path;
    }

    # If the change only contains modifications, make sure they aren't
    # just property changes
    if ($only_modified) {
      my @changedpaths;
      for my $path (@paths) {
        (my $file = $path) =~ s#^$url_path/*##;
        my @diff = $SVN->stdout(
          qw{svn diff --no-diff-deleted --summarize -c}, $rev,
          sprintf("%s/%s@%s", $url->url(), $file, $rev),
        );
        next unless $diff[-1] =~ /^[A-Z]/;
        push @changedpaths, $path;
      }
      @paths = @changedpaths;
    }

    next unless @paths;

    # Create the patch using "svn diff"
    my $patch = ();
    if ($use_patch) {
      $patch = $SVN->stdout(
          qw{svn diff --no-diff-deleted -c}, $rev, $url->url(),
      );
      if ($patch) {
        # Don't use the patch if it may contain subversion keywords or
        # any changes to PDF files or any changes to symbolic links or
        # any carriage returns in the middle of a line
        for (split(qr{\n}msx, $patch)) {
          if (/\$[a-zA-Z:]+ *\$/ or /^--- .+\.pdf\t/ or /^\+link / or /\r.+/) {
            $use_patch = 0;
            last;
          }
        }
      } else {
        $use_patch = 0;
      }
    }

    # Create a directory for this revision in the output directory
    my $outdir_rev = File::Spec->catfile ($outdir, $rev);
    mkpath($outdir_rev)
      || return _cm_err(FCM1::Cm::Exception->MKPATH, $outdir_rev);

    # Parse commit log message
    my @msg = split /\n/, $log{$rev}{msg};
    for (@msg) {
      # Re-instate line break
      $_ .= "\n";

      # Remove line if it matches a merge template
      $_ = '' if /^Reversed r\d+(?::\d+)? of \S+$/;
      $_ = '' if /^Custom merge into \S+:.+$/;
      $_ = '' if /^Merged into \S+: \S+ cf\. \S+$/;

      # Modify Trac ticket link
      s/(?:#|ticket:)(\d+)/${organisation}_ticket:$1/g;

      # Modify Trac changeset link
      s/(?:r|changeset:)(\d+)/${organisation}_changeset:$1/g;
      s/\[(\d+)\]/${organisation}_changeset:$1/g;
    }

    push @msg, '(' . $organisation . '_changeset:' . $rev . ')' . "\n";

    # Write commit log message in a file
    my $f_revlog = File::Spec->catfile ($outdir_rev, 'log-message');
    open FILE, '>', $f_revlog or die $f_revlog, ': cannot open (', $!, ')';
    print FILE @msg;
    close FILE or die $f_revlog, ': cannot close (', $!, ')';

    # Handle each changed path
    my $export_file   = 1;  # name for next exported file (gets incremented)
    my $patch_needed  = 0;  # is a patch file required?
    my @before_script = (); # patch script to run before patch applied
    my @after_script  = (); # patch script to run after patch applied
    my @copied_dirs   = (); # copied directories
    CHANGED: for my $path (@paths) {
      (my $file = $path) =~ s#^$url_path/*##;
      my $url_file = $url->url . '/' . $file . '@' . $rev;

      # Skip paths within copied directories
      for my $copied_dir (@copied_dirs) {
        next CHANGED if $file =~ m#^$copied_dir(?:/|$)#;
      }

      # Handle deleted files
      if ($log{$rev}{paths}{$path}{action} eq 'D') {
        push @after_script, 'svn delete "' . $file . '"';

      } else {
        # Skip property changes (if not done earlier)
        if (not $only_modified and $log{$rev}{paths}{$path}{action} eq 'M') {
          my @diff = $SVN->stdout(
            qw{svn diff --no-diff-deleted --summarize -c}, $rev, $url_file,
          );
          next CHANGED unless $diff[-1] =~ /^[A-Z]/;
        }

        # Determine if the file is a directory
        my $is_dir
          =     $log{$rev}{paths}{$path}{action} ne 'M'
            &&  $SVN->get_info($url_file)->[0]->{'kind'} eq 'dir';

        # Decide how to treat added files
        my $export_required = 0;
        if ($log{$rev}{paths}{$path}{action} eq 'A') {
          my $is_newfile = 0;
          # Determine if the file is copied
          if (exists $log{$rev}{paths}{$path}{'copyfrom-path'}) {
            if ($is_dir) {
              # A copied directory needs to be exported and added recursively
              push @after_script, 'svn add "' . $file . '"';
              $export_required = 1;
              push @copied_dirs, $file;
            } else {
              # History exists for this file
              my $copyfrom_path = $log{$rev}{paths}{$path}{'copyfrom-path'};
              my $copyfrom_rev  = $log{$rev}{paths}{$path}{'copyfrom-rev'};
              my $cp_url = FCM1::CmUrl->new (
                URL => $url->root . $copyfrom_path . '@' . $copyfrom_rev,
              );

              if ($copyfrom_path =~ s#^$url_path/*##) {
                # File is copied from a file under the specified URL
                # Check source exists
                $is_newfile = 1 unless $cp_url->url_exists ($rev - 1);
              } else {
                # File copied from outside of the specified URL
                $is_newfile = 1;

                # Check branches can be determined
                if ($url->branch and $cp_url->branch) {

                  # Follow its history, stop on copy
                  my %cp_log = $cp_url->svnlog (STOP_ON_COPY => 1);

                  # "First" revision of the copied file
                  my $cp_rev = (sort {$a <=> $b} keys %cp_log) [0];
                  my %attrib = %{ $cp_log{$cp_rev}{paths}{$cp_url->path} }
                    if $cp_log{$cp_rev}{paths}{$cp_url->path};

                  # Check whether the "first" revision is copied from elsewhere.
                  if (exists $attrib{'copyfrom-path'}) {
                    # If source exists in the specified URL, set up the copy
                    my $cp_cp_url = FCM1::CmUrl->new (
                      URL => $url->root . $attrib{'copyfrom-path'} . '@' .
                             $attrib{'copyfrom-rev'},
                    );
                    if ($cp_cp_url->subdir()) {
                      $cp_cp_url->url_peg(
                        $cp_cp_url->project_url()
                        . '/' . $url->branch()
                        . '/' . $cp_cp_url->subdir()
                        . '@' . $cp_cp_url->pegrev(),
                      );
                      if ($cp_cp_url->url_exists ($rev - 1)) {
                        ($copyfrom_path = $cp_cp_url->path) =~ s#^$url_path/*##;
                        # Check path is defined - if not it probably means the
                        # branch doesn't follow the FCM naming convention
                        $is_newfile = 0 if $copyfrom_path;
                      }
                    }
                  }

                  # Note: The logic above does not cover all cases. However, it
                  # should do the right thing for the most common case. Even
                  # where it gets it wrong the file contents should always be
                  # correct even if the file history is not.
                }
              }

              # Check whether file is copied from an excluded or copied path
              if (not $is_newfile) {
                for my $path (@exclude,@copied_dirs) {
                  if ($copyfrom_path =~ m#^$path(?:/|$)#) {
                    $is_newfile = 1;
                    last;
                  }
                }
              }

              # Check whether file is copied from a file which has been replaced
              if (not $is_newfile) {
                my $copyfrom_fullpath = $url->branch_path . "/" . $copyfrom_path;
                $is_newfile = 1 if ($log{$rev}{paths}{$copyfrom_fullpath}{action} and
                                    $log{$rev}{paths}{$copyfrom_fullpath}{action} eq 'R');
              }

              # Copy the file, if required
              push @before_script, 'svn copy ' . $copyfrom_path .  ' "' . $file . '"'
                if not $is_newfile;
            }

          } else {
            # History does not exist, must be a new file
            if ($is_dir) {
              # If it's a directory then create it and add it immediately
              # (in case it contains any copied files)
              push @before_script, 'mkdir "' . $file. '"';
              push @before_script, 'svn add "' . $file . '"';
            } else {
              $is_newfile = 1;
	    }
          }

          # Add the file, if required
          if ($is_newfile) {
            push @after_script, 'svn add "' . $file . '"';
          }
        }

        if ($is_dir and $log{$rev}{paths}{$path}{action} eq 'R') {
          # Subversion does not appear to support replacing a directory in a
          # single transaction from a working copy (other than as the result
          # of a merge). Therefore the delete of the old directory must be
          # done in advance as a separate commit.
          push @script, 'svn delete -m "Delete directory in preparation for' .
            ' replacing it (part of ' . $organisation . '_changeset:' . $rev .
            ')" $target/' . $file;
          push @script, 'svn update --non-interactive';
          # The replaced directory needs to be exported and added recursively
          push @after_script, 'svn add "' . $file . '"';
          $export_required = 1;
          push @copied_dirs, $file;
        }

        if (not $is_dir and $log{$rev}{paths}{$path}{action} ne 'A') {
          my ($was_symlink) = $SVN->stdout(
            qw{svn propget svn:special},
            sprintf("%s/%s@%d", $url->url(), $file, ($rev - 1)),
          );
          my ($is_symlink) = $SVN->stdout(
            qw{svn propget svn:special}, $url_file,
          );
          if ($was_symlink and not $is_symlink) {
            # A symbolic link has been changed to a normal file
            push @before_script, 'svn propdel -q svn:special "' . $file . '"';
            push @before_script, 'rm "' . $file . '"';
	  } elsif ($log{$rev}{paths}{$path}{action} eq 'R') {
            # Delete the old file and then add the new file
            push @before_script, 'svn delete "' . $file . '"';
            push @after_script, 'svn add "' . $file . '"';
          } elsif ($is_symlink and not $was_symlink) {
            # A normal file has been changed to a symbolic link
            push @after_script, 'svn propset -q svn:special \* "' . $file . '"';
          } elsif ($is_symlink and $was_symlink) {
            # If a symbolic link has been modified then remove the old
            # copy first to allow the copy to work
            push @before_script, 'rm "' . $file . '"';
          }
        }

        # Decide whether the file needs to be exported
        if (not $is_dir) {
          if (not $use_patch) {
            $export_required = 1;
          } else {
            # Export the file if it is binary
            my @file_diff = $SVN->stdout(
              qw{svn diff --no-diff-deleted -c}, $rev, $url_file,
            );
            for (@file_diff) {
              $export_required = 1 if /Cannot display: file marked as a binary type./;
            }
            # Only create a patch file if necessary
            $patch_needed = 1 if not $export_required;
          }
        }

        if ($export_required) {
          # Download the file using "svn export"
          my $export = File::Spec->catfile ($outdir_rev, $export_file);
          $SVN->call(qw{export -q -r}, $rev, $url_file, $export);

          # Copy the exported file into the file
          push @before_script,
               'cp -r ${fcm_patch_dir}/' . $export_file . ' "' . $file . '"';
          $export_file++;
        }
      }
    }

    # Write the patch file
    if ($patch_needed) {
      my $patchfile = File::Spec->catfile ($outdir_rev, 'patchfile');
      open FILE, '>', $patchfile
        or die $patchfile, ': cannot open (', $!, ')';
      print FILE $patch;
      close FILE or die $patchfile, ': cannot close (', $!, ')';
    }

    # Add line break to each line in @before_script and @after_script
    @before_script = map {($_ ? $_ . ' || exit 1' . "\n" : "\n")}
                     @before_script if (@before_script);
    @after_script  = map {($_ ? $_ . ' || exit 1' . "\n" : "\n")}
                     @after_script if (@after_script);

    # Write patch script to output
    my $out = File::Spec->catfile ($outdir_rev, 'apply-patch');
    open FILE, '>', $out or die $out, ': cannot open (', $!, ')';

    # Script header
    print FILE <<EOF;
#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# NAME
#   apply-patch
#
# DESCRIPTION
#   This script is generated automatically by the "fcm mkpatch" command. It
#   applies the patch to the current working directory which must be a working
#   copy of a valid project tree that can accept the import of the patches.
#
#   Patch created from $organisation URL: $u
#   Changeset: $rev
# ------------------------------------------------------------------------------

this=`basename \$0`
echo "\$this: Applying patch for changeset $rev."

# Location of the patch, base on the location of this script
cd `dirname \$0` || exit 1
fcm_patch_dir=\$PWD

# Change directory back to the working copy
cd \$OLDPWD || exit 1

# Check working copy does not have local changes
status=`svn status`
if [[ -n \$status ]]; then
  echo "\$this: working copy contains changes, abort." >&2
  exit 1
fi
if [[ -a "#commit_message#" ]]; then
  echo "\$this: existing commit message in "#commit_message#", abort." >&2
  exit 1
fi

# Apply the changes
patch_command=\${patch_command:-"patch --no-backup-if-mismatch -p0"}
EOF

    # Script content
    print FILE @before_script if @before_script;
    print FILE "\$patch_command <\${fcm_patch_dir}/patchfile || exit 1\n"
      if $patch_needed;
    print FILE @after_script  if @after_script;

    # Script footer
    print FILE <<EOF;

# Copy in the commit message
cp \${fcm_patch_dir}/log-message "#commit_message#"

echo "\$this: finished normally."
#EOF
EOF

    close FILE or die $out, ': cannot close (', $!, ')';

    # Add executable permission
    chmod 0755, $out;

    # Script to commit the change
    push @script, '${fcm_patches_dir}/' . $rev . '/apply-patch';
    push @script, 'svn commit -F "#commit_message#"';
    push @script, 'rm -f "#commit_message#"';
    push @script, 'svn update --non-interactive';
    push @script, '';

    $CLI_MESSAGE->('PATCH_REV', $rev);
  }

  # Write the main output script if necessary. Otherwise remove output directory
  # ----------------------------------------------------------------------------
  if (@script) {
    # Add line break to each line in @script
    @script = map {($_ ? $_ . ' || exit 1' . "\n" : "\n")} @script;

    # Write script to output
    my $out = File::Spec->catfile ($outdir, 'fcm-import-patch');
    open FILE, '>', $out or die $out, ': cannot open (', $!, ')';

    # Script header
    print FILE <<EOF;
#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# NAME
#   fcm-import-patch
#
# SYNOPSIS
#   fcm-import-patch TARGET
#
# DESCRIPTION
#   This script is generated automatically by the "fcm mkpatch" command, as are
#   the revision "patches" created in the same directory. The script imports the
#   patches into TARGET, which must either be a URL or a working copy of a valid
#   project tree that can accept the import of the patches.
#
#   Patch created from $organisation URL: $u
# ------------------------------------------------------------------------------

this=`basename \$0`

# Check argument
target=\$1

# First argument must be a URL or working copy
if [[ -z \$target ]]; then
  echo "\$this: the first argument must be a URL or a working copy, abort." >&2
  exit 1
fi

if [[ \$target == svn://*  || \$target == svn+ssh://* || \\
      \$target == http://* || \$target == https://*   || \\
      \$target == file://* ]]; then
  # A URL, checkout a working copy in a temporary location
  fcm_tmp_dir=`mktemp -d \${TMPDIR:=/tmp}/\$this.XXXXXX`
  fcm_working_copy=\$fcm_tmp_dir
  svn checkout -q \$target \$fcm_working_copy || exit 1
else
  fcm_working_copy=\$target
  target=`svn info \$fcm_working_copy | grep "^URL: " | sed 's/URL: //'` || exit 1
fi

# Location of the patches, base on the location of this script
cd `dirname \$0` || exit 1
fcm_patches_dir=\$PWD

# Change directory to the working copy
cd \$fcm_working_copy || exit 1

# Set the language to avoid encoding problems
if locale -a | grep -q en_GB\$; then
  export LANG=en_GB
fi

# Commands to apply patches
EOF

    # Script content
    print FILE @script;

    # Script footer
    print FILE <<EOF;
# Check working copy does not have local changes
status=`svn status`
if [[ -n \$status ]]; then
  echo "\$this: working copy still contains changes, abort." >&2
  exit 1
fi

# Remove temporary working copy, if necessary
if [[ -d \$fcm_tmp_dir && -w \$fcm_tmp_dir ]]; then
  rm -rf \$fcm_tmp_dir
fi

echo "\$this: finished normally."
#EOF
EOF

    close FILE or die $out, ': cannot close (', $!, ')';

    # Add executable permission
    chmod 0755, $out;

    # Diagnostic
    $CLI_MESSAGE->('PATCH_DONE', $outdir);

  } else {
    # Remove output directory
    rmtree $outdir or die $outdir, ': cannot remove';

    # Diagnostic
    return _cm_abort(FCM1::Cm::Abort->NULL);
  }

  return 1;
}

# ------------------------------------------------------------------------------
# CLI error.
sub _cli_err {
    my ($key, @args) = @_;
    my $message = sprintf($CLI_MESSAGE_FOR_ERROR{$key}, @args);
    die(FCM1::CLI::Exception->new({message => $message}));
}

# ------------------------------------------------------------------------------
# The default handler of the "WC_STATUS" event.
sub _cli_handler_of_wc_status {
    my ($name, $target_list_ref, $status_list_ref) = @_;
    $target_list_ref ||= [q{.}];
    if (@{$status_list_ref}) {
        $CLI_MESSAGE->(
            'STATUS',
            $name,
            q{"} . join(q{", "}, @{$target_list_ref}) . q{"},
            join("\n", @{$status_list_ref}),
        );
        if ($CLI_PROMPT->($name, 'CONTINUE', $name) ne 'y') {
            return _cm_abort();
        }
    }
    return @{$status_list_ref};
}

# ------------------------------------------------------------------------------
# The default handler of the "WC_STATUS_PATH" event.
sub _cli_handler_of_wc_status_path {
    my ($name, $target_list_ref, $status_list_ref) = @_;
    my $message
        = @{$status_list_ref} ? (join("\n", @{$status_list_ref}) . "\n") : q{};
    $CLI_MESSAGE->(q{}, $message);
    my @paths = map {chomp(); ($_ =~ $PATTERN_OF{ST_PATH})} @{$status_list_ref};
    my @paths_of_interest;
    while (my $path = shift(@paths)) {
        my %handler_of = (
            a => sub {push(@paths_of_interest, $path, @paths); @paths = ()},
            n => sub {},
            y => sub {push(@paths_of_interest, $path)},
        );
        my $reply = $CLI_PROMPT->(
            {type => 'yna'}, $name, 'RUN_SVN_COMMAND', "$name $path",
        );
        $handler_of{$reply}->();
    }
    return @paths_of_interest;
}

# ------------------------------------------------------------------------------
# Expands location keywords in a list.
sub _cli_keyword_expand_url {
    my ($arg_list_ref) = @_;
    ARG:
    for my $arg (@{$arg_list_ref}) {
        my ($label, $value) = ($arg =~ $PATTERN_OF{CLI_OPT});
        if (!$label) {
            ($label, $value) = (q{}, $arg);
        }
        if (!$value) {
            next ARG;
        }
        eval {
            $value = FCM1::Util::tidy_url(FCM1::Keyword::expand($value));
        };
        if ($@) {
            if ($value ne 'fcm:revision') {
                die($@);
            }
        }
        $arg = $label . $value;
    }
}

# ------------------------------------------------------------------------------
# Expands revision keywords in -r and --revision options in a list.
sub _cli_keyword_expand_rev {
    my ($arg_list_ref) = @_;
    my @targets;
    for my $arg (@{$arg_list_ref}) {
        if (-e $arg && is_wc($arg) || is_url($arg)) {
            push(@targets, $arg);
        }
    }
    if (!@targets) {
        push(@targets, get_url_of_wc());
    }
    if (!@targets) {
        return;
    }
    my @old_arg_list = @{$arg_list_ref};
    my @new_arg_list = ();
    ARG:
    while (defined(my $arg = shift(@old_arg_list))) {
        my ($key, $value) = $arg =~ $PATTERN_OF{CLI_OPT_REV};
        if (!$key) {
            push(@new_arg_list, $arg);
            next ARG;
        }
        push(@new_arg_list, '--revision');
        if (!$value) {
            $value = shift(@old_arg_list);
        }
        my @revs = grep {defined()} ($value =~ $PATTERN_OF{CLI_OPT_REV_RANGE});
        my ($url, @url_list) = @targets;
        for my $rev (@revs) {
            if ($rev !~ $PATTERN_OF{SVN_REV}) {
                $rev = (FCM1::Keyword::expand($url, $rev))[1];
            }
            if (@url_list) {
                $url = shift(@url_list);
            }
        }
        push(@new_arg_list, join(q{:}, @revs));
    }
    @{$arg_list_ref} = @new_arg_list;
}

# ------------------------------------------------------------------------------
# Prints a message.
sub _cli_message {
    my ($key, @args) = @_;
    for (
        [\*STDOUT, \%CLI_MESSAGE_FOR        , q{}          ],
        [\*STDERR, \%CLI_MESSAGE_FOR_WARNING, q{[WARNING] }],
        [\*STDERR, \%CLI_MESSAGE_FOR_ABORT  , q{[ABORT] }  ],
        [\*STDERR, \%CLI_MESSAGE_FOR_ERROR  , q{[ERROR] }  ],
    ) {
        my ($handle, $hash_ref, $prefix) = @{$_};
        if (exists($hash_ref->{$key})) {
            return printf({$handle} $prefix . $hash_ref->{$key}, @args);
        }
    }
}

# ------------------------------------------------------------------------------
# Wrapper for FCM1::Interactive::get_input.
sub _cli_prompt {
    my %option
        = (type => 'yn', default => 'n', (ref($_[0]) ? %{shift(@_)} : ()));
    my ($name, $key, @args) = @_;
    return FCM1::Interactive::get_input(
        title   => $CLI_PROMPT_PREFIX . $name,
        message => sprintf($CLI_MESSAGE_FOR_PROMPT{$key}, @args),
        %option,
    );
}

# ------------------------------------------------------------------------------
# Check missing status and delete.
sub cm_check_missing {
    my %option = %{shift()};
    my $checker
        = _svn_status_checker('delete', 'MISSING', $option{st_check_handler});
    my @paths = $checker->(\@_);
    if (@paths) {
        $SVN->call('delete', @paths);
    }
}

# ------------------------------------------------------------------------------
# Check unknown status and add.
sub cm_check_unknown {
    my %option = %{shift()};
    my $checker
        = _svn_status_checker('add', 'UNKNOWN', $option{st_check_handler});
    my @paths = $checker->(\@_);
    if (@paths) {
        $SVN->call('add', @paths);
    }
}

# ------------------------------------------------------------------------------
# FCM wrapper to SVN switch.
sub cm_switch {
    my %option = %{shift()};
    my ($source, $path) = @_;
    $path ||= cwd();
    if (!$source) {
        return _cm_err(FCM1::Cm::Exception->INVALID_TARGET, q{});
    }
    if (!-e $path) {
        return _cm_err(FCM1::Cm::Exception->NOT_EXIST, $path);
    }
    if (!is_wc($path)) {
        return _cm_err(FCM1::Cm::Exception->INVALID_WC, $path);
    }

    # Check for merge template in the commit log file in the working copy
    my $path_of_wc = $SVN->get_wc_root($path);
    my $commit_message_file = $COMMIT_MESSAGE_UTIL->path($path_of_wc);
    my $commit_message_ctx = $COMMIT_MESSAGE_UTIL->load($commit_message_file);
    if ($commit_message_ctx->get_auto_part()) {
        return _cm_err(
            FCM1::Cm::Exception->SWITCH_UNSAFE,
            ($path eq $path_of_wc
                ? File::Spec->abs2rel($commit_message_file)
                : $commit_message_file
            ),
        );
    }

    # Check for any local modifications
    if (defined($option{st_check_handler})) {
        _svn_status_checker('switch', 'MODIFIED', $option{st_check_handler})->(
            [$path_of_wc],
        );
    }

    my @targets = $path_of_wc eq cwd() ? () : ($path_of_wc);
    $SVN->call('cleanup', @targets);
    $SVN->call(
        'switch',
        '--non-interactive',
        ($option{revision} ? ('-r', $option{revision}) : ()),
        ($option{quiet}    ? '--quiet'                 : ()),
        _cm_get_source(
            $source,
            FCM1::CmBranch->new(URL => $path_of_wc),
        )->url_peg(),
        @targets,
    );
}

# ------------------------------------------------------------------------------
# FCM wrapper to SVN update.
sub cm_update {
    my %option = %{shift()};
    my @targets = @_;
    if (!@targets) {
        @targets = (cwd());
    }
    for my $target (@targets) {
        if (!-e $target) {
            return _cm_err(FCM1::Cm::Exception->NOT_EXIST, $target);
        }
        if (!is_wc($target)) {
            return _cm_err(FCM1::Cm::Exception->INVALID_WC, $target);
        }
        $target = $SVN->get_wc_root($target);
        if ($target eq cwd()) {
            $target = q{.};
        }
    }
    if (defined($option{st_check_handler})) {
        my ($matcher_keys_ref, $show_updates)
            = defined($option{revision}) ? (['MODIFIED'       ], undef)
            :                              (['MODIFIED', 'OOD'], 1    )
            ;
        my $matcher = sub {
            for my $key (@{$matcher_keys_ref}) {
                $ST_MATCHER_FOR{$key}->(@_) && return 1;
            }
        };
        _svn_status_checker(
            'update', $matcher, $option{st_check_handler}, $show_updates,
        )->(\@targets);
    }
    if ($option{revision} && $option{revision} !~ $PATTERN_OF{SVN_REV}) {
        $option{revision} = (
            FCM1::Keyword::expand(get_url_of_wc($targets[0]), $option{revision})
        )[1];
    }
    _svn_update(\@targets, \%option);
}

# ------------------------------------------------------------------------------
# Raises an abort exception.
sub _cm_abort {
    my ($code) = @_;
    $code ||= FCM1::Cm::Abort->USER;
    die(bless({code => $code, message => 'abort'}, 'FCM1::Cm::Abort'));
}

# ------------------------------------------------------------------------------
# Raises a failure.
sub _cm_err {
    my ($code, @targets) = @_;
    die(bless(
        {code => $code, message => "ERROR: $code", targets => \@targets},
        'FCM1::Cm::Exception',
    ));
}

# ------------------------------------------------------------------------------
# Return a corresponding FCM1::CmBranch instance for $source_url w.r.t. $target.
sub _cm_get_source {
    my ($source_url, $target) = @_;
    if (!$UTIL->uri_match($source_url)) {
        # Source not full URL, construct source URL based on target URL
        my ($path, $peg) = $source_url =~ qr{\A(.*?)(@[^@/]+)?\z}msx;
        my $project = $target->project_path();
        if (index($path, $project . '/') == 0) {
            # $path contains the full path under the repository root
            $path = substr($path, length($project));
        }
        my %layout_config = %{$target->layout()->get_config()};
        if (!grep {!defined($layout_config{"dir-$_"})} qw{trunk branch tag}) {
            # $path must be under the specified sub-directories for the trunk,
            # branches and tags
            my @dirs = map {$layout_config{"dir-$_"}} qw{trunk branch tag};
            my @paths = split(qr{/+}msx, $path);
            if (!@paths || !grep {$_ eq $paths[0]} @dirs) {
                $path = $layout_config{'dir-branch'} . '/' . $path;
            }
        }
        $peg ||= q{};
        $source_url = join('/', $target->project_url(), $path) . $peg;
    }
    my $source = FCM1::CmBranch->new(URL => $source_url);
    my $layout = eval {$source->layout()};
    if ($@) {
        $@ = undef;
        return _cm_err(FCM1::Cm::Exception->INVALID_URL, $source_url);
    }
    if (!$layout->get_branch()) {
        return _cm_err(FCM1::Cm::Exception->INVALID_BRANCH, $source_url);
    }
    $source->url_peg(
        $source->branch_url()
        . ($target->subdir() ? '/' . $target->subdir() : q{})
        . ('@' . $source->pegrev())
    );
    # Ensure that the source and target URLs are in the same project
    if ($source->project_url() ne $target->project_url()) {
        return _cm_err(
            FCM1::Cm::Exception->DIFF_PROJECTS,
            $target->url_peg(),
            $source->url_peg(),
        );
    }
    return $source;
}

# ------------------------------------------------------------------------------
# Returns the results of "svn status".
sub _svn_status_get {
    my ($targets_ref, $show_updates) = @_;
    my @targets = (defined($targets_ref) ? @{$targets_ref} : ());
    for my $target (@targets) {
        if ($target eq cwd()) {
            $target = q{.};
        }
    }
    my @options = ($show_updates ? qw{--show-updates} : ());
    $SVN->stdout(qw{svn status --ignore-externals}, @options, @targets);
}

# ------------------------------------------------------------------------------
# Returns a "svn status" checker.
sub _svn_status_checker {
    my ($name, $matcher, $handler, $show_updates) = @_;
    if (!ref($matcher)) {
        $matcher = $ST_MATCHER_FOR{$matcher};
    }
    my $P = $PATTERN_OF{ST_PATH};
    sub {
        my ($targets_ref) = @_;
        my @status = _svn_status_get($targets_ref, $show_updates);
        if ($show_updates) {
            @status = map {$_ =~ $PATTERN_OF{ST_AGAINST_REV} ? () : $_} @status;
        }
        my @status_of_interest = grep {$matcher->($_)} @status;
        # Note: for future expansion...
        #my @paths;
        #if (!$show_updates) {
        #    @paths = map {chomp(); $_} map {($_ =~ $P)} @status_of_interest;
        #}
        #defined($handler)
        #? $handler->($name, $targets_ref, \@status_of_interest, \@paths)
        #: @status_of_interest
        #;
        defined($handler)
        ? $handler->($name, $targets_ref, \@status_of_interest)
        : @status_of_interest
        ;
    };
}

# ------------------------------------------------------------------------------
# Runs "svn update".
sub _svn_update {
    my ($targets_ref, $option_hash_ref) = @_;
    my %option = (defined($option_hash_ref) ? %{$option_hash_ref} : ());
    my @targets = defined($targets_ref) ? @{$targets_ref} : ();
    $SVN->call('cleanup', @targets);
    $SVN->call(
        'update',
        '--non-interactive',
        ($option{revision} ? ('-r', $option{revision}) : ()),
        ($option{quiet}    ? '--quiet'                 : ()),
        @targets,
    );
}

# ------------------------------------------------------------------------------
# CLI exception.
package FCM1::CLI::Exception;
use base qw{FCM1::Exception};

# ------------------------------------------------------------------------------
# Abort exception.
package FCM1::Cm::Abort;
use base qw{FCM1::Exception};
use constant {FAIL => 'FAIL', NULL => 'NULL', USER => 'USER'};

sub get_code {
    return $_[0]->{code};
}

# ------------------------------------------------------------------------------
# Resource exception.
package FCM1::Cm::Exception;
our @ISA = qw{FCM1::Cm::Abort};
use constant {
    CHDIR             => 'CHDIR',
    DIFF_PROJECTS     => 'DIFF_PROJECTS',
    INVALID_BRANCH    => 'INVALID_BRANCH',
    INVALID_PROJECT   => 'INVALID_PROJECT',
    INVALID_TARGET    => 'INVALID_TARGET',
    INVALID_URL       => 'INVALID_URL',
    INVALID_WC        => 'INVALID_WC',
    MERGE_REV_INVALID => 'MERGE_REV_INVALID',
    MERGE_SELF        => 'MERGE_SELF',
    MERGE_UNRELATED   => 'MERGE_UNRELATED',
    MERGE_UNSAFE      => 'MERGE_UNSAFE',
    MKPATH            => 'MKPATH',
    NOT_EXIST         => 'NOT_EXIST',
    PARENT_NOT_EXIST  => 'PARENT_NOT_EXIST',
    RMTREE            => 'RMTREE',
    SWITCH_UNSAFE     => 'SWITCH_UNSAFE',
    WC_INVALID_BRANCH => 'WC_INVALID_BRANCH',
    WC_URL_NOT_EXIST  => 'WC_URL_NOT_EXIST',
};

sub get_targets {
    return @{$_[0]->{targets}};
}

1;
__END__

=pod

=head1 NAME

FCM1::Cm

=head1 SYNOPSIS

    use FCM1::Cm qw{cm_check_missing cm_check_unknown cm_switch cm_update};

    # Checks status for "missing" items and "svn delete" them
    $missing_st_handler = sub {
        my ($name, $targets_ref, $status_list_ref) = @_;
        # ...
        return @paths_of_interest;
    };
    cm_check_missing({st_check_handler => $missing_st_handler}, @targets);

    # Checks status for "unknown" items and "svn add" them
    $unknown_st_handler = sub {
        my ($name, $targets_ref, $status_list_ref) = @_;
        # ...
        return @paths_of_interest;
    };
    cm_check_unknown({st_check_handler => $unknown_st_handler}, @targets);

    # Sets up a status checker
    $st_check_handler = sub {
        my ($name, $targets_ref, $status_list_ref) = @_;
        # ...
    };
    # Switches a "working copy" at the "root" level to a new URL target
    cm_switch(
        {
            'non-interactive'  => $non_interactive_flag,
            'quiet'            => $quiet_flag,
            'revision'         => $revision,
            'st_check_handler' => $st_check_handler,
        },
        $target, $path_of_wc,
    );
    # Runs "svn update" on each working copy from their "root" level
    cm_update(
        {
            'non-interactive'  => $non_interactive_flag,
            'quiet'            => $quiet_flag,
            'revision'         => $revision,
            'st_check_handler' => $st_check_handler,
        },
        @targets,
    );

=head1 DESCRIPTION

Wraps the Subversion client and implements other FCM code management
functionalities.

=head1 FUNCTIONS

=over 4

=item cm_check_missing(\%option,@targets)

Use "svn status" to check for missing items in @targets. If @targets is an empty
list, the function adds the current working directory to it. Expects
$option{st_check_handler} to be a CODE reference. Calls
$option{st_check_handler} with ($name, $targets_ref, $status_list_ref) where
$name is "delete", $targets_ref is \@targets, and $status_list_ref is an
ARRAY reference to a list of "svn status" output with the "missing" status.
$option{st_check_handler} should return a list of interesting paths, which will
be scheduled for removal using "svn delete".

=item cm_check_unknown(\%option,@targets)

Similar to cm_check_missing(\%option,@targets) but checks for "unknown" items,
which will be scheduled for addition using "svn add".

=item cm_switch(\%option,$target,$path_of_wc)

Invokes "svn switch" at the root of a working copy specified by $path_of_wc (or
the current working directory if $path_of_wc is not specified).
$option{'non-interactive'}, $option{quiet}, $option{revision} determines the
options (of the same name) that are passed to "svn switch". If
$option{st_check_handler} is set, it should be a CODE reference, and will be
called with ('switch', [$path_of_wc], $status_list_ref), where $status_list_ref
is an ARRAY reference to the output returned by "svn status" on $path_of_wc.
This can be used for the application to display the working copy status to the
user before prompting him/her to continue. The return value of
$option{st_check_handler} is ignored.

=item cm_update(\%option,@targets)

Invokes "svn update" at the root of each working copy specified by @targets. If
@targets is an empty list, the function adds the current working directory to
it. $option{'non-interactive'}, $option{quiet}, $option{revision} determines the
options (of the same name) that are passed to "svn update". If
$option{st_check_handler} is set, it should be a CODE reference, and will be
called with ($name, $targets_ref, $status_list_ref), where $name is
'update', $targets_ref is \@targets and $status_list_ref is an ARRAY
reference to the output returned by "svn status -u" on the @targets. This can be
used for the application to display the working copy update status to the user
before prompting him/her to continue. The return value of
$option{st_check_handler} is ignored.

=back

=head1 DIAGNOSTICS

The following exceptions can be raised:

=over 4

=item FCM1::Cm::Abort

This exception @ISA L<FCM1::Exception|FCM1::Exception>. It is raised if a command
is aborted for some reason. The $e->get_code() method can be used to retrieve an
error code, which can be one of the following:

=over 4

=item $e->FAIL

The command aborts because of a failure.

=item $e->NULL

The command aborts because it will result in no change.

=item $e->USER

The command aborts because of an action by the user.

=back

=item FCM1::Cm::Exception

This exception @ISA L<FCM1::Abort|FCM1::Abort>. It is raised if a command fails
with a known reason. The $e->get_targets() method can be used to retrieve a list
of targets/resources associated with this exception. The $e->get_code() method
can be used to retrieve an error code, which can be one of the following:

=over 4

=item $e->CHDIR

Fails to change directory to a target.

=item $e->INVALID_BRANCH

A target is not a valid branch URL in the standard FCM project layout.

=item $e->INVALID_PROJECT

A target is not a valid project URL in the standard FCM project layout.

=item $e->INVALID_TARGET

A target is not a valid Subversion URL or working copy.

=item $e->INVALID_URL

A target is not a valid Subversion URL.

=item $e->INVALID_WC

A target is not a valid Subversion working copy.

=item $e->MERGE_REV_INVALID

An invalid revision (target element 0) is specified for a merge.

=item $e->MERGE_SELF

Attempt to merge a URL (target element 0) to its own working copy (target
element 1).

=item $e->MERGE_UNRELATED

The merge target (target element 0) is not directly related to the merge source
(target element 1).

=item $e->MERGE_UNSAFE

A merge source (target element 0) contains changes outside the target
sub-directory.

=item $e->MKPATH

Fail to create a directory (target element 0) recursively.

=item $e->NOT_EXIST

A target does not exist.

=item $e->PARENT_NOT_EXIST

The parent of the target no longer exists.

=item $e->RMTREE

Fail to remove a directory (target element 0) recursively.

=item $e->SWITCH_UNSAFE

A merge template exists in the commit message file (target element 0) in a
working copy target.

=item $e->WC_INVALID_BRANCH

The URL of the target working copy is not a valid branch URL in the standard FCM
project layout.

=item $e->WC_URL_NOT_EXIST

The URL of the target working copy no longer exists at the HEAD revision.

=back

=back

=head1 TO DO

Reintegrate with L<FCM1::CmUrl|FCM1::CmUrl> and L<FCM1::CmBranch|FCM1::CmBranch>,
but separate this module into the CLI part and the CM part. Expose the remaining
CM functions when this is done.

Use L<SVN::Client|SVN::Client> to interface with Subversion.

Move C<mkpatch> out of this module.

=head1 COPYRIGHT

Copyright (C) British Crown (Met Office) & Contributors..

=cut
opy already exists.

=item $e->WC_INVALID_BRANCH

The URL of the target working copy is not a valid branch URL in the standard FCM
project layout.

=item $e->WC_URL_NOT_EXIST

The URL of the target working copy no longer exists at the HEAD revision.

=back

=back

=head1 TO DO

Reintegrate with L<FCM1::CmUrl|FCM1::CmUrl> and L<FCM1::CmBranch|FCM1::CmBranch>,
but separate this module into the CLI part and the CM part. Expose the remaining
CM functions when this is done.

Use L<SVN::Client|SVN::Client> to interface with Subversion.

Move C<mkpatch> out of this module.

=head1 COPYRIGHT

Copyright (C) British Crown (Met Office) & Contributors..

=cut
$e->CHDIR

Fails to change directory to a target.

=item $e->INVALID_BRANCH

A target is not a valid branch URL in the standard FCM project layout.

=item $e->INVALID_PROJECT

A target is not a valid project URL in the standard FCM project layout.

=item $e->INVALID_TARGET

A target is not a valid Subversion URL or working copy.

=item $e->INVALID_URL

A target is not a valid Subversion URL.

=item $e->INVALID_WC

A target is not a valid Subversion working copy.

=item $e->MERGE_REV_INVALID

An invalid revision (target element 0) is specified for a merge.

=item $e->MERGE_SELF

Attempt to merge a URL (target element 0) to its own working copy (target
element 1).

=item $e->MERGE_UNRELATED

The merge target (target element 0) is not directly related to the merge source
(target element 1).

=item $e->MERGE_UNSAFE

A merge source (target element 0) contains changes outside the target
sub-directory.

=item $e->MKPATH

Fail to create a directory (target element 0) recursively.

=item $e->NOT_EXIST

A target does not exist.

=item $e->PARENT_NOT_EXIST

The parent of the target no longer exists.

=item $e->RMTREE

Fail to remove a directory (target element 0) recursively.

=item $e->SWITCH_UNSAFE

A merge template exists in the commit message file (target element 0) in a
working copy target.

=item $e->WC_INVALID_BRANCH

The URL of the target working copy is not a valid branch URL in the standard FCM
project layout.

=item $e->WC_URL_NOT_EXIST

The URL of the target working copy no longer exists at the HEAD revision.

=back

=back

=head1 TO DO

Migrate to FCM::System hierarchy.

Move C<mkpatch> out of this module.

=head1 COPYRIGHT

Copyright (C) British Crown (Met Office) & Contributors..

=cut
