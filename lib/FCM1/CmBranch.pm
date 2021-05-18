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
# NAME
#   FCM1::CmBranch
#
# DESCRIPTION
#   This class contains methods for manipulating a branch. It is a sub-class of
#   FCM1::CmUrl, and inherits all methods from that class.
#
# ------------------------------------------------------------------------------

package FCM1::CmBranch;
use base qw{FCM1::CmUrl};

use strict;
use warnings;

use FCM1::Config;
use FCM1::Interactive;
use FCM1::Keyword;
use FCM1::Util qw/e_report w_report svn_date/;

my @properties = (
  'CREATE_REV',  # revision at which the branch is created
  'DELETE_REV',  # revision at which the branch is deleted
  'PARENT',      # reference to parent branch FCM1::CmBranch
  'ANCESTOR',    # list of common ancestors with other branches
                 # key = URL, value = ancestor FCM1::CmBranch
  'LAST_MERGE',  # list of last merges from branches
                 # key = URL@REV, value = [TARGET, UPPER, LOWER]
  'AVAIL_MERGE', # list of available revisions for merging
                 # key = URL@REV, value = [REV ...]
  'CHILDREN',    # list of children of this branch
  'SIBLINGS',    # list of siblings of this branch
);

# Set the commit message utility provided by FCM::System::CM.
our $COMMIT_MESSAGE_UTIL;
sub set_commit_message_util {
    $COMMIT_MESSAGE_UTIL = shift();
}

