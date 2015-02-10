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
#   FCM1::CfgFile
#
# DESCRIPTION
#   This class is used for reading and writing FCM config files. A FCM config
#   file is a line-based text file that provides information on how to perform
#   a particular task using the FCM system.
#
# ------------------------------------------------------------------------------

package FCM1::CfgFile;
@ISA = qw(FCM1::Base);

# Standard pragma
use warnings;
use strict;

# Standard modules
use Carp;
use File::Basename;
use File::Path;
use File::Spec;

# FCM component modules
use FCM1::Base;
use FCM1::CfgLine;
use FCM1::Config;
use FCM1::Keyword;
use FCM1::Util;

# List of property methods for this class
my @scalar_properties = (
  'actual_src', # actual source of configuration file
  'lines',      # list of lines, FCM1::CfgLine objects
  'pegrev',     # peg revision of configuration file
  'src',        # source of configuration file
  'type',       # type of configuration file
  'version',    # version of configuration file
);

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $obj = FCM1::CfgFile->new (%args);
#
# DESCRIPTION
#   This method constructs a new instance of the FCM1::CfgFile class. See above
#   for allowed list of properties. (KEYS should be in uppercase.)
# ------------------------------------------------------------------------------

sub new {
  my $this  = shift;
  my %args  = @_;
  my $class = ref $this || $this;

  my $self = FCM1::Base->new (%args);

  bless $self, $class;

  for (@scalar_properties) {
    $self->{$_} = exists $args{uc ($_)} ? $args{uc ($_)} : undef;
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

    if (@_) {
      $self->{$name} = $_[0];
    }

    if (not defined $self->{$name}) {
      if ($name eq 'lines') {
        $self->{$name} = [];
      }
    }

    return $self->{$name};
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $mtime = $obj->mtime ();
#
# DESCRIPTION
#   This method returns the modified time of the configuration file source.
# ------------------------------------------------------------------------------

sub mtime {
  my $self  = shift;
  my $mtime = undef;

  if (-f $self->src) {
    $mtime = (stat $self->src)[9];
  }

  return $mtime;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $read = $obj->read_cfg($is_for_inheritance);
#
# DESCRIPTION
#   This method reads the current configuration file. It returns the number of
#   lines read from the config file, or "undef" if it fails. The result is
#   placed in the LINES array of the current instance, and can be accessed via
#   the "lines" method.
# ------------------------------------------------------------------------------

sub read_cfg {
  my ($self, $is_for_inheritance) = @_;

  my @lines = $self->_get_cfg_lines($is_for_inheritance);

  # List of CFG types that need INC declarations expansion
  my %exp_inc    = ();
  for (split (/$FCM1::Config::DELIMITER_LIST/, $self->setting ('CFG_EXP_INC'))) {
    $exp_inc{uc ($_)} = 1;
  }

  # List of CFG labels that are reserved keywords
  my %cfg_keywords = ();
  for (split (/$FCM1::Config::DELIMITER_LIST/, $self->setting ('CFG_KEYWORD'))) {
    $cfg_keywords{$self->cfglabel ($_)} = 1;
  }

  # Loop each line, to separate lines into label : value pairs
  my $cont = undef;
  my $here = undef;
  for my $line_num (1 .. @lines) {
    my $line = $lines[$line_num - 1];
    chomp $line;

    my $label   = '';
    my $value   = '';
    my $comment = '';

    # If this line is a continuation, set $start to point to the line that
    # starts this continuation. Otherwise, set $start to undef
    my $start = defined ($cont) ? $self->lines->[$cont] : undef;
    my $warning = undef;

    if ($line =~ /^(\s*#.*)$/) { # comment line
      $comment = $1;

    } elsif ($line =~ /\S/) {    # non-blank line
      if (defined $cont) {
        # Previous line has a continuation mark
        $value = $line;

        # Separate value and comment
        if ($value =~ s/((?:\s+|^)#\s+.*)$//) {
          $comment = $1;
        }

        # Remove leading spaces
        $value =~ s/^\s*\\?//;

        # Expand environment variables
        my $warn;
        ($value, $warn) = $self->_expand_variable ($value, 1) if $value;
        $warning .= ($warning ? ', ' : '') . $warn if $warn;

        # Expand internal variables
        ($value, $warn) = $self->_expand_variable ($value, 0) if $value;
        $warning .= ($warning ? ', ' : '') . $warn if $warn;

        # Get "line" that begins the current continuation
        my $v = $start->value . $value;
        $v =~ s/\\$//;
        $start->value ($v);

      } else {
        # Previous line does not have a continuation mark
        if ($line =~ /^\s*(\S+)(?:\s+(.*))?$/) {
          # Check line contains a valid label:value pair
          $label = $1;
          $value = defined ($2) ? $2 : '';

          # Separate value and comment
          if ($value =~ s/((?:\s+|^)#\s+.*)$//) {
            $comment = $1;
          }

          # Remove trailing spaces
          $value =~ s/\s+$//;

          # Value begins with $HERE?
          $here  = ($value =~ /\$\{?HERE\}?(?:[^A-Z_]|$)/);

          # Expand environment variables
          my $warn;
          ($value, $warn) = $self->_expand_variable ($value, 1) if $value;
          $warning .= ($warning ? ', ' : '') . $warn if $warn;

          # Expand internal variables
          ($value, $warn) = $self->_expand_variable ($value, 0) if $value;
          $warning .= ($warning ? ', ' : '') . $warn if $warn;
        }
      }

      # Determine whether current line ends with a continuation mark
      if ($value =~ s/\\$//) {
        $cont = scalar (@{ $self->lines }) unless defined $cont;

      } else {
        $cont = undef;
      }
    }

    if (    defined($self->type())
        &&  exists($exp_inc{uc($self->type())})
        &&  uc($start ? $start->label() : $label) eq $self->cfglabel('INC')
        &&  !defined($cont)
    ) {
      # Current configuration file requires expansion of INC declarations
      # The start/current line is an INC declaration
      # The current line is not a continuation or is the end of the continuation

      # Get lines from an "include" configuration file
      my $src = ($start ? $start->value : $value);
      $src   .= '@' . $self->pegrev if $here and $self->pegrev;

      if ($src) {
        # Invoke a new instance to read the source
        my $cfg = FCM1::CfgFile->new (
          SRC => expand_tilde ($src), TYPE => $self->type,
        );

        $cfg->read_cfg;

        # Add lines to the lines array in the current configuration file
        $comment = 'INC ' . $src . ' ';
        push @{$self->lines}, FCM1::CfgLine->new (
          comment => $comment . '# Start',
          number  => ($start ? $start->number : $line_num),
          src     => $self->actual_src,
          warning => $warning,
        );
        push @{ $self->lines }, @{ $cfg->lines };
        push @{$self->lines}, FCM1::CfgLine->new (
          comment => $comment . '# End',
          src     => $self->actual_src,
        );

      } else {
        push @{$self->lines}, FCM1::CfgLine->new (
          number  => $line_num,
          src     => $self->actual_src,
          warning => 'empty INC declaration.'
        );
      }

    } else {
      # Push label:value pair into lines array
      push @{$self->lines}, FCM1::CfgLine->new (
        label   => $label,
        value   => ($label ? $value : ''),
        comment => $comment,
        number  => $line_num,
        src     => $self->actual_src,
        warning => $warning,
      );
    }

    next if defined $cont; # current line not a continuation

    my $slabel = ($start ? $start->label : $label);
    my $svalue = ($start ? $start->value : $value);
    next unless $slabel;

    # Check config file type and version
    if (index (uc ($slabel), $self->cfglabel ('CFGFILE')) == 0) {
      my @words = split /$FCM1::Config::DELIMITER_PATTERN/, $slabel;
      shift @words;

      my $name = @words ? lc ($words[0]) : 'type';

      if ($self->can ($name)) {
        $self->$name ($svalue);
      }
    }

    # Set internal variable
    $slabel =~ s/^\%//; # Remove leading "%" from label

    $self->config->variable ($slabel, $svalue)
      unless exists $cfg_keywords{$slabel};
  }

  # Report and reset warnings
  # ----------------------------------------------------------------------------
  for my $line (@{ $self->lines }) {
    w_report $line->format_warning if $line->warning;
    $line->warning (undef);
  }

  return @{ $self->lines };

}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->print_cfg ($file, [$force]);
#
# DESCRIPTION
#   This method prints the content of current configuration file. If no
#   argument is specified, it prints output to the standard output. If $file is
#   specified, and is a writable file name, the output is sent to the file.  If
#   the file already exists, its content is compared to the current output.
#   Nothing will be written if the content is unchanged unless $force is
#   specified. Otherwise, for typed configuration files, the existing file is
#   renamed using a prefix that contains its last modified time. The method
#   returns 1 if there is no error.
# ------------------------------------------------------------------------------

sub print_cfg {
  my ($self, $file, $force) = @_;

  # Count maximum number of characters in the labels, (for pretty printing)
  my $max_label_len = 0;
  for my $line (@{ $self->lines }) {
    next unless $line->label;
    my $label_len  = length $line->label;
    $max_label_len = $label_len if $label_len > $max_label_len;
  }

  # Output string
  my $out = '';

  # Append each line of the config file to the output string
  for my $line (@{ $self->lines }) {
    $out .= $line->print_line ($max_label_len - length ($line->label) + 1);
    $out .= "\n";
  }

  if ($out) {
    my $out_handle = select();

    # Open file if necessary
    if ($file) {
      # Make sure the host directory exists and is writable
      my $dirname = dirname $file;
      if (not -d $dirname) {
        print 'Make directory: ', $dirname, "\n" if $self->verbose;
        mkpath $dirname;
      }
      croak $dirname, ': cannot write to config file directory, abort'
        unless -d $dirname;

      if (-f $file and not $force) {
        # Read old config file to see if content has changed
        open(my $handle, '<', $file) || croak("$file: $!\n");
        my $in_lines = '';
        while (my $line = readline($handle)) {
          $in_lines .= $line;
        }
        close($handle);

        # Return if content is up-to-date
        if ($in_lines eq $out) {
          print 'No change in ', lc ($self->type), ' cfg: ', $file, "\n"
            if $self->verbose > 1 and $self->type;
          return 1;
        }

        # If config file already exists, make sure it is writable
        if ($self->type) {
          # Existing config file writable, rename it using its time stamp
          my $mtime = (stat $file)[9];
          my ($sec, $min, $hour, $mday, $mon, $year) = (gmtime $mtime)[0 .. 5];
          my $timestamp = sprintf '%4d%2.2d%2.2d_%2.2d%2.2d%2.2d_',
                          $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
          my $oldfile   = File::Spec->catfile (
            $dirname, $timestamp . basename ($file)
          );
          rename $file, $oldfile;
          print 'Rename existing ', lc ($self->type), ' cfg: ',
                $oldfile, "\n" if $self->verbose > 1;
        }
      }

      # Open file and select file handle
      open(my $handle, '>', $file) || croak("$file: $!\n");
      $out_handle = $handle;
    }

    # Print output
    print($out_handle $out);

    # Close file if necessary
    if ($file) {
      close($out_handle) || croak("$file: $!\n");

      if ($self->type and $self->verbose > 1) {
        print 'Generated ', lc ($self->type), ' cfg: ', $file, "\n";

      } elsif ($self->verbose > 2) {
        print 'Generated cfg: ', $file, "\n";
      }
    }

  } else {
    # Warn if nothing to print
    my $warning = 'Empty configuration';
    $warning   .= ' - nothing written to file: ' . $file if $file;
    carp $warning if $self->type;
  }

  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @lines = $self->_get_cfg_lines($is_for_inheritance);
#
# DESCRIPTION
#   This internal method opens the configuration file and returns its contents
#   as an array of lines. If the $self->src() is given as a URI, the method
#   tries to read it with "svn cat". Otherwise, the method tries to read
#   $self->src() with open() and readline(). If $self->type() is not a known
#   type, $self->src() can only be a regular file and $is_for_inheritance is
#   ignored.  Otherwise, $self->src() can be a regular file or a directory and
#   $is_for_inheritance is used to determine the behaviour for searching the
#   directory for a configuration file. If $is_for_inheritance is set, the
#   config file may be located at "$src/cfg/$type.cfg". If $is_for_inheritance
#   is not set, the config file may be located at "$src/$type.cfg" or
#   "$src/cfg/$type.cfg".
# ------------------------------------------------------------------------------

sub _get_cfg_lines {
  my ($self, $is_for_inheritance) = @_;
  my $DIAG = sub {};
  my @paths_refs = ([]);
  if ($self->type() && exists($self->setting('CFG_NAME')->{uc($self->type())})) {
    my $base = $self->setting('CFG_NAME')->{uc($self->type())};
    if (!$is_for_inheritance) {
      push(@paths_refs, [$base]);
    }
    push(@paths_refs, [$self->setting(qw/DIR CFG/), $base]);
    if ($self->verbose()) {
      $DIAG = sub {printf("Config file (%s): %s\n", $self->type(), @_)};
    }
  }
  if ($self->src() =~ qr{\A([A-Za-z][\w\+-\.]*):}xms) {
    # $self->src() is a URI, try "svn cat"
    my $src = FCM1::Util::tidy_url(FCM1::Keyword::expand($self->src()));
    my ($uri, $rev) = $src =~ qr{\A(.+?)(?:\@([^\@]+))?\z}msx;
    $rev ||= 'HEAD';
    for my $paths_ref (@paths_refs) {
      my $path = join('/', $uri, @{$paths_ref}) . '@' . $rev;
      local($@);
      my @lines = eval {
        run_command([qw/svn cat/, $path], METHOD => 'qx', DEVNULL => 1);
      };
      if (!$@) {
        $self->pegrev($rev);
        $self->actual_src($path);
        $DIAG->($path);
        return @lines;
      }
    }
  }
  else {
    # $self->src() is not a URI, assume that it resides in the file system
    for my $paths_ref (@paths_refs) {
      my $path = File::Spec->catfile($self->src(), @{$paths_ref});
      if (-e $path && !-d $path) { # "-f $path" returns false for "/dev/null"
        open(my $handle, '<', $path)
          || croak("$path: cannot open config file, abort: $!");
        my @lines = readline($handle);
        close($handle);
        $self->actual_src($path);
        $DIAG->($path);
        return @lines;
      }
    }
  }
  croak(sprintf("%s: cannot locate config file, abort", $self->src()));
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = $self->_expand_variable ($string, $env[, \%recursive_set]);
#
# DESCRIPTION
#   This internal method expands variables in $string. If $env is true, it
#   expands environment variables. Otherwise, it expands local variables. If
#   %recursive_set is specified, it indicates that this method is being called
#   recursively. In which case, it must not attempt to expand a variable that
#   exists in the keys of %recursive_set.
# ------------------------------------------------------------------------------

sub _expand_variable {
  my ($self, $string, $env, $recursive_set_ref) = @_;

  # Pattern for environment/local variable
  my @patterns = $env
    ? (qr#\$([A-Z][A-Z0-9_]+)#, qr#\$\{([A-Z][A-Z0-9_]+)\}#)
    : (qr#%(\w+(?:::[\w\.-]+)*)#, qr#%\{(\w+(?:(?:::|/)[\w\.-]+)*)\}#);

  my $ret = '';
  my $warning = undef;
  while ($string) {
    # Find the first match in $string
    my ($prematch, $match, $postmatch, $var_label);
    for my $pattern (@patterns) {
      next unless $string =~ /$pattern/;
      if ((not defined $prematch) or length ($`) < length ($prematch)) {
        $prematch = $`;
        $match = $&;
        $var_label = $1;
        $postmatch = $';
      }
    }

    if ($match) {
      $ret .= $prematch;
      $string = $postmatch;

      # Get variable value from environment or local configuration
      my $variable = $env
                     ? (exists $ENV{$var_label} ? $ENV{$var_label} : undef)
                     : $self->config->variable ($var_label);

      if ($env and $var_label eq 'HERE' and not defined $variable) {
        $variable = dirname ($self->actual_src);
        $variable = File::Spec->rel2abs ($variable) if not &is_url ($variable);
      }

      # Substitute match with value of variable
      if (defined $variable) {
        my %set = (($recursive_set_ref ? %{$recursive_set_ref} : ()));
        if (exists($set{$var_label})) {
          $warning .= ', ' if $warning;
          $warning .= $match . ': cyclic dependency, variable not expanded';
          $ret .= $variable;

        } else {
          my ($r, $w)
            = $self->_expand_variable($variable, $env, {%set, $var_label => 1});
          $ret .= $r;
          if ($w) {
            $warning .= ', ' if $warning;
            $warning .= $w;
          }
        }

      } else {
        $warning .= ', ' if $warning;
        $warning .= $match . ': variable not expanded';
        $ret .= $match;
      }

    } else {
      $ret .= $string;
      $string = "";
    }
  }

  return ($ret, $warning);
}

1;

__END__
