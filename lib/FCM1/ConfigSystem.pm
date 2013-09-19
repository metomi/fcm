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
#   FCM1::ConfigSystem
#
# DESCRIPTION
#   This is the base class for FCM systems that are based on inherited
#   configuration files, e.g. the extract and the build systems.
#
# ------------------------------------------------------------------------------

package FCM1::ConfigSystem;
use base qw{FCM1::Base};

use strict;
use warnings;

use FCM1::CfgFile;
use FCM1::CfgLine;
use FCM1::Dest;
use FCM1::Util     qw{expand_tilde e_report w_report};
use Sys::Hostname qw{hostname};

# List of property methods for this class
my @scalar_properties = (
 'cfg',         # configuration file
 'cfg_methods', # list of sub-methods for parse_cfg
 'cfg_prefix',  # optional prefix in configuration declaration
 'dest',        # destination for output
 'inherit',     # list of inherited configurations
 'inherited',   # list of inheritance hierarchy
 'type',        # system type
);

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $obj = FCM1::ConfigSystem->new;
#
# DESCRIPTION
#   This method constructs a new instance of the FCM1::ConfigSystem class.
# ------------------------------------------------------------------------------

sub new {
  my $this  = shift;
  my %args  = @_;
  my $class = ref $this || $this;

  my $self = FCM1::Base->new (%args);

  $self->{$_} = undef for (@scalar_properties);

  bless $self, $class;

  # List of sub-methods for parse_cfg
  $self->cfg_methods ([qw/header inherit dest/]);

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
      if ($name eq 'cfg') {
        # New configuration file
        $self->{$name} = FCM1::CfgFile->new (TYPE => $self->type);

      } elsif ($name =~ /^(?:cfg_methods|inherit|inherited)$/) {
        # Reference to an array
        $self->{$name} = [];

      } elsif ($name eq 'cfg_prefix' or $name eq 'type') {
        # Reference to an array
        $self->{$name} = '';

      } elsif ($name eq 'dest') {
        # New destination
        $self->{$name} = FCM1::Dest->new (TYPE => $self->type);
      }
    }

    return $self->{$name};
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   ($rc, $out_of_date) = $obj->check_cache ();
#
# DESCRIPTION
#   This method returns $rc = 1 on success or undef on failure. It returns
#   $out_of_date = 1 if current cache file is out of date relative to those in
#   inherited runs or 0 otherwise.
# ------------------------------------------------------------------------------

