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
#   FCM1::Dest
#
# DESCRIPTION
#   This class contains methods to set up a destination location of an FCM
#   extract/build.
#
# ------------------------------------------------------------------------------
use warnings;
use strict;

package FCM1::Dest;
use base qw{FCM1::Base};

use Carp             qw{croak}                          ;
use Cwd              qw{cwd}                            ;
use FCM1::CfgLine                                       ;
use FCM1::Timer      qw{timestamp_command}              ;
use FCM1::Util       qw{run_command touch_file w_report};
use File::Basename   qw{basename dirname}               ;
use File::Find       qw{find}                           ;
use File::Path       qw{mkpath rmtree}                  ;
use File::Spec                                          ;
use Sys::Hostname    qw{hostname}                       ;
use Text::ParseWords qw{shellwords}                     ;

# Useful variables
# ------------------------------------------------------------------------------
# List of configuration files
our @cfgfiles = (
  'bldcfg',     # default location of the build configuration file
  'extcfg',     # default location of the extract configuration file
);

# List of cache and configuration files, according to the dest type
our @cfgfiles_type = (
  'cache',     # default location of the cache file
  'cfg',       # default location of the configuration file
  'parsedcfg', # default location of the as-parsed configuration file
);

# List of lock files
our @lockfiles = (
  'bldlock',    # the build lock file
  'extlock',    # the extract lock file
);

# List of misc files
our @miscfiles_bld = (
  'bldrunenvsh', # the build run environment shell script
  'bldmakefile', # the build Makefile
);

# List of sub-directories created by extract
our @subdirs_ext = (
  'cfgdir',     # sub-directory for configuration files
  'srcdir',     # sub-directory for source tree
);

# List of sub-directories that can be archived by "tar" at end of build
our @subdirs_tar = (
  'donedir',    # sub-directory for "done" files
  'flagsdir',   # sub-directory for "flags" files
  'incdir',     # sub-directory for include files
  'ppsrcdir',   # sub-directory for pre-process source tree
  'objdir',     # sub-directory for object files
);

# List of sub-directories created by build
our @subdirs_bld = (
  'bindir',     # sub-directory for executables
  'etcdir',     # sub-directory for miscellaneous files
  'libdir',     # sub-directory for object libraries
  'tmpdir',     # sub-directory for temporary build files
  @subdirs_tar, # -see above-
);

# List of sub-directories under rootdir
our @subdirs = (
  'cachedir',   # sub-directory for caches
  @subdirs_ext, # -see above-
  @subdirs_bld, # -see above-
);

# List of inherited search paths
# "rootdir" + all @subdirs, with "XXXdir" replaced with "XXXpath"
our @paths = (
    'rootpath',
    (map {my $key = $_; $key =~ s{dir\z}{path}msx; $key} @subdirs),
);

# List of properties and their default values.
my %PROP_OF = (
  # the original destination (if current destination is a mirror)
  'dest0'                => undef,
  # list of inherited FCM1::Dest objects
  'inherit'              => [],
  # remote login name
  'logname'              => scalar(getpwuid($<)),
  # lock file
  'lockfile'             => undef,
  # remote machine
  'machine'              => hostname(),
  # mirror command to use
  'mirror_cmd'           => 'rsync',
  # (for rsync) remote mkdir, the remote shell command
  'rsh_mkdir_rsh'        => 'ssh',
  # (for rsync) remote mkdir, the remote shell command flags
  'rsh_mkdir_rshflags'   => '-n -oBatchMode=yes',
  # (for rsync) remote mkdir, the remote shell command
  'rsh_mkdir_mkdir'      => 'mkdir',
  # (for rsync) remote mkdir, the remote shell command flags
  'rsh_mkdir_mkdirflags' => '-p',
  # (for rsync) remote mkdir, the remote shell command
  'rsync'                => 'rsync',
  # (for rsync) remote mkdir, the remote shell command flags
  'rsyncflags'           => q{-a --exclude='.*' --delete-excluded}
                            . q{ --timeout=900 --rsh='ssh -oBatchMode=yes'},
  # destination root directory
  'rootdir'              => undef,
  # destination type, "bld" (default) or "ext"
  'type'                 => 'bld',
);
# Hook for property setter
my %PROP_HOOK_OF = (
  'inherit' => \&_reset_inherit,
  'rootdir' => \&_reset_rootdir,
);

