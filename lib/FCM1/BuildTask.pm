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
# NAME
#   FCM1::BuildTask
#
# DESCRIPTION
#   This class hosts information of a build task in the FCM build system.
#
# ------------------------------------------------------------------------------

package FCM1::BuildTask;
@ISA = qw(FCM1::Base);

# Standard pragma
use strict;
use warnings;

# Standard modules
use Carp;
use File::Compare;
use File::Copy;
use File::Basename;
use File::Path;
use File::Spec::Functions;

# FCM component modules
use FCM1::Base;
use FCM1::Timer;
use FCM1::Util;

# List of property methods for this class
my @scalar_properties = (
  'actiontype',  # type of action
  'dependency',  # list of dependencies for this target
  'srcfile',     # reference to input FCM1::BuildSrc instance
  'output',      # output file
  'outputmtime', # output file modification time
  'target',      # target name for this task
  'targetpath',  # search path for the target
);

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $obj = FCM1::BuildTask->new (%args);
#
# DESCRIPTION
#   This method constructs a new instance of the FCM1::BuildTask class. See
#   above for allowed list of properties. (KEYS should be in uppercase.)
# ------------------------------------------------------------------------------

sub new {
  my $this  = shift;
  my %args  = @_;
  my $class = ref $this || $this;

  my $self = FCM1::Base->new (%args);

  bless $self, $class;

  for my $name (@scalar_properties) {
    $self->{$name} = exists $args{uc ($name)} ? $args{uc ($name)} : undef;
  }

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

      if ($name eq 'output') {
        $self->{outputmtime} = $_[0] ? (stat $_[0]) [9] : undef;
      }
    }

    # Default value for property
    if (not defined $self->{$name}) {
      if ($name eq 'dependency' or $name eq 'targetpath') {
        # Reference to an array
        $self->{$name} = [];
      }
    }

    return $self->{$name};
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->action (TASKLIST => \%tasklist);
#
# DESCRIPTION
#   This method performs the task action and sets the output accordingly. The
#   argument TASKLIST must be a reference to a hash containing the other tasks
#   of the build, which this task may depend on. The keys of the hash must the
#   name of the target names of the tasks, and the values of the hash must be
#   the references to the corresponding FCM1::BuildTask instances. The method
#   returns true if the task has been performed to create a new version of the
#   target.
# ------------------------------------------------------------------------------