sub check_cache {
  my $self = shift;

  my $rc = 1;
  my $out_of_date = 0;

  if (@{ $self->inherit } and -f $self->dest->cache) {
    # Get modification time of current cache file
    my $cur_mtime = (stat ($self->dest->cache))[9];

    # Compare with modification times of inherited cache files
    for my $use (@{ $self->inherit }) {
      next unless -f $use->dest->cache;
      my $use_mtime = (stat ($use->dest->cache))[9];
      $out_of_date = 1 if $use_mtime > $cur_mtime;
    }
  }

  return ($rc, $out_of_date);
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->check_lock ();
#
# DESCRIPTION
#   This method returns true if no lock is found in the destination or if the
#   locks found are allowed. 
# ------------------------------------------------------------------------------

sub check_lock {
  my $self = shift;

  # Check all types of locks
  for my $method (@FCM1::Dest::lockfiles) {
    my $lock = $self->dest->$method;

    # Check whether lock exists
    next unless -e $lock;

    # Check whether this lock is allowed
    next if $self->check_lock_is_allowed ($lock);

    # Throw error if a lock exists
    w_report 'ERROR: ', $lock, ': lock file exists,';
    w_report '       ', $self->dest->rootdir, ': destination is busy.';
    return;
  }

  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->check_lock_is_allowed ($lock);
#
# DESCRIPTION
#   This method returns true if it is OK for $lock to exist in the destination.
# ------------------------------------------------------------------------------

sub check_lock_is_allowed {
  my ($self, $lock) = @_;

  # Disallow all types of locks by default
  return 0;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->compare_setting (
#     METHOD_LIST  => \@method_list,
#     [METHOD_ARGS => \@method_args,]
#     [CACHEBASE   => $cachebase,]
#   );
#
# DESCRIPTION
#   This method gets settings from the previous cache and updates the current.
#
# METHOD
#   The method returns true on success. @method_list must be a list of method
#   names for processing the cached lines in the previous run. If an existing
#   cache exists, its content is read into $old_lines, which is a list of
#   FCM1::CfgLine objects. Otherwise, $old_lines is set to undef. If $cachebase
#   is set, it is used for as the cache basename. Otherwise, the default for
#   the current system is used. It calls each method in the @method_list using
#   $self->$method ($old_lines, @method_args), which should return a
#   two-element list. The first element should be a return code (1 for out of
#   date, 0 for up to date and undef for failure). The second element should be
#   a reference to a list of FCM1::CfgLine objects for the output.
# ------------------------------------------------------------------------------

sub compare_setting {
  my ($self, %args) = @_;

  my @method_list = exists ($args{METHOD_LIST}) ? @{ $args{METHOD_LIST} } : ();
  my @method_args = exists ($args{METHOD_ARGS}) ? @{ $args{METHOD_ARGS} } : ();
  my $cachebase   = exists ($args{CACHEBASE}) ? $args{CACHEBASE} : undef;

  my $rc = 1;

  # Read cache if the file exists
  # ----------------------------------------------------------------------------
  my $cache = $cachebase
              ? File::Spec->catfile ($self->dest->cachedir, $cachebase)
              : $self->dest->cache;
  my @in_caches = ();
  if (-r $cache) {
    push @in_caches, $cache;

  } else {
    for my $use (@{ $self->inherit }) {
      my $use_cache = $cachebase
                      ? File::Spec->catfile ($use->dest->cachedir, $cachebase)
                      : $use->dest->cache;
      push @in_caches, $use_cache if -r $use_cache;
    }
  }

  my $old_lines = undef;
  for my $in_cache (@in_caches) {
    next unless -r $in_cache;
    my $cfg = FCM1::CfgFile->new (SRC => $in_cache);

    if ($cfg->read_cfg) {
      $old_lines = [] if not defined $old_lines;
      push @$old_lines, @{ $cfg->lines };
    }
  }

  # Call methods in @method_list to see if cache is out of date
  # ----------------------------------------------------------------------------
  my @new_lines = ();
  my $out_of_date = 0;
  for my $method (@method_list) {
    my ($return, $lines);
    ($return, $lines) = $self->$method ($old_lines, @method_args) if $rc;

    if (defined $return) {
      # Method succeeded
      push @new_lines, @$lines;
      $out_of_date = 1 if $return;

    } else {
      # Method failed
      $rc = $return;
      last;
    }
  }

  # Update the cache in the current run
  # ----------------------------------------------------------------------------
  if ($rc) {
    if (@{ $self->inherited } and $out_of_date) {
      # If this is an inherited configuration, the cache must not be changed
      w_report 'ERROR: ', $self->cfg->src,
               ': inherited configuration does not match with its cache.';
      $rc = undef;

    } elsif ((not -f $cache) or $out_of_date) {
      my $cfg = FCM1::CfgFile->new;
      $cfg->lines ([sort {$a->label cmp $b->label} @new_lines]);
      $rc = $cfg->print_cfg ($cache, 1);
    }
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   ($changed_hash_ref, $new_lines_array_ref) =
#     $self->compare_setting_in_config($prefix, \@old_lines);
#
# DESCRIPTION
#   This method compares old and current settings for a specified item.
#
# METHOD
#   This method does two things.
#
#   It uses the current configuration for the $prefix item to generate a list of
#   new FCM1::CfgLine objects (which is returned as a reference in the second
#   element of the returned list).
#
#   The values of the old lines are then compared with those of the new lines.
#   Any settings that are changed are stored in a hash, which is returned as a
#   reference in the first element of the returned list. The key of the hash is
#   the name of the changed setting, and the value is the value of the new
#   setting or undef if the setting no longer exists.
#
# ARGUMENTS
#   $prefix    - the name of an item in FCM1::Config to be compared
#   @old_lines - a list of FCM1::CfgLine objects containing the old settings
# ------------------------------------------------------------------------------

sub compare_setting_in_config {
  my ($self, $prefix, $old_lines_ref) = @_;
  
  my %changed = %{$self->setting($prefix)};
  my (@new_lines, %new_val_of);
  while (my ($key, $val) = each(%changed)) {
    $new_val_of{$key} = (ref($val) eq 'ARRAY' ? join(q{ }, sort(@{$val})) : $val);
    push(@new_lines, FCM1::CfgLine->new(
      LABEL => $prefix . $FCM1::Config::DELIMITER . $key,
      VALUE => $new_val_of{$key},
    ));
  }

  if (defined($old_lines_ref)) {
    my %old_val_of
      = map {($_->label_from_field(1), $_->value())} # converts into a hash
        grep {$_->label_starts_with($prefix)}        # gets relevant lines
        @{$old_lines_ref};

    while (my ($key, $val) = each(%old_val_of)) {
      if (exists($changed{$key})) {
        if ($val eq $new_val_of{$key}) { # no change from old to new
          delete($changed{$key});
        }
      }
      else { # exists in old but not in new
        $changed{$key} = undef;
      }
    }
  }

  return (\%changed, \@new_lines);
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->invoke ([CLEAN => 1, ]%args);
#
# DESCRIPTION
#   This method invokes the system. If CLEAN is set to true, it will only parse
#   the configuration and set up the destination, but will not invoke the
#   system. See the invoke_setup_dest and the invoke_system methods for list of
#   other arguments in %args.
# ------------------------------------------------------------------------------

sub invoke {
  my $self = shift;
  my %args = @_;

  # Print diagnostic at beginning of run
  # ----------------------------------------------------------------------------
  # Name of the system
  (my $name = ref ($self)) =~ s/^FCM1:://;

  # Print start time on system run, if verbose is true
  my $date = localtime;
  print $name, ' command started on ', $date, '.', "\n"
    if $self->verbose;

  # Start time (seconds since epoch)
  my $otime = time;

  # Parse the configuration file
  my $rc = $self->invoke_stage ('Parse configuration', 'parse_cfg');

  # Set up the destination
  $rc = $self->invoke_stage ('Setup destination', 'invoke_setup_dest', %args)
    if $rc;

  # Invoke the system
  # ----------------------------------------------------------------------------
  $rc = $self->invoke_system (%args) if $rc and not $args{CLEAN};

  # Remove empty directories
  $rc = $self->dest->clean (MODE => 'EMPTY') if $rc;

  # Print diagnostic at end of run
  # ----------------------------------------------------------------------------
  # Print lapse time at the end, if verbose is true
  if ($self->verbose) {
    my $total = time - $otime;
    my $s_str = $total > 1 ? 'seconds' : 'second';
    print '->TOTAL: ', $total, ' ', $s_str, "\n";
  }

  # Report end of system run
  $date = localtime;
  if ($rc) {
    # Success
    print $name, ' command finished on ', $date, '.', "\n"
      if $self->verbose;

  } else {
    # Failure
    e_report $name, ' failed on ', $date, '.';
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->invoke_setup_dest ([CLEAN|FULL => 1], [IGNORE_LOCK => 1]);
#
# DESCRIPTION
#   This method sets up the destination and returns true on success.
#
# ARGUMENTS
#   CLEAN|FULL   - If set to "true", set up the system in "clean|full" mode.
#                  Sub-directories and files in the root directory created by
#                  the previous invocation of the system will be removed. If
#                  not set, the default is to run in "incremental" mode.
#   IGNORE_LOCK  - If set to "true", it ignores any lock files that may exist in
#                  the destination root directory. 
# ------------------------------------------------------------------------------

sub invoke_setup_dest {
  my $self = shift;
  my %args = @_;

  # Set up destination
  # ----------------------------------------------------------------------------
  # Print destination in verbose mode
  if ($self->verbose()) {
    printf(
      "Destination: %s@%s:%s\n",
      scalar(getpwuid($<)),
      hostname(),
      $self->dest()->rootdir(),
    );
  }

  my $rc = 1;
  my $out_of_date = 0;

  # Check whether lock exists in the destination root
  $rc = $self->check_lock if $rc and not $args{IGNORE_LOCK};

  # Check whether current cache is out of date relative to the inherited ones
  ($rc, $out_of_date) = $self->check_cache if $rc;

  # Remove sub-directories and files in destination in "full" mode
  $rc = $self->dest->clean (MODE => 'ALL')
    if $rc and ($args{FULL} or $args{CLEAN} or $out_of_date);

  # Create build root directory if necessary
  $rc = $self->dest->create if $rc;

  # Set a lock in the destination root
  $rc = $self->dest->set_lock if $rc;

  # Generate an as-parsed configuration file
  $self->cfg->print_cfg ($self->dest->parsedcfg);

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->invoke_stage ($name, $method, @args);
#
# DESCRIPTION
#   This method invokes a named stage of the system, where $name is the name of
#   the stage, $method is the name of the method for invoking the stage and
#   @args are the arguments to the &method.
# ------------------------------------------------------------------------------

sub invoke_stage {
  my ($self, $name, $method, @args) = @_;

  # Print diagnostic at beginning of a stage
  print '->', $name, ': start', "\n" if $self->verbose;
  my $stime = time;

  # Invoke the stage
  my $rc = $self->$method (@args);

  # Print diagnostic at end of a stage
  my $total = time - $stime;
  my $s_str = $total > 1 ? 'seconds' : 'second';
  print '->', $name, ': ', $total, ' ', $s_str, "\n";

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->invoke_system (%args);
#
# DESCRIPTION
#   This is a prototype method for invoking the system.
# ------------------------------------------------------------------------------

sub invoke_system {
  my $self = shift;
  my %args = @_;

  print "Dummy code.\n";

  return 0;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->parse_cfg($is_for_inheritance);
#
# DESCRIPTION
#   This method calls other methods to parse the configuration file.
# ------------------------------------------------------------------------------

sub parse_cfg {
  my ($self, $is_for_inheritance) = @_;

  # Read config file
  # ----------------------------------------------------------------------------
  if (!$self->cfg()->src() || !$self->cfg()->read_cfg($is_for_inheritance)) {
    return;
  }

  if ($self->cfg->type ne $self->type) {
    w_report 'ERROR: ', $self->cfg->src, ': not a ', $self->type,
             ' config file.';
    return;
  }

  # Strip out optional prefix from all labels
  # ----------------------------------------------------------------------------
  if ($self->cfg_prefix) {
    for my $line (@{ $self->cfg->lines }) {
      $line->prefix ($self->cfg_prefix);
    }
  }

  # Filter lines from the configuration file
  # ----------------------------------------------------------------------------
  my @cfg_lines = grep {
    $_->slabel                   and       # ignore empty/comment lines
    index ($_->slabel, '%') != 0 and       # ignore user variable
    not $_->slabel_starts_with_cfg ('INC') # ignore INC line
  } @{ $self->cfg->lines };

  # Parse the lines to read in the various settings, by calling the methods:
  # $self->parse_cfg_XXX, where XXX is: header, inherit, dest, and the values
  # in the list @{ $self->cfg_methods }.
  # ----------------------------------------------------------------------------
  my $rc = 1;
  for my $name (@{ $self->cfg_methods }) {
    my $method = 'parse_cfg_' . $name;
    $self->$method (\@cfg_lines) or $rc = 0;
  }

  # Report warnings/errors
  # ----------------------------------------------------------------------------
  for my $line (@cfg_lines) {
    $rc = 0 if not $line->parsed;
    my $mesg = $line->format_error;
    w_report $mesg if $mesg;
  }

  return ($rc);
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->parse_cfg_dest (\@cfg_lines);
#
# DESCRIPTION
#   This method parses the destination settings in the @cfg_lines.
# ------------------------------------------------------------------------------

sub parse_cfg_dest {
  my ($self, $cfg_lines) = @_;

  my $rc = 1;

  # DEST/DIR declarations
  # ----------------------------------------------------------------------------
  my @lines  = grep {
    $_->slabel_starts_with_cfg ('DEST') or $_->slabel_starts_with_cfg ('DIR')
  } @$cfg_lines;

  # Only ROOTDIR declarations are accepted
  for my $line (@lines) {
    my ($d, $method) = $line->slabel_fields;
    $d = lc $d;
    $method = lc $method;

    # Backward compatibility
    $d = 'dest' if $d eq 'dir';

    # Default to "rootdir"
    $method = 'rootdir' if (not $method) or $method eq 'root';

    # Only "rootdir" can be set
    next unless $method eq 'rootdir';

    $self->$d->$method (&expand_tilde ($line->value));
    $line->parsed (1);
  }

  # Make sure root directory is set
  # ----------------------------------------------------------------------------
  if (not $self->dest->rootdir) {
    w_report 'ERROR: ', $self->cfg->actual_src,
             ': destination root directory not set.';
    $rc = 0;
  }

  # Inherit destinations
  # ----------------------------------------------------------------------------
  @{$self->dest()->inherit()} = ();
  my @nodes = @{$self->inherit()};
  while (my $node = pop(@nodes)) {
      push(@nodes, @{$node->inherit()});
      push(@{$self->dest()->inherit()}, $node->dest());
  }
  @{$self->dest()->inherit()} = reverse(@{$self->dest()->inherit()});

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->parse_cfg_header (\@cfg_lines);
#
# DESCRIPTION
#   This method parses the header setting in the @cfg_lines.
# ------------------------------------------------------------------------------

sub parse_cfg_header {
  my ($self, $cfg_lines) = @_;

  # Set header lines as "parsed"
  map {$_->parsed (1)} grep {$_->slabel_starts_with_cfg ('CFGFILE')} @$cfg_lines;

  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->parse_cfg_inherit (\@cfg_lines);
#
# DESCRIPTION
#   This method parses the inherit setting in the @cfg_lines.
# ------------------------------------------------------------------------------

sub parse_cfg_inherit {
  my ($self, $cfg_lines) = @_;

  # USE declaration
  # ----------------------------------------------------------------------------
  my @lines = grep {$_->slabel_starts_with_cfg ('USE')} @$cfg_lines;

  # Check for cyclic dependency
  if (@lines and grep {$_ eq $self->cfg->actual_src} @{ $self->inherited }) {
    # Error if current configuration file is in its own inheritance hierarchy
    w_report 'ERROR: ', $self->cfg->actual_src, ': attempt to inherit itself.';
    $_->error ($_->label . ': ignored due to cyclic dependency.') for (@lines);
    return 0;
  }

  my $rc = 1;

  for my $line (@lines) {
    # Invoke new instance of the current class
    my $use = ref ($self)->new;

    # Set configuration file, inheritance hierarchy
    # and attempt to parse the configuration
    $use->cfg->src  (&expand_tilde ($line->value));
    $use->inherited ([$self->cfg->actual_src, @{ $self->inherited }]);
    $use->parse_cfg(1); # 1 = is for inheritance

    # Add to list of inherit configurations
    push @{ $self->inherit }, $use;

    $line->parsed (1);
  }

  # Check locks in inherited destination
  # ----------------------------------------------------------------------------
  for my $use (@{ $self->inherit }) {
    $rc = 0 unless $use->check_lock;
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @cfglines = $obj->to_cfglines ();
#
# DESCRIPTION
#   This method returns the configuration lines of this object.
# ------------------------------------------------------------------------------

sub to_cfglines {
  my ($self) = @_;

  my @inherited_dests = map {
    FCM1::CfgLine->new (
      label => $self->cfglabel ('USE'), value => $_->dest->rootdir
    );
  } @{ $self->inherit };

  return (
    FCM1::CfgLine::comment_block ('File header'),
    FCM1::CfgLine->new (
      label => $self->cfglabel ('CFGFILE') . $FCM1::Config::DELIMITER . 'TYPE',
      value => $self->type,
    ),
    FCM1::CfgLine->new (
      label => $self->cfglabel ('CFGFILE') . $FCM1::Config::DELIMITER . 'VERSION',
      value => '1.0',
    ),
    FCM1::CfgLine->new (),

    @inherited_dests,

    FCM1::CfgLine::comment_block ('Destination'),
    ($self->dest->to_cfglines()),
  );
}

# ------------------------------------------------------------------------------

1;

__END__
