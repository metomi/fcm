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
#   FCM1::Config
#
# DESCRIPTION
#   This is a class for reading and processing central and user configuration
#   settings for FCM.
#
# ------------------------------------------------------------------------------

package FCM1::Config;

# Standard pragma
use warnings;
use strict;

# Standard modules
use File::Basename;
use File::Spec::Functions;
use FindBin;
use POSIX qw/setlocale LC_ALL/;

# FCM component modules
use FCM1::CfgFile;

# Other declarations:
sub _get_hash_value;

# Delimiter for setting and for list
our $DELIMITER         = '::';
our $DELIMITER_PATTERN = qr{::|/};
our $DELIMITER_LIST    = ',';

my $INSTANCE;

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $config = FCM1::Config->instance();
#
# DESCRIPTION
#   Returns an instance of this class.
# ------------------------------------------------------------------------------

sub instance {
    my ($class) = @_;
    if (!defined($INSTANCE)) {
        $INSTANCE = $class->new();
        $INSTANCE->get_config();
        $INSTANCE->is_initialising(0);
    }
    return $INSTANCE;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $obj = FCM1::Config->new (VERBOSE => $verbose);
#
# DESCRIPTION
#   This method constructs a new instance of the FCM1::Config class.
#
# ARGUMENTS
#   VERBOSE - Set the verbose level of diagnostic output
# ------------------------------------------------------------------------------

sub new {
  my $this  = shift;
  my %args  = @_;
  my $class = ref $this || $this;

  # Ensure that all subsequent Subversion output is in UK English
  if (setlocale (LC_ALL, 'en_GB')) {
    $ENV{LANG} = 'en_GB';
  }

  my $self = {
    initialising   => 1,
    central_config => undef,
    user_config    => undef,
    user_id        => undef,
    verbose        => exists $args{VERBOSE} ? $args{VERBOSE} : undef,
    variable       => {},

    # Primary settings
    setting => {
      # Fortran BLOCKDATA dependencies
      BLD_BLOCKDATA => {},

      # Copy dummy target
      BLD_CPDUMMY => '$(FCM_DONEDIR)/FCM_CP.dummy',

      # No dependency check
      BLD_DEP_N => {},

      # Additional (PP) dependencies
      BLD_DEP => {},
      BLD_DEP_PP => {},

      # Excluded dependency
      BLD_DEP_EXCL => {
        '' => [
          # Fortran intrinsic modules
          'USE' . $DELIMITER . 'ISO_C_BINDING',
          'USE' . $DELIMITER . 'IEEE_EXCEPTIONS',
          'USE' . $DELIMITER . 'IEEE_ARITHMETIC',
          'USE' . $DELIMITER . 'IEEE_FEATURES',

          # Fortran intrinsic subroutines
          'OBJ' . $DELIMITER . 'CPU_TIME',
          'OBJ' . $DELIMITER . 'GET_COMMAND',
          'OBJ' . $DELIMITER . 'GET_COMMAND_ARGUMENT',
          'OBJ' . $DELIMITER . 'GET_ENVIRONMENT_VARIABLE',
          'OBJ' . $DELIMITER . 'MOVE_ALLOC',
          'OBJ' . $DELIMITER . 'MVBITS',
          'OBJ' . $DELIMITER . 'RANDOM_NUMBER',
          'OBJ' . $DELIMITER . 'RANDOM_SEED',
          'OBJ' . $DELIMITER . 'SYSTEM_CLOCK',

          # Dummy statements
          'OBJ' . $DELIMITER . 'NONE',
          'EXE' . $DELIMITER . 'NONE',
        ],
      },

      # Extra executable dependencies
      BLD_DEP_EXE => {},

      # Dependency pattern for each type
      BLD_DEP_PATTERN => {
        H         => q/^#\s*include\s*['"](\S+)['"]/,
        USE       => q/^\s*use\s+(\w+)/,
        INTERFACE => q/^#?\s*include\s+['"](\S+##OUTFILE_EXT/ . $DELIMITER .
                     q/INTERFACE##)['"]/,
        INC       => q/^\s*include\s+['"](\S+)['"]/,
        OBJ       => q#^\s*(?:/\*|!)\s*depends\s*on\s*:\s*(\S+)#,
        EXE       => q/^\s*(?:#|;)\s*(?:calls|list|if|interface)\s*:\s*(\S+)/,
      },

      # Rename main program targets
      BLD_EXE_NAME => {},

      # Rename library targets
      BLD_LIB => {'' => 'fcm_default'},

      # Name of Makefile and run environment shell script
      BLD_MISC => {
        'BLDMAKEFILE' => 'Makefile',
        'BLDRUNENVSH' => 'fcm_env.sh',
      },

      # PP flags
      BLD_PP => {},

      # Custom source file type
      BLD_TYPE => {},

      # Types that always need to be built
      BLD_TYPE_ALWAYS_BUILD =>                   'PVWAVE' .
                               $DELIMITER_LIST . 'GENLIST' .
                               $DELIMITER_LIST . 'SQL',

      # Dependency scan types
      BLD_TYPE_DEP => {
        FORTRAN =>              'USE' .
                   $DELIMITER . 'INTERFACE' .
                   $DELIMITER . 'INC' .
                   $DELIMITER . 'OBJ',
        FPP     =>              'USE' .
                   $DELIMITER . 'INTERFACE' .
                   $DELIMITER . 'INC' .
                   $DELIMITER . 'H' .
                   $DELIMITER . 'OBJ',
        CPP     =>              'H' .
                   $DELIMITER . 'OBJ',
        C       =>              'H' .
                   $DELIMITER . 'OBJ',
        SCRIPT  =>              'EXE',
      },

      # Dependency scan types for pre-processing
      BLD_TYPE_DEP_PP => {
        FPP => 'H',
        CPP => 'H',
        C   => 'H',
      },

      # Types that cannot have duplicated targets
      BLD_TYPE_NO_DUPLICATED_TARGET => '',

      # BLD_VPATH, each value must be a comma separate list
      # ''     translates to %
      # 'FLAG' translates to {OUTFILE_EXT}{FLAG}
      BLD_VPATH   => {
        BIN   => q{},
        ETC   => 'ETC',
        DONE  => join($DELIMITER_LIST, qw{DONE IDONE}),
        FLAGS => 'FLAGS',
        INC   => q{},
        LIB   => 'LIB',
        OBJ   => 'OBJ',
      },

      # Cache basename
      CACHE          => '.config',
      CACHE_DEP      => '.config_dep',
      CACHE_DEP_PP   => '.config_dep_pp',
      CACHE_FILE_SRC => '.config_file_src',

      # Types of "inc" statements expandable CFG files
      CFG_EXP_INC =>                   'BLD' .
                     $DELIMITER_LIST . 'EXT' .
                     $DELIMITER_LIST . 'FCM',

      # Configuration file labels that can be declared more than once
      CFG_KEYWORD =>                   'USE' .
                     $DELIMITER_LIST . 'INC' .
                     $DELIMITER_LIST . 'TARGET' .
                     $DELIMITER_LIST . 'BLD_DEP_EXCL',

      # Labels for all types of FCM configuration files
      CFG_LABEL => {
        CFGFILE => 'CFG', # config file information
        INC     => 'INC', # "include" from an configuration file

        # Labels for central/user internal config setting
        SETTING => 'SET',

        # Labels for systems that allow inheritance
        DEST => 'DEST', # destination
        USE  => 'USE',  # use (inherit) a previous configuration

        # Labels for bld and pck cfg
        TARGET => 'TARGET', # BLD: declare targets, PCK: target of source file

        # Labels for bld cfg
        BLD_BLOCKDATA => 'BLOCKDATA',   # declare Fortran BLOCKDATA dependencies
        BLD_DEP       => 'DEP',         # additional dependencies
        BLD_DEP_N     => 'NO_DEP',      # no dependency check
        BLD_DEP_EXCL  => 'EXCL_DEP',    # exclude automatic dependencies
        BLD_DEP_EXE   => 'EXE_DEP',     # declare dependencies for program
        BLD_EXE_NAME  => 'EXE_NAME',    # rename a main program
        BLD_LIB       => 'LIB',         # rename library
        BLD_PP        => 'PP',          # sub-package needs pre-process?
        BLD_TYPE      => 'SRC_TYPE',    # custom source file type
        DIR           => 'DIR',         # DEPRECATED, same as DEST
        INFILE_EXT    => 'INFILE_EXT',  # change input file name extension type
        INHERIT       => 'INHERIT',     # inheritance flag
        NAME          => 'NAME',        # name the build
        OUTFILE_EXT   => 'OUTFILE_EXT', # change output file type extension
        FILE          => 'SRC',         # declare a sub-package
        SEARCH_SRC    => 'SEARCH_SRC',  # search src/ sub-directory?
        TOOL          => 'TOOL',        # declare a tool

        # Labels for ext cfg
        BDECLARE   => 'BLD',      # build declaration
        CONFLICT   => 'CONFLICT', # set conflict mode
        DIRS       => 'SRC',      # declare source directory
        EXPDIRS    => 'EXPSRC',   # declare expandable source directory
        MIRROR     => 'MIRROR',   # DEPRECATED, same as RDEST::MIRROR_CMD
        OVERRIDE   => 'OVERRIDE', # DEPRECATED, replaced by CONFLICT
        RDEST      => 'RDEST',    # declare remote destionation
        REVISION   => 'REVISION', # declare branch revision in a project
        REVMATCH   => 'REVMATCH', # branch revision must match changed revision
        REPOS      => 'REPOS',    # declare branch in a project
        VERSION    => 'VERSION',  # DEPRECATED, same as REVISION
      },

      # Default names of known FCM configuration files
      CFG_NAME => {
        BLD        => 'bld.cfg',      # build configuration file
        EXT        => 'ext.cfg',      # extract configuration file
        PARSED     => 'parsed_',      # as-parsed configuration file prefix
      },

      # Latest version of known FCM configuration files
      CFG_VERSION => {
        BLD        => '1.0', # bld cfg
        EXT        => '1.0', # ext cfg
      },

      # Standard sub-directories for extract/build
      DIR => {
        BIN    => 'bin',    # executable
        BLD    => 'bld',    # build
        CACHE  => '.cache', # cache
        CFG    => 'cfg',    # configuration
        DONE   => 'done',   # "done"
        ETC    => 'etc',    # miscellaneous items
        FLAGS  => 'flags',  # "flags"
        INC    => 'inc',    # include
        LIB    => 'lib',    # library
        OBJ    => 'obj',    # object
        PPSRC  => 'ppsrc',  # pre-processed source
        SRC    => 'src',    # source
        TMP    => 'tmp',    # temporary directory
      },

      # A flag to indicate whether the revision of a given branch for extract
      # must match with the revision of a changed revision of the branch
      EXT_REVMATCH => 0, # default is false (allow any revision)

      # Input file name extension and type
      # (may overlap with output (below) and vpath (above))
      INFILE_EXT => {
        # General extensions
        'f'    =>              'FORTRAN' .
                  $DELIMITER . 'SOURCE',
        'for'  =>              'FORTRAN' .
                  $DELIMITER . 'SOURCE',
        'ftn'  =>              'FORTRAN' .
                  $DELIMITER . 'SOURCE',
        'f77'  =>              'FORTRAN' .
                  $DELIMITER . 'SOURCE',
        'f90'  =>              'FORTRAN' .
                  $DELIMITER . 'FORTRAN9X' .
                  $DELIMITER . 'SOURCE',
        'f95'  =>              'FORTRAN' .
                  $DELIMITER . 'FORTRAN9X' .
                  $DELIMITER . 'SOURCE',
        'F'    =>              'FPP' .
                  $DELIMITER . 'SOURCE',
        'FOR'  =>              'FPP' .
                  $DELIMITER . 'SOURCE',
        'FTN'  =>              'FPP' .
                  $DELIMITER . 'SOURCE',
        'F77'  =>              'FPP' .
                  $DELIMITER . 'SOURCE',
        'F90'  =>              'FPP' .
                  $DELIMITER . 'FPP9X' .
                  $DELIMITER . 'SOURCE',
        'F95'  =>              'FPP' .
                  $DELIMITER . 'FPP9X' .
                  $DELIMITER . 'SOURCE',
        'c'    =>              'C' .
                  $DELIMITER . 'SOURCE',
        'cpp'  =>              'C' .
                  $DELIMITER . 'C++' .
                  $DELIMITER . 'SOURCE',
        'h'    =>              'CPP' .
                  $DELIMITER . 'INCLUDE',
        'o'    =>              'BINARY' .
                  $DELIMITER . 'OBJ',
        'obj'  =>              'BINARY' .
                  $DELIMITER . 'OBJ',
        'exe'  =>              'BINARY' .
                  $DELIMITER . 'EXE',
        'a'    =>              'BINARY' .
                  $DELIMITER . 'LIB',
        'sh'   =>              'SCRIPT' .
                  $DELIMITER . 'SHELL',
        'ksh'  =>              'SCRIPT' .
                  $DELIMITER . 'SHELL',
        'bash' =>              'SCRIPT' .
                  $DELIMITER . 'SHELL',
        'csh'  =>              'SCRIPT' .
                  $DELIMITER . 'SHELL',
        'pl'   =>              'SCRIPT' .
                  $DELIMITER . 'PERL',
        'pm'   =>              'SCRIPT' .
                  $DELIMITER . 'PERL',
        'py'   =>              'SCRIPT' .
                  $DELIMITER . 'PYTHON',
        'tcl'  =>              'SCRIPT' .
                  $DELIMITER . 'TCL',
        'pro'  =>              'SCRIPT' .
                  $DELIMITER . 'PVWAVE',

        # Local extensions
        'cfg'       =>              'CFGFILE',
        'h90'       =>              'CPP' .
                       $DELIMITER . 'INCLUDE',
        'inc'       =>              'FORTRAN' .
                       $DELIMITER . 'FORTRAN9X' .
                       $DELIMITER . 'INCLUDE',
        'interface' =>              'FORTRAN' .
                       $DELIMITER . 'FORTRAN9X' .
                       $DELIMITER . 'INCLUDE' .
                       $DELIMITER . 'INTERFACE',
      },

      # Ignore input files matching the following names (comma-separated list)
      INFILE_IGNORE =>                   'fcm_env.ksh' .
                       $DELIMITER_LIST . 'fcm_env.sh',

      # Input file name pattern and type
      INFILE_PAT => {
        '\w+Scr_\w+'              =>              'SCRIPT' .
                                     $DELIMITER . 'SHELL',
        '\w+Comp_\w+'             =>              'SCRIPT' .
                                     $DELIMITER . 'SHELL' .
                                     $DELIMITER . 'GENTASK',
        '\w+(?:IF|Interface)_\w+' =>              'SCRIPT' .
                                     $DELIMITER . 'SHELL' .
                                     $DELIMITER . 'GENIF',
        '\w+Suite_\w+'            =>              'SCRIPT' .
                                     $DELIMITER . 'SHELL' .
                                     $DELIMITER . 'GENSUITE',
        '\w+List_\w+'             =>              'SCRIPT' .
                                     $DELIMITER . 'SHELL' .
                                     $DELIMITER . 'GENLIST',
        '\w+Sql_\w+'              =>              'SCRIPT' .
                                     $DELIMITER . 'SQL',
      },

      # Input text file pattern and type
      INFILE_TXT => {
        '(?:[ck]|ba)?sh'  =>              'SCRIPT' .
                             $DELIMITER . 'SHELL',
        'perl'            =>              'SCRIPT' .
                             $DELIMITER . 'PERL',
        'python'          =>              'SCRIPT' .
                             $DELIMITER . 'PYTHON',
        'tcl(?:sh)?|wish' =>              'SCRIPT' .
                             $DELIMITER . 'TCL',
      },

      # Lock file
      LOCK => {
        BLDLOCK => 'fcm.bld.lock', # build lock file
        EXTLOCK => 'fcm.ext.lock', # extract lock file
      },

      # Output file type and extension
      # (may overlap with input and vpath (above))
      OUTFILE_EXT => {
        CFG       => '.cfg',       # FCM configuration file
        DONE      => '.done',      # "done" files for compiled source
        ETC       => '.etc',       # "etc" dummy file
        EXE       => '.exe',       # binary executables
        FLAGS     => '.flags',     # "flags" files, compiler flags config
        IDONE     => '.idone',     # "done" files for included source
        INTERFACE => '.interface', # interface for F90 subroutines/functions
        LIB       => '.a',         # archive object library
        MOD       => '.mod',       # compiled Fortran module information files
        OBJ       => '.o',         # compiled object files
        PDONE     => '.pdone',     # "done" files for pre-processed files
        TAR       => '.tar',       # TAR archive
      },

      # Build commands and options (i.e. tools)
      TOOL => {
        SHELL        => '/bin/sh',         # Default shell

        CPP          => 'cpp',             # C pre-processor
        CPPFLAGS     => '-C',              # CPP flags
        CPP_INCLUDE  => '-I',              # CPP flag, specify "include" path
        CPP_DEFINE   => '-D',              # CPP flag, define macro
        CPPKEYS      => '',                # CPP keys (definition macro)

        CC           => 'cc',              # C compiler
        CFLAGS       => '',                # CC flags
        CC_COMPILE   => '-c',              # CC flag, compile only
        CC_OUTPUT    => '-o',              # CC flag, specify output file name
        CC_INCLUDE   => '-I',              # CC flag, specify "include" path
        CC_DEFINE    => '-D',              # CC flag, define macro

        FPP          => 'cpp',             # Fortran pre-processor
        FPPFLAGS     => '-P -traditional', # FPP flags
        FPP_INCLUDE  => '-I',              # FPP flag, specify "include" path
        FPP_DEFINE   => '-D',              # FPP flag, define macro
        FPPKEYS      => '',                # FPP keys (definition macro)

        FC           => 'f90',             # Fortran compiler
        FFLAGS       => '',                # FC flags
        FC_COMPILE   => '-c',              # FC flag, compile only
        FC_OUTPUT    => '-o',              # FC flag, specify output file name
        FC_INCLUDE   => '-I',              # FC flag, specify "include" path
        FC_MODSEARCH => '',                # FC flag, specify "module" path
        FC_DEFINE    => '-D',              # FC flag, define macro

        LD           => '',                # linker
        LDFLAGS      => '',                # LD flags
        LD_OUTPUT    => '-o',              # LD flag, specify output file name
        LD_LIBSEARCH => '-L',              # LD flag, specify "library" path
        LD_LIBLINK   => '-l',              # LD flag, specify link library

        AR           => 'ar',              # library archiver
        ARFLAGS      => 'rs',              # AR flags

        MAKE         => 'make',            # make command
        MAKEFLAGS    => '',                # make flags
        MAKE_FILE    => '-f',              # make flag, path to Makefile
        MAKE_SILENT  => '-s',              # make flag, silent diagnostic
        MAKE_JOB     => '-j',              # make flag, number of jobs

        INTERFACE    => 'file',            # name interface after file/program
        GENINTERFACE => '',                # Fortran 9x interface generator

        DIFF3        => 'diff3',           # extract diff3 merge
        DIFF3FLAGS   => '-E -m',           # DIFF3 flags
        GRAPHIC_DIFF => 'xxdiff',          # graphical diff tool
        GRAPHIC_MERGE=> 'xxdiff',          # graphical merge tool
      },

      # List of tools that are local to FCM, (will not be exported to a Makefile)
      TOOL_LOCAL =>                   'CPP' .
                    $DELIMITER_LIST . 'CPPFLAGS' .
                    $DELIMITER_LIST . 'CPP_INCLUDE' .
                    $DELIMITER_LIST . 'CPP_DEFINE' .
                    $DELIMITER_LIST . 'DIFF3' .
                    $DELIMITER_LIST . 'DIFF3_FLAGS' .
                    $DELIMITER_LIST . 'FPP' .
                    $DELIMITER_LIST . 'FPPFLAGS' .
                    $DELIMITER_LIST . 'FPP_INCLUDE' .
                    $DELIMITER_LIST . 'FPP_DEFINE' .
                    $DELIMITER_LIST . 'GRAPHIC_DIFF' .
                    $DELIMITER_LIST . 'GRAPHIC_MERGE' .
                    $DELIMITER_LIST . 'MAKE' .
                    $DELIMITER_LIST . 'MAKEFLAGS' .
                    $DELIMITER_LIST . 'MAKE_FILE' .
                    $DELIMITER_LIST . 'MAKE_SILENT' .
                    $DELIMITER_LIST . 'MAKE_JOB' .
                    $DELIMITER_LIST . 'INTERFACE' .
                    $DELIMITER_LIST . 'GENINTERFACE' .
                    $DELIMITER_LIST . 'MIRROR' .
                    $DELIMITER_LIST . 'REMOTE_SHELL',

      # List of tools that allow sub-package declarations
      TOOL_PACKAGE =>                   'CPPFLAGS' .
                      $DELIMITER_LIST . 'CPPKEYS' .
                      $DELIMITER_LIST . 'CFLAGS' .
                      $DELIMITER_LIST . 'FPPFLAGS' .
                      $DELIMITER_LIST . 'FPPKEYS' .
                      $DELIMITER_LIST . 'FFLAGS' .
                      $DELIMITER_LIST . 'LD' .
                      $DELIMITER_LIST . 'LDFLAGS' .
                      $DELIMITER_LIST . 'INTERFACE' .
                      $DELIMITER_LIST . 'GENINTERFACE',

      # Supported tools for compilable source
      TOOL_SRC_PP => {
        FPP     => {
          COMMAND => 'FPP',
          FLAGS   => 'FPPFLAGS',
          PPKEYS  => 'FPPKEYS',
          INCLUDE => 'FPP_INCLUDE',
          DEFINE  => 'FPP_DEFINE',
        },

        C       => {
          COMMAND => 'CPP',
          FLAGS   => 'CPPFLAGS',
          PPKEYS  => 'CPPKEYS',
          INCLUDE => 'CPP_INCLUDE',
          DEFINE  => 'CPP_DEFINE',
        },
      },

      # Supported tools for compilable source
      TOOL_SRC => {
        FORTRAN => {
          COMMAND => 'FC',
          FLAGS   => 'FFLAGS',
          OUTPUT  => 'FC_OUTPUT',
          INCLUDE => 'FC_INCLUDE',
        },

        FPP     => {
          COMMAND => 'FC',
          FLAGS   => 'FFLAGS',
          PPKEYS  => 'FPPKEYS',
          OUTPUT  => 'FC_OUTPUT',
          INCLUDE => 'FC_INCLUDE',
          DEFINE  => 'FC_DEFINE',
        },

        C       => {
          COMMAND => 'CC',
          FLAGS   => 'CFLAGS',
          PPKEYS  => 'CPPKEYS',
          OUTPUT  => 'CC_OUTPUT',
          INCLUDE => 'CC_INCLUDE',
          DEFINE  => 'CC_DEFINE',
        },
      },

      # FCM URL keyword and prefix, FCM revision keyword, and FCM Trac URL
      URL          => {},
      URL_REVISION => {},

      URL_BROWSER_MAPPING => {},
      URL_BROWSER_MAPPING_DEFAULT => {
        LOCATION_COMPONENT_PATTERN
        => qr{\A // ([^/]+) /+ ([^/]+)_svn /+(.*) \z}xms,
        BROWSER_URL_TEMPLATE
        => 'http://{1}/projects/{2}/intertrac/source:{3}{4}',
        BROWSER_REV_TEMPLATE => '@{1}',
      },

      # Default web browser
      WEB_BROWSER   => 'firefox',
    },
  };

  # Backward compatibility: the REPOS setting is equivalent to the URL setting
  $self->{setting}{REPOS} = $self->{setting}{URL};

  # Alias the REVISION and TRAC setting to URL_REVISION and URL_TRAC
  $self->{setting}{REVISION} = $self->{setting}{URL_REVISION};

  bless $self, $class;
  return $self;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $value = $obj->X;
#   $obj->X ($value);
#
# DESCRIPTION
#   Details of these properties are explained in the "new" method.
# ------------------------------------------------------------------------------

for my $name (qw/central_config user_config user_id verbose/) {
  no strict 'refs';

  *$name = sub {
    my $self = shift;

    # Argument specified, set property to specified argument
    if (@_) {
      $self->{$name} = $_[0];
    }

    # Default value for property
    if (not defined $self->{$name}) {
      if ($name eq 'central_config') {
        # Central configuration file
        if (-f catfile (dirname ($FindBin::Bin), 'etc', 'fcm.cfg')) {
          $self->{$name} = catfile (
            dirname ($FindBin::Bin), 'etc', 'fcm.cfg'
          );

        } elsif (-f catfile ($FindBin::Bin, 'fcm.cfg')) {
          $self->{$name} = catfile ($FindBin::Bin, 'fcm.cfg');
        }

      } elsif ($name eq 'user_config') {
        # User configuration file
        my $home = (getpwuid ($<))[7];
        $home = $ENV{HOME} if not defined $home;
        $self->{$name} = catfile ($home, '.fcm')
          if defined ($home) and -f catfile ($home, '.fcm');

      } elsif ($name eq 'user_id') {
        # User ID of current process
        my $user = (getpwuid ($<))[0];
        $user = $ENV{LOGNAME} if not defined $user;
        $user = $ENV{USER} if not defined $user;
        $self->{$name} = $user;

      } elsif ($name eq 'verbose') {
        # Verbose mode
        $self->{$name} = exists $ENV{FCM_VERBOSE} ? $ENV{FCM_VERBOSE} : 1;
      }
    }

    return $self->{$name};
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $flag = $obj->is_initialising();
#
# DESCRIPTION
#   Returns true if this object is initialising.
# ------------------------------------------------------------------------------
sub is_initialising {
  my ($self, $value) = @_;
  if (defined($value)) {
    $self->{initialising} = $value;
  }
  return $self->{initialising};
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
#   Details of these properties are explained in the "new" method.
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

for my $name (qw/variable/) {
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
#   $setting = $obj->setting (@labels);
#   $obj->setting (\@labels, $setting);
#
# DESCRIPTION
#   This method returns/sets an item under the setting hash table. The depth
#   within the hash table is given by the list of arguments @labels, which
#   should match with the keys in the multi-dimension setting hash table.
# ------------------------------------------------------------------------------

sub setting {
  my $self = shift;

  if (@_) {
    my $arg1 = shift;
    my $s    = $self->{setting};

    if (ref ($arg1) eq 'ARRAY') {
      # Assign setting
      # ------------------------------------------------------------------------
      my $value = shift;

      while (defined (my $label = shift @$arg1)) {
        if (exists $s->{$label}) {
          if (ref $s->{$label} eq 'HASH') {
            $s = $s->{$label};

          } else {
            $s->{$label} = $value;
            last;
          }

        } else {
          if (@$arg1) {
            $s->{$label} = {};
            $s           = $s->{$label};

          } else {
            $s->{$label} = $value;
          }
        }
      }

    } else {
      # Get setting
      # ------------------------------------------------------------------------
      return _get_hash_value ($s->{$arg1}, @_) if exists $s->{$arg1};
    }
  }

  return undef;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $obj->get_config ();
#
# DESCRIPTION
#   This method reads the configuration settings from the central and the user
#   configuration files.
# ------------------------------------------------------------------------------

sub get_config {
  my $self = shift;

  $self->_read_config_file ($self->central_config);  
  $self->_read_config_file ($self->user_config);

  return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $obj->_read_config_file ();
#
# DESCRIPTION
#   This internal method reads a configuration file and assign values to the
#   attributes of the current instance.
# ------------------------------------------------------------------------------

sub _read_config_file {
  my $self        = shift;
  my $config_file = $_[0];

  if (!$config_file || !-f $config_file) {
    return;
  }

  my $cfgfile = FCM1::CfgFile->new (SRC => $config_file, TYPE => 'FCM');
  $cfgfile->read_cfg ();

  LINE: for my $line (@{ $cfgfile->lines }) {
    next unless $line->label;

    # "Environment variables" start with $
    if ($line->label =~ /^\$([A-Za-z_]\w*)$/) {
      $ENV{$1} = $line->value;
      next LINE;
    }

    # "Settings variables" start with "set"
    if ($line->label_starts_with_cfg ('SETTING')) {
      my @tags = $line->label_fields;
      shift @tags;
      @tags = map {uc} @tags;
      $self->setting (\@tags, $line->value);
      next LINE;
    }

    # Not a standard setting variable, put in internal variable list
    (my $label = $line->label) =~ s/^\%//;
    $self->variable ($label, $line->value);
  }

  1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $ref = _get_hash_value (arg1, arg2, ...);
#
# DESCRIPTION
#   This internal method recursively gets a value from a multi-dimensional
#   hash.
# ------------------------------------------------------------------------------

sub _get_hash_value {
  my $value = shift;

  while (defined (my $arg = shift)) {
    if (exists $value->{$arg}) {
      $value = $value->{$arg};

    } else {
      return undef;
    }
  }

  return $value;
}

# ------------------------------------------------------------------------------

1;

__END__
