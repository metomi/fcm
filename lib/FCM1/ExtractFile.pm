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
#   FCM1::ExtractFile
#
# DESCRIPTION
#   Select/combine a file in different branches and extract it to destination.
#
# ------------------------------------------------------------------------------

use warnings;
use strict;

package FCM1::ExtractFile;
use base qw{FCM1::Base};

use FCM1::Util      qw{run_command w_report};
use File::Basename qw{dirname};
use File::Compare  qw{compare};
use File::Copy     qw{copy};
use File::Path     qw{mkpath};
use File::Spec;
use File::Temp     qw(tempfile);

# List of property methods for this class
my @scalar_properties = (
  'conflict',    # conflict mode
  'dest',        # search path to destination file
  'dest_status', # destination status, see below
  'pkgname',     # package name of this file
  'src',         # list of FCM1::ExtractSrc, specified for this file
  'src_actual',  # list of FCM1::ExtractSrc, actually used by this file
  'src_status',  # source status, see below
);

# Status code definition for $self->dest_status
our %DEST_STATUS_CODE = (
  ''  => 'unchanged',
  'M' => 'modified',
  'A' => 'added',
  'a' => 'added, overridding inherited',
  'D' => 'deleted',
  'd' => 'deleted, overridding inherited',
  '?' => 'irrelevant',
);

# Status code definition for $self->src_status
our %SRC_STATUS_CODE = (
  'A' => 'added by a branch',
  'B' => 'from the base',
  'D' => 'deleted by a branch',
  'M' => 'modified by a branch',
  'G' => 'merged from 2+ branches',
  'O' => 'overridden by a branch',
  '?' => 'irrelevant',
);

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $obj = FCM1::ExtractFile->new ();
#
# DESCRIPTION
#   This method constructs a new instance of the FCM1::ExtractFile class.
# ------------------------------------------------------------------------------

