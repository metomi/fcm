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
# NAME
#   FCM1::Build
#
# DESCRIPTION
#   This is the top level class for the FCM build system.
#
# ------------------------------------------------------------------------------

use strict;
use warnings;

package FCM1::Build;
use base qw(FCM1::ConfigSystem);

use Carp             qw{croak}                                       ;
use Cwd              qw{cwd}                                         ;
use FCM1::BuildSrc                                                   ;
use FCM1::BuildTask                                                  ;
use FCM1::Config                                                     ;
use FCM1::Dest                                                       ;
use FCM1::CfgLine                                                    ;
use FCM1::Timer      qw{timestamp_command}                           ;
use FCM1::Util       qw{expand_tilde run_command touch_file w_report};
use File::Basename   qw{dirname}                                     ;
use File::Spec                                                       ;
use List::Util       qw{first}                                       ;
use Text::ParseWords qw{shellwords}                                  ;

# List of scalar property methods for this class
my @scalar_properties = (
  'name',    # name of this build
  'target',  # targets of this build
);

# List of hash property methods for this class
my @hash_properties = (
  'srcpkg',      # source packages of this build
  'dummysrcpkg', # dummy for handling package inheritance with file extension
);

# List of compare_setting_X methods
my @compare_setting_methods = (
  'compare_setting_bld_blockdata', # program executable blockdata dependency
  'compare_setting_bld_dep',       # custom dependency setting
  'compare_setting_bld_dep_excl',  # exclude dependency setting
  'compare_setting_bld_dep_n',     # no dependency check
  'compare_setting_bld_dep_pp',    # custom PP dependency setting
  'compare_setting_bld_dep_exe',   # program executable extra dependency
  'compare_setting_bld_exe_name',  # program executable rename
  'compare_setting_bld_pp',        # PP flags
  'compare_setting_infile_ext',    # input file extension
  'compare_setting_outfile_ext',   # output file extension
  'compare_setting_tool',          # build tool settings
);

my $DELIMITER_LIST = $FCM1::Config::DELIMITER_LIST;

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $obj = FCM1::Build->new;
#
# DESCRIPTION
#   This method constructs a new instance of the FCM1::Build class.
# ------------------------------------------------------------------------------

