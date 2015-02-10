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
# NAME
#   FCM1::CmUrl
#
# DESCRIPTION
#   This class contains methods for manipulating a Subversion URL in a standard
#   FCM project.
#
# ------------------------------------------------------------------------------

package FCM1::CmUrl;
use base qw{FCM1::Base};

use strict;
use warnings;

use FCM::System::Exception;
use FCM1::Keyword;
use FCM1::Util qw/svn_date/;

# Special branches
our %owner_keywords = (Share => 'shared', Config => 'config', Rel => 'release');

# Revision pattern
my $rev_pattern = '\d+|HEAD|BASE|COMMITTED|PREV|\{.+\}';

my $E = 'FCM::System::Exception';

# "svn log --xml" handlers.
# -> element node start tag handlers
my %SVN_LOG_ELEMENT_0_HANDLER_FOR = (
#   tag        => handler
    'logentry' => \&_svn_log_handle_element_0_logentry,
    'path'     => \&_svn_log_handle_element_0_path,
);
# -> text node (after a start tag) handlers
my %SVN_LOG_TEXT_HANDLER_FOR = (
#   tag    => handler
    'date' => \&_svn_log_handle_text_date,
    'path' => \&_svn_log_handle_text_path,
);

# Set the SVN utility provided by FCM::System::CM.
our $SVN;
sub set_svn_util {
    $SVN = shift();
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $cm_url = FCM1::CmUrl->new ([URL => $url,]);
#
# DESCRIPTION
#   This method constructs a new instance of the FCM1::CmUrl class.
#
# ARGUMENTS
#   URL - URL of a branch
# ------------------------------------------------------------------------------

sub new {
  my $this  = shift;
  my %args  = @_;
  my $class = ref $this || $this;

  my $self = FCM1::Base->new (%args);

  $self->{URL} = (exists $args{URL} ? $args{URL} : '');

  for (qw/LAYOUT BRANCH_LIST INFO LIST LOG LOG_RANGE RLIST/) {
    $self->{$_} = undef;
  }

  bless $self, $class;
  return $self;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $url = $cm_url->url_peg;
#   $cm_url->url_peg ($url);
#
# DESCRIPTION
#   This method returns/sets the current URL@PEG.
# ------------------------------------------------------------------------------

sub url_peg {
  my $self = shift;

  if (@_) {
    if (! $self->{URL} or $_[0] ne $self->{URL}) {
      # Re-set URL
      $self->{URL} = shift;

      # Re-set essential variables
      $self->{$_}  = undef for (qw/LAYOUT RLIST LIST INFO LOG LOG_RANGE/);
    }
  }

  return $self->{URL};
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $flag = $cm_url->is_url ();
#
# DESCRIPTION
#   Returns true if current url is a valid Subversion URL.
# ------------------------------------------------------------------------------

sub is_url {
  my $self = shift;

  # This should handle URL beginning with svn://, http:// and svn+ssh://
  return ($self->url_peg =~ qr{^[\w\+\-]+://}msx);
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $flag = $cm_url->url_exists ([$rev]);
#
# DESCRIPTION
#   Returns true if current url exists (at operative revision $rev) in a
#   Subversion repository.
# ------------------------------------------------------------------------------

sub url_exists {
  my ($self, $rev) = @_;

  my $url = eval {$self->svninfo(FLAG => 'url', REV => $rev)};
  if ($@) {
    $@ = undef;
  }

  defined($url);
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = $cm_url->svninfo([FLAG => $flag], [REV => $rev]);
#
# DESCRIPTION
#   Returns the value of $flag, where $flag is a field returned by "svn info
#   --xml". The original hierarchy below the entry element is delimited by a
#   colon in the name. (If $flag is not set, default to "url".) If REV is
#   specified, it will be used as the operative revision.
# ------------------------------------------------------------------------------

sub svninfo {
  my ($self, %args) = @_;
  if (!$self->is_url()) {
    return;
  }
  my $flag = exists($args{FLAG}) ? $args{FLAG} : 'url';
  my $rev  = exists($args{REV})  ? $args{REV}  : undef;
  $rev ||= ($self->pegrev ? $self->pegrev : 'HEAD');
  # Get "info" for the specified revision if necessary
  if (!exists($self->{INFO}{$rev})) {
    $self->{INFO}{$rev}
      = $SVN->get_info({'revision' => $rev}, $self->url_peg())->[0];
  }
  exists($self->{INFO}{$rev}{$flag}) ? $self->{INFO}{$rev}{$flag} : undef;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   %logs = $cm_url->svnlog (
#     [REV          => $rev,]
#     [REV          => \@revs,] # reference to a 2-element array
#     [STOP_ON_COPY => 1,]
#   );
#
# DESCRIPTION
#   Returns the logs for the current URL. If REV is a range of revisions or not
#   specified, return a hash where the keys are revision numbers and the values
#   are the entries (which are hash references). If a single REV is specified,
#   return the entry (a hash reference) at the specified REV. Each entry in the
#   returned list is a hash reference, with the following structure:
#
#   $entry = {
#     author => $author,              # the commit author
#     date   => $date,                # the commit date (in seconds since epoch)
#     msg    => $msg,                 # the log message
#     paths  => {                     # list of changed paths
#       $path1  => {                  # a changed path
#         copyfrom-path => $frompath, # copy-from-path
#         copyfrom-rev  => $fromrev,  # copy-from-revision
#         action        => $action,   # action status code
#       },
#       ...     => { ... },           # ... more changed paths ...
#     },
#   }
# ------------------------------------------------------------------------------

sub svnlog {
  my $self = shift;
  my %args = @_;

  my $stop_on_copy  = exists $args{STOP_ON_COPY} ? $args{STOP_ON_COPY} : undef;
  my $rev_arg       = exists $args{REV}          ? $args{REV}          : 0;

  my @revs;

  # Get revision options
  # ----------------------------------------------------------------------------
  if ($rev_arg) {
    if (ref ($rev_arg)) {
      # Revision option is an array, a range of revisions specified?
      ($revs [0], $revs [1]) = @$rev_arg;

    } else {
      # A single revision specified
      $revs [0] = $rev_arg;
    }

    # Expand 'HEAD' revision
    for my $rev (@revs) {
      next unless uc ($rev) eq 'HEAD';
      $rev = $self->svninfo(FLAG => 'revision', REV => 'HEAD');
    }

  } else {
    # No revision option specified, get log for all revisions
    $revs [0] = $self->svninfo(FLAG => 'revision');
    $revs [1] = 1;
  }

  $revs [1] = $revs [0] if not $revs [1];
  @revs     = sort {$b <=> $a} @revs;

  # Check whether a "svn log" run is necessary
  # ----------------------------------------------------------------------------
  my $need_update = ! ($revs [0] == $revs [1] and exists $self->{LOG}{$revs [0]});
  my @ranges      = @revs;
  if ($need_update and $self->{LOG_RANGE}) {
    my %log_range = %{ $self->{LOG_RANGE} };

    if ($stop_on_copy) {
      $ranges [1] = $log_range{UPPER} if $ranges [1] >= $log_range{LOWER_SOC};

    } else {
      $ranges [1] = $log_range{UPPER} if $ranges [1] >= $log_range{LOWER};
    }
  }

  $need_update = 0 if $ranges [0] < $ranges [1];

  if ($need_update) {
    my @entries = @{$SVN->get_log(
      {'revision' => join(':', @ranges), 'stop-on-copy' => $stop_on_copy},
      $self->url_peg(),
    )};
    for my $entry (@entries) {
      $self->{LOG}{$entry->{revision}} = $entry;
      $entry->{paths} = {map {($_->{path} => $_)} @{$entry->{paths}}};
    }

    # Update the range cache
    # --------------------------------------------------------------------------
    # Upper end of the range
    $self->{LOG_RANGE}{UPPER} = $ranges [0]
      if ! $self->{LOG_RANGE}{UPPER} or $ranges [0] > $self->{LOG_RANGE}{UPPER};

    # Lower end of the range, need to take into account the stop-on-copy option
    if ($stop_on_copy) {
      # Lower end of the range with stop-on-copy option
      $self->{LOG_RANGE}{LOWER_SOC} = $ranges [1]
        if ! $self->{LOG_RANGE}{LOWER_SOC} or
           $ranges [1] < $self->{LOG_RANGE}{LOWER_SOC};

      my $low = (sort {$a <=> $b} keys %{ $self->{LOG} }) [0];
      $self->{LOG_RANGE}{LOWER} = $low
        if ! $self->{LOG_RANGE}{LOWER} or $low < $self->{LOG_RANGE}{LOWER};

    } else {
      # Lower end of the range without the stop-on-copy option
      $self->{LOG_RANGE}{LOWER} = $ranges [1]
        if ! $self->{LOG_RANGE}{LOWER} or
           $ranges [1] < $self->{LOG_RANGE}{LOWER};

      $self->{LOG_RANGE}{LOWER_SOC} = $ranges [1]
        if ! $self->{LOG_RANGE}{LOWER_SOC} or
           $ranges [1] < $self->{LOG_RANGE}{LOWER_SOC};
    }
  }

  my %return = ();

  if (! $rev_arg or ref ($rev_arg)) {
    # REV is an array, return log entries if they are within range
    for my $rev (sort {$b <=> $a} keys %{ $self->{LOG} }) {
      next if $rev > $revs [0] or $revs [1] > $rev;

      $return{$rev} = $self->{LOG}{$rev};

      if ($stop_on_copy) {
        last if exists $self->{LOG}{$rev}{paths}{$self->branch_path} and
           $self->{LOG}{$rev}{paths}{$self->branch_path}{action} eq 'A';
      }
    }

  } else {
    # REV is a scalar, return log of the specified revision if it exists
    %return = %{ $self->{LOG}{$revs [0]} } if exists $self->{LOG}{$revs [0]};
  }

  return %return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = $cm_branch->display_svnlog ($rev, [$wiki]);
#
# DESCRIPTION
#   This method returns a string for displaying the log of the current branch
#   at a $rev. If $wiki is set, returns a string for displaying in a Trac wiki
#   table.  The value of $wiki should be the Subversion URL of a FCM project
#   associated with the intended Trac system.
# ------------------------------------------------------------------------------

sub display_svnlog {
  my ($self, $rev, $wiki) = @_;
  my $return = '';

  my %log = $self->svnlog (REV => $rev);

  if ($wiki) {
    # Output in Trac wiki format
    # --------------------------------------------------------------------------
    $return .= '|| ' . &svn_date ($log{date}) . ' || ' . $log{author} . ' || ';

    my $trac_url = FCM1::Keyword::get_browser_url($self->url);

    # Get list of tickets from log
    my @tickets;
    while ($log{msg} =~ /(?:(\w+):)?(?:#|ticket:)(\d+)/g) {
      push @tickets, [$1, $2];
    }
    @tickets = sort {
      if ($a->[0] and $b->[0]) {
        $a->[0] cmp $b->[0] or $a->[1] <=> $b->[1];

      } elsif ($a->[0]) {
        1;

      } else {
        $a->[1] <=> $b->[1];
      }
    } @tickets;

    if ($trac_url =~ qr{^$wiki(?:/*|$)}msx) {
      # URL is in the specified $wiki, use Trac link
      $return .= '[' . $rev . '] ||';

      for my $ticket (@tickets) {
        $return .= ' ';
        $return .= $ticket->[0] . ':' if $ticket->[0];
        $return .= '#' . $ticket->[1];
      }

      $return .= ' ||';

    } else {
      # URL is not in the specified $wiki, use full URL
      my $rev_url = $trac_url;
      $rev_url    =~ s{/intertrac/source:.*\z}{/intertrac/changeset:$rev}xms;
      $return    .= '[' . $rev_url . ' ' . $rev . '] ||';

      my $ticket_url = $trac_url;
      $ticket_url    =~ s{/intertrac/source:.*\z}{/intertrac/}xms;

      for my $ticket (@tickets) {
        $return .= ' [' . $ticket_url;
        $return .= $ticket->[0] . ':' if $ticket->[0];
        $return .= 'ticket:' . $ticket->[1] . ' ' . $ticket->[1] . ']';
      }

      $return .= ' ||';
    }

  } else {
    # Output in plain text format
    # --------------------------------------------------------------------------
    my @msg  = split /\n/, $log{msg};
    my $line = (@msg > 1 ? ' lines' : ' line');

    $return .= join (
      ' | ',
      ('r' . $rev, $log{author}, &svn_date ($log{date}), scalar (@msg) . $line),
    );
    $return .= "\n\n";
    $return .= $log{msg};
  }

  return $return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @list = $cm_url->branch_list ($rev);
#
# DESCRIPTION
#   The method returns a list of branches in the current project, assuming the
#   FCM naming convention. If $rev if specified, it returns the list of
#   branches at $rev.
# ------------------------------------------------------------------------------

sub branch_list {
  my ($self, $rev) = @_;
  if (!defined($self->project())) {
    return;
  }
  $rev = $self->svninfo(FLAG => 'revision', REV => $rev);
  if (!exists($self->{BRANCH_LIST}{$rev})) {
    my %layout_config = %{$self->layout()->get_config()};
    my $url0 = $self->project_url();
    my @d1_filters = ();
    if ($layout_config{'dir-branch'}) {
      $url0 .= '/' . $layout_config{'dir-branch'};
    }
    else {
      for my $key (qw{trunk tag}) {
        if ($layout_config{"dir-$key"}) {
          push(@d1_filters, $layout_config{"dir-$key"});
        }
      }
    }
    $self->{BRANCH_LIST}{$rev} = [$SVN->get_list(
      $url0 . '@' . $self->pegrev(),
      sub {
        my ($this_url, $this_name, $is_dir, $depth) = @_;
        if ($depth == 1 && @d1_filters && grep {$this_name eq $_} @d1_filters) {
          return (0, 0);
        }
        my $can_return = $depth >= $layout_config{'depth-branch'};
        ($can_return, ($is_dir && !$can_return));
      },
    )];
  }
  @{$self->{BRANCH_LIST}{$rev}};
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $layout = $self->layout();
#
# DESCRIPTION
#   Wrap FCM::System::CM::SVN->get_layout($url).
# ------------------------------------------------------------------------------

sub layout {
  my ($self) = @_;
  if (defined($self->{LAYOUT})) {
    return $self->{LAYOUT};
  }
  my $url = $self->url_peg();
  my $layout = $SVN->get_layout($url);
  $self->{URL} = $layout->get_url();
  $self->{LAYOUT} = $layout;

  $layout;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $url = $cm_url->url();
#   $url = $cm_url->pegrev();
#   $url = $cm_url->root();
#   $url = $cm_url->path();
#   $url = $cm_url->path_peg();
#
# DESCRIPTION
#   Return the relevant part of the current URL. The url method returns the URL
#   without the peg revision. The pegrev method returns the peg revision. The
#   root method returns the repository root. The path method returns the path in
#   URL under root. The path_peg method returns the path in URL with a peg
#   revision.
# ------------------------------------------------------------------------------

sub url {
  my $layout = $_[0]->layout();
  $layout->get_root() . $layout->get_path();
}

sub pegrev {
  $_[0]->layout()->get_peg_rev();
}

sub root {
  $_[0]->layout()->get_root();
}

sub path {
  $_[0]->layout()->get_path();
}

sub path_peg {
  my $layout = $_[0]->layout();
  $layout->get_path() . '@' . $layout->get_peg_rev();
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $url = $cm_url->project_url_peg();
#   $url = $cm_url->project_url();
#   $url = $cm_url->project_path();
#   $url = $cm_url->project();
#   $url = $cm_url->branch_url();
#   $url = $cm_url->branch_url_peg();
#   $url = $cm_url->branch_path();
#   $url = $cm_url->branch();
#   $url = $cm_url->subdir();
#
# DESCRIPTION
#   Return the relevant part of the current URL. The "project_*" methods return
#   the "project" part. The "branch_*" methods return the "branch" part.
#   The "*_url_peg" methods return the URL@PEG, and the "*_url" methods return
#   the URL without the peg revision. The "*_path" methods return the path in
#   the URL under the root.
# ------------------------------------------------------------------------------

sub project_url_peg {
  my $layout = $_[0]->layout();
  if (!defined($layout->get_project())) {
    return;
  }
  my $path = $layout->get_project() ? '/' . $layout->get_project() : q{};
  $layout->get_root() . $path . '@' . $layout->get_peg_rev();
}

sub project_url {
  my $layout = $_[0]->layout();
  if (!defined($layout->get_project())) {
    return;
  }
  my $path = $layout->get_project() ? '/' . $layout->get_project() : q{};
  $layout->get_root() . $path;
}

sub project_path {
  my $layout = $_[0]->layout();
  if (!defined($layout->get_project())) {
    return;
  }
  '/' . $layout->get_project();
}

sub project {
  $_[0]->layout()->get_project();
}

sub branch_url_peg {
  my $layout = $_[0]->layout();
  if (!$layout->get_branch()) {
    return;
  }
  $_[0]->project_url() . '/' . $layout->get_branch()
    . '@' . $layout->get_peg_rev();
}

sub branch_url {
  my $layout = $_[0]->layout();
  if (!$layout->get_branch()) {
    return;
  }
  $_[0]->project_url() . '/' . $layout->get_branch();
}

sub branch_path {
  my $layout = $_[0]->layout();
  if (!$layout->get_branch()) {
    return;
  }
  ($_[0]->project() ? '/' . $_[0]->project() : q{}) . '/' . $layout->get_branch();
}

sub branch {
  $_[0]->layout()->get_branch();
}

sub subdir {
  $_[0]->layout()->get_sub_tree();
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = $obj->branch_owner();
#
# DESCRIPTION
#   This method returns the owner of the branch (based on the default layout).
# ------------------------------------------------------------------------------

sub branch_owner {
  $_[0]->layout()->get_branch_owner();
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $flag = $cm_url->is_trunk();
#   $flag = $cm_url->is_branch();
#   $flag = $cm_url->is_tag();
#
# DESCRIPTION
#   Return true if the branch of current URL belongs to a given category (i.e.
#   trunk, branch or tag).
# ------------------------------------------------------------------------------

sub is_trunk {
  $_[0]->layout()->is_trunk();
}

sub is_branch {
  $_[0]->layout()->is_branch();
}

sub is_tag {
  $_[0]->layout()->is_tag();
}

# ------------------------------------------------------------------------------

1;
__END__