sub new {
  my $this  = shift;
  my %args  = @_;
  my $class = ref $this || $this;

  my $self = FCM1::Base->new (%args);

  for (@scalar_properties) {
    $self->{$_} = exists $args{$_} ? $args{$_} : undef;
  }

  bless $self, $class;
  return $self;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $value = $obj->X;
#   $obj->X ($value);
#
# DESCRIPTION
#   Details of these properties are explained in @scalar_properties.
# ------------------------------------------------------------------------------

for my $name (@scalar_properties) {
  no strict 'refs';

  *$name = sub {
    my $self = shift;

    # Argument specified, set property to specified argument
    if (@_) {
      $self->{$name} = $_[0];
    }

    # Default value for property
    if (not defined $self->{$name}) {
      if ($name eq 'conflict') {
        $self->{$name} = 'merge'; # default to "merge" mode

      } elsif ($name eq 'dest' or $name eq 'src' or $name eq 'src_actual') {
        $self->{$name} = [];      # default to an empty list
      }
    }

    return $self->{$name};
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->run();
#
# DESCRIPTION
#   This method runs only if $self->dest_status is not defined. It updates the
#   destination according to the source in the list and the conflict mode
#   setting. It updates the file in $self->dest as appropriate and sets
#   $self->dest_status. (See above.) This method returns true on success.
# ------------------------------------------------------------------------------

sub run {
  my ($self) = @_;
  my $rc = 1;

  if (not defined ($self->dest_status)) {
    # Assume file unchanged
    $self->dest_status ('');

    if (@{ $self->src }) {
      my $used;
      # Determine or set up a file for comparing with the destination
      ($rc, $used) = $self->run_get_used();

      # Attempt to compare the destination with $used. Update on change.
      if ($rc) {
        $rc = defined ($used) ? $self->run_update($used) : $self->run_delete();
      }

    } else {
      # No source, delete file in destination
      $self->src_status ('?');
      $rc = $self->run_delete();
    }
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->run_delete();
#
# DESCRIPTION
#   This method is part of run(). It detects this file in the destination path.
#   If this file is in the current destination, it attempts to delete it and
#   sets the dest_status to "D". If this file is in an inherited destination,
#   it sets the dest_status to "d".
# ------------------------------------------------------------------------------

sub run_delete {
  my ($self) = @_;

  my $rc = 1;

  $self->dest_status ('?');
  for my $i (0 .. @{ $self->dest } - 1) {
    my $dest = File::Spec->catfile ($self->dest->[$i], $self->pkgname);
    next unless -f $dest;
    if ($i == 0) {
      $rc = unlink $dest;
      $self->dest_status ('D');

    } else {
      $self->dest_status ('d');
      last;
    }
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   ($rc, $used) = $obj->run_get_used();
#
# DESCRIPTION
#   This method is part of run(). It attempts to work out or set up the $used
#   file. ($used is undef if it is not defined in a branch for this file.)
# ------------------------------------------------------------------------------

sub run_get_used {
  my ($self) = @_;
  my $rc = 1;
  my $used;

  my @sources = ($self->src->[0]);
  my $src_status = 'B';
  if (defined ($self->src->[0]->cache)) {
    # File exists in base branch
    for my $i (1 .. @{ $self->src } - 1) {
      if (defined ($self->src->[$i]->cache)) {
        # Detect changes in this file between base branch and branch $i
        push @sources, $self->src->[$i]
          if &compare ($self->src->[0]->cache, $self->src->[$i]->cache);

      } else {
        # File deleted in branch $i
        @sources = ($self->src->[$i]);
        last unless $self->conflict eq 'override';
      }
    }

    if ($rc) {
      if (@sources > 2) {
        if ($self->conflict eq 'fail') {
          # On conflict, fail in fail mode
          w_report 'ERROR: ', $self->pkgname,
                   ': modified in 2+ branches in fail conflict mode.';
          $rc = undef;

        } elsif ($self->conflict eq 'override') {
          $used = $sources[-1]->cache;
          $src_status = 'O';

        } else {
          # On conflict, attempt to merge in merge mode
          ($rc, $used) = $self->run_get_used_by_merge (@sources);
          $src_status = 'G' if $rc;
        }

      } else {
        # 0 or 1 change, use last source
        if (defined $sources[-1]->cache) {
          $used = $sources[-1]->cache;
          $src_status = 'M' if @sources > 1;

        } else {
          $src_status = 'D';
        }
      }
    }

  } else {
    # File does not exist in base branch
    @sources = ($self->src->[-1]);
    $used = $self->src->[1]->cache;
    $src_status = (defined ($used) ? 'A' : 'D');
    if ($self->conflict ne 'override' and defined ($used)) {
      for my $i (1 - @{ $self->src } .. -2) {
        # Allow this only if files are the same in all branches
        my $file = $self->src->[$i]->cache;
        if ((not defined ($file)) or &compare ($used, $file)) {
          w_report 'ERROR: ', $self->pkgname, ': cannot merge:',
                   ' not found in base branch,',
                   ' but differs in subsequent branches.';
          $rc = undef;
          last;

        } else {
          unshift @sources, $self->src->[$i];
        }
      }
    }
  }

  $self->src_status ($src_status);
  $self->src_actual (\@sources);

  return ($rc, $used);
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   ($rc, $used) = $obj->run_get_used_by_merge(@soruces);
#
# DESCRIPTION
#   This method is part of run_get_used(). It attempts to merge the files in
#   @sources and return a temporary file $used. @sources should be an array of
#   FCM1::ExtractSrc objects. On success, $rc will be set to true.
# ------------------------------------------------------------------------------

sub run_get_used_by_merge {
  my ($self, @sources) = @_;
  my $rc = 1;

  # Get temporary file
  my ($fh, $used) = &tempfile ('fcm.ext.merge.XXXXXX', UNLINK => 1);
  close $fh or die $used, ': cannot close';

  for my $i (2 .. @sources - 1) {
    # Invoke the diff3 command to merge
    my $mine = ($i == 2 ? $sources[1]->cache : $used);
    my $older = $sources[0]->cache;
    my $yours = $sources[$i]->cache;
    my @command = (
      $self->setting (qw/TOOL DIFF3/),
      split (/\s+/, $self->setting (qw/TOOL DIFF3FLAGS/)),
      $mine, $older, $yours,
    );
    my $code;
    my @out = &run_command (
      \@command,
      METHOD => 'qx',
      ERROR  => 'ignore',
      PRINT  => $self->verbose > 1,
      RC     => \$code,
      TIME   => $self->verbose > 2,
    );

    if ($code) {
      # Failure, report and return
      my $m = ($code == 1)
              ? 'cannot resolve conflicts:'
              : $self->setting (qw/TOOL DIFF3/) . 'command failed';
      w_report 'ERROR: ', $self->pkgname, ': merge - ', $m;
      if ($code == 1 and $self->verbose) {
        for (0 .. $i) {
          my $src = $sources[$_]->uri eq $sources[$_]->cache
                    ? $sources[$_]->cache
                    : ($sources[$_]->uri . '@' . $sources[$_]->rev);
          w_report '  source[', $_, ']=', $src;
        }

        for (0 .. $i) {
          w_report '  cache', $_, '=', $sources[$_]->cache;
        }

        w_report @out if $self->verbose > 2;
      }
      $rc = undef;
      last;

    } else {
      # Success, write result to temporary file
      open FILE, '>', $used or die $used, ': cannot open (', $!, ')';
      print FILE @out;
      close FILE or die $used, ': cannot close (', $!, ')';

      # File permission, use most permissive combination of $mine and $yours
      my $perm = ((stat($mine))[2] & 07777) | ((stat($yours))[2] & 07777);
      chmod ($perm, $used);
    }
  }

  return ($rc, $used);
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->run_update($used_file);
#
# DESCRIPTION
#   This method is part of run(). It compares the $used_file with the one in
#   the destination. If the file does not exist in the destination or if its
#   content is out of date, the destination is updated with the content in the
#   $used_file. Returns true on success.
# ------------------------------------------------------------------------------

sub run_update {
  my ($self, $used_file) = @_;
  my ($is_diff, $is_diff_in_perms, $is_in_prev, $rc) = (1, 1, undef, 1);

  # Compare with the previous version if it exists
  DEST:
  for my $i (0 .. @{$self->dest()} - 1) {
    my $prev_file = File::Spec->catfile($self->dest()->[$i], $self->pkgname());
    if (-f $prev_file) {
      $is_in_prev = $i;
      $is_diff = compare($used_file, $prev_file);
      $is_diff_in_perms = (stat($used_file))[2] != (stat($prev_file))[2];
      last DEST;
    }
  }
  if (!$is_diff && !$is_diff_in_perms) {
    return $rc;
  }

  # Update destination
  my $dest_file = File::Spec->catfile($self->dest()->[0], $self->pkgname());
  if ($is_diff) {
    my $dir = dirname($dest_file);
    if (!-d $dir) {
      mkpath($dir);
    }
    $rc = copy($used_file, $dest_file);
  }
  $rc &&= chmod((stat($used_file))[2] & oct(7777), $dest_file);
  if ($rc) {
    $self->dest_status(
        $is_in_prev          ? 'a'
      : defined($is_in_prev) ? 'M'
      :                        'A'
    );
  }
  return $rc;
}

# ------------------------------------------------------------------------------

1;

__END__
