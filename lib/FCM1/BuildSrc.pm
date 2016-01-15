# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-16 Met Office.
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
#   FCM1::BuildSrc
#
# DESCRIPTION
#   This is a class to group functionalities of source in a build.
#
# ------------------------------------------------------------------------------

use strict;
use warnings;

package FCM1::BuildSrc;
use base qw{FCM1::Base};

use Carp qw{croak};
use Cwd qw{cwd};
use FCM1::Build::Fortran;
use FCM1::CfgFile;
use FCM1::CfgLine;
use FCM1::Config;
use FCM1::Timer qw{timestamp_command};
use FCM1::Util qw{find_file_in_path run_command};
use File::Basename qw{basename dirname};
use File::Spec;

# List of scalar property methods for this class
my @scalar_properties = (
  'children',   # list of children packages
  'is_updated', # is this source (or its associated settings) updated?
  'mtime',      # modification time of src
  'ppmtime',    # modification time of ppsrc
  'ppsrc',      # full path of the pre-processed source
  'pkgname',    # package name of the source
  'progname',   # program unit name in the source
  'src',        # full path of the source
  'type',       # type of the source
);

# List of hash property methods for this class
my @hash_properties = (
  'dep',   # dependencies
  'ppdep', # pre-process dependencies
  'rules', # make rules
);

# Error message formats
my %ERR_MESS_OF = (
  CHDIR       => '%s: cannot change directory (%s), abort',
  OPEN        => '%s: cannot open (%s), abort',
  CLOSE_PIPE  => '%s: failed (%d), abort',
);

# Event message formats and levels
my %EVENT_SETTING_OF = (
  CHDIR            => ['%s: change directory'                   , 2],
  F_INTERFACE_NONE => ['%s: Fortran interface generation is off', 3],
  GET_DEPENDENCY   => ['%s: %d line(s), %d auto dependency(ies)', 3],
);

my %RE_OF = (
  F_PREFIX => qr{
    (?:
      (?:ELEMENTAL|PURE(?:\s+RECURSIVE)?|RECURSIVE(?:\s+PURE)?)
      \s+
    )?
  }imsx,
  F_SPEC => qr{
    (?:
      (?:CHARACTER|COMPLEX|DOUBLE\s*PRECISION|INTEGER|LOGICAL|REAL|TYPE)
      (?: \s* \( .+ \) | \s* \* \d+ \s*)??
      \s+
    )?
  }imsx,
);