sub new {
  my $this  = shift;
  my %args  = @_;
  my $class = ref $this || $this;

  my $self = FCM1::ConfigSystem->new (%args);

  $self->{$_} = undef for (@scalar_properties);

  $self->{$_} = {} for (@hash_properties);

  bless $self, $class;

  # List of sub-methods for parse_cfg
  push @{ $self->cfg_methods }, (qw/target source tool dep misc/);

  # Optional prefix in configuration declaration
  $self->cfg_prefix ($self->setting (qw/CFG_LABEL BDECLARE/));

  # System type
  $self->type ('bld');

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
      if ($name eq 'target') {
        # Reference to an array
        $self->{$name} = [];

      } elsif ($name eq 'name') {
        # Empty string
        $self->{$name} = '';
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
    $self->{$name} = {} if not defined ($self->{$name});

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
#   ($rc, $new_lines) = $self->X ($old_lines);
#
# DESCRIPTION
#   This method compares current settings with those in the cache, where X is
#   one of @compare_setting_methods.
#
#   If setting has changed:
#   * For bld_blockdata, bld_dep_ext and bld_exe_name, it sets the re-generate
#     make-rule flag to true.
#   * For bld_dep_excl, in a standalone build, the method will remove the
#     dependency cache files for affected sub-packages. It returns an error if
#     the current build inherits from previous builds.
#   * For bld_pp, it updates the PP setting for affected sub-packages.
#   * For infile_ext, in a standalone build, the method will remove all the
#     sub-package cache files and trigger a re-build by removing most
#     sub-directories created by the previous build. It returns an error if the
#     current build inherits from previous builds.
#   * For outfile_ext, in a standalone build, the method will remove all the
#     sub-package dependency cache files. It returns an error if the current
#     build inherits from previous builds.
#   * For tool, it updates the "flags" files for any changed tools.
# ------------------------------------------------------------------------------

for my $name (@compare_setting_methods) {
  no strict 'refs';

  *$name = sub {
    my ($self, $old_lines) = @_;

    (my $prefix = uc ($name)) =~ s/^COMPARE_SETTING_//;

    my ($changed, $new_lines) =
      $self->compare_setting_in_config ($prefix, $old_lines);

    my $rc = scalar (keys %$changed);

    if ($rc and $old_lines) {
      $self->srcpkg ('')->is_updated (1);

      if ($name =~ /^compare_setting_bld_dep(?:_excl|_n|_pp)?$/) {
        # Mark affected packages as being updated
        for my $key (keys %$changed) {
          for my $pkg (values %{ $self->srcpkg }) {
            next unless $pkg->is_in_package ($key);
            $pkg->is_updated (1);
          }
        }

      } elsif ($name eq 'compare_setting_bld_pp') {
        # Mark affected packages as being updated
        for my $key (keys %$changed) {
          for my $pkg (values %{ $self->srcpkg }) {
            next unless $pkg->is_in_package ($key);
            next unless $self->srcpkg ($key)->is_type_any (
              keys %{ $self->setting ('BLD_TYPE_DEP_PP') }
            ); # Is a type requiring pre-processing

            $pkg->is_updated (1);
          }
        }

      } elsif ($name eq 'compare_setting_infile_ext') {
        # Re-set input file type if necessary
        for my $key (keys %$changed) {
          for my $pkg (values %{ $self->srcpkg }) {
            next unless $pkg->src and $pkg->ext and $key eq $pkg->ext;

            $pkg->type (undef);
          }
        }

        # Mark affected packages as being updated
        for my $pkg (values %{ $self->srcpkg }) {
          $pkg->is_updated (1);
        }

      } elsif ($name eq 'compare_setting_outfile_ext') {
        # Mark affected packages as being updated
        for my $pkg (values %{ $self->srcpkg }) {
          $pkg->is_updated (1);
        }

      } elsif ($name eq 'compare_setting_tool') {
        # Update the "flags" files for changed tools
        for my $name (sort keys %$changed) {
          my ($tool, @names) = split /__/, $name;
          my $pkg  = join ('__', @names);
          my @srcpkgs
            = $self->srcpkg($pkg)      ? ($self->srcpkg($pkg))
            : $self->dummysrcpkg($pkg) ? @{$self->dummysrcpkg($pkg)->children()}
            :                            ()
            ;
          for my $srcpkg (@srcpkgs) {
            my $file = File::Spec->catfile (
              $self->dest->flagsdir, $srcpkg->flagsbase ($tool)
            );
            &touch_file ($file) or croak $file, ': cannot update, abort';

            print $file, ': updated', "\n" if $self->verbose > 2;
          }
        }
      }
    }

    return ($rc, $new_lines);
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   ($rc, $new_lines) = $self->compare_setting_dependency ($old_lines, $flag);
#
# DESCRIPTION
#   This method uses the previous settings to determine the dependencies of
#   current source files.
# ------------------------------------------------------------------------------

sub compare_setting_dependency {
  my ($self, $old_lines, $flag) = @_;

  my $prefix = $flag ? 'DEP_PP' : 'DEP';
  my $method = $flag ? 'ppdep'  : 'dep';

  my $rc = 0;
  my $new_lines = [];

  # Separate old lines
  my %old;
  if ($old_lines) {
    for my $line (@$old_lines) {
      next unless $line->label_starts_with ($prefix);
      $old{$line->label_from_field (1)} = $line;
    }
  }

  # Go through each source to see if the cache is up to date
  my $count = 0;
  my %mtime;
  for my $srcpkg (values %{ $self->srcpkg }) {
    next unless $srcpkg->cursrc and $srcpkg->type;

    my $key = $srcpkg->pkgname;
    my $out_of_date = $srcpkg->is_updated;

    # Check modification time of cache and source file if not out of date
    if (exists $old{$key}) {
      if (not $out_of_date) {
        $mtime{$old{$key}->src} = (stat ($old{$key}->src))[9]
          if not exists ($mtime{$old{$key}->src});

        $out_of_date = 1 if $mtime{$old{$key}->src} < $srcpkg->curmtime;
      }
    }
    else {
      $out_of_date = 1;
    }

    if ($out_of_date) {
      # Re-scan dependency
      $srcpkg->is_updated(1);
      my ($source_is_read, $dep_hash_ref) = $srcpkg->get_dep($flag);
      if ($source_is_read) {
        $count++;
      }
      $srcpkg->$method($dep_hash_ref);
      $rc = 1;
    }
    else {
      # Use cached dependency
      my ($progname, %hash) = split (
        /$FCM1::Config::DELIMITER_PATTERN/, $old{$key}->value
      );
      $srcpkg->progname ($progname) if $progname and not $flag;
      $srcpkg->$method (\%hash);
    }

    # New lines values: progname[::dependency-name::type][...]
    my @value = ((defined $srcpkg->progname ? $srcpkg->progname : ''));
    for my $name (sort keys %{ $srcpkg->$method }) {
      push @value, $name, $srcpkg->$method ($name);
    }

    push @$new_lines, FCM1::CfgLine->new (
      LABEL => $prefix . $FCM1::Config::DELIMITER . $key,
      VALUE => join ($FCM1::Config::DELIMITER, @value),
    );
  }

  print 'No. of file', ($count > 1 ? 's' : ''), ' scanned for',
        ($flag ? ' PP': ''), ' dependency: ', $count, "\n"
    if $self->verbose and $count;

  return ($rc, $new_lines);
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   ($rc, $new_lines) = $self->compare_setting_srcpkg ($old_lines);
#
# DESCRIPTION
#   This method uses the previous settings to determine the type of current
#   source files.
# ------------------------------------------------------------------------------

sub compare_setting_srcpkg {
  my ($self, $old_lines) = @_;

  my $prefix = 'SRCPKG';

  # Get relevant items from old lines, stripping out $prefix
  my %old;
  if ($old_lines) {
    for my $line (@$old_lines) {
      next unless $line->label_starts_with ($prefix);
      $old{$line->label_from_field (1)} = $line;
    }
  }

  # Check for change, use previous setting if exist
  my $out_of_date = 0;
  my %mtime;
  for my $key (keys %{ $self->srcpkg }) {
    if (exists $old{$key}) {
      next unless $self->srcpkg ($key)->cursrc;

      my $type = defined $self->setting ('BLD_TYPE', $key)
                 ? $self->setting ('BLD_TYPE', $key) : $old{$key}->value;

      $self->srcpkg ($key)->type ($type);

      if ($type ne $old{$key}->value) {
        $self->srcpkg ($key)->is_updated (1);
        $out_of_date = 1;
      }

      if (not $self->srcpkg ($key)->is_updated) {
        $mtime{$old{$key}->src} = (stat ($old{$key}->src))[9]
          if not exists ($mtime{$old{$key}->src});

        $self->srcpkg ($key)->is_updated (1)
          if $mtime{$old{$key}->src} < $self->srcpkg ($key)->curmtime;
      }

    } else {
      $self->srcpkg ($key)->is_updated (1);
      $out_of_date = 1;
    }
  }

  # Check for deleted keys
  for my $key (keys %old) {
    next if $self->srcpkg ($key);

    $out_of_date = 1;
  }

  # Return reference to an array of new lines
  my $new_lines = [];
  for my $key (keys %{ $self->srcpkg }) {
    push @$new_lines, FCM1::CfgLine->new (
      LABEL => $prefix . $FCM1::Config::DELIMITER . $key,
      VALUE => $self->srcpkg ($key)->type,
    );
  }

  return ($out_of_date, $new_lines);
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   ($rc, $new_lines) = $self->compare_setting_target ($old_lines);
#
# DESCRIPTION
#   This method compare the previous target settings with current ones.
# ------------------------------------------------------------------------------

sub compare_setting_target {
  my ($self, $old_lines) = @_;

  my $prefix = 'TARGET';
  my $old;
  if ($old_lines) {
    for my $line (@$old_lines) {
      next unless $line->label_starts_with ($prefix);
      $old = $line->value;
      last;
    }
  }

  my $new = join (' ', sort @{ $self->target });

  return (
    (defined ($old) ? $old ne $new : 1),
    [FCM1::CfgLine->new (LABEL => $prefix, VALUE => $new)],
  );
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->invoke_fortran_interface_generator ();
#
# DESCRIPTION
#   This method invokes the Fortran interface generator for all Fortran free
#   format source files. It returns true on success.
# ------------------------------------------------------------------------------

sub invoke_fortran_interface_generator {
  my $self = shift;

  my $pdoneext = $self->setting (qw/OUTFILE_EXT PDONE/);

  # Set up build task to generate interface files for all selected Fortran 9x
  # sources
  my %task = ();
  SRC_FILE:
  for my $srcfile (values %{ $self->srcpkg }) {
    if (!defined($srcfile->interfacebase())) {
      next SRC_FILE;
    }
    my $target  = $srcfile->interfacebase . $pdoneext;

    $task{$target} = FCM1::BuildTask->new (
      TARGET     => $target,
      TARGETPATH => $self->dest->donepath,
      SRCFILE    => $srcfile,
      DEPENDENCY => [$srcfile->flagsbase ('GENINTERFACE')],
      ACTIONTYPE => 'GENINTERFACE',
    );

    # Set up build tasks for each source file/package flags file for interface
    # generator tool
    for my $i (1 .. @{ $srcfile->pkgnames }) {
      my $target = $srcfile->flagsbase ('GENINTERFACE', -$i);
      my $depend = $i < @{ $srcfile->pkgnames }
                   ? $srcfile->flagsbase ('GENINTERFACE', -$i - 1)
                   : undef;

      $task{$target} = FCM1::BuildTask->new (
        TARGET     => $target,
        TARGETPATH => $self->dest->flagspath,
        DEPENDENCY => [defined ($depend) ? $depend : ()],
        ACTIONTYPE => 'UPDATE',
      ) if not exists $task{$target};
    }
  }

  # Set up build task to update the flags file for interface generator tool
  $task{$self->srcpkg ('')->flagsbase ('GENINTERFACE')} = FCM1::BuildTask->new (
    TARGET     => $self->srcpkg ('')->flagsbase ('GENINTERFACE'),
    TARGETPATH => $self->dest->flagspath,
    ACTIONTYPE => 'UPDATE',
  );

  my $count = 0;

  # Performs task
  for my $task (values %task) {
    next unless $task->actiontype eq 'GENINTERFACE';

    my $rc = $task->action (TASKLIST => \%task);
    $count++ if $rc;
  }

  print 'No. of generated Fortran interface', ($count > 1 ? 's' : ''), ': ',
        $count, "\n"
    if $self->verbose and $count;

  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->invoke_make (%args);
#
# DESCRIPTION
#   This method invokes the make stage of the build system. It returns true on
#   success.
#
# ARGUMENTS
#   ARCHIVE - If set to "true", invoke the "archive" mode. Most build files and
#             directories created by this build will be archived using the
#             "tar" command.  If not set, the default is not to invoke the
#             "archive" mode.
#   JOBS    - Specify number of jobs that can be handled by "make". If set, the
#             value must be a natural integer. If not set, the default value is
#             1 (i.e.  run "make" in serial mode).
#   TARGETS - Specify targets to be built. If set, these targets will be built
#             instead of the ones specified in the build configuration file.
# ------------------------------------------------------------------------------

sub invoke_make {
  my ($self, %args) = @_;
  $args{TARGETS} ||= ['all'];
  $args{JOBS}    ||= 1;
  my @command = (
    $self->setting(qw/TOOL MAKE/),
    shellwords($self->setting(qw/TOOL MAKEFLAGS/)),
    # -f Makefile
    ($self->setting(qw/TOOL MAKE_FILE/), $self->dest()->bldmakefile()),
    # -j N
    ($args{JOBS} ? ($self->setting(qw/TOOL MAKE_JOB/), $args{JOBS}) : ()),
    # -s
    ($self->verbose() < 3 ? $self->setting(qw/TOOL MAKE_SILENT/) : ()),
    @{$args{TARGETS}}
  );
  my $old_cwd = $self->_chdir($self->dest()->rootdir());
  run_command(
    \@command, ERROR => 'warn', RC => \my($code), TIME => $self->verbose() >= 3,
  );
  $self->_chdir($old_cwd);

  my $rc = !$code;
  if ($rc && $args{ARCHIVE}) {
    $rc = $self->dest()->archive();
  }
  $rc &&= $self->dest()->create_bldrunenvsh();
  while (my ($key, $source) = each(%{$self->srcpkg()})) {
    $rc &&= defined($source->write_lib_dep_excl());
  }
  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->invoke_pre_process ();
#
# DESCRIPTION
#   This method invokes the pre-process stage of the build system. It
#   returns true on success.
# ------------------------------------------------------------------------------

sub invoke_pre_process {
  my $self = shift;
   
  # Check whether pre-processing is necessary
  my $invoke = 0;
  for (values %{ $self->srcpkg }) {
    next unless $_->get_setting ('BLD_PP');
    $invoke = 1;
    last;
  }
  return 1 unless $invoke;

  # Scan header dependency
  my $rc = $self->compare_setting (
    METHOD_LIST => ['compare_setting_dependency'],
    METHOD_ARGS => ['BLD_TYPE_DEP_PP'],
    CACHEBASE   => $self->setting ('CACHE_DEP_PP'),
  );

  return $rc if not $rc;

  my %task     = ();
  my $pdoneext = $self->setting (qw/OUTFILE_EXT PDONE/);

  # Set up tasks for each source file
  for my $srcfile (values %{ $self->srcpkg }) {
    if ($srcfile->is_type_all (qw/CPP INCLUDE/)) {
      # Set up a copy build task for each include file
      $task{$srcfile->base} = FCM1::BuildTask->new (
        TARGET     => $srcfile->base,
        TARGETPATH => $self->dest->incpath,
        SRCFILE    => $srcfile,
        DEPENDENCY => [keys %{ $srcfile->ppdep }],
        ACTIONTYPE => 'COPY',
      );

    } elsif ($srcfile->lang ('TOOL_SRC_PP')) {
      next unless $srcfile->get_setting ('BLD_PP');

      # Set up a PP build task for each source file
      my $target = $srcfile->base . $pdoneext;

      # Issue warning for duplicated tasks
      if (exists $task{$target}) {
        w_report 'WARNING: ', $target, ': unable to create task for: ',
                 $srcfile->src, ': task already exists for: ',
                 $task{$target}->srcfile->src;
        next;
      }

      $task{$target} = FCM1::BuildTask->new (
        TARGET     => $target,
        TARGETPATH => $self->dest->donepath,
        SRCFILE    => $srcfile,
        DEPENDENCY => [$srcfile->flagsbase ('PPKEYS'), keys %{ $srcfile->ppdep }],
        ACTIONTYPE => 'PP',
      );

      # Set up update ppkeys/flags build tasks for each source file/package
      my $ppkeys = $self->setting (
        'TOOL_SRC_PP', $srcfile->lang ('TOOL_SRC_PP'), 'PPKEYS'
      );

      for my $i (1 .. @{ $srcfile->pkgnames }) {
        my $target = $srcfile->flagsbase ($ppkeys, -$i);
        my $depend = $i < @{ $srcfile->pkgnames }
                     ? $srcfile->flagsbase ($ppkeys, -$i - 1)
                     : undef;

        $task{$target} = FCM1::BuildTask->new (
          TARGET     => $target,
          TARGETPATH => $self->dest->flagspath,
          DEPENDENCY => [defined ($depend) ? $depend : ()],
          ACTIONTYPE => 'UPDATE',
        ) if not exists $task{$target};
      }
    }
  }

  # Set up update global ppkeys build tasks
  for my $lang (keys %{ $self->setting ('TOOL_SRC_PP') }) {
    my $target = $self->srcpkg ('')->flagsbase (
      $self->setting ('TOOL_SRC_PP', $lang, 'PPKEYS')
    );

    $task{$target} = FCM1::BuildTask->new (
      TARGET     => $target,
      TARGETPATH => $self->dest->flagspath,
      ACTIONTYPE => 'UPDATE',
    );
  }

  # Build all PP tasks
  my $count = 0;
  for my $task (values %task) {
    next unless $task->actiontype eq 'PP';

    my $rc = $task->action (TASKLIST => \%task);
    $task->srcfile->is_updated ($rc);
    $count++ if $rc;
  }

  print 'No. of pre-processed file', ($count > 1 ? 's' : ''), ': ', $count, "\n"
    if $self->verbose and $count;

  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->invoke_scan_dependency ();
#
# DESCRIPTION
#   This method invokes the scan dependency stage of the build system. It
#   returns true on success.
# ------------------------------------------------------------------------------

sub invoke_scan_dependency {
  my $self = shift;

  # Scan/retrieve dependency
  # ----------------------------------------------------------------------------
  my $rc = $self->compare_setting (
    METHOD_LIST => ['compare_setting_dependency'],
    CACHEBASE   => $self->setting ('CACHE_DEP'),
  );

  # Check whether make file is out of date
  # ----------------------------------------------------------------------------
  my $out_of_date = ! -f $self->dest->bldmakefile;

  if ($rc and not $out_of_date) {
    for (qw/CACHE CACHE_DEP/) {
      my $cache_mtime = (stat (File::Spec->catfile (
        $self->dest->cachedir, $self->setting ($_),
      )))[9];
      my $mfile_mtime = (stat ($self->dest->bldmakefile))[9];

      next if not defined $cache_mtime;
      next if $cache_mtime < $mfile_mtime;
      $out_of_date = 1;
      last;
    }
  }

  if ($rc and not $out_of_date) {
    for (values %{ $self->srcpkg }) {
      next unless $_->is_updated;
      $out_of_date = 1;
      last;
    }
  }

  if ($rc and $out_of_date) {
    # Write Makefile
    # --------------------------------------------------------------------------
    # Register non-word package name
    my $unusual = 0;
    for my $key (sort keys %{ $self->srcpkg }) {
      next if $self->srcpkg ($key)->src;
      next if $key =~ /^\w*$/;

      $self->setting (
        ['FCM_PCK_OBJECTS', $key], 'FCM_PCK_OBJECTS' . $unusual++,
      );
    }

    # Write different parts in the Makefile
    my $makefile = '# Automatic Makefile' . "\n\n";
    $makefile .= 'FCM_BLD_NAME = ' . $self->name . "\n" if $self->name;
    $makefile .= 'FCM_BLD_CFG = ' . $self->cfg->actual_src . "\n";
    $makefile .= 'export FCM_VERBOSE ?= ' . $self->verbose . "\n\n";
    $makefile .= "export OBJECTS\n";
    $makefile .= $self->dest->write_rules;
    $makefile .= $self->_write_makefile_perl5lib;
    $makefile .= $self->_write_makefile_tool;
    $makefile .= $self->_write_makefile_vpath;
    $makefile .= $self->_write_makefile_target;

    # Write rules for each source package
    # Ensure that container packages come before files - this allows $(OBJECTS)
    # and its dependent variables to expand correctly
    my @srcpkg = sort {
      if ($self->srcpkg ($a)->libbase and $self->srcpkg ($b)->libbase) {
        $b cmp $a;

      } elsif ($self->srcpkg ($a)->libbase) {
        -1;

      } elsif ($self->srcpkg ($b)->libbase) {
        1;

      } else {
        $a cmp $b;
      }
    } keys %{ $self->srcpkg };

    for (@srcpkg) {
      $makefile .= $self->srcpkg ($_)->write_rules if $self->srcpkg ($_)->rules;
    }
    $makefile .= '# EOF' . "\n";

    # Update Makefile
    open OUT, '>', $self->dest->bldmakefile
      or croak $self->dest->bldmakefile, ': cannot open (', $!, '), abort';
    print OUT $makefile;
    close OUT
      or croak $self->dest->bldmakefile, ': cannot close (', $!, '), abort';

    print $self->dest->bldmakefile, ': updated', "\n" if $self->verbose;

    # Check for duplicated targets
    # --------------------------------------------------------------------------
    # Get list of types that cannot have duplicated targets
    my @no_duplicated_target_types = split (
      /$DELIMITER_LIST/,
      $self->setting ('BLD_TYPE_NO_DUPLICATED_TARGET'),
    );

    my %targets;
    for my $name (sort keys %{ $self->srcpkg }) {
      next unless $self->srcpkg ($name)->rules;

      for my $key (sort keys %{ $self->srcpkg ($name)->rules }) {
        if (exists $targets{$key}) {
          # Duplicated target: warning for most file types
          my $status = 'WARNING';

          # Duplicated target: error for the following file types
          if (@no_duplicated_target_types and
              $self->srcpkg ($name)->is_type_any (@no_duplicated_target_types) and
              $targets{$key}->is_type_any (@no_duplicated_target_types)) {
            $status = 'ERROR';
            $rc = 0;
          }

          # Report the warning/error
          w_report $status, ': ', $key, ': duplicated targets for building:';
          w_report '       ', $targets{$key}->src;
          w_report '       ', $self->srcpkg ($name)->src;

        } else {
          $targets{$key} = $self->srcpkg ($name);
        }
      }
    }
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->invoke_setup_build ();
#
# DESCRIPTION
#   This method invokes the setup_build stage of the build system. It returns
#   true on success.
# ------------------------------------------------------------------------------

sub invoke_setup_build {
  my $self = shift;

  my $rc = 1;

  # Extract archived sub-directories if necessary
  $rc = $self->dest->dearchive if $rc;

  # Compare cache
  $rc = $self->compare_setting (METHOD_LIST => [
    'compare_setting_target', # targets
    'compare_setting_srcpkg', # source package type
    @compare_setting_methods,
  ]) if $rc;

  # Set up runtime dependency scan patterns
  my %dep_pattern = %{ $self->setting ('BLD_DEP_PATTERN') };
  for my $key (keys %dep_pattern) {
    my $pattern = $dep_pattern{$key};

    while ($pattern =~ /##([\w:]+)##/g) {
      my $match = $1;
      my $val   = $self->setting (split (/$FCM1::Config::DELIMITER/, $match));

      last unless defined $val;
      $val =~ s/\./\\./;

      $pattern =~ s/##$match##/$val/;
    }

    $self->setting (['BLD_DEP_PATTERN', $key], $pattern)
      unless $pattern eq $dep_pattern{$key};
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->invoke_system (%args);
#
# DESCRIPTION
#   This method invokes the build system. It returns true on success. See also
#   the header for invoke_make for further information on arguments.
#
# ARGUMENTS
#   STAGE - If set, it should be an integer number or a recognised keyword or
#           abbreviation. If set, the build is performed up to the named stage.
#           If not set, the default is to perform all stages of the build.
#           Allowed values are:
#             1, setup or s
#             2, pre_process or pp
#             3, generate_dependency or gd
#             4, generate_interface or gi
#             5, all, a, make or m
# ------------------------------------------------------------------------------

sub invoke_system {
  my $self = shift;
  my %args = @_;

  # Parse arguments
  # ----------------------------------------------------------------------------
  # Default: run all 5 stages
  my $stage = (exists $args{STAGE} and $args{STAGE}) ? $args{STAGE} : 5;

  # Resolve named stages
  if ($stage !~ /^\d$/) {
    my %stagenames = (
      'S(?:ETUP)?'                      => 1,
      'P(?:RE)?_?P(?:ROCESS)?'          => 2,
      'G(?:ENERATE)?_?D(?:ENPENDENCY)?' => 3,
      'G(?:ENERATE)?_?I(?:NTERFACE)?'   => 4,
      '(?:A(?:LL)|M(?:AKE)?)'           => 5,
    );

    # Does it match a recognised stage?
    for my $name (keys %stagenames) {
      next unless $stage =~ /$name/i;

      $stage = $stagenames{$name};
      last;
    }

    # Specified stage name not recognised, default to 5
    if ($stage !~ /^\d$/) {
      w_report 'WARNING: ', $stage, ': invalid build stage, default to 5.';
      $stage = 5;
    }
  }

  # Run the method associated with each stage
  # ----------------------------------------------------------------------------
  my $rc = 1;

  my @stages = (
    ['Setup build'               , 'invoke_setup_build'],
    ['Pre-process'               , 'invoke_pre_process'],
    ['Scan dependency'           , 'invoke_scan_dependency'],
    ['Generate Fortran interface', 'invoke_fortran_interface_generator'],
    ['Make'                      , 'invoke_make'],
  );

  for my $i (1 .. 5) {
    last if (not $rc) or $i > $stage;

    my ($name, $method) = @{ $stages[$i - 1] };
    $rc = $self->invoke_stage ($name, $method, %args) if $rc and $stage >= $i;
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->parse_cfg_dep (\@cfg_lines);
#
# DESCRIPTION
#   This method parses the dependency settings in the @cfg_lines.
# ------------------------------------------------------------------------------

sub parse_cfg_dep {
  my ($self, $cfg_lines) = @_;

  my $rc = 1;

  # EXCL_DEP, EXE_DEP and BLOCKDATA declarations
  # ----------------------------------------------------------------------------
  for my $name (qw/BLD_BLOCKDATA BLD_DEP BLD_DEP_EXCL BLD_DEP_EXE/) {
    for my $line (grep {$_->slabel_starts_with_cfg ($name)} @$cfg_lines) {
      # Separate label into a list, delimited by double-colon, remove 1st field
      my @flds = $line->slabel_fields;
      shift @flds;

      if ($name =~ /^(?:BLD_DEP|BLD_DEP_EXCL|BLD_DEP_PP)$/) {
        # BLD_DEP_*: label fields may contain sub-package
        my $pk = @flds ? join ('__', @flds) : '';

        # Check whether sub-package is valid
        if ($pk and not ($self->srcpkg ($pk) or $self->dummysrcpkg ($pk))) {
          $line->error ($line->label . ': invalid sub-package in declaration.');
          $rc = 0;
          next;
        }

        # Setting is stored in an array reference
        $self->setting ([$name, $pk], [])
          if not defined $self->setting ($name, $pk);

        # Add current declaration to the array if necessary
        my $list  = $self->setting ($name, $pk);
        my $value = $name eq 'BLD_DEP_EXCL' ? uc ($line->value) : $line->value;
        push @$list, $value if not grep {$_ eq $value} @$list;

      } else {
        # EXE_DEP and BLOCKDATA: label field may be an executable target
        my $target = @flds ? $flds[0] : '';

        # The value contains a list of objects and/or sub-package names
        my @deps   = split /\s+/, $line->value;

        if (not @deps) {
          if ($name eq 'BLD_BLOCKDATA') {
            # The objects containing a BLOCKDATA program unit must be declared
            $line->error ($line->label . ': value not set.');
            $rc = 0;
            next;

          } else {
            # If $value is a null string, target(s) depends on all objects
            push @deps, '';
          }
        }

        for my $dep (@deps) {
          $dep =~ s/$FCM1::Config::DELIMITER_PATTERN/__/g;
        }

        $self->setting ([$name, $target], join (' ', sort @deps));
      }

      $line->parsed (1);
    }
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->parse_cfg_dest (\@cfg_lines);
#
# DESCRIPTION
#   This method parses the build destination settings in the @cfg_lines.
# ------------------------------------------------------------------------------

sub parse_cfg_dest {
  my ($self, $cfg_lines) = @_;

  my $rc = $self->SUPER::parse_cfg_dest ($cfg_lines);

  # Set up search paths
  for my $name (@FCM1::Dest::paths) {
    (my $label = uc ($name)) =~ s/PATH//;

    $self->setting (['PATH', $label], $self->dest->$name);
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->parse_cfg_misc (\@cfg_lines);
#
# DESCRIPTION
#   This method parses misc build settings in the @cfg_lines.
# ------------------------------------------------------------------------------

sub parse_cfg_misc {
    my ($self, $cfg_lines_ref) = @_;
    my $rc = 1;
    my %item_of = (
        BLD_DEP_N    => [\&_parse_cfg_misc_dep_n   , 1   ], # boolean
        BLD_EXE_NAME => [\&_parse_cfg_misc_exe_name      ],
        BLD_LIB      => [\&_parse_cfg_misc_dep_n         ],
        BLD_PP       => [\&_parse_cfg_misc_dep_n   , 1   ], # boolean
        BLD_TYPE     => [\&_parse_cfg_misc_dep_n         ],
        INFILE_EXT   => [\&_parse_cfg_misc_file_ext, 0, 1], # uc($value)
        OUTFILE_EXT  => [\&_parse_cfg_misc_file_ext, 1, 0], # uc($ns)
    );
    while (my ($key, $item) = each(%item_of)) {
        my ($handler, @extra_arguments) = @{$item};
        for my $line (@{$cfg_lines_ref}) {
            if ($line->slabel_starts_with_cfg($key)) {
                if ($handler->($self, $key, $line, @extra_arguments)) {
                    $line->parsed(1);
                }
                else {
                    $rc = 0;
                }
            }
        }
    }
    return $rc;
}

# ------------------------------------------------------------------------------
# parse_cfg_misc: handler of BLD_EXE_NAME or similar.
sub _parse_cfg_misc_exe_name {
    my ($self, $key, $line) = @_;
    my ($prefix, $name, @fields) = $line->slabel_fields();
    if (!$name || @fields) {
        $line->error(sprintf('%s: expects a single label name field.', $key));
        return 0;
    }
    $self->setting([$key, $name], $line->value());
    return 1;
}

# ------------------------------------------------------------------------------
# parse_cfg_misc: handler of BLD_DEP_N or similar.
sub _parse_cfg_misc_dep_n {
    my ($self, $key, $line, $value_is_boolean) = @_;
    my ($prefix, @fields) = $line->slabel_fields();
    my $ns = @fields ? join(q{__}, @fields) : q{};
    if ($ns && !$self->srcpkg($ns) && !$self->dummysrcpkg($ns)) {
        $line->error($line->label() . ': invalid sub-package in declaration.');
        return 0;
    }
    my @srcpkgs
        = $self->dummysrcpkg($ns) ? @{$self->dummysrcpkg($ns)->children()}
        :                           $self->srcpkg($ns)
        ;
    my $value = $value_is_boolean ? $line->bvalue() : $line->value();
    for my $srcpkg (@srcpkgs) {
        $self->setting([$key, $srcpkg->pkgname()], $value);
    }
    return 1;
}

# ------------------------------------------------------------------------------
# parse_cfg_misc: handler of INFILE_EXT/OUTFILE_EXT or similar.
sub _parse_cfg_misc_file_ext {
    my ($self, $key, $line, $ns_in_uc, $value_in_uc) = @_;
    my ($prefix, $ns) = $line->slabel_fields();
    my $value = $value_in_uc ? uc($line->value()) : $line->value();
    $self->setting([$key, ($ns_in_uc ? uc($ns) : $ns)], $value);
    return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->parse_cfg_source (\@cfg_lines);
#
# DESCRIPTION
#   This method parses the source package settings in the @cfg_lines.
# ------------------------------------------------------------------------------

sub parse_cfg_source {
  my ($self, $cfg_lines) = @_;

  my $rc  = 1;
  my %src = ();

  # Automatic source directory search?
  # ----------------------------------------------------------------------------
  my $search = 1;

  for my $line (grep {$_->slabel_starts_with_cfg ('SEARCH_SRC')} @$cfg_lines) {
    $search = $line->bvalue;
    $line->parsed (1);
  }

  # Search src/ sub-directory if necessary
  %src = %{ $self->dest->get_source_files } if $search;

  # SRC declarations
  # ----------------------------------------------------------------------------
  for my $line (grep {$_->slabel_starts_with_cfg ('FILE')} @$cfg_lines) {
    # Expand ~ notation and path relative to srcdir of destination
    my $value = $line->value;
    $value = File::Spec->rel2abs (&expand_tilde ($value), $self->dest->srcdir);

    if (! -e $value) {
      $line->error ($value . ': source does not exist or is not readable.');
      next;
    }

    # Package name
    my @names = $line->slabel_fields;
    shift @names;

    # If package name not set, determine using the path if possible
    if (not @names) {
      my $package = $self->dest->get_pkgname_of_path ($value);
      @names = @$package if defined $package;
    }

    if (not @names) {
      $line->error ($self->cfglabel ('FILE') .
                    ': package not specified/cannot be determined.');
      next;
    }

    $src{join ('__', @names)} = $value;

    $line->parsed (1);
  }

  # For directories, get non-recursive file listing, and add to %src
  # ----------------------------------------------------------------------------
  for my $key (keys %src) {
    next unless -d $src{$key};

    opendir DIR, $src{$key} or die $src{$key}, ': cannot read directory';
    while (my $base = readdir 'DIR') {
      next if $base =~ /^\./;

      my $file = File::Spec->catfile ($src{$key}, $base);
      next if ! -f $file;

      my $name = join ('__', ($key, $base));
      $src{$name} = $file unless exists $src{$name};
    }
    closedir DIR;

    delete $src{$key};
  }

  # Set up source packages
  # ----------------------------------------------------------------------------
  my %pkg = ();
  for my $name (keys %src) {
    $pkg{$name} = FCM1::BuildSrc->new (PKGNAME => $name, SRC => $src{$name});
  }

  # INHERIT::SRC declarations
  # ----------------------------------------------------------------------------
  my %can_inherit = ();
  for my $line (
    grep {$_->slabel_starts_with_cfg(qw/INHERIT FILE/)} @{$cfg_lines}
  ) {
    my ($key1, $key2, @ns) = $line->slabel_fields();
    $can_inherit{join('__', @ns)} = $line->bvalue();
    $line->parsed(1);
  }

  # Inherit packages, if it is OK to do so
  for my $inherited_build (reverse(@{$self->inherit()})) {
    SRCPKG:
    while (my ($key, $srcpkg) = each(%{$inherited_build->srcpkg()})) {
      if (exists($pkg{$key}) || !$srcpkg->src()) {
        next SRCPKG;
      }
      my $known_key = first {exists($can_inherit{$_})} @{$srcpkg->pkgnames()};
      if (defined($known_key) && !$can_inherit{$known_key}) {
        next SRCPKG;
      }
      $pkg{$key} = $srcpkg;
    }
  }

  # Get list of intermediate "packages"
  # ----------------------------------------------------------------------------
  for my $name (keys %pkg) {
    # Name of current package
    my @names = split /__/, $name;

    my $cur = $name;

    while ($cur) {
      # Name of parent package
      pop @names;
      my $parent = @names ? join ('__', @names) : '';

      # If parent package does not exist, create it
      $pkg{$parent} = FCM1::BuildSrc->new (PKGNAME => $parent)
        unless exists $pkg{$parent};

      # Current package is a child of the parent package
      push @{ $pkg{$parent}->children }, $pkg{$cur}
        unless grep {$_->pkgname eq $cur} @{ $pkg{$parent}->children };

      # Go up a package
      $cur = $parent;
    }
  }

  $self->srcpkg (\%pkg);

  # Dummy: e.g. "foo/bar/baz.egg" belongs to the "foo/bar/baz" dummy.
  # ----------------------------------------------------------------------------
  SRCPKG:
  while (my ($name, $srcpkg) = each(%pkg)) {
    if (!$srcpkg->src()) { # ensure that $srcpkg represents a source file
      next SRCPKG;
    }
    my @names = split('__', $name);
    if (@names) {
      $names[-1] =~ s{\.\w+ \z}{}msx;
    }
    my $dummy_name = join('__', @names);
    if ($dummy_name eq $name || defined($self->srcpkg($dummy_name))) {
      next SRCPKG;
    }
    if (!defined($self->dummysrcpkg($dummy_name))) {
      $self->dummysrcpkg($dummy_name, FCM1::BuildSrc->new(PKGNAME => $dummy_name));
    }
    push(@{$self->dummysrcpkg($dummy_name)->children()}, $srcpkg);
  }

  # Make sure a package is defined
  # ----------------------------------------------------------------------------
  if (not %{$self->srcpkg}) {
    w_report 'ERROR: ', $self->cfg->actual_src, ': no source file to build.';
    $rc = 0;
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->parse_cfg_target (\@cfg_lines);
#
# DESCRIPTION
#   This method parses the target settings in the @cfg_lines.
# ------------------------------------------------------------------------------

sub parse_cfg_target {
  my ($self, $cfg_lines) = @_;

  # NAME declaraions
  # ----------------------------------------------------------------------------
  for my $line (grep {$_->slabel_starts_with_cfg ('NAME')} @$cfg_lines) {
    $self->name ($line->value);
    $line->parsed (1);
  }

  # TARGET declarations
  # ----------------------------------------------------------------------------
  for my $line (grep {$_->slabel_starts_with_cfg ('TARGET')} @$cfg_lines) {
    # Value is a space delimited list
    push @{ $self->target }, split (/\s+/, $line->value);
    $line->parsed (1);
  }

  # INHERIT::TARGET declarations
  # ----------------------------------------------------------------------------
  # By default, do not inherit target
  my $inherit_flag = 0;

  for (grep {$_->slabel_starts_with_cfg (qw/INHERIT TARGET/)} @$cfg_lines) {
    $inherit_flag = $_->bvalue;
    $_->parsed (1);
  }

  # Inherit targets from inherited build, if $inherit_flag is set to true
  # ----------------------------------------------------------------------------
  if ($inherit_flag) {
    for my $use (reverse @{ $self->inherit }) {
      unshift @{ $self->target }, @{ $use->target };
    }
  }

  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->parse_cfg_tool (\@cfg_lines);
#
# DESCRIPTION
#   This method parses the tool settings in the @cfg_lines.
# ------------------------------------------------------------------------------

sub parse_cfg_tool {
  my ($self, $cfg_lines) = @_;

  my $rc = 1;

  my %tools         = %{ $self->setting ('TOOL') };
  my @package_tools = split(/$DELIMITER_LIST/, $self->setting('TOOL_PACKAGE'));

  # TOOL declaration
  # ----------------------------------------------------------------------------
  for my $line (grep {$_->slabel_starts_with_cfg ('TOOL')} @$cfg_lines) {
    # Separate label into a list, delimited by double-colon, remove TOOL
    my @flds = $line->slabel_fields;
    shift @flds;

    # Check that there is a field after TOOL
    if (not @flds) {
      $line->error ('TOOL: not followed by a valid label.');
      $rc = 0;
      next;
    }

    # The first field is the tool iteself, identified in uppercase
    $flds[0] = uc ($flds[0]);

    # Check that the tool is recognised
    if (not exists $tools{$flds[0]}) {
      $line->error ($flds[0] . ': not a valid TOOL.');
      $rc = 0;
      next;
    }

    # Check sub-package declaration
    if (@flds > 1 and not grep {$_ eq $flds[0]} @package_tools) {
      $line->error ($flds[0] . ': sub-package not accepted with this TOOL.');
      $rc = 0;
      next;
    }

    # Name of declared package
    my $pk = join ('__', @flds[1 .. $#flds]);

    # Check whether package exists
    if (not ($self->srcpkg ($pk) or $self->dummysrcpkg ($pk))) {
      $line->error ($line->label . ': invalid sub-package in declaration.');
      $rc = 0;
      next;
    }

    $self->setting (['TOOL', join ('__', @flds)], $line->value);
    $line->parsed (1);
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = $self->_write_makefile_perl5lib ();
#
# DESCRIPTION
#   This method returns a makefile $string for defining $PERL5LIB.
# ------------------------------------------------------------------------------

sub _write_makefile_perl5lib {
  my $self = shift;

  my $classpath = File::Spec->catfile (split (/::/, ref ($self))) . '.pm';

  my $libdir  = dirname (dirname ($INC{$classpath}));
  my @libpath = split (/:/, (exists $ENV{PERL5LIB} ? $ENV{PERL5LIB} : ''));

  my $string = ((grep {$_ eq $libdir} @libpath)
                ? ''
                : 'export PERL5LIB := ' . $libdir .
                  (exists $ENV{PERL5LIB} ? ':$(PERL5LIB)' : '') . "\n\n");

  return $string;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = $self->_write_makefile_target ();
#
# DESCRIPTION
#   This method returns a makefile $string for defining the default targets.
# ------------------------------------------------------------------------------

sub _write_makefile_target {
  my $self = shift;

  # Targets of the build
  # ----------------------------------------------------------------------------
  my @targets = @{ $self->target };
  if (not @targets) {
    # Build targets not specified by user, default to building all main programs
    my @programs = ();

    # Get all main programs from all packages
    for my $pkg (values %{ $self->srcpkg }) {
      push @programs, $pkg->exebase if $pkg->exebase;
    }

    @programs = sort (@programs);

    if (@programs) {
      # Build main programs, if there are any
      @targets = @programs;

    } else {
      # No main program in source tree, build the default library
      @targets = ($self->srcpkg ('')->libbase);
    }
  }

  my $return = 'FCM_BLD_TARGETS = ' . join (' ', @targets) . "\n\n";

  # Default targets
  $return .= '.PHONY : all' . "\n\n";
  $return .= 'all : $(FCM_BLD_TARGETS)' . "\n\n";

  # Targets for copy dummy
  $return .= sprintf("%s:\n\ttouch \$@\n\n", $self->setting(qw/BLD_CPDUMMY/));

  return $return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = $self->_write_makefile_tool ();
#
# DESCRIPTION
#   This method returns a makefile $string for defining the build tools.
# ------------------------------------------------------------------------------

sub _write_makefile_tool {
  my $self = shift;

  # List of build tools
  my $tool = $self->setting ('TOOL');

  # List of tools local to FCM, (will not be exported)
  my %localtool = map {($_, 1)} split ( # map into a hash table
    /$DELIMITER_LIST/, $self->setting ('TOOL_LOCAL'),
  );

  # Export required tools
  my $count = 0;
  my $return = '';
  for my $name (sort keys %$tool) {
    # Ignore local tools
    next if exists $localtool{(split (/__/, $name))[0]};

    if ($name =~ /^\w+$/) {
      # Tools with normal name, just export it as an environment variable
      $return .= 'export ' . $name . ' = ' . $tool->{$name} . "\n";

    } else {
      # Tools with unusual characters, export using a label/value pair
      $return .= 'export FCM_UNUSUAL_TOOL_LABEL' . $count . ' = ' . $name . "\n";
      $return .= 'export FCM_UNUSUAL_TOOL_VALUE' . $count . ' = ' .
                 $tool->{$name} . "\n";
      $count++;
    }
  }

  $return .= "\n";

  return $return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = $self->_write_makefile_vpath ();
#
# DESCRIPTION
#   This method returns a makefile $string for defining vpath directives.
# ------------------------------------------------------------------------------

sub _write_makefile_vpath {
  my $self = shift();
  my $FMT = 'vpath %%%s $(FCM_%sPATH)';
  my %SETTING_OF = %{$self->setting('BLD_VPATH')};
  my %EXT_OF = %{$self->setting('OUTFILE_EXT')};
  # Note: each setting can be either an empty string or a comma-separated list
  # of output file extension keys.
  join(
    "\n",
    (
      map
      {
        my $key = $_;
        my @types = split(qr{$DELIMITER_LIST}msx, $SETTING_OF{$key});
          @types ? (map {sprintf($FMT, $EXT_OF{$_}, $key)} sort @types)
        :          sprintf($FMT, q{}, $key)
        ;
      }
      sort keys(%SETTING_OF)
    ),
  ) . "\n\n";
}

# Wraps chdir. Returns the old working directory.
sub _chdir {
  my ($self, $path) = @_;
  if ($self->verbose() >= 3) {
    printf("cd %s\n", $path);
  }
  my $old_cwd = cwd();
  chdir($path) || croak(sprintf("%s: cannot change directory ($!)\n", $path));
  $old_cwd;
}

# ------------------------------------------------------------------------------

1;

__END__