# Mirror implementations
my %MIRROR_IMPL_OF = (
  rdist => \&_mirror_with_rdist,
  rsync => \&_mirror_with_rsync,
);

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $obj = FCM1::Dest->new(%args);
#
# DESCRIPTION
#   This method constructs a new instance of the FCM1::Dest class. See above for
#   allowed list of properties. (KEYS should be in uppercase.)
# ------------------------------------------------------------------------------

sub new {
  my ($class, %args) = @_;
  my $self = bless(FCM1::Base->new(%args), $class);
  while (my ($key, $value) = each(%args)) {
    $key = lc($key);
    if (exists($PROP_OF{$key})) {
        $self->{$key} = $value;
    }
  }
  for my $key (@subdirs, @paths, @lockfiles, @cfgfiles) {
    $self->{$key} = undef;
  }
  return $self;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $self->DESTROY;
#
# DESCRIPTION
#   This method is called automatically when the FCM1::Dest object is
#   destroyed.
# ------------------------------------------------------------------------------

sub DESTROY {
  my $self = shift;

  # Remove the lockfile if it is set
  unlink $self->lockfile if $self->lockfile and -f $self->lockfile;

  return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $value = $obj->X($value);
#
# DESCRIPTION
#   Details of these properties are explained in %PROP_OF.
# ------------------------------------------------------------------------------

while (my ($key, $default) = each(%PROP_OF)) {
  no strict 'refs';
  *{$key} = sub {
    my $self = shift();
    # Set property to specified value
    if (@_) {
      $self->{$key} = $_[0];
      if (exists($PROP_HOOK_OF{$key})) {
        $PROP_HOOK_OF{$key}->($self, $key);
      }
    }
    # Sets default where possible
    if (!defined($self->{$key})) {
      $self->{$key} = $default;
    }
    return $self->{$key};
  };
}

# Remote shell property: deprecated.
sub remote_shell {
  my $self = shift();
  $self->rsh_mkdir_rsh(@_);
}

# Resets properties associated with root directory.
sub _reset_rootdir {
  my $self = shift();
  for my $key (@cfgfiles, @lockfiles, @miscfiles_bld, @subdirs) {
    $self->{$key} = undef;
  }
}

# Reset properties associated with inherited paths.
sub _reset_inherit {
  my $self = shift();
  for my $key (@paths) {
    $self->{$key} = undef;
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $value = $obj->X;
#
# DESCRIPTION
#   This method returns X, where X is a location derived from rootdir, and can
#   be one of:
#     bindir, bldcfg, blddir, bldlock, bldrunenv, cache, cachedir, cfg, cfgdir,
#     donedir, etcdir, extcfg, extlock, flagsdir, incdir, libdir, parsedcfg,
#     ppsrcdir, objdir, or tmpdir.
#
#   Details of these properties are explained earlier.
# ------------------------------------------------------------------------------

for my $name (@cfgfiles, @cfgfiles_type, @lockfiles, @miscfiles_bld, @subdirs) {
  no strict 'refs';

  *$name = sub {
    my $self = shift;

    # If variable not set, derive it from rootdir
    if ($self->rootdir and not defined $self->{$name}) {
      if ($name eq 'cache') {
        # Cache file under root/.cache
        $self->{$name} =  File::Spec->catfile (
          $self->cachedir, $self->setting ('CACHE'),
        );

      } elsif ($name eq 'cfg') {
        # Configuration file of current type
        my $method = $self->type . 'cfg';
        $self->{$name} = $self->$method;

      } elsif (grep {$name eq $_} @cfgfiles) {
        # Configuration files under the root/cfg
        (my $label = uc ($name)) =~ s/CFG//;
        $self->{$name} = File::Spec->catfile (
          $self->cfgdir, $self->setting ('CFG_NAME', $label),
        );

      } elsif (grep {$name eq $_} @lockfiles) {
        # Lock file
        $self->{$name} = File::Spec->catfile (
          $self->rootdir, $self->setting ('LOCK', uc ($name)),
        );

      } elsif (grep {$name eq $_} @miscfiles_bld) {
        # Misc file
        $self->{$name} = File::Spec->catfile (
          $self->rootdir, $self->setting ('BLD_MISC', uc ($name)),
        );

      } elsif ($name eq 'parsedcfg') {
        # As-parsed configuration file of current type
        $self->{$name} = File::Spec->catfile (
          dirname ($self->cfg),
          $self->setting (qw/CFG_NAME PARSED/) . basename ($self->cfg),
        )

      } elsif (grep {$name eq $_} @subdirs) {
        # Sub-directories under the root
        (my $label = uc ($name)) =~ s/DIR//;
        $self->{$name} = File::Spec->catfile (
          $self->rootdir,
          $self->setting ('DIR', $label),
          ($name eq 'cachedir' ? '.' . $self->type : ()),
        );
      }
    }

    return $self->{$name};
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $value = $obj->X;
#
# DESCRIPTION
#   This method returns X, an array containing the search path of a destination
#   directory, which can be one of:
#     binpath, bldpath, cachepath, cfgpath, donepath, etcpath, flagspath,
#     incpath, libpath, ppsrcpath, objpath, rootpath, srcpath, or tmppath,
#
#   Details of these properties are explained earlier.
# ------------------------------------------------------------------------------

for my $name (@paths) {
  no strict 'refs';

  *$name = sub {
    my $self = shift;

    (my $dir = $name) =~ s/path/dir/;

    if ($self->$dir and not defined $self->{$name}) {
      my @path = ();

      # Recursively inherit the search path
      for my $d (@{ $self->inherit }) {
        unshift @path, $d->$dir;
      }

      # Place the path of the current build in the front
      unshift @path, $self->$dir;

      $self->{$name} = \@path;
    }

    return $self->{$name};
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->archive ();
#
# DESCRIPTION
#   This method creates TAR archives for selected sub-directories.
# ------------------------------------------------------------------------------

sub archive {
  my $self = shift;

  # Save current directory
  my $cwd = cwd ();

  my $tar      = $self->setting (qw/OUTFILE_EXT TAR/);
  my $verbose  = $self->verbose;

  for my $name (@subdirs_tar) {
    my $dir = $self->$name;

    # Ignore unless sub-directory exists
    next unless -d $dir;

    # Change to container directory
    my $base = basename ($dir);
    print 'cd ', dirname ($dir), "\n" if $verbose > 2;
    chdir dirname ($dir);

    # Run "tar" command
    my $rc = &run_command (
      [qw/tar -czf/, $base . $tar, $base],
      PRINT => $verbose > 1, ERROR => 'warn',
    );

    # Remove sub-directory
    &run_command ([qw/rm -rf/, $base], PRINT => $verbose > 1) if not $rc;
  }

  # Change back to "current" directory
  print 'cd ', $cwd, "\n" if $verbose > 2;
  chdir $cwd;

  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $authority = $obj->authority();
#
# DESCRIPTION
#   Returns LOGNAME@MACHINE for this destination if LOGNAME is defined and not
#   the same as the user ID of the current process. Returns MACHINE if LOGNAME
#   is the same as the user ID of the current process, but MACHINE is not the
#   same as the current hostname. Returns an empty string if LOGNAME and
#   MACHINE are not defined or are the same as in the current process.
# ------------------------------------------------------------------------------

sub authority {
  my $self = shift;
  my $return = '';

  if ($self->logname ne $self->config->user_id) {
    $return = $self->logname . '@' . $self->machine;

  } elsif ($self->machine ne &hostname()) {
    $return = $self->machine;
  }

  return $return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->clean([ITEM => <list>,] [MODE => 'ALL|CONTENT|EMPTY',]);
#
# DESCRIPTION
#   This method removes files/directories from the destination. If ITEM is set,
#   it must be a reference to a list of method names for files/directories to
#   be removed. Otherwise, the list is determined by the destination type. If
#   MODE is ALL, all directories/files created by the extract/build are
#   removed. If MODE is CONTENT, only contents within sub-directories are
#   removed. If MODE is EMPTY (default), only empty sub-directories are
#   removed.
# ------------------------------------------------------------------------------

sub clean {
  my ($self, %args) = @_;
  my $mode = exists $args{MODE} ? $args{MODE} : 'EMPTY';
  my $rc = 1;
  my @names
    = $args{ITEM}            ? @{$args{ITEM}}
    : $self->type() eq 'ext' ? ('cachedir', @subdirs_ext)
    :                          ('cachedir', @subdirs_bld, @miscfiles_bld)
    ;
  my @items;
  if ($mode eq 'CONTENT') {
    for my $name (@names) {
      my $item = $self->$name();
      push(@items, _directory_contents($item));
    }
  }
  else {
    for my $name (@names) {
      my $item = $self->$name();
      if ($mode eq 'ALL' || -d $item && !_directory_contents($item)) {
        push(@items, $item);
      }
    }
  }
  for my $item (@items) {
    if ($self->verbose() >= 2) {
      printf("%s: remove\n", $item);
    }
    eval {rmtree($item)};
    if ($@) {
      w_report($@);
      $rc = 0;
    }
  }
  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->create ([DIR => <dir-list>,]);
#
# DESCRIPTION
#   This method creates the directories of a destination. If DIR is set, it
#   must be a reference to a list of sub-directories to be created.  Otherwise,
#   the sub-directory list is determined by the destination type. It returns
#   true if the destination is created or if it exists and is writable.
# ------------------------------------------------------------------------------

sub create {
  my ($self, %args) = @_;

  my $rc = 1;

  my @dirs;
  if (exists $args{DIR} and $args{DIR}) {
    # Create only selected sub-directories
    @dirs = @{ $args{DIR} };

  } else {
    # Create rootdir, cachedir and read-write sub-directories for extract/build
    @dirs = (
      qw/rootdir cachedir/,
      ($self->type eq 'ext' ? @subdirs_ext : @subdirs_bld),
    );
  }

  for my $name (@dirs) {
    my $dir = $self->$name;

    # Create directory if it does not already exist
    if (not -d $dir) {
      print 'Make directory: ', $dir, "\n" if $self->verbose > 1;
      mkpath $dir;
    }

    # Check whether directory exists and is writable
    if (!-d $dir) {
      w_report 'ERROR: ', $dir, ': cannot create destination.';
      $rc = 0;
    }
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->create_bldrunenvsh ();
#
# DESCRIPTION
#   This method creates the runtime environment script for the build.
# ------------------------------------------------------------------------------

sub create_bldrunenvsh {
  my $self = shift;

  # Path to executable files and directory for misc files
  my @bin_paths = grep {_directory_contents($_)} @{$self->binpath()};
  my $bin_dir = -d $self->bindir() ? $self->bindir() : undef;
  my $etc_dir = _directory_contents($self->etcdir()) ? $self->etcdir() : undef;

  # Create a runtime environment script if necessary
  if (@bin_paths || $etc_dir) {
    my $path = $self->bldrunenvsh();
    open(my $handle, '>', $path) || croak("$path: cannot open ($!)\n");
    printf($handle "#!%s\n", $self->setting(qw/TOOL SHELL/));
    if (@bin_paths) {
      printf($handle "PATH=%s:\$PATH\n", join(':', @bin_paths));
      print($handle "export PATH\n");
    }
    if ($etc_dir) {
      printf($handle "FCM_ETCDIR=%s\n", $etc_dir);
      print($handle "export FCM_ETCDIR\n");
    }
    close($handle) || croak("$path: cannot close ($!)\n");

    # Create symbolic links fcm_env.ksh and bin/fcm_env.ksh for backward
    # compatibility
    my $FCM_ENV_KSH = 'fcm_env.ksh';
    for my $link (
      File::Spec->catfile($self->rootdir, $FCM_ENV_KSH),
      ($bin_dir ? File::Spec->catfile($bin_dir, $FCM_ENV_KSH) : ()),
    ) {
      if (-l $link && readlink($link) ne $path || -e $link) {
        unlink($link);
      }
      if (!-l $link) {
        symlink($path, $link) || croak("$link: cannot create symbolic link\n");
      }
    }
  }
  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->dearchive ();
#
# DESCRIPTION
#   This method extracts from TAR archives for selected sub-directories.
# ------------------------------------------------------------------------------

sub dearchive {
  my $self = shift;

  my $tar     = $self->setting (qw/OUTFILE_EXT TAR/);
  my $verbose = $self->verbose;

  # Extract archives if necessary
  for my $name (@subdirs_tar) {
    my $tar_file = $self->$name . $tar;

    # Check whether tar archive exists for the named sub-directory
    next unless -f $tar_file;

    # If so, extract the archive and remove it afterwards
    &run_command ([qw/tar -xzf/, $tar_file], PRINT => $verbose > 1);
    &run_command ([qw/rm -f/, $tar_file], PRINT => $verbose > 1);
  }

  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $name = $obj->get_pkgname_of_path ($path);
#
# DESCRIPTION
#   This method returns the package name of $path if $path is in (a relative
#   path of) $self->srcdir, or undef otherwise.
# ------------------------------------------------------------------------------

sub get_pkgname_of_path {
  my ($self, $path) = @_;

  my $relpath = File::Spec->abs2rel ($path, $self->srcdir);
  my $name = $relpath ? [File::Spec->splitdir ($relpath)] : undef;

  return $name;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   %src = $obj->get_source_files ();
#
# DESCRIPTION
#   This method returns a hash (keys = package names, values = file names)
#   under $self->srcdir.
# ------------------------------------------------------------------------------

sub get_source_files {
  my $self = shift;

  my %src;
  if ($self->srcdir and -d $self->srcdir) {
    &find (sub {
      return if /^\./;                    # ignore system/hidden file
      return if -d $File::Find::name;     # ignore directory

      my $name = join (
        '__', @{ $self->get_pkgname_of_path ($File::Find::name) },
      );
      $src{$name} = $File::Find::name;
    }, $self->srcdir);
  }

  return \%src;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->mirror (\@items);
#
# DESCRIPTION
#   This method mirrors @items (list of method names for directories or files)
#   from $dest0 (which must be an instance of FCM1::Dest for a local
#   destination) to this destination.
# ------------------------------------------------------------------------------

sub mirror {
  my ($self, $items_ref) = @_;
  if ($self->authority() || $self->dest0()->rootdir() ne $self->rootdir()) {
    # Diagnostic
    if ($self->verbose()) {
      printf(
        "Destination: %s\n",
        ($self->authority() ? $self->authority() . q{:} : q{}) . $self->rootdir()
      );
    }
    if ($MIRROR_IMPL_OF{$self->mirror_cmd()}) {
      $MIRROR_IMPL_OF{$self->mirror_cmd()}->($self, $self->dest0(), $items_ref);
    }
    else {
      # Unknown mirroring tool
      w_report($self->mirror_cmd, ': unknown mirroring tool, abort.');
      return 0;
    }
  }
  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->_mirror_with_rdist ($dest0, \@items);
#
# DESCRIPTION
#   This internal method implements $self->mirror with "rdist".
# ------------------------------------------------------------------------------

sub _mirror_with_rdist {
  my ($self, $dest0, $items) = @_;

  my $rhost = $self->authority ? $self->authority : &hostname();

  # Print distfile content to temporary file
  my @distfile = ();
  for my $label (@$items) {
    push @distfile, '( ' . $dest0->$label . ' ) -> ' . $rhost . "\n";
    push @distfile, '  install ' . $self->$label . ';' . "\n";
  }

  # Set up mirroring command (use "rdist" at the moment)
  my $command = 'rdist -R';
  $command   .= ' -q' unless $self->verbose > 1;
  $command   .= ' -f - 1>/dev/null';

  # Diagnostic
  my $croak = 'Cannot execute "' . $command . '"';
  if ($self->verbose > 2) {
    print timestamp_command ($command, 'Start');
    print '  ', $_ for (@distfile);
  }

  # Execute the mirroring command
  open COMMAND, '|-', $command or croak $croak, ' (', $!, '), abort';
  for my $line (@distfile) {
    print COMMAND $line;
  }
  close COMMAND or croak $croak, ' (', $?, '), abort';

  # Diagnostic
  print timestamp_command ($command, 'End  ') if $self->verbose > 2;

  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->_mirror_with_rsync($dest0, \@items);
#
# DESCRIPTION
#   This internal method implements $self->mirror() with "rsync".
# ------------------------------------------------------------------------------

sub _mirror_with_rsync {
  my ($self, $dest0, $items_ref) = @_;
  my @rsh_mkdir;
  if ($self->authority()) {
    @rsh_mkdir = (
        $self->rsh_mkdir_rsh(),
        shellwords($self->rsh_mkdir_rshflags()),
        $self->authority(),
        $self->rsh_mkdir_mkdir(),
        shellwords($self->rsh_mkdir_mkdirflags()),
    );
  }
  my @rsync = ($self->rsync(), shellwords($self->rsyncflags()));
  my @rsync_verbose = ($self->verbose() > 2 ? '-v' : ());
  my $auth = $self->authority() ? $self->authority() . q{:} : q{};
  for my $item (@{$items_ref}) {
    # Create container directory, as rsync does not do it automatically
    my $dir = dirname($self->$item());
    if (@rsh_mkdir) {
      run_command([@rsh_mkdir, $dir], TIME => $self->verbose() > 2);
    }
    else {
      mkpath($dir);
    }
    run_command(
      [@rsync, @rsync_verbose, $dest0->$item(), $auth . $dir],
      TIME => $self->verbose > 2,
    );
  }
  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->set_lock ();
#
# DESCRIPTION
#   This method sets a lock in the current destination.
# ------------------------------------------------------------------------------

sub set_lock {
  my $self = shift;

  $self->lockfile ();

  if ($self->type eq 'ext' and not $self->dest0) {
    # Only set an extract lock for the local destination
    $self->lockfile ($self->extlock);

  } elsif ($self->type eq 'bld') {
    # Set a build lock
    $self->lockfile ($self->bldlock);
  }

  return &touch_file ($self->lockfile) if $self->lockfile;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @cfglines = $obj->to_cfglines ([$index]);
#
# DESCRIPTION
#   This method returns a list of configuration lines for the current
#   destination. If it is set, $index is the index number of the current
#   destination.
# ------------------------------------------------------------------------------

sub to_cfglines {
  my ($self, $index) = @_;

  my $PREFIX = $self->cfglabel($self->dest0() ? 'RDEST' : 'DEST');
  my $SUFFIX = ($index ? $FCM1::Config::DELIMITER . $index : q{});

  my @return = (
    FCM1::CfgLine->new(label => $PREFIX . $SUFFIX, value => $self->rootdir()),
  );
  if ($self->dest0()) {
    for my $name (qw{
      logname
      machine
      mirror_cmd
      rsh_mkdir_rsh
      rsh_mkdir_rshflags
      rsh_mkdir_mkdir
      rsh_mkdir_mkdirflags
      rsync
      rsyncflags
    }) {
      if ($self->{$name} && $self->{$name} ne $PROP_OF{$name}) { # not default
        push(
          @return,
          FCM1::CfgLine->new(
            label => $PREFIX . $FCM1::Config::DELIMITER . uc($name) . $SUFFIX,
            value => $self->{$name},
          ),
        );
      }
    }
  }

  return @return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = $obj->write_rules ();
#
# DESCRIPTION
#   This method returns a string containing Makefile variable declarations for
#   directories and search paths in this destination.
# ------------------------------------------------------------------------------

sub write_rules {
  my $self   = shift;
  my $return = '';

  # FCM_*DIR*
  for my $i (0 .. @{ $self->inherit }) {
    for my $name (@paths) {
      (my $label = $name) =~ s/path$/dir/;
      my $dir = $name eq 'rootpath' ? $self->$name->[$i] : File::Spec->catfile (
        '$(FCM_ROOTDIR' . ($i ? $i : '') . ')',
        File::Spec->abs2rel ($self->$name->[$i], $self->rootpath->[$i]),
      );

      $return .= ($i ? '' : 'export ') . 'FCM_' . uc ($label) . ($i ? $i : '') .
                 ' := ' . $dir . "\n";
    }
  }

  # FCM_*PATH
  for my $name (@paths) {
    (my $label = $name) =~ s/path$/dir/;

    $return .= 'export FCM_' . uc ($name) . ' := ';
    for my $i (0 .. @{ $self->$name } - 1) {
      $return .= ($i ? ':' : '') . '$(FCM_' . uc ($label) . ($i ? $i : '') . ')';
    }
    $return .= "\n";
  }

  $return .= "\n";

  return $return;
}

# Returns contents in directory.
sub _directory_contents {
  my $path = shift();
  if (!-d $path) {
    return;
  }
  opendir(my $handle, $path) || croak("$path: cannot open directory ($!)\n");
  my @items = grep {$_ ne q{.} && $_ ne q{..}} readdir($handle);
  closedir($handle);
  map {File::Spec->catfile($path . $_)} @items;
}

# ------------------------------------------------------------------------------

1;

__END__