{
  # Returns a singleton instance of FCM1::Build::Fortran.
  my $FORTRAN_UTIL;
  sub _get_fortran_util {
    $FORTRAN_UTIL ||= FCM1::Build::Fortran->new();
    return $FORTRAN_UTIL;
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $obj = FCM1::BuildSrc->new (%args);
#
# DESCRIPTION
#   This method constructs a new instance of the FCM1::BuildSrc class. See
#   above for allowed list of properties. (KEYS should be in uppercase.)
# ------------------------------------------------------------------------------

sub new {
  my ($class, %args) = @_;
  my $self = bless(FCM1::Base->new(%args), $class);
  for my $key (@scalar_properties, @hash_properties) {
    $self->{$key}
      = exists($args{uc($key)}) ? $args{uc($key)}
      :                           undef
      ;
  }
  $self;
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

      if ($name eq 'ppsrc') {
        $self->ppmtime (undef);

      } elsif ($name eq 'src') {
        $self->mtime (undef);
      }
    }

    # Default value for property
    if (not defined $self->{$name}) {
      if ($name eq 'children') {
        # Reference to an empty array
        $self->{$name} = [];
        
      } elsif ($name =~ /^(?:is_cur|pkgname|ppsrc|src)$/) {
        # Empty string
        $self->{$name} = '';
        
      } elsif ($name eq 'mtime') {
        # Modification time
        $self->{$name} = (stat $self->src)[9] if $self->src;
        
      } elsif ($name eq 'ppmtime') {
        # Modification time
        $self->{$name} = (stat $self->ppsrc)[9] if $self->ppsrc;
        
      } elsif ($name eq 'type') {
        # Attempt to get the type if src is set
        $self->{$name} = $self->get_type if $self->src;
      }
    }

    return $self->{$name};
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   %hash = %{ $obj->X () };
#   $obj->X (\%hash);
#
#   $value = $obj->X ($index);
#   $obj->X ($index, $value);
#
# DESCRIPTION
#   Details of these properties are explained in @hash_properties.
#
#   If no argument is set, this method returns a hash containing a list of
#   objects. If an argument is set and it is a reference to a hash, the objects
#   are replaced by the specified hash.
#
#   If a scalar argument is specified, this method returns a reference to an
#   object, if the indexed object exists or undef if the indexed object does
#   not exist. If a second argument is set, the $index element of the hash will
#   be set to the value of the argument.
# ------------------------------------------------------------------------------

for my $name (@hash_properties) {
  no strict 'refs';

  *$name = sub {
    my ($self, $arg1, $arg2) = @_;

    # Ensure property is defined as a reference to a hash
    if (not defined $self->{$name}) {
      if ($name eq 'rules') {
        $self->{$name} = $self->get_rules;

      } else {
        $self->{$name} = {};
      }
    }

    # Argument 1 can be a reference to a hash or a scalar index
    my ($index, %hash);

    if (defined $arg1) {
      if (ref ($arg1) eq 'HASH') {
        %hash = %$arg1;

      } else {
        $index = $arg1;
      }
    }

    if (defined $index) {
      # A scalar index is defined, set and/or return the value of an element
      $self->{$name}{$index} = $arg2 if defined $arg2;

      return (
        exists $self->{$name}{$index} ? $self->{$name}{$index} : undef
      );

    } else {
      # A scalar index is not defined, set and/or return the hash
      $self->{$name} = \%hash if defined $arg1;
      return $self->{$name};
    }
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $value = $obj->X;
#   $obj->X ($value);
#
# DESCRIPTION
#   This method returns/sets property X, all derived from src, where X is:
#     base  - (read-only) basename of src
#     dir   - (read-only) dirname of src
#     ext   - (read-only) file extension of src
#     root  - (read-only) basename of src without the file extension
# ------------------------------------------------------------------------------

sub base {
  return &basename ($_[0]->src);
}

# ------------------------------------------------------------------------------

sub dir {
  return &dirname ($_[0]->src);
}

# ------------------------------------------------------------------------------

sub ext {
  return substr $_[0]->base, length ($_[0]->root);
}

# ------------------------------------------------------------------------------

sub root {
  (my $root = $_[0]->base) =~ s/\.\w+$//;
  return $root;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $value = $obj->X;
#   $obj->X ($value);
#
# DESCRIPTION
#   This method returns/sets property X, all derived from ppsrc, where X is:
#     ppbase  - (read-only) basename of ppsrc
#     ppdir   - (read-only) dirname of ppsrc
#     ppext   - (read-only) file extension of ppsrc
#     pproot  - (read-only) basename of ppsrc without the file extension
# ------------------------------------------------------------------------------

sub ppbase {
  return &basename ($_[0]->ppsrc);
}

# ------------------------------------------------------------------------------

sub ppdir {
  return &dirname ($_[0]->ppsrc);
}

# ------------------------------------------------------------------------------

sub ppext {
  return substr $_[0]->ppbase, length ($_[0]->pproot);
}

# ------------------------------------------------------------------------------

sub pproot {
  (my $root = $_[0]->ppbase) =~ s/\.\w+$//;
  return $root;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $value = $obj->X;
#
# DESCRIPTION
#   This method returns/sets property X, derived from src or ppsrc, where X is:
#     curbase  - (read-only) basename of cursrc
#     curdir   - (read-only) dirname of cursrc
#     curext   - (read-only) file extension of cursrc
#     curmtime - (read-only) modification time of cursrc
#     curroot  - (read-only) basename of cursrc without the file extension
#     cursrc   - ppsrc or src
# ------------------------------------------------------------------------------

for my $name (qw/base dir ext mtime root src/) {
  no strict 'refs';

  my $subname = 'cur' . $name;

  *$subname = sub {
    my $self = shift;
    my $method = $self->ppsrc ? 'pp' . $name : $name;
    return $self->$method (@_);
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $base = $obj->X ();
#
# DESCRIPTION
#   This method returns a basename X for the source, where X is:
#     donebase      - "done" file name
#     etcbase       - target for copying data files
#     exebase       - executable name for source containing a main program
#     interfacebase - Fortran interface file name
#     libbase       - library file name
#     objbase       - object name for source containing compilable source
#   If the source file contains a compilable procedure, this method returns
#   the name of the object file.
# ------------------------------------------------------------------------------

sub donebase {
  my $self   = shift;

  my $return;
  if ($self->is_type_all ('SOURCE')) {
    if ($self->objbase and not $self->is_type_all ('PROGRAM')) {
      $return = ($self->progname ? $self->progname : lc ($self->curroot)) .
                $self->setting (qw/OUTFILE_EXT DONE/);
    }

  } elsif ($self->is_type_all ('INCLUDE')) {
    $return = $self->curbase . $self->setting (qw/OUTFILE_EXT IDONE/);
  }

  return $return;
}

# ------------------------------------------------------------------------------

sub etcbase {
  my $self = shift;

  my $return = @{ $self->children }
               ? $self->pkgname . $self->setting (qw/OUTFILE_EXT ETC/)
               : undef;

  return $return;
}

# ------------------------------------------------------------------------------

sub exebase {
  my $self = shift;

  my $return;
  if ($self->objbase and $self->is_type_all ('PROGRAM')) {
    if ($self->setting ('BLD_EXE_NAME', $self->curroot)) {
      $return = $self->setting ('BLD_EXE_NAME', $self->curroot);

    } else {
      $return = $self->curroot . $self->setting (qw/OUTFILE_EXT EXE/);
    }
  }

  return $return;
}

# ------------------------------------------------------------------------------

sub interfacebase {
  my $self = shift();
  if (
        defined($self->get_setting(qw/TOOL GENINTERFACE/))
    &&  uc($self->get_setting(qw/TOOL GENINTERFACE/)) ne 'NONE'
    &&  $self->progname()
    &&  $self->is_type_all(qw/SOURCE/)
    &&  $self->is_type_any(qw/FORTRAN9X FPP9X/)
    &&  !$self->is_type_any(qw/PROGRAM MODULE BLOCKDATA/)
  ) {
    my $flag = lc($self->get_setting(qw/TOOL INTERFACE/));
    my $ext  = $self->setting(qw/OUTFILE_EXT INTERFACE/);

    return (($flag eq 'program' ? $self->progname() : $self->curroot()) . $ext);
  }
  return;
}

# ------------------------------------------------------------------------------

sub objbase {
  my $self = shift;

  my $return;

  if ($self->is_type_all ('SOURCE')) {
    my $ext = $self->setting (qw/OUTFILE_EXT OBJ/);

    if ($self->is_type_any (qw/FORTRAN FPP/)) {
      $return = lc ($self->progname) . $ext if $self->progname;

    } else {
      $return = lc ($self->curroot) . $ext;
    }
  }

  return $return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $value = $obj->flagsbase ($flag, [$index,]);
#
# DESCRIPTION
#   Returns the base name of the flags file for the current package namespace
#   for a given $flag. The returned base name should look like
#   "LABEL___PACKAGE__NAME__SPACE.flags", where "LABEL" is normally the $flag,
#   and "PACKAGE__NAME__SPACE" is the current package namespace without the file
#   extension. If $flag is FLAGS or PPKEYS and $self->lang() is defined, it
#   will attempt to determine the correct label for the language. E.g. If
#   $self->lang() is 'C', the label will be "CFLAGS". If $index is set, returns
#   the base name of the flags file for the $index'th element in package name
#   space (as described in "pkgnames" method) instead of the current package
#   name space.
# ------------------------------------------------------------------------------

sub flagsbase {
  my ($self, $flag, $index) = @_;
  my $name = $index ? $self->pkgnames()->[$index] : $self->pkgname();
  my @names = split('__', $name);
  if (@names && $self->src() && $name eq $self->pkgname()) {
    $names[-1] =~ s{\.\w+ \z}{}msx;
  }
  my $label = $flag;
  if ($self->lang() && ($flag eq 'FLAGS' || $flag eq 'PPKEYS')) {
    if (!exists($self->setting('TOOL_SRC')->{$self->lang()}{$flag})) {
      return;
    }
    $label = $self->setting('TOOL_SRC')->{$self->lang()}{$flag};
  }
  join('__', $label, @names) . $self->setting(qw/OUTFILE_EXT FLAGS/);
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $value = $obj->libbase ([$prefix], [$suffix]);
#
# DESCRIPTION
#   This method returns the property libbase (derived from pkgname) the base
#   name of the library archive. $prefix and $suffix defaults to 'lib' and '.a'
#   respectively.
# ------------------------------------------------------------------------------

sub libbase {
  my ($self, $prefix, $suffix) = @_;
  $prefix ||= 'lib';
  $suffix ||= $self->setting(qw/OUTFILE_EXT LIB/);
  if ($self->src()) { # applies to directories only
    return;
  }
  my $name = $self->setting('BLD_LIB', $self->pkgname());
  if (!defined($name)) {
    $name = $self->pkgname();
  }
  $prefix . $name . $suffix;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $value = $obj->lang ([$setting]);
#
# DESCRIPTION
#   This method returns the property lang (derived from type) the programming
#   language name if type matches one supported in the TOOL_SRC setting. If
#   $setting is specified, use $setting instead of TOOL_SRC.
# ------------------------------------------------------------------------------

sub lang {
  my ($self, $setting) = @_;

  my @keys = keys %{ $self->setting ($setting ? $setting : 'TOOL_SRC') };

  my $return = undef;
  for my $key (@keys) {
    next unless $self->is_type_all ('SOURCE', $key);
    $return = $key;
    last;
  }

  return $return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $value = $obj->pkgnames;
#
# DESCRIPTION
#   This method returns a list of container packages, derived from pkgname:
# ------------------------------------------------------------------------------

sub pkgnames {
  my $self = shift;

  my $return = [];
  if ($self->pkgname) {
    my @names = split (/__/, $self->pkgname);

    for my $i (0 .. $#names) {
      push @$return, join ('__', (@names[0 .. $i]));
    }

    unshift @$return, '';
  }

  return $return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   %dep = %{$obj->get_dep()};
#   %dep = %{$obj->get_dep($flag)};
#
# DESCRIPTION
#   This method scans the current source file for dependencies and returns the
#   dependency hash (keys = dependencies, values = dependency types). If $flag
#   is specified, the config setting for $flag is used to determine the types of
#   types. Otherwise, those specified in 'BLD_TYPE_DEP' is used.
# ------------------------------------------------------------------------------

sub get_dep {
  my ($self, $flag) = @_;
  # Work out list of exclude for this file, using its sub-package name
  my %EXCLUDE_SET = map {($_, 1)} @{$self->get_setting('BLD_DEP_EXCL')};
  # Determine what dependencies are supported by this known type
  my %DEP_TYPE_OF = %{$self->setting($flag ? $flag : 'BLD_TYPE_DEP')};
  my %PATTERN_OF = %{$self->setting('BLD_DEP_PATTERN')};
  my @dep_types = ();
  if (!$self->get_setting('BLD_DEP_N')) {
    DEP_TYPE:
    while (my ($key, $dep_type_string) = each(%DEP_TYPE_OF)) {
      # Check if current file is a type of file requiring dependency scan
      if (!$self->is_type_all($key)) {
        next DEP_TYPE;
      }
      # Get list of dependency type for this file
      for my $dep_type (split(/$FCM1::Config::DELIMITER/, $dep_type_string)) {
        if (exists($PATTERN_OF{$dep_type}) && !exists($EXCLUDE_SET{$dep_type})) {
          push(@dep_types, $dep_type);
        }
      }
    }
  }

  # Automatic dependencies
  my %dep_of;
  my $can_get_symbol # Also scan for program unit name in Fortran source
      =  !$flag
      && $self->is_type_all('SOURCE')
      && $self->is_type_any(qw/FPP FORTRAN/)
      ;
  my $has_read_file;
  if ($can_get_symbol || @dep_types) {
    my $handle = _open($self->cursrc());
    LINE:
    while (my $line = readline($handle)) {
      chomp($line);
      if ($line =~ qr{\A \s* \z}msx) { # empty lines
        next LINE;
      }
      if ($can_get_symbol) {
        my $symbol = _get_dep_symbol($line);
        if ($symbol) {
          $self->progname($symbol);
          $can_get_symbol = 0;
          next LINE;
        }
      }
      DEP_TYPE:
      for my $dep_type (@dep_types) {
        my ($match) = $line =~ /$PATTERN_OF{$dep_type}/i;
        if (!$match) {
          next DEP_TYPE;
        }
        # $match may contain multiple items delimited by space
        for my $item (split(qr{\s+}msx, $match)) {
          my $key = uc($dep_type . $FCM1::Config::DELIMITER . $item);
          if (!exists($EXCLUDE_SET{$key})) {
            $dep_of{$item} = $dep_type;
          }
        }
        next LINE;
      }
    }
    $self->_event('GET_DEPENDENCY', $self->pkgname(), $., scalar(keys(%dep_of)));
    close($handle);
    $has_read_file = 1;
  }

  # Manual dependencies
  my $manual_deps_ref
      = $self->setting('BLD_DEP' . ($flag ? '_PP' : ''), $self->pkgname());
  if (defined($manual_deps_ref)) {
    for (@{$manual_deps_ref}) {
      my ($dep_type, $item) = split(/$FCM1::Config::DELIMITER/, $_, 2);
      $dep_of{$item} = $dep_type;
    }
  }

  return ($has_read_file, \%dep_of);
}

# Returns, if possible, the program unit declared in the $line.
sub _get_dep_symbol {
  my $line = shift();
  for my $pattern (
    qr{\A \s* $RE_OF{F_PREFIX} SUBROUTINE              \s+ ([A-Za-z]\w*)}imsx,
    qr{\A \s* MODULE (?!\s+PROCEDURE)                  \s+ ([A-Za-z]\w*)}imsx,
    qr{\A \s* PROGRAM                                  \s+ ([A-Za-z]\w*)}imsx,
    qr{\A \s* $RE_OF{F_PREFIX} $RE_OF{F_SPEC} FUNCTION \s+ ([A-Za-z]\w*)}imsx,
    qr{\A \s* BLOCK\s*DATA                             \s+ ([A-Za-z]\w*)}imsx,
  ) {
    my ($match) = $line =~ $pattern;
    if ($match) {
      return lc($match);
    }
  }
  return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @out = @{ $obj->get_fortran_interface () };
#
# DESCRIPTION
#   This method invokes the Fortran interface block generator to generate
#   an interface block for the current source file. It returns a reference to
#   an array containing the lines of the interface block.
# ------------------------------------------------------------------------------

sub get_fortran_interface {
  my $self = shift();
  my %ACTION_OF = (
    q{}    => \&_get_fortran_interface_by_internal_code,
    f90aib => \&_get_fortran_interface_by_f90aib,
    none   => sub {$self->_event('F_INTERFACE_NONE', $self->root()); []},
  );
  my $key = lc($self->get_setting(qw/TOOL GENINTERFACE/));
  if (!$key || !exists($ACTION_OF{$key})) {
    $key = q{};
  }
  $ACTION_OF{$key}->($self->cursrc());
}

# Generates Fortran interface block using "f90aib".
sub _get_fortran_interface_by_f90aib {
  my $path = shift();
  my $command = sprintf(q{f90aib <'%s' 2>'%s'}, $path, File::Spec->devnull());
  my $pipe = _open($command, '-|');
  my @lines = readline($pipe);
  close($pipe) || croak($ERR_MESS_OF{CLOSE_PIPE}, $command, $?);
  \@lines;
}

# Generates Fortran interface block using internal code.
sub _get_fortran_interface_by_internal_code {
  my $path = shift();
  my $handle = _open($path);
  my @lines = _get_fortran_util()->extract_interface($handle);
  close($handle);
  \@lines;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @out = @{ $obj->get_pre_process () };
#
# DESCRIPTION
#   This method invokes the pre-processor on the source file and returns a
#   reference to an array containing the lines of the pre-processed source on
#   success.
# ------------------------------------------------------------------------------

sub get_pre_process {
  my $self = shift;

  # Supported source files
  my $lang = $self->lang ('TOOL_SRC_PP');
  return unless $lang;

  # List of include directories
  my @inc = @{ $self->setting (qw/PATH INC/) };

  # Build the pre-processor command according to file type
  my %tool        = %{ $self->setting ('TOOL') };
  my %tool_src_pp = %{ $self->setting ('TOOL_SRC_PP', $lang) };

  # The pre-processor command and its options
  my @command = ($tool{$tool_src_pp{COMMAND}});
  my @ppflags = split /\s+/, $self->get_setting ('TOOL', $tool_src_pp{FLAGS});

  # List of defined macros, add "-D" in front of each macro
  my @ppkeys  = split /\s+/, $self->get_setting ('TOOL', $tool_src_pp{PPKEYS});
  @ppkeys     = map {($tool{$tool_src_pp{DEFINE}} . $_)} @ppkeys;

  # Add "-I" in front of each include directories
  @inc        = map {($tool{$tool_src_pp{INCLUDE}} . $_)} @inc;

  push @command, (@ppflags, @ppkeys, @inc, $self->base);

  # Change to container directory of source file
  my $old_cwd = $self->_chdir($self->dir());

  # Execute the command, getting the output lines
  my $verbose = $self->verbose;
  my @outlines = &run_command (
    \@command, METHOD => 'qx', PRINT => $verbose > 1, TIME => $verbose > 2,
  );

  # Change back to original directory
  $self->_chdir($old_cwd);

  return \@outlines;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rules = %{ $self->get_rules };
#
# DESCRIPTION
#   This method returns a reference to a hash in the following format:
#     $rules = {
#       target => {ACTION => action, DEP => [dependencies], ...},
#       ...    => {...},
#     };
#   where the 1st rank keys are the available targets for building this source
#   file, the second rank keys are ACTION and DEP. The value of ACTION is the
#   action for building the target, which can be "COMPILE", "LOAD", "TOUCH",
#   "CP" or "AR". The value of DEP is a refernce to an array containing a list
#   of dependencies suitable for insertion into the Makefile.
# ------------------------------------------------------------------------------

sub get_rules {
  my $self = shift;

  my $rules;
  my %outfile_ext = %{ $self->setting ('OUTFILE_EXT') };

  if ($self->is_type_all (qw/SOURCE/)) {
    # Source file
    # --------------------------------------------------------------------------
    # Determine whether the language of the source file is supported
    my %tool_src = %{ $self->setting ('TOOL_SRC') };

    return () unless $self->lang;

    # Compile object
    # --------------------------------------------------------------------------
    if ($self->objbase) {
      # Depends on the source file
      my @dep = ($self->rule_src);

      # Depends on the compiler flags flags-file
      my @flags;
      push @flags, ('FLAGS' )
        if $self->flagsbase ('FLAGS' );
      push @flags, ('PPKEYS')
        if $self->flagsbase ('PPKEYS') and not $self->ppsrc;

      push @dep, $self->flagsbase ($_) for (@flags);

      # Source file dependencies
      for my $name (sort keys %{ $self->dep }) {
        # A Fortran 9X module, lower case object file name
        if ($self->dep ($name) eq 'USE') {
          (my $root = $name) =~ s/\.\w+$//;
          push @dep, lc ($root) . $outfile_ext{OBJ};

        # An include file
        } elsif ($self->dep ($name) =~ /^(?:INC|H|INTERFACE)$/) {
          push @dep, $name;
        }
      }

      $rules->{$self->objbase} = {ACTION => 'COMPILE', DEP => \@dep};

      # Touch flags-files
      # ------------------------------------------------------------------------
      for my $flag (@flags) {
        next unless $self->flagsbase ($flag);

        $rules->{$self->flagsbase ($flag)} = {
          ACTION => 'TOUCH',
          DEP    => [
            $self->flagsbase ($tool_src{$self->lang}{$flag}, -2),
          ],
          DEST   => '$(FCM_FLAGSDIR)',
        };
      }
    }

    if ($self->exebase) {
      # Link into an executable
      # ------------------------------------------------------------------------
      my @dep = ();
      push @dep, $self->objbase               if $self->objbase;
      push @dep, $self->flagsbase ('LD'     ) if $self->flagsbase ('LD'     );
      push @dep, $self->flagsbase ('LDFLAGS') if $self->flagsbase ('LDFLAGS');

      # Depends on BLOCKDATA program units, for Fortran programs
      my %blockdata = %{ $self->setting ('BLD_BLOCKDATA') };
      my @blkobj    = ();

      if ($self->is_type_any (qw/FPP FORTRAN/) and keys %blockdata) {
        # List of BLOCKDATA object files
        if (exists $blockdata{$self->exebase}) {
          @blkobj = split /\s+/, $blockdata{$self->exebase};

        } elsif (exists $blockdata{''}) {
          @blkobj = split /\s+/, $blockdata{''};
        }

        for my $name (@blkobj) {
          (my $root = $name) =~ s/\.\w+$//;
          $name = $root . $outfile_ext{OBJ};
          push @dep, $root . $outfile_ext{DONE};
        }
      }

      # Extra executable dependencies
      my %exe_dep = %{ $self->setting ('BLD_DEP_EXE') };
      if (keys %exe_dep) {
        my @exe_deps;
        if (exists $exe_dep{$self->exebase}) {
          @exe_deps = split /\s+/, $exe_dep{$self->exebase};

        } elsif (exists $exe_dep{''}) {
          @exe_deps = $exe_dep{''} ? split (/\s+/, $exe_dep{''}) : ('');
        }

        my $pattern = '\\' . $outfile_ext{OBJ} . '$';

        for my $name (@exe_deps) {
          if ($name =~ /$pattern/) {
            # Extra dependency is an object
            (my $root = $name) =~ s/\.\w+$//;
            push @dep, $root . $outfile_ext{DONE};

          } else {
            # Extra dependency is a sub-package
            my $var;
            if ($self->setting ('FCM_PCK_OBJECTS', $name)) {
              # sub-package name contains unusual characters
              $var = $self->setting ('FCM_PCK_OBJECTS', $name);

            } else {
              # sub-package name contains normal characters
              $var = $name ? join ('__', ('OBJECTS', $name)) : 'OBJECTS';
            }

            push @dep, '$(' . $var . ')';
          }
        }
      }

      # Source file dependencies
      for my $name (sort keys %{ $self->dep }) {
        (my $root = $name) =~ s/\.\w+$//;

        # Lowercase name for object dependency
        $root = lc ($root) unless $self->dep ($name) =~ /^(?:INC|H)$/;

        # Select "done" file extension
        if ($self->dep ($name) =~ /^(?:INC|H)$/) {
          push @dep, $name . $outfile_ext{IDONE};

        } else {
          push @dep, $root . $outfile_ext{DONE};
        }
      }

      $rules->{$self->exebase} = {
        ACTION => 'LOAD', DEP => \@dep, BLOCKDATA => \@blkobj,
      };

      # Touch Linker flags-file
      # ------------------------------------------------------------------------
      for my $flag (qw/LD LDFLAGS/) {
        $rules->{$self->flagsbase ($flag)} = {
          ACTION => 'TOUCH',
          DEP    => [$self->flagsbase ($flag, -2)],
          DEST   => '$(FCM_FLAGSDIR)',
        };
      }

    }

    if ($self->donebase) {
      # Touch done file
      # ------------------------------------------------------------------------
      my @dep = ($self->objbase);

      for my $name (sort keys %{ $self->dep }) {
        (my $root = $name) =~ s/\.\w+$//;

        # Lowercase name for object dependency
        $root = lc ($root) unless $self->dep ($name) =~ /^(?:INC|H)$/;

        # Select "done" file extension
        if ($self->dep ($name) =~ /^(?:INC|H)$/) {
          push @dep, $name . $outfile_ext{IDONE};

        } else {
          push @dep, $root . $outfile_ext{DONE};
        }
      }

      $rules->{$self->donebase} = {
        ACTION => 'TOUCH', DEP => \@dep, DEST => '$(FCM_DONEDIR)',
      };
    }
    
    if ($self->interfacebase) {
      # Interface target
      # ------------------------------------------------------------------------
      # Source file dependencies
      my @dep = ();
      for my $name (sort keys %{ $self->dep }) {
        # Depends on Fortran 9X modules
        push @dep, lc ($name) . $outfile_ext{OBJ}
          if $self->dep ($name) eq 'USE';
      }

      $rules->{$self->interfacebase} = {ACTION => '', DEP => \@dep};
    }

  } elsif ($self->is_type_all ('INCLUDE')) {
    # Copy include target
    # --------------------------------------------------------------------------
    my @dep = ($self->rule_src);

    for my $name (sort keys %{ $self->dep }) {
      # A Fortran 9X module, lower case object file name
      if ($self->dep ($name) eq 'USE') {
        (my $root = $name) =~ s/\.\w+$//;
        push @dep, lc ($root) . $outfile_ext{OBJ};

      # An include file
      } elsif ($self->dep ($name) =~ /^(?:INC|H|INTERFACE)$/) {
        push @dep, $name;
      }
    }

    $rules->{$self->curbase} = {
      ACTION => 'CP', DEP => \@dep, DEST => '$(FCM_INCDIR)',
    };

    # Touch IDONE file
    # --------------------------------------------------------------------------
    if ($self->donebase) {
      my @dep = ($self->rule_src);

      for my $name (sort keys %{ $self->dep }) {
        (my $root = $name) =~ s/\.\w+$//;

        # Lowercase name for object dependency
        $root   = lc ($root) unless $self->dep ($name) =~ /^(?:INC|H)$/;

        # Select "done" file extension
        if ($self->dep ($name) =~ /^(?:INC|H)$/) {
          push @dep, $name . $outfile_ext{IDONE};

        } else {
          push @dep, $root . $outfile_ext{DONE};
        }
      }

      $rules->{$self->donebase} = {
        ACTION => 'TOUCH', DEP => \@dep, DEST => '$(FCM_DONEDIR)',
      };
    }

  } elsif ($self->is_type_any (qw/EXE SCRIPT/)) {
    # Copy executable file
    # --------------------------------------------------------------------------
    my @dep = ($self->rule_src);

    # Depends on dummy copy file, if file is an "always build type"
    push @dep, $self->setting (qw/BLD_CPDUMMY/)
      if $self->is_type_any (split (
        /$FCM1::Config::DELIMITER_LIST/, $self->setting ('BLD_TYPE_ALWAYS_BUILD')
      ));

    # Depends on other executable files
    for my $name (sort keys %{ $self->dep }) {
      push @dep, $name if $self->dep ($name) eq 'EXE';
    }

    $rules->{$self->curbase} = {
      ACTION => 'CP', DEP => \@dep, DEST => '$(FCM_BINDIR)',
    };

  } elsif (@{ $self->children }) {
    # Targets for top level and package flags files and dummy dependencies
    # --------------------------------------------------------------------------
    my %tool_src   = %{ $self->setting ('TOOL_SRC') };
    my %flags_tool = (LD => '', LDFLAGS => '');

    for my $key (keys %tool_src) {
      $flags_tool{$tool_src{$key}{FLAGS}} = $tool_src{$key}{COMMAND}
        if exists $tool_src{$key}{FLAGS};

      $flags_tool{$tool_src{$key}{PPKEYS}} = ''
        if exists $tool_src{$key}{PPKEYS};
    }

    for my $name (sort keys %flags_tool) {
      my @dep = $self->pkgname eq '' ? () : $self->flagsbase ($name, -2);
      push @dep, $self->flagsbase ($flags_tool{$name})
        if $self->pkgname eq '' and $flags_tool{$name};

      $rules->{$self->flagsbase ($flags_tool{$name})} = {
        ACTION => 'TOUCH',
        DEST   => '$(FCM_FLAGSDIR)',
      } if $self->pkgname eq '' and $flags_tool{$name};

      $rules->{$self->flagsbase ($name)} = {
        ACTION => 'TOUCH',
        DEP    => \@dep,
        DEST   => '$(FCM_FLAGSDIR)',
      };
    }

    # Package object and library
    # --------------------------------------------------------------------------
    {
      my @dep;
      # Add objects from children
      for my $child (sort {$a->pkgname cmp $b->pkgname} @{ $self->children }) {
        push @dep, $child->rule_obj_var (1)
          if $child->libbase and $child->rules ($child->libbase);
        push @dep, $child->objbase
          if $child->cursrc and $child->objbase and
             not $child->is_type_any (qw/PROGRAM BLOCKDATA/);
      }

      if (@dep) {
        $rules->{$self->libbase} = {ACTION => 'AR', DEP => \@dep};
      }
    }

    # Package data files
    # --------------------------------------------------------------------------
    {
      my @dep;
      for my $child (@{ $self->children }) {
        push @dep, $child->rule_src if $child->src and not $child->type;
      }

      if (@dep) {
        push @dep, $self->setting (qw/BLD_CPDUMMY/);
        $rules->{$self->etcbase} = {
          ACTION => 'CP_DATA', DEP => \@dep, DEST => '$(FCM_ETCDIR)',
        };
      }
    }
  }

  return $rules;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $value = $obj->get_setting ($setting[, @prefix]);
#
# DESCRIPTION
#   This method gets the correct $setting for the current source by following
#   its package name. If @prefix is set, get the setting with the given prefix.
# ------------------------------------------------------------------------------

sub get_setting {
  my ($self, $setting, @prefix) = @_;

  my $val;
  for my $name (reverse @{ $self->pkgnames }) {
    my @names = split /__/, $name;
    $val = $self->setting ($setting, join ('__', (@prefix, @names)));

    $val = $self->setting ($setting, join ('__', (@prefix, @names)))
      if (not defined $val) and @names and $names[-1] =~ s/\.[^\.]+$//;
    last if defined $val;
  }

  return $val;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $type = $self->get_type();
#
# DESCRIPTION
#   This method determines whether the source is a type known to the
#   build system. If so, it returns the type flags delimited by "::".
# ------------------------------------------------------------------------------

sub get_type {
  my $self = shift();
  my @IGNORE_LIST
    = split(/$FCM1::Config::DELIMITER_LIST/, $self->setting('INFILE_IGNORE'));
  if (grep {$self->curbase() eq $_} @IGNORE_LIST) {
    return q{};
  }
  # User defined
  my $type = $self->setting('BLD_TYPE', $self->pkgname());
  # Extension
  if (!defined($type)) {
    my $ext = $self->curext() ? substr($self->curext(), 1) : q{};
    $type = $self->setting('INFILE_EXT', $ext);
  }
  # Pattern of name
  if (!defined($type)) {
    my %NAME_PATTERN_TO_TYPE_HASH = %{$self->setting('INFILE_PAT')};
    PATTERN:
    while (my ($pattern, $value) = each(%NAME_PATTERN_TO_TYPE_HASH)) {
      if ($self->curbase() =~ $pattern) {
        $type = $value;
        last PATTERN;
      }
    }
  }
  # Pattern of #! line
  if (!defined($type) && -s $self->cursrc() && -T _) {
    my $handle = _open($self->cursrc());
    my $line = readline($handle);
    close($handle);
    my %SHEBANG_PATTERN_TO_TYPE_HASH = %{$self->setting('INFILE_TXT')};
    PATTERN:
    while (my ($pattern, $value) = each(%SHEBANG_PATTERN_TO_TYPE_HASH)) {
      if ($line =~ qr{^\#!.*$pattern}msx) {
        $type = $value;
        last PATTERN;
      }
    }
  }
  if (!$type) {
    return $type;
  }
  # Extra type information for selected file types
  my %EXTRA_FOR = (
    qr{\b (?:FORTRAN|FPP) \b}msx => \&_get_type_extra_for_fortran,
    qr{\b C \b}msx               => \&_get_type_extra_for_c,
  );
  EXTRA:
  while (my ($key, $code_ref) = each(%EXTRA_FOR)) {
    if ($type =~ $key) {
      my $handle = _open($self->cursrc());
      LINE:
      while (my $line = readline($handle)) {
        my $extra = $code_ref->($line);
        if ($extra) {
          $type .= $FCM1::Config::DELIMITER . $extra;
          last LINE;
        }
      }
      close($handle);
      last EXTRA;
    }
  }
  return $type;
}

sub _get_type_extra_for_fortran {
  my ($match) = $_[0] =~ qr{\A \s* (PROGRAM|MODULE|BLOCK\s*DATA) \b}imsx;
  if (!$match) {
    return;
  }
  $match =~ s{\s}{}g;
  uc($match)
}

sub _get_type_extra_for_c {
  ($_[0] =~ qr{int\s+main\s*\(}msx) ? 'PROGRAM' : undef;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $flag = $obj->is_in_package ($name);
#
# DESCRIPTION
#   This method returns true if current package is in the package $name.
# ------------------------------------------------------------------------------

sub is_in_package {
  my ($self, $name) = @_;
  
  my $return = 0;
  for (@{ $self->pkgnames }) {
    next unless /^$name(?:\.\w+)?$/;
    $return = 1;
    last;
  }

  return $return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $flag = $obj->is_type_all ($arg, ...);
#   $flag = $obj->is_type_any ($arg, ...);
#
# DESCRIPTION
#   This method returns a flag for the following:
#     is_type_all - does type match all of the arguments?
#     is_type_any - does type match any of the arguments?
# ------------------------------------------------------------------------------

for my $name ('all', 'any') {
  no strict 'refs';

  my $subname = 'is_type_' . $name;

  *$subname = sub {
    my ($self, @intypes) = @_;

    my $rc = 0;
    if ($self->type) {
      my %types = map {($_, 1)} split /$FCM1::Config::DELIMITER/, $self->type;

      for my $intype (@intypes) {
        $rc = exists $types{$intype};
        last if ($name eq 'all' and not $rc) or ($name eq 'any' and $rc);
      }
    }

    return $rc;
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = $obj->rule_obj_var ([$read]);
#
# DESCRIPTION
#   This method returns a string containing the make rule object variable for
#   the current package. If $read is set, return $($string)
# ------------------------------------------------------------------------------

sub rule_obj_var {
  my ($self, $read) = @_;

  my $return;
  if ($self->setting ('FCM_PCK_OBJECTS', $self->pkgname)) {
    # Package name registered in unusual list
    $return = $self->setting ('FCM_PCK_OBJECTS', $self->pkgname);

  } else {
    # Package name not registered in unusual list
    $return = $self->pkgname
              ? join ('__', ('OBJECTS', $self->pkgname)) : 'OBJECTS';
  }

  $return = $read ? '$(' . $return . ')' : $return;

  return $return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = $obj->rule_src ();
#
# DESCRIPTION
#   This method returns a string containing the location of the source file
#   relative to the build root. This string will be suitable for use in a
#   "Make" rule file for FCM.
# ------------------------------------------------------------------------------

sub rule_src {
  my $self = shift;

  my $return = $self->cursrc;
  LABEL: for my $name (qw/SRC PPSRC/) {
    for my $i (0 .. @{ $self->setting ('PATH', $name) } - 1) {
      my $dir = $self->setting ('PATH', $name)->[$i];
      next unless index ($self->cursrc, $dir) == 0;

      $return = File::Spec->catfile (
        '$(FCM_' . $name . 'DIR' . ($i ? $i : '') . ')',
        File::Spec->abs2rel ($self->cursrc, $dir),
      );
      last LABEL;
    }
  }

  return $return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->write_lib_dep_excl ();
#
# DESCRIPTION
#   This method writes a set of exclude dependency configurations for the
#   library of this package.
# ------------------------------------------------------------------------------

sub write_lib_dep_excl {
  my $self = shift();
  if (!find_file_in_path($self->libbase(), $self->setting(qw/PATH LIB/))) {
    return 0;
  }

  my $ETC_DIR = $self->setting(qw/PATH ETC/)->[0];
  my $CFG_EXT = $self->setting(qw/OUTFILE_EXT CFG/);
  my $LABEL_OF_EXCL_DEP = $self->cfglabel('BLD_DEP_EXCL');
  my @SETTINGS = (
       #dependency   #source file type list       #dependency name function
       ['H'        , [qw{INCLUDE CPP          }], sub {$_[0]->base()}         ],
       ['INTERFACE', [qw{INCLUDE INTERFACE    }], sub {$_[0]->base()}         ],
       ['INC'      , [qw{INCLUDE              }], sub {$_[0]->base()}         ],
       ['USE'      , [qw{SOURCE FORTRAN MODULE}], sub {$_[0]->root()}         ],
       ['INTERFACE', [qw{SOURCE FORTRAN       }], sub {$_[0]->interfacebase()}],
       ['OBJ'      , [qw{SOURCE               }], sub {$_[0]->root()}         ],
  );

  my $cfg = FCM1::CfgFile->new();
  my @stack = ($self);
  NODE:
  while (my $node = pop(@stack)) {
    # Is a directory
    if (@{$node->children()}) {
      push(@stack, reverse(@{$node->children()}));
      next NODE;
    }
    # Is a typed file
    if (
          $node->cursrc()
      &&  $node->type()
      &&  !$node->is_type_any(qw{PROGRAM BLOCKDATA})
    ) {
      for (@SETTINGS) {
        my ($key, $type_list_ref, $name_func_ref) = @{$_};
        my $name = $name_func_ref->($node);
        if ($name && $node->is_type_all(@{$type_list_ref})) {
          push(
            @{$cfg->lines()},
            FCM1::CfgLine->new(
              label => $LABEL_OF_EXCL_DEP,
              value => $key . $FCM1::Config::DELIMITER . $name,
            ),
          );
          next NODE;
        }
      }
    }
  }

  # Write to configuration file
  $cfg->print_cfg(
    File::Spec->catfile($ETC_DIR, $self->libbase('lib', $CFG_EXT)),
  );
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = $obj->write_rules ();
#
# DESCRIPTION
#   This method returns a string containing the "Make" rules for building the
#   source file.
# ------------------------------------------------------------------------------

sub write_rules {
  my $self  = shift;
  my $mk    = '';

  for my $target (sort keys %{ $self->rules }) {
    my $rule = $self->rules ($target);
    next unless defined ($rule->{ACTION});

    if ($rule->{ACTION} eq 'AR') {
      my $var = $self->rule_obj_var;
      $mk .= ($var eq 'OBJECTS' ? 'export ' : '') . $var . ' =';
      $mk .= ' ' . join (' ', @{ $rule->{DEP} });
      $mk .= "\n\n";
    }

    $mk .= $target . ':';
    
    if ($rule->{ACTION} eq 'AR') {
      $mk .= ' ' . $self->rule_obj_var (1);

    } else {
      for my $dep (@{ $rule->{DEP} }) {
        $mk .= ' ' . $dep;
      }
    }

    $mk .= "\n";

    if (exists $rule->{ACTION}) {
      if ($rule->{ACTION} eq 'AR') {
        $mk .= "\t" . 'fcm_internal archive $@ $^' . "\n";

      } elsif ($rule->{ACTION} eq 'CP') {
        $mk .= "\t" . 'cp $< ' . $rule->{DEST} . "\n";
        $mk .= "\t" . 'chmod u+w ' .
               File::Spec->catfile ($rule->{DEST}, '$@') . "\n";

      } elsif ($rule->{ACTION} eq 'CP_DATA') {
        $mk .= "\t" . 'cp $^ ' . $rule->{DEST} . "\n";
        $mk .= "\t" . 'touch ' .
               File::Spec->catfile ($rule->{DEST}, '$@') . "\n";

      } elsif ($rule->{ACTION} eq 'COMPILE') {
        if ($self->lang) {
          $mk .= "\t" . 'fcm_internal compile:' . substr ($self->lang, 0, 1) .
                 ' ' . $self->pkgnames->[-2] . ' $< $@';
          $mk .= ' 1' if ($self->flagsbase ('PPKEYS') and not $self->ppsrc);
          $mk .= "\n";
        }

      } elsif ($rule->{ACTION} eq 'LOAD') {
        if ($self->lang) {
          $mk .= "\t" . 'fcm_internal load:' . substr ($self->lang, 0, 1) .
                 ' ' . $self->pkgnames->[-2] . ' $< $@';
          $mk .= ' ' . join (' ', @{ $rule->{BLOCKDATA} })
            if @{ $rule->{BLOCKDATA} };
          $mk .= "\n";
        }

      } elsif ($rule->{ACTION} eq 'TOUCH') {
        $mk .= "\t" . 'touch ' .
               File::Spec->catfile ($rule->{DEST}, '$@') . "\n";
      }
    }

    $mk .= "\n";
  }

  return $mk;
}

# Wraps "chdir". Returns old directory.
sub _chdir {
  my ($self, $dir) = @_;
  my $old_cwd = cwd();
  $self->_event('CHDIR', $dir);
  chdir($dir) || croak(sprintf($ERR_MESS_OF{CHDIR}, $dir));
  $old_cwd;
}

# Wraps an event.
sub _event {
  my ($self, $key, @args) = @_;
  my ($format, $level) = @{$EVENT_SETTING_OF{$key}};
  $level ||= 1;
  if ($self->verbose() >= $level) {
    printf($format . ".\n", @args);
  }
}

# Wraps "open".
sub _open {
  my ($path, $mode) = @_;
  $mode ||= '<';
  open(my $handle, $mode, $path) || croak(sprintf($ERR_MESS_OF{OPEN}, $path, $!));
  $handle;
}

# ------------------------------------------------------------------------------

1;

__END__
