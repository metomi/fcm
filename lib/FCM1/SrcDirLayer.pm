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
#   FCM1::SrcDirLayer
#
# DESCRIPTION
#   This class contains methods to manipulate the extract of a source
#   directory from a branch of a (Subversion) repository.
#
# ------------------------------------------------------------------------------
use warnings;
use strict;

package FCM1::SrcDirLayer;
use base qw{FCM1::Base};

use FCM1::Util      qw{run_command e_report w_report};
use File::Basename qw{dirname};
use File::Path     qw{mkpath};
use File::Spec;

# List of property methods for this class
my @scalar_properties = (
  'cachedir',  # cache directory for this directory branch
  'commit',    # revision at which the source directory was changed
  'extracted', # is this branch already extracted?
  'files',     # list of source files in this directory branch
  'location',  # location of the source directory in the branch
  'name',      # sub-package name of the source directory
  'package',   # top level package name of which the current repository belongs
  'reposroot', # repository root URL
  'revision',  # revision of the repository branch
  'tag',       # package/revision tag of the current repository branch
  'type',      # type of the repository branch ("svn" or "user")
);

my %ERR_MESS_OF = (
    CACHE_WRITE => '%s: cannot write to cache',
    SYMLINK     => '%s/%s: ignore symbolic link',
    VC_TYPE     => '%s: repository type not supported',
);

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $obj = FCM1::SrcDirLayer->new (%args);
#
# DESCRIPTION
#   This method constructs a new instance of the FCM1::SrcDirLayer class. See
#   above for allowed list of properties. (KEYS should be in uppercase.)
# ------------------------------------------------------------------------------

sub new {
  my $this  = shift;
  my %args  = @_;
  my $class = ref $this || $this;

  my $self = FCM1::Base->new (%args);

  for (@scalar_properties) {
    $self->{$_} = exists $args{uc ($_)} ? $args{uc ($_)} : undef;
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
      if ($name eq 'files') {
        # Reference to an array
        $self->{$name} = [];
      }
    }

    return $self->{$name};
  }
}

# Handles error/warning events.
sub _err {
    my ($key, $args_ref, $warn_only) = @_;
    my $reporter = $warn_only ? \&w_report : \&e_report;
    $args_ref ||= [];
    $reporter->(sprintf($ERR_MESS_OF{$key} . ".\n", @{$args_ref}));
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $dir = $obj->localdir;
#
# DESCRIPTION
#   This method returns the user or cache directory for the current revision
#   of the repository branch.
# ------------------------------------------------------------------------------

sub localdir {
  my $self = shift;

  return $self->user ? $self->location : $self->cachedir;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $user = $obj->user;
#
# DESCRIPTION
#   This method returns the string "user" if the current source directory
#   branch is a local directory. Otherwise, it returns "undef".
# ------------------------------------------------------------------------------

sub user {
  my $self = shift;

  return $self->type eq 'user' ? 'user' : undef;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rev = $obj->get_commit;
#
# DESCRIPTION
#   If the current repository type is "svn", this method attempts to obtain
#   the revision in which the branch is last committed. On a successful
#   operation, it returns this revision number. Otherwise, it returns
#   "undef".
# ------------------------------------------------------------------------------

sub get_commit {
  my $self = shift;

  if ($self->type eq 'svn') {
    # Execute the "svn info" command
    my @lines   = &run_command (
      [qw/svn info -r/, $self->revision, $self->location . '@' . $self->revision],
      METHOD => 'qx', TIME => $self->config->verbose > 2,
    );

    my $rev;
    for (@lines) {
      if (/^Last\s+Changed\s+Rev\s*:\s*(\d+)/i) {
        $rev = $1;
        last;
      }
    }

    # Commit revision of this source directory
    $self->commit ($rev);

    return $self->commit;

  } elsif ($self->type eq 'user') {
    return;

  } else {
    _err('VC_TYPE', [$self->type()]);
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->update_cache;
#
# DESCRIPTION
#   If the current repository type is "svn", this method attempts to extract
#   the current revision source directory from the current branch from the
#   repository, sending the output to the cache directory. It returns true on
#   a successful operation, or false if the repository is not of type "svn".
# ------------------------------------------------------------------------------

sub update_cache {
  my $self = shift;

  return unless $self->cachedir;

  # Create cache extract destination, if necessary
  my $dirname = dirname $self->cachedir;
  mkpath($dirname);

  if (!-d $dirname) {
    _err('CACHE_WRITE', [$dirname]);
  }
  
  if ($self->type eq 'svn') {
    # Set up the extract command, "svn export --force -q -N"
    my @command = (
      qw/svn export --force -q -N/,
      $self->location . '@' . $self->revision,
      $self->cachedir,
    );

    &run_command (\@command, TIME => $self->config->verbose > 2);

  } elsif ($self->type eq 'user') {
    return;

  } else {
    _err('VC_TYPE', [$self->type()]);
  }

  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @files = $obj->get_files();
#
# DESCRIPTION
#   This method returns a list of file base names in the (cache of) this source
#   directory in the current branch.
# ------------------------------------------------------------------------------

sub get_files {
  my ($self) = @_;
  opendir(my $dir, $self->localdir())
    || die($self->localdir(), ': cannot read directory');
  my @base_names = ();
  BASE_NAME:
  while (my $base_name = readdir($dir)) {
    if ($base_name =~ qr{\A\.}xms || $base_name =~ qr{~\z}xms) {
        next BASE_NAME;
    }
    my $path = File::Spec->catfile($self->localdir(), $base_name);
    if (-d $path) {
        next BASE_NAME;
    }
    if (-l $path) {
        _err('SYMLINK', [$self->location(), $base_name], 1);
        next BASE_NAME;
    }
    push(@base_names, $base_name);
  }
  closedir($dir);
  $self->files(\@base_names);
  return @base_names;
}

# ------------------------------------------------------------------------------

1;

__END__