# Set the SVN utility provided by FCM::System::CM.
our $SVN;
sub set_svn_util {
    $SVN = shift();
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $cm_branch = FCM1::CmBranch->new (URL => $url,);
#
# DESCRIPTION
#   This method constructs a new instance of the FCM1::CmBranch class.
#
# ARGUMENTS
#   URL    - URL of a branch
# ------------------------------------------------------------------------------

sub new {
  my $this  = shift;
  my %args  = @_;
  my $class = ref $this || $this;

  my $self = FCM1::CmUrl->new (%args);

  $self->{$_} = undef for (@properties);

  bless $self, $class;
  return $self;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $url = $cm_branch->url_peg;
#   $cm_branch->url_peg ($url);
#
# DESCRIPTION
#   This method returns/sets the current URL.
# ------------------------------------------------------------------------------

sub url_peg {
  my $self = shift;

  if (@_) {
    if (! $self->{URL} or $_[0] ne $self->{URL}) {
      # Re-set URL and other essential variables in the SUPER-class
      $self->SUPER::url_peg (@_);

      # Re-set essential variables
      $self->{$_} = undef for (@properties);
    }
  }

  return $self->{URL};
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rev = $cm_branch->create_rev;
#
# DESCRIPTION
#   This method returns the revision at which the branch was created.
# ------------------------------------------------------------------------------

sub create_rev {
  my $self = shift;

  if (not $self->{CREATE_REV}) {
    return unless $self->url_exists ($self->pegrev);

    # Use "svn log" to find out the first revision of the branch
    my %log = $self->svnlog (STOP_ON_COPY => 1);

    # Look at log in ascending order
    my $rev   = (sort {$a <=> $b} keys %log) [0];
    my $paths = $log{$rev}{paths};

    # Get revision when URL is first added to the repository
    if (exists $paths->{$self->branch_path}) {
      $self->{CREATE_REV} = $rev if $paths->{$self->branch_path}{action} eq 'A';
    }
  }

  return $self->{CREATE_REV};
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $parent = $cm_branch->parent;
#
# DESCRIPTION
#   This method returns the parent (a FCM1::CmBranch object) of the current
#   branch.
# ------------------------------------------------------------------------------

sub parent {
  my $self = shift;

  if (not $self->{PARENT}) {
    # Use the log to find out the parent revision
    my %log = $self->svnlog (REV => $self->create_rev);

    if (exists $log{paths}{$self->branch_path}) {
      my $path = $log{paths}{$self->branch_path};

      if ($path->{action} eq 'A') {
        if (exists $path->{'copyfrom-path'}) {
          # Current branch is copied from somewhere, set the source as the parent
          my $url = $self->root .  $path->{'copyfrom-path'};
          my $rev = $path->{'copyfrom-rev'};
          $self->{PARENT} = FCM1::CmBranch->new (URL => $url . '@' . $rev);

        } else {
          # Current branch is not copied from somewhere
          $self->{PARENT} = $self;
        }
      }
    }
  }

  return $self->{PARENT};
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rev = $cm_branch->delete_rev;
#
# DESCRIPTION
#   This method returns the revision at which the branch was deleted.
# ------------------------------------------------------------------------------

sub delete_rev {
  my $self = shift;

  if (not $self->{DELETE_REV}) {
    return if $self->url_exists ('HEAD');

    # Container of the current URL
    (my $dir_url = $self->branch_url) =~ s#/+[^/]+/*$##;

    # Use "svn log" on the container between a revision where the branch exists
    # and the HEAD
    my $dir = FCM1::CmUrl->new (URL => $dir_url);
    my %log = $dir->svnlog (
      REV => ['HEAD', ($self->pegrev ? $self->pegrev : $self->create_rev)],
    );

    # Go through the log to see when branch no longer exists
    for my $rev (sort {$a <=> $b} keys %log) {
      next unless exists $log{$rev}{paths}{$self->branch_path} and
                  $log{$rev}{paths}{$self->branch_path}{action} eq 'D';

      $self->{DELETE_REV} = $rev;
      last;
    }
  }

  return $self->{DELETE_REV};
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $flag = $cm_branch->is_child_of ($branch);
#
# DESCRIPTION
#   This method returns true if the current branch is a child of $branch.
# ------------------------------------------------------------------------------

sub is_child_of {
  my ($self, $branch) = @_;
  !$self->is_trunk()
    && $self->parent()->url() eq $branch->url()
    && (!$branch->is_branch() || $self->create_rev() >= $branch->create_rev());
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $flag = $cm_branch->is_sibling_of ($branch);
#
# DESCRIPTION
#   This method returns true if the current branch is a sibling of $branch.
# ------------------------------------------------------------------------------

sub is_sibling_of {
  my ($self, $branch) = @_;

  # The trunk cannot be a sibling branch
  return if $branch->is_trunk;

  return if $self->parent->url ne $branch->parent->url;

  # If the parent is a branch, ensure they are actually the same branch
  return if $branch->parent->is_branch and
            $self->parent->create_rev != $branch->parent->create_rev;

  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $self->_get_relatives ($relation);
#
# DESCRIPTION
#   This method sets the $self->{$relation} variable by inspecting the list of
#   branches at the current revision of the current branch. $relation can be
#   either "CHILDREN" or "SIBLINGS".
# ------------------------------------------------------------------------------

sub _get_relatives {
  my ($self, $relation) = @_;

  $self->{$relation} = [];

  # If we are searching for CHILDREN, get list of SIBLINGS, and vice versa
  my $other = ($relation eq 'CHILDREN' ? 'SIBLINGS' : 'CHILDREN');
  my %other_list;
  if ($self->{$other}) {
    %other_list = map {$_->url(), 1} @{$self->{$other}};
  }

  my @url_peg_list = $self->branch_list();
  URL:
  for my $url_peg (@url_peg_list) {
    my ($url, $peg) = $SVN->split_by_peg($url_peg);
    # Ignore URL of current branch and its parent
    if ( $url eq $self->url()
         # Ignore parent
      || $self->is_branch() && $url eq $self->parent()->url()
         # Ignore the other type of relatives
      || exists($other_list{$url})
    ) {
      next URL;
    }

    my $branch = FCM1::CmBranch->new(URL => $url_peg);

    # Test whether $branch is a relative we are looking for
    my $can_return = $relation eq 'CHILDREN'
      ? $branch->is_child_of($self) : $branch->is_sibling_of($self);
    if ($can_return) {
      push(@{$self->{$relation}}, $branch);
    }
  }

  return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @children = $cm_branch->children;
#
# DESCRIPTION
#   This method returns a list of children (FCM1::CmBranch objects) of the
#   current branch that exists in the current revision.
# ------------------------------------------------------------------------------

sub children {
  my $self = shift;

  $self->_get_relatives ('CHILDREN') if not $self->{CHILDREN};

  return @{ $self->{CHILDREN} };
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @siblings = $cm_branch->siblings;
#
# DESCRIPTION
#   This method returns a list of siblings (FCM1::CmBranch objects) of the
#   current branch that exists in the current revision.
# ------------------------------------------------------------------------------

sub siblings {
  my $self = shift;

  $self->_get_relatives ('SIBLINGS') if not $self->{SIBLINGS};

  return @{ $self->{SIBLINGS} };
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $ancestor = $cm_branch->ancestor ($branch);
#
# DESCRIPTION
#   This method returns the common ancestor (a FCM1::CmBranch object) of a
#   specified $branch and the current branch. The argument $branch must be a
#   FCM1::CmBranch object. Both the current branch and $branch are assumed to be
#   in the same project.
# ------------------------------------------------------------------------------

sub ancestor {
  my ($self, $branch) = @_;

  if (not exists $self->{ANCESTOR}{$branch->url_peg}) {
    if ($self->url_peg eq $branch->url_peg) {
      $self->{ANCESTOR}{$branch->url_peg} = $self;

    } else {
      # Get family tree of current branch, from trunk to current branch
      my @this_family = ($self);
      while (not $this_family [0]->is_trunk) {
        unshift @this_family, $this_family [0]->parent;
      }

      # Get family tree of $branch, from trunk to $branch
      my @that_family = ($branch);
      while (not $that_family [0]->is_trunk) {
        unshift @that_family, $that_family [0]->parent;
      }

      # Find common ancestor from list of parents
      my $ancestor = undef;

      while (not $ancestor) {
        # $this and $that should both start as some revisions on the trunk.
        # Walk down a generation each time it loops around.
        my $this = shift @this_family;
        my $that = shift @that_family;

        if ($this->url eq $that->url) {
          if ($this->is_trunk or $this->create_rev eq $that->create_rev) {
            # $this and $that are the same branch
            if (@this_family and @that_family) {
              # More generations in both branches, try comparing the next
              # generations.
              next;

            } else {
              # End of lineage in one of the branches, ancestor is at the lower
              # revision of the current URL.
              if ($this->pegrev and $that->pegrev) {
                $ancestor = $this->pegrev < $that->pegrev ? $this : $that;

              } else {
                $ancestor = $this->pegrev ? $this : $that;
              }
            }

          } else {
            # Despite the same URL, $this and $that are different branches as
            # they are created at different revisions. The ancestor must be the
            # parent with the lower revision. (This should not occur at the
            # start.)
            $ancestor = $this->parent->pegrev < $that->parent->pegrev
                        ? $this->parent : $that->parent;
          }

        } else {
          # Different URLs, ancestor must be the parent with the lower revision.
          # (This should not occur at the start.)
          $ancestor = $this->parent->pegrev < $that->parent->pegrev
                      ? $this->parent : $that->parent;
        }
      }

      $self->{ANCESTOR}{$branch->url_peg} = $ancestor;
    }
  }

  return $self->{ANCESTOR}{$branch->url_peg};
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   ($target, $upper, $lower) = $cm_branch->last_merge_from (
#     $branch, $stop_on_copy,
#   );
#
# DESCRIPTION
#   This method returns a 3-element list with information of the last merge
#   into the current branch from a specified $branch. The first element in the
#   list $target (a FCM1::CmBranch object) is the target at which the merge was
#   performed. (This can be the current branch or a parent branch up to the
#   common ancestor with the specified $branch.) The second and third elements,
#   $upper and $lower, (both FCM1::CmBranch objects), are the upper and lower
#   ends of the source delta. If there is no merge from $branch into the
#   current branch from their common ancestor to the current revision, this
#   method will return an empty list. If $stop_on_copy is specified, it ignores
#   merges from parents of $branch, and merges into parents of the current
#   branch.
# ------------------------------------------------------------------------------

sub last_merge_from {
  my ($self, $branch, $stop_on_copy) = @_;

  if (not exists $self->{LAST_MERGE}{$branch->url_peg}) {
    # Get "log" of current branch down to the common ancestor
    my %log = $self->svnlog (
      REV => [
       ($self->pegrev ? $self->pegrev : 'HEAD'),
       $self->ancestor ($branch)->pegrev,
      ],

      STOP_ON_COPY => $stop_on_copy,
    );

    my $cr = $self;

    # Go down the revision log, checking for merge template messages
    REV: for my $rev (sort {$b <=> $a} keys %log) {
      # Loop each line of the log message at each revision
      my @msg = split /\n/, $log{$rev}{msg};

      # Also consider merges into parents of current branch
      $cr = $cr->parent if ($cr->is_branch and $rev < $cr->create_rev);

      for (@msg) {
        # Ignore unless log message matches a merge template
        next unless /Merged into \S+: (\S+) cf\. (\S+)/;

        # Upper $1 and lower $2 ends of the source delta
        my $u_path = $1;
        my $l_path = $2;

        # Add the root directory to the paths if necessary
        $u_path = '/' . $u_path if substr ($u_path, 0, 1) ne '/';
        $l_path = '/' . $l_path if substr ($l_path, 0, 1) ne '/';

        # Only consider merges with specified branch (and its parent)
        (my $path = $u_path) =~ s/@(\d+)$//;
        my $u_rev = $1;

        my $br = $branch;
        $br    = $br->parent while (
          $br->is_branch and $u_rev < $br->create_rev and not $stop_on_copy
        );

        next unless $br->branch_path eq $path;

        # If $br is a parent of branch, ignore those merges with the parent
        # above the branch point of the current branch
        next if $br->pegrev and $br->pegrev < $u_rev;

        # Set the return values
        $self->{LAST_MERGE}{$branch->url_peg} = [
          FCM1::CmBranch->new (URL => $cr->url . '@' . $rev), # target
          FCM1::CmBranch->new (URL => $self->root . $u_path), # delta upper
          FCM1::CmBranch->new (URL => $self->root . $l_path), # delta lower
        ];

        last REV;
      }
    }
  }

  return (exists $self->{LAST_MERGE}{$branch->url_peg}
          ? @{ $self->{LAST_MERGE}{$branch->url_peg} } : ());
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @revs = $cm_branch->avail_merge_from ($branch[, $stop_on_copy]);
#
# DESCRIPTION
#   This method returns a list of revisions of a specified $branch, which are
#   available for merging into the current branch. If $stop_on_copy is
#   specified, it will not list available merges from the parents of $branch.
# ------------------------------------------------------------------------------

sub avail_merge_from {
  my ($self, $branch, $stop_on_copy) = @_;

  if (not exists $self->{AVAIL_MERGE}{$branch->url_peg}) {
    # Find out the revision of the upper delta at the last merge from $branch
    # If no merge is found, use revision of common ancestor with $branch
    my @last_merge = $self->last_merge_from ($branch);
    my $rev        = $self->ancestor ($branch)->pegrev;
    $rev           = $last_merge [1]->pegrev
      if @last_merge and $last_merge [1]->pegrev > $rev;

    # Get the "log" of the $branch down to $rev
    my %log = $branch->svnlog (
      REV          => [($branch->pegrev ? $branch->pegrev : 'HEAD'), $rev],
      STOP_ON_COPY => $stop_on_copy,
    );

    # No need to include $rev itself, as it has already been merged
    delete $log{$rev};

    # No need to include the branch create revision
    delete $log{$branch->create_rev}
      if $branch->is_branch and exists $log{$branch->create_rev};

    if (keys %log) {
      # Check whether there is a latest merge from $self into $branch, if so,
      # all revisions of $branch below that merge should become unavailable
      my @last_merge_into = $branch->last_merge_from ($self);

      if (@last_merge_into) {
        for my $rev (keys %log) {
          delete $log{$rev} if $rev < $last_merge_into [0]->pegrev;
        }
      }
    }

    # Available merges include all revisions above the branch creation revision
    # or the revision of the last merge
    $self->{AVAIL_MERGE}{$branch->url_peg} = [sort {$b <=> $a} keys %log];
  }

  return @{ $self->{AVAIL_MERGE}{$branch->url_peg} };
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $lower = $cm_branch->base_of_merge_from ($branch);
#
# DESCRIPTION
#   This method returns the lower delta (a FCM1::CmBranch object) for the next
#   merge from $branch.
# ------------------------------------------------------------------------------

sub base_of_merge_from {
  my ($self, $branch) = @_;

  # Base is the ancestor if there is no merge between $self and $branch
  my $return = $self->ancestor ($branch);

  # Get configuration for the last merge from $branch to $self
  my @merge_from = $self->last_merge_from ($branch);

  # Use the upper delta of the last merge from $branch, as all revisions below
  # that have already been merged into the $self
  $return = $merge_from [1]
    if @merge_from and $merge_from [1]->pegrev > $return->pegrev;

  # Get configuration for the last merge from $self to $branch
  my @merge_into = $branch->last_merge_from ($self);

  # Use the upper delta of the last merge from $self, as the current revision
  # of $branch already contains changes of $self up to the peg revision of the
  # upper delta
  $return = $merge_into [1]
    if @merge_into and $merge_into [0]->pegrev > $return->pegrev;

  return $return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $flag = $cm_branch->allow_subdir_merge_from ($branch, $subdir);
#
# DESCRIPTION
#   This method returns true if a merge from the sub-directory $subdir in
#   $branch  is allowed - i.e. it does not result in losing changes made in
#   $branch outside of $subdir.
# ------------------------------------------------------------------------------

sub allow_subdir_merge_from {
  my ($self, $branch, $subdir) = @_;

  # Get revision at last merge from $branch or ancestor
  my @merge_from = $self->last_merge_from ($branch);
  my $last       = @merge_from ? $merge_from [1] : $self->ancestor ($branch);
  my $rev        = $last->pegrev;

  my $return = 1;
  if ($branch->pegrev > $rev) {
    # Use "svn diff --summarize" to work out what's changed between last
    # merge/ancestor and current revision
    my $range = $branch->pegrev . ':' . $rev;
    my @out = $SVN->stdout(
        qw{svn diff --summarize -r}, $range, $branch->url_peg(),
    );

    # Returns false if there are changes outside of $subdir
    my $url = join ('/', $branch->url, $subdir);
    for my $line (@out) {
      chomp $line;
      $line = substr ($line, 7); # file name begins at column 7
      if ($line !~ m#^$url(?:/|$)#) {
        $return = 0;
        last;
      }
    }
  }

  return $return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $cm_branch->delete (
#     [NON_INTERACTIVE     => 1,]
#     [PASSWORD            => $password,]
#     [SVN_NON_INTERACTIVE => 1,]
#   );
#
# DESCRIPTION
#   This method deletes the current branch from the Subversion repository.
#
# OPTIONS
#   NON_INTERACTIVE     - Do no interactive prompting, set SVN_NON_INTERACTIVE
#                         to true automatically.
#   PASSWORD            - specify the password for commit access.
#   SVN_NON_INTERACTIVE - Do no interactive prompting when running svn commit,
#                         etc. This option is implied by NON_INTERACTIVE.
# ------------------------------------------------------------------------------

sub del {
  my $self = shift;
  my %args = @_;

  # Options
  # ----------------------------------------------------------------------------
  my $password            = exists $args{PASSWORD} ? $args{PASSWORD} : undef;
  my $non_interactive     = exists $args{NON_INTERACTIVE}
                            ? $args{NON_INTERACTIVE} : 0;
  my $svn_non_interactive = exists $args{SVN_NON_INTERACTIVE}
                            ? $args{SVN_NON_INTERACTIVE} : 0;
  $svn_non_interactive    = $non_interactive ? 1 : $svn_non_interactive;

  # Ensure URL is a branch
  # ----------------------------------------------------------------------------
  e_report $self->url_peg, ': not a branch, abort.' if not $self->is_branch;

  # Create a temporary file for the commit log message
  my $temp_handle = $self->_commit_message(
    sprintf("Deleted %s.\n", $self->branch_path()), 'D', $non_interactive,
  );

  # Check with the user to see if he/she wants to go ahead
  # ----------------------------------------------------------------------------
  if (!$non_interactive) {
    my $mesg = '';
    if ($self->branch_owner() && !$self->layout()->is_owned_by_user()) {
      $mesg .= "\n";

      if (exists $FCM1::CmUrl::owner_keywords{$self->branch_owner()}) {
        my $type = $FCM1::CmUrl::owner_keywords{$self->branch_owner()};
        $mesg .= '*** WARNING: YOU ARE DELETING A ' . uc ($type) .
                 ' BRANCH.';

      } else {
        $mesg .= '*** WARNING: YOU ARE DELETING A BRANCH NOT OWNED BY YOU.';
      }

      $mesg .= "\n" .
               '*** Please ensure that you have the owner\'s permission.' .
               "\n\n";
    }

    $mesg   .= 'Would you like to go ahead and delete this branch?';

    my $reply = FCM1::Interactive::get_input (
      title   => 'fcm branch',
      message => $mesg,
      type    => 'yn',
      default => 'n',
    );

    return unless $reply eq 'y';
  }

  # Delete branch if answer is "y" for "yes"
  # ----------------------------------------------------------------------------
  print 'Deleting branch ', $self->url, ' ...', "\n";
  $SVN->call(
    'delete',
    '-F', $temp_handle->filename(),
    (defined $password    ? ('--password', $password) : ()),
    ($svn_non_interactive ? '--non-interactive'       : ()),
    $self->url(),
  );

  return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $cm_branch->display_info (
#     [SHOW_CHILDREN => 1],
#     [SHOW_OTHER    => 1]
#     [SHOW_SIBLINGS => 1]
#   );
#
# DESCRIPTION
#   This method displays information of the current branch. If SHOW_CHILDREN is
#   set, it shows information of all current children branches of the current
#   branch. If SHOW_SIBLINGS is set, it shows information of siblings that have
#   been merged recently with the current branch. If SHOW_OTHER is set, it shows
#   information of custom/reverse merges.
# ------------------------------------------------------------------------------

sub display_info {
  my $self = shift;
  my %args = @_;

  # Arguments
  # ----------------------------------------------------------------------------
  my $show_children = exists $args{SHOW_CHILDREN} ? $args{SHOW_CHILDREN} : 0;
  my $show_other    = exists $args{SHOW_OTHER   } ? $args{SHOW_OTHER}    : 0;
  my $show_siblings = exists $args{SHOW_SIBLINGS} ? $args{SHOW_SIBLINGS} : 0;

  # Useful variables
  # ----------------------------------------------------------------------------
  my $separator  = '-' x 80 . "\n";
  my $separator2 = '  ' . '-' x 78 . "\n";

  # Print "info" as returned by "svn info"
  # ----------------------------------------------------------------------------
  for (
    ['URL',                 'url'            ],
    ['Repository Root',     'repository:root'],
    ['Revision',            'revision'       ],
    ['Last Changed Author', 'commit:author'  ],
    ['Last Changed Rev',    'commit:revision'],
    ['Last Changed Date',   'commit:date'    ],
  ) {
    my ($key, $flag) = @{$_};
    if ($self->svninfo(FLAG => $flag)) {
      printf("%s: %s\n", $key, $self->svninfo(FLAG => $flag));
    }
  }

  if ($self->config->verbose) {
    # Verbose mode, print log message at last changed revision
    my %log = $self->svnlog (REV => $self->svninfo(FLAG => 'commit:revision'));
    my @log = split /\n/, $log{msg};
    print 'Last Changed Log:', "\n\n", map ({'  ' . $_ . "\n"} @log), "\n";
  }

  if ($self->is_branch) {
    # Print create information
    # --------------------------------------------------------------------------
    my %log = $self->svnlog (REV => $self->create_rev);

    print $separator;
    print 'Branch Create Author: ', $log{author}, "\n" if $log{author};
    print 'Branch Create Rev: ', $self->create_rev, "\n";
    print 'Branch Create Date: ', &svn_date ($log{date}), "\n";

    if ($self->config->verbose) {
      # Verbose mode, print log message at last create revision
      my @log = split /\n/, $log{msg};
      print 'Branch Create Log:', "\n\n", map ({'  ' . $_ . "\n"} @log), "\n";
    }

    # Print delete information if branch no longer exists
    # --------------------------------------------------------------------------
    print 'Branch Delete Rev: ', $self->delete_rev, "\n" if $self->delete_rev;

    # Report merges into/from the parent
    # --------------------------------------------------------------------------
    # Print the URL@REV of the parent branch
    print $separator, 'Branch Parent: ', $self->parent->url_peg, "\n";

    # Set up a new object for the parent at the current revision
    # --------------------------------------------------------------------------
    my $p_url  = $self->parent->url;
    $p_url    .= '@' . $self->pegrev if $self->pegrev;
    my $parent = FCM1::CmBranch->new (URL => $p_url);

    if (not $parent->url_exists) {
      print 'Branch parent deleted.', "\n";
      return;
    }

    # Report merges into/from the parent
    # --------------------------------------------------------------------------
    print $self->_report_merges ($parent, 'Parent');
  }

  # Report merges with siblings
  # ----------------------------------------------------------------------------
  if ($show_siblings) {
    # Report number of sibling branches found
    print $separator, 'Searching for siblings ... ';
    my @siblings = $self->siblings;
    print scalar (@siblings), ' ', (@siblings> 1 ? 'siblings' : 'sibling'),
          ' found.', "\n";

    # Report branch name and merge information only if there are recent merges
    my $out = '';
    for my $sibling (@siblings) {
      my $string = $self->_report_merges ($sibling, 'Sibling');

      $out .= $separator2 . '  ' . $sibling->url . "\n" . $string if $string;
    }

    if (@siblings) {
      if ($out) {
        print 'Merges with existing siblings:', "\n", $out;

      } else {
        print 'No merges with existing siblings.', "\n";
      }
    }
  }

  # Report children
  # ----------------------------------------------------------------------------
  if ($show_children) {
    # Report number of child branches found
    print $separator, 'Searching for children ... ';
    my @children = $self->children;
    print scalar (@children), ' ', (@children > 1 ? 'children' : 'child'),
          ' found.', "\n";

    # Report children if they exist
    print 'Current children:', "\n" if @children;

    for my $child (@children) {
      print $separator2, '  ', $child->url, "\n";
      print '  Child Create Rev: ', $child->create_rev, "\n";
      print $self->_report_merges ($child, 'Child');
    }
  }

  # Report custom/reverse merges into the branch
  # ----------------------------------------------------------------------------
  if ($show_other) {
    my %log = $self->svnlog (STOP_ON_COPY => 1);
    my @out;

    # Go down the revision log, checking for merge template messages
    REV: for my $rev (sort {$b <=> $a} keys %log) {
      # Loop each line of the log message at each revision
      my @msg = split /\n/, $log{$rev}{msg};

      for (@msg) {
        # Ignore unless log message matches a merge template
        if (/^Reversed r\d+(:\d+)? of \S+$/ or
            s/^(Custom merge) into \S+(:.+)$/$1$2/) {
          push @out, ('r' . $rev . ': ' . $_) . "\n";
        }
      }
    }

    print $separator, 'Other merges:', "\n", @out if @out;
  }

  return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = $self->_report_merges ($branch, $relation);
#
# DESCRIPTION
#   This method returns a string for displaying merge information with a
#   branch, the $relation of which can be a Parent, a Sibling or a Child.
# ------------------------------------------------------------------------------

sub _report_merges {
  my ($self, $branch, $relation) = @_;

  my $indent    = ($relation eq 'Parent') ? '' : '  ';
  my $separator = ($relation eq 'Parent') ? ('-' x 80) : ('  ' . '-' x 78);
  $separator   .= "\n";

  my $return = '';

  # Report last merges into/from the $branch
  # ----------------------------------------------------------------------------
  my %merge  = (
    'Last Merge From ' . $relation . ':'
    => [$self->last_merge_from ($branch, 1)],
    'Last Merge Into ' . $relation . ':'
    => [$branch->last_merge_from ($self, 1)],
  );

  if ($self->config->verbose) {
    # Verbose mode, print the log of the merge
    for my $key (keys %merge) {
      next if not @{ $merge{$key} };

      # From: target (0) is self, upper delta (1) is $branch
      # Into: target (0) is $branch, upper delta (1) is self
      my $t = ($key =~ /From/) ? $self : $branch;

      $return .= $indent . $key . "\n";
      $return .= $separator . $t->display_svnlog ($merge{$key}[0]->pegrev);
    }

  } else {
    # Normal mode, print in simplified form (rREV Parent@REV)
    for my $key (keys %merge) {
      next if not @{ $merge{$key} };

      # From: target (0) is self, upper delta (1) is $branch
      # Into: target (0) is $branch, upper delta (1) is self
      $return .= $indent . $key . ' r' . $merge{$key}[0]->pegrev . ' ' .
                 $merge{$key}[1]->path_peg . ' cf. ' .
                 $merge{$key}[2]->path_peg . "\n";
    }
  }

  if ($relation eq 'Sibling') {
    # For sibling, do not report further if there is no recent merge
    my @values = values %merge;

    return $return unless (@{ $values[0] } or @{ $values[1] });
  }

  # Report available merges into/from the $branch
  # ----------------------------------------------------------------------------
  my %avail = (
    'Merges Avail From ' . $relation . ':'
    => ($self->delete_rev ? [] : [$self->avail_merge_from ($branch, 1)]),
    'Merges Avail Into ' . $relation . ':'
    => [$branch->avail_merge_from ($self, 1)],
  );

  if ($self->config->verbose) {
    # Verbose mode, print the log of each revision
    for my $key (sort keys %avail) {
      next unless @{ $avail{$key} };

      $return .= $indent . $key . "\n";

      my $s = ($key =~ /From/) ? $branch: $self;

      for my $rev (@{ $avail{$key} }) {
        $return .= $separator . $s->display_svnlog ($rev);
      }
    }

  } else {
    # Normal mode, print only the revisions
    for my $key (sort keys %avail) {
      next unless @{ $avail{$key} };

      $return .= $indent . $key . ' ' . join (' ', @{ $avail{$key} }) . "\n";
    }
  }

  return $return;
}

# Returns a File::Temp object containing the commit log for create/del.
sub _commit_message {
    my ($self, $message, $action, $non_interactive) = @_;
    my $commit_message_ctx = $COMMIT_MESSAGE_UTIL->ctx();
    $commit_message_ctx->set_auto_part($message);
    $commit_message_ctx->set_info_part(
        sprintf("%s    %s\n", $action, $self->url())
    );
    if (!$non_interactive) {
        $COMMIT_MESSAGE_UTIL->edit($commit_message_ctx);
    }
    $COMMIT_MESSAGE_UTIL->notify($commit_message_ctx);
    $COMMIT_MESSAGE_UTIL->temp($commit_message_ctx);
}

# ------------------------------------------------------------------------------

1;

__END__