sub action {
  my $self     = shift;
  my %args     = @_;
  my $tasklist = exists $args{TASKLIST} ? $args{TASKLIST} : {};

  return unless $self->actiontype;

  my $uptodate     = 1;
  my $dep_uptodate = 1;

  # Check if dependencies are up to date
  # ----------------------------------------------------------------------------
  for my $depend (@{ $self->dependency }) {
    if (exists $tasklist->{$depend}) {
      if (not $tasklist->{$depend}->output) {
        # Dependency task output is not set, performs its task action
        if ($tasklist->{$depend}->action (TASKLIST => $tasklist)) {
          $uptodate     = 0;
          $dep_uptodate = 0;
        }
      }

    } elsif ($self->verbose > 1) {
      w_report 'Warning: Task for "', $depend,
               '" does not exist, may be required by ', $self->target;
    }
  }

  # Check if the target exists in the search path
  # ----------------------------------------------------------------------------
  if (@{ $self->targetpath }) {
    my $output = find_file_in_path ($self->target, $self->targetpath);
    $self->output ($output) if $output;
  }

  # Target is out of date if it does not exist
  if ($uptodate) {
    $uptodate = 0 if not $self->output;
  }

  # Check if current target is older than its dependencies
  # ----------------------------------------------------------------------------
  if ($uptodate) {
    for my $depend (@{ $self->dependency }) {
      next unless exists $tasklist->{$depend};

      if ($tasklist->{$depend}->outputmtime > $self->outputmtime) {
        $uptodate     = 0;
        $dep_uptodate = 0;
      }
    }

    if ($uptodate and ref $self->srcfile) {
      $uptodate = 0 if $self->srcfile->mtime > $self->outputmtime;
    }
  }

  if ($uptodate) {
    # Current target and its dependencies are up to date
    # --------------------------------------------------------------------------
    if ($self->actiontype eq 'PP') {
      # "done" file up to date, set name of pre-processed source file
      # ------------------------------------------------------------------------
      my $base     = $self->srcfile->root . lc ($self->srcfile->ext);
      my @pknames  = split '__', (@{ $self->srcfile->pkgnames })[-2];
      my @path     = map {
        catfile ($_, @pknames);
      } @{ $self->setting (qw/PATH PPSRC/) };
      my $oldfile = find_file_in_path ($base, \@path);
      $self->srcfile->ppsrc ($oldfile);
    }

  } else {
    # Perform action is not up to date
    # --------------------------------------------------------------------------
    # (For GENINTERFACE and PP, perform action if "done" file not up to date)
    my $new_output = @{ $self->targetpath }
                     ? catfile ($self->targetpath->[0], $self->target)
                     : $self->target;

    # Create destination container directory if necessary
    my $destdir = dirname $new_output;

    if (not -d $destdir) {
      print 'Make directory: ', $destdir, "\n" if $self->verbose > 2;
      mkpath $destdir;
    }

    # List of actions
    if ($self->actiontype eq 'UPDATE') {
      # Action is UPDATE: Update file
      # ------------------------------------------------------------------------
      print 'Update: ', $new_output, "\n" if $self->verbose > 2;
      touch_file $new_output
        or croak 'Unable to update "', $new_output, '", abort';
      $self->output ($new_output);

    } elsif ($self->actiontype eq 'COPY') {
      # Action is COPY: copy file to destination if necessary
      # ------------------------------------------------------------------------
      my $copy_required = ($dep_uptodate and $self->output and -r $self->output)
                          ? compare ($self->output, $self->srcfile->src)
                          : 1;

      if ($copy_required) {
        # Set up copy command
        my $srcfile = $self->srcfile->src;
        my $destfile = catfile ($destdir, basename($srcfile));
        print 'Copy: ', $srcfile, "\n", '  to: ', $destfile, "\n"
          if $self->verbose > 2;
        &copy ($srcfile, $destfile)
          or die $srcfile, ': copy to ', $destfile, ' failed (', $!, '), abort';
        chmod (((stat ($srcfile))[2] & 07777), $destfile);

        $self->output ($new_output);

      } else {
        $uptodate = 1;
      }

    } elsif ($self->actiontype eq 'PP' or $self->actiontype eq 'GENINTERFACE') {
      # Action is PP or GENINTERFACE: process file
      # ------------------------------------------------------------------------
      my ($newlines, $base, @path);

      if ($self->actiontype eq 'PP') {
        # Invoke the pre-processor on the source file
        # ----------------------------------------------------------------------
        # Get lines in the pre-processed source
        $newlines = $self->srcfile->get_pre_process;
        $base     = $self->srcfile->root . lc ($self->srcfile->ext);

        # Get search path for the existing pre-processed file
        my @pknames  = split '__', (@{ $self->srcfile->pkgnames })[-2];
        @path        = map {
          catfile ($_, @pknames);
        } @{ $self->setting (qw/PATH PPSRC/) };

      } else { # if ($self->actiontype eq 'GENINTERFACE')
        # Invoke the interface generator
        # ----------------------------------------------------------------------
        # Get new interface lines
        $newlines = $self->srcfile->get_fortran_interface;

        # Get search path for the existing interface file
        $base     = $self->srcfile->interfacebase;
        @path     = @{ $self->setting (qw/PATH INC/) },
      }


      # If pre-processed or interface file exists,
      # compare its content with new lines to see if it has been updated
      my $update_required = 1;
      my $oldfile = find_file_in_path ($base, \@path);

      if ($oldfile and -r $oldfile) {
        # Read old file
        open FILE, '<', $oldfile;
        my @oldlines = readline 'FILE';
        close FILE;

        # Compare old contents and new contents
        if (@oldlines eq @$newlines) {
          $update_required = grep {
            $oldlines[$_] ne $newlines->[$_];
          } (0 .. $#oldlines);
        }
      }

      if ($update_required) {
        # Update the pre-processed source or interface file
        # ----------------------------------------------------------------------
        # Determine container directory of the  pre-processed or interface file
        my $newfile = @path ? catfile ($path[0], $base) : $base;

        # Create the container directory if necessary
        if (not -d $path[0]) {
          print 'Make directory: ', $path[0], "\n"
            if $self->verbose > 1;
          mkpath $path[0];
        }

        # Update the pre-processor or interface file
        open FILE, '>', $newfile
          or croak 'Cannot write to "', $newfile, '" (', $!, '), abort';
        print FILE @$newlines;
        close FILE
          or croak 'Cannot write to "', $newfile, '" (', $!, '), abort';
        print 'Generated: ', $newfile, "\n" if $self->verbose > 1;

        # Set the name of the pre-processed file
        $self->srcfile->ppsrc ($newfile) if $self->actiontype eq 'PP';

      } else {
        # Content in pre-processed source or interface file is up to date
        # ----------------------------------------------------------------------
        $uptodate = 1;

        # Set the name of the pre-processed file
        $self->srcfile->ppsrc ($oldfile) if $self->actiontype eq 'PP';
      }

      # Update the "done" file
      print 'Update: ', $new_output, "\n" if $self->verbose > 2;
      touch_file $new_output
        or croak 'Unable to update "', $new_output, '", abort';
      $self->output ($new_output);

    } else {
      carp 'Action type "', $self->actiontype, "' not supported";
    }
  }

  return not $uptodate;
}

# ------------------------------------------------------------------------------

1;

__END__
