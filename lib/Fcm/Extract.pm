# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-2012 Met Office.
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
#   Fcm::Extract
#
# DESCRIPTION
#   This is the top level class for the FCM extract system.
#
# ------------------------------------------------------------------------------

package Fcm::Extract;
@ISA = qw(Fcm::ConfigSystem);

# Standard pragma
use warnings;
use strict;

# Standard modules
use File::Path;
use File::Spec;

# FCM component modules
use Fcm::CfgFile;
use Fcm::CfgLine;
use Fcm::Config;
use Fcm::ConfigSystem;
use Fcm::Dest;
use Fcm::ExtractFile;
use Fcm::ExtractSrc;
use Fcm::Keyword;
use Fcm::ReposBranch;
use Fcm::SrcDirLayer;
use Fcm::Util;

# List of scalar property methods for this class
my @scalar_properties = (
 'bdeclare', # list of build declarations
 'branches', # list of repository branches
 'conflict', # conflict mode
 'rdest'   , # remote destination information
);

# List of hash property methods for this class
my @hash_properties = (
 'srcdirs' , # list of source directory extract info
 'files',    # list of files processed key=pkgname, value=Fcm::ExtractFile
);

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $obj = Fcm::Extract->new;
#
# DESCRIPTION
#   This method constructs a new instance of the Fcm::Extract class.
# ------------------------------------------------------------------------------

sub new {
  my $this  = shift;
  my %args  = @_;
  my $class = ref $this || $this;

  my $self = Fcm::ConfigSystem->new (%args);

  $self->{$_} = undef for (@scalar_properties);

  $self->{$_} = {} for (@hash_properties);

  bless $self, $class;

  # List of sub-methods for parse_cfg
  push @{ $self->cfg_methods }, (qw/rdest bld conflict project/);

  # System type
  $self->type ('ext');

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
      if ($name eq 'bdeclare' or $name eq 'branches') {
        # Reference to an array
        $self->{$name} = [];

      } elsif ($name eq 'rdest') {
        # New extract destination local/remote
        $self->{$name} = Fcm::Dest->new (DEST0 => $self->dest(), TYPE => 'ext');

      } elsif ($name eq 'conflict') {
        # Conflict mode, default to "merge"
        $self->{$name} = 'merge';
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
#   $rc = $self->check_lock_is_allowed ($lock);
#
# DESCRIPTION
#   This method returns true if it is OK for $lock to exist in the destination.
# ------------------------------------------------------------------------------

sub check_lock_is_allowed {
  my ($self, $lock) = @_;

  # Allow existence of build lock in inherited extract
  return ($lock eq $self->dest->bldlock and @{ $self->inherited });
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->invoke_extract ();
#
# DESCRIPTION
#   This method invokes the extract stage of the extract system. It returns
#   true on success.
# ------------------------------------------------------------------------------

sub invoke_extract {
  my $self = shift;

  my $rc = 1;

  my @methods = (
    'expand_cfg',       # expand URL, revision keywords, relative path, etc
    'create_dir_stack', # analyse the branches to create an extract sequence
    'extract_src',      # use the sequence to extract source to destination
    'write_cfg',        # generate final configuration file
    'write_cfg_bld',    # generate build configuration file
  );

  for my $method (@methods) {
    $rc = $self->$method if $rc;
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->invoke_mirror ();
#
# DESCRIPTION
#   This method invokes the mirror stage of the extract system. It returns
#   true on success.
# ------------------------------------------------------------------------------

sub invoke_mirror {
  my $self = shift;
  return $self->rdest->mirror ([qw/bldcfg extcfg srcdir/]);
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->invoke_system ();
#
# DESCRIPTION
#   This method invokes the extract system. It returns true on success.
# ------------------------------------------------------------------------------

sub invoke_system {
  my $self = shift;

  my $rc = 1;
  
  $rc = $self->invoke_stage ('Extract', 'invoke_extract');
  $rc = $self->invoke_stage ('Mirror', 'invoke_mirror')
    if $rc and $self->rdest->rootdir;

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->parse_cfg_rdest(\@cfg_lines);
#
# DESCRIPTION
#   This method parses the remote destination settings in the @cfg_lines.
# ------------------------------------------------------------------------------

sub parse_cfg_rdest {
  my ($self, $cfg_lines_ref) = @_;

  # RDEST declarations
  # ----------------------------------------------------------------------------
  for my $line (grep {$_->slabel_starts_with_cfg('RDEST')} @{$cfg_lines_ref}) {
    my ($d, $method) = map {lc($_)} $line->slabel_fields();
    $method ||= 'rootdir';
    if ($self->rdest()->can($method)) {
      $self->rdest()->$method(expand_tilde($line->value()));
      $line->parsed(1);
    }
  }

  # MIRROR declaration, deprecated = RDEST::MIRROR_CMD
  # ----------------------------------------------------------------------------
  for my $line (grep {$_->slabel_starts_with_cfg('MIRROR')} @{$cfg_lines_ref}) {
    $self->rdest()->mirror_cmd($line->value());
    $line->parsed(1);
  }

  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->parse_cfg_bld (\@cfg_lines);
#
# DESCRIPTION
#   This method parses the build configurations in the @cfg_lines.
# ------------------------------------------------------------------------------

sub parse_cfg_bld {
  my ($self, $cfg_lines) = @_;

  # BLD declarations
  # ----------------------------------------------------------------------------
  for my $line (grep {$_->slabel_starts_with_cfg ('BDECLARE')} @$cfg_lines) {
    # Remove BLD from label
    my @words = $line->slabel_fields;

    # Check that a declaration follows BLD
    next if @words <= 1;

    push @{ $self->bdeclare }, Fcm::CfgLine->new (
      LABEL  => join ($Fcm::Config::DELIMITER, @words),
      PREFIX => $self->cfglabel ('BDECLARE'),
      VALUE  => $line->value,
    );
    $line->parsed (1);
  }

  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->parse_cfg_conflict (\@cfg_lines);
#
# DESCRIPTION
#   This method parses the conflict settings in the @cfg_lines.
# ------------------------------------------------------------------------------

sub parse_cfg_conflict {
  my ($self, $cfg_lines) = @_;

  # Deprecated: Override mode setting
  # ----------------------------------------------------------------------------
  for my $line (grep {$_->slabel_starts_with_cfg ('OVERRIDE')} @$cfg_lines) {
    next if ($line->slabel_fields) > 1;
    $self->conflict ($line->bvalue ? 'override' : 'fail');
    $line->parsed (1);
    $line->warning($line->slabel . ' is deprecated. Use ' .
                   $line->cfglabel('CONFLICT') . ' override|merge|fail.');
  }

  # Conflict mode setting
  # ----------------------------------------------------------------------------
  my @conflict_modes = qw/fail merge override/;
  my $conflict_modes_pattern = join ('|', @conflict_modes);
  for my $line (grep {$_->slabel_starts_with_cfg ('CONFLICT')} @$cfg_lines) {
    if ($line->value =~ /$conflict_modes_pattern/i) {
      $self->conflict (lc ($line->value));
      $line->parsed (1);

    } elsif ($line->value =~ /^[012]$/) {
      $self->conflict ($conflict_modes[$line->value]);
      $line->parsed (1);

    } else {
      $line->error ($line->value, ': invalid value');
    }
  }

  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->parse_cfg_project (\@cfg_lines);
#
# DESCRIPTION
#   This method parses the project settings in the @cfg_lines.
# ------------------------------------------------------------------------------

sub parse_cfg_project {
  my ($self, $cfg_lines) = @_;

  # Flag to indicate that a declared branch revision must match with its changed
  # revision
  # ----------------------------------------------------------------------------
  for my $line (grep {$_->slabel_starts_with_cfg ('REVMATCH')} @$cfg_lines) {
    next if ($line->slabel_fields) > 1;
    $self->setting ([qw/EXT_REVMATCH/], $line->bvalue);
    $line->parsed (1);
  }

  # Repository, revision and source directories
  # ----------------------------------------------------------------------------
  for my $name (qw/repos revision dirs expdirs/) {
    my @lines = grep {
      $_->slabel_starts_with_cfg (uc ($name)) or
      $name eq 'revision' and $_->slabel_starts_with_cfg ('VERSION');
    } @$cfg_lines;
    for my $line (@lines) {
      my @names = $line->slabel_fields;
      shift @names;

      # Detemine package and tag
      my $tag     = pop @names;
      my $pckroot = $names[0];
      my $pck     = join ($Fcm::Config::DELIMITER, @names);

      # Check that $tag and $pckroot are defined
      next unless $tag and $pckroot;

      # Check if branch already exists.
      # If so, set $branch to point to existing branch
      my $branch = undef;
      for (@{ $self->branches }) {
        next unless $_->package eq $pckroot and $_->tag eq $tag;

        $branch = $_;
        last;
      }

      # Otherwise, create a new branch
      if (not $branch) {
        $branch = Fcm::ReposBranch->new (PACKAGE => $pckroot, TAG => $tag,);

        push @{ $self->branches }, $branch;
      }

      if ($name eq 'repos' or $name eq 'revision') {
        # Branch location or revision
        $branch->$name ($line->value);

      } else { # $name eq 'dirs' or $name eq 'expdirs'
        # Source directory or expandable source directory
        if ($pck eq $pckroot and $line->value !~ m#^/#) {
          # Sub-package name not set and source directory quoted as a relative
          # path, determine package name from path name
          $pck = join (
            $Fcm::Config::DELIMITER,
            ($pckroot, File::Spec->splitdir ($line->value)),
          );
        }

        # A "/" is equivalent to the top (empty) package
        my $value = ($line->value =~ m#^/+$#) ? '' : $line->value;
        $branch->$name ($pck, $value);
      }

      $line->parsed (1);
    }
  }

  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->expand_cfg ();
#
# DESCRIPTION
#   This method expands the settings of the extract configuration.
# ------------------------------------------------------------------------------

sub expand_cfg {
  my $self = shift;

  my $rc = 1;
  for my $use (@{ $self->inherit }) {
    $rc = $use->expand_cfg if $rc;
  }

  return $rc unless $rc;

  # Establish a set of source directories from the "base repository"
  my %base_branches = ();

  # Inherit "base" set of source directories from re-used extracts
  for my $use (@{ $self->inherit }) {
    my @branches = @{ $use->branches };

    for my $branch (@branches) {
      my $package              = $branch->package;
      $base_branches{$package} = $branch unless exists $base_branches{$package};
    }
  }

  for my $branch (@{ $self->branches }) {
    # Expand URL keywords if necessary
    if ($branch->repos) {
      my $repos = Fcm::Util::tidy_url(Fcm::Keyword::expand($branch->repos()));
      $branch->repos ($repos) if $repos ne $branch->repos;
    }

    # Check that repository type and revision are set
    if ($branch->repos and &is_url ($branch->repos)) {
      $branch->type ('svn') unless $branch->type;
      $branch->revision ('head') unless $branch->revision;

    } else {
      $branch->type ('user') unless $branch->type;
      $branch->revision ('user') unless $branch->revision;
    }

    $rc = $branch->expand_revision if $rc; # Get revision number from keywords
    $rc = $branch->expand_path     if $rc; # Expand relative path to full path
    $rc = $branch->expand_all      if $rc; # Search sub-directories
    last unless $rc;

    my $package = $branch->package;

    if (exists $base_branches{$package}) {
      # A base branch for this package exists

      # If current branch has no source directory, use the set provided by the
      # base branch
      my %dirs = %{ $branch->dirs };
      $branch->add_base_dirs ($base_branches{$package}) unless keys %dirs;

    } else {
      # This package does not yet have a base branch, set this branch as base
      $base_branches{$package} = $branch;
    }
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->create_dir_stack ();
#
# DESCRIPTION
#   This method creates a hash of source directories to be processed. If the
#   flag INHERITED is set to true, the source directories are assumed processed
#   and extracted.
# ------------------------------------------------------------------------------

sub create_dir_stack {
  my $self = shift;
  my %args = @_;

  # Inherit from USE ext cfg
  for my $use (@{ $self->inherit }) {
    $use->create_dir_stack () or return 0;
    my %use_srcdirs = %{ $use->srcdirs };

    while (my ($key, $value) = each %use_srcdirs) {
      $self->srcdirs ($key, $value);

      # Re-set destination to current destination
      my @path = split (/$Fcm::Config::DELIMITER/, $key);
      $self->srcdirs ($key)->{DEST} = File::Spec->catfile (
        $self->dest->srcdir, @path,
      );
    }
  }

  # Build stack from current ext cfg
  for my $branch (@{ $self->branches }) {
    my %branch_dirs = %{ $branch->dirs };

    for my $dir (keys %branch_dirs) {
      # Check whether source directory is already in the list
      if (not $self->srcdirs ($dir)) { # if not, create it
        $self->srcdirs ($dir, {
          DEST  => File::Spec->catfile (
            $self->dest->srcdir, split (/$Fcm::Config::DELIMITER/, $dir)
          ),
          STACK => [],
          FILES => {},
        });
      }

      my $stack = $self->srcdirs ($dir)->{STACK}; # copy reference

      # Create a new layer in the input stack
      my $layer = Fcm::SrcDirLayer->new (
        NAME      => $dir,
        PACKAGE   => $branch->package,
        TAG       => $branch->tag,
        LOCATION  => $branch->dirs ($dir),
        REPOSROOT => $branch->repos,
        REVISION  => $branch->revision,
        TYPE      => $branch->type,
        EXTRACTED => @{ $self->inherited }
                     ? $self->srcdirs ($dir)->{DEST} : undef,
      );

      # Check whether layer is already in the stack
      my $exist = grep {
        $_->location eq $layer->location and $_->revision eq $layer->revision;
      } @{ $stack };

      if (not $exist) {
        # If not already exist, put layer into stack

        # Note: user stack always comes last
        if (! $layer->user and exists $stack->[-1] and $stack->[-1]->user) {
          my $lastlayer = pop @{ $stack };
          push @{ $stack }, $layer;
          $layer = $lastlayer;
        }

        push @{ $stack }, $layer;

      } elsif ($layer->user) {

        # User layer already exists, overwrite it
        $stack->[-1] = $layer;

      }
    }
  }

  # Use the cache to sort the source directory layer hash
  return $self->compare_setting (METHOD_LIST => ['sort_dir_stack']);
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   ($rc, \@new_lines) = $self->sort_dir_stack ($old_lines);
#
# DESCRIPTION
#   This method sorts thesource directories hash to be processed.
# ------------------------------------------------------------------------------

sub sort_dir_stack {
  my ($self, $old_lines) = @_;

  my $rc = 0;

  my %old = ();
  if ($old_lines) {
    for my $line (@$old_lines) {
      $old{$line->label} = $line->value;
    }
  }

  my %new;

  # Compare each layer to base layer, discard unnecessary layers
  DIR: for my $srcdir (keys %{ $self->srcdirs }) {
    my @stack = ();

    while (my $layer = shift @{ $self->srcdirs ($srcdir)->{STACK} }) {
      if ($layer->user) {
        # Local file system branch, check that the declared location exists
        if (-d $layer->location) {
          # Local file system branch always takes precedence
          push @stack, $layer;

        } else {
          w_report 'ERROR: ', $layer->location, ': declared source directory ',
                   'does not exists ';
          $rc = undef;
          last DIR;
        }

      } else {
        my $key = join ($Fcm::Config::DELIMITER, (
          $srcdir, $layer->location, $layer->revision
        ));

        unless ($layer->extracted and $layer->commit) {
          # See if commit revision information is cached
          if (keys %old and exists $old{$key}) {
            $layer->commit ($old{$key});

          } else {
            $layer->get_commit;
            $rc = 1;
          }

          # Check source directory for commit revision, if necessary
          if (not $layer->commit) {
            w_report 'Error: cannot determine the last changed revision of ',
                     $layer->location;
            $rc = undef;
            last DIR;
          }

          # Set cache directory for layer
          my $tag_ver = $layer->tag . '__' . $layer->commit;
          $layer->cachedir (File::Spec->catfile (
            $self->dest->cachedir,
            split (/$Fcm::Config::DELIMITER/, $srcdir),
            $tag_ver,
          ));
        }

        # New line in cache config file
        $new{$key} = $layer->commit;

        # Push this layer in the stack:
        # 1. it has a different revision compared to the top layer
        # 2. it is the top layer (base line code)
        if (@stack > 0) {
          push @stack, $layer if $layer->commit != $stack[0]->commit;

        } else {
          push @stack, $layer;
        }

      }
    }

    $self->srcdirs ($srcdir)->{STACK} = \@stack;
  }

  # Write "commit cache" file
  my @new_lines;
  if (defined ($rc)) {
    for my $key (sort keys %new) {
      push @new_lines, Fcm::CfgLine->new (label => $key, value => $new{$key});
    }
  }

  return ($rc, \@new_lines);
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->extract_src ();
#
# DESCRIPTION
#   This internal method performs the extract of the source directories and
#   files if necessary.
# ------------------------------------------------------------------------------

sub extract_src {
  my $self = shift;
  my $rc = 1;

  # Ensure destinations exist and are directories
  for my $srcdir (values %{ $self->srcdirs }) {
    last if not $rc;
    if (-f $srcdir->{DEST}) {
      w_report $srcdir->{DEST},
               ': destination exists and is not a directory, abort.';
      $rc = 0;
    }
  }

  # Retrieve previous/record current extract configuration for each file.
  $rc = $self->compare_setting (
    CACHEBASE => $self->setting ('CACHE_FILE_SRC'),
    METHOD_LIST => ['compare_setting_srcfiles'],
  ) if $rc;

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   ($rc, \@new_lines) = $self->compare_setting_srcfiles ($old_lines);
#
# DESCRIPTION
#   For each file to be extracted, this method creates an instance of an
#   Fcm::ExtractFile object. It then compares its file's sources to determine
#   if they have changed. If so, it will allow the Fcm::ExtractFile to
#   "re-extract" the file to the destination. Otherwise, it will set
#   Fcm::ExtractFile->dest_status to a null string to denote an "unchanged"
#   dest_status.
#
# SEE ALSO
#   Fcm::ConfigSystem->compare_setting.
# ------------------------------------------------------------------------------

sub compare_setting_srcfiles {
  my ($self, $old_lines) = @_;
  my $rc = 1;

  # Retrieve previous extract configuration for each file
  # ----------------------------------------------------------------------------
  my %old = ();
  if ($old_lines) {
    for my $line (@$old_lines) {
      $old{$line->label} = $line->value;
    }
  }

  # Build up a sequence using a Fcm::ExtractFile object for each file
  # ----------------------------------------------------------------------------
  for my $srcdir (values %{ $self->srcdirs }) {
    my %pkgnames0; # (to be) list of package names in the base layer
    for my $i (0 .. @{ $srcdir->{STACK} } - 1) {
      my $layer = $srcdir->{STACK}->[$i];
      # Update the cache for each layer of the stack if necessary
      $layer->update_cache unless $layer->extracted or -d $layer->localdir;

      # Get list of files in the cache or local directory
      my %pkgnames;
      for my $file (($layer->get_files)) {
        my $pkgname = join (
          '/', split (/$Fcm::Config::DELIMITER/, $layer->name), $file
        );
        $pkgnames0{$pkgname} = 1 if $i == 0; # store package name in base layer
        $pkgnames{$pkgname} = 1; # store package name in the current layer
        if (not $self->files ($pkgname)) {
          $self->files ($pkgname, Fcm::ExtractFile->new (
            conflict => $self->conflict,
            dest     => $self->dest->srcpath,
            pkgname  => $pkgname,
          ));

          # Base is empty
          $self->files ($pkgname)->src->[0] = Fcm::ExtractSrc->new (
            id      => $layer->tag,
            pkgname => $pkgname,
          ) if $i > 0;
        }
        my $cache = File::Spec->catfile ($layer->localdir, $file);
        push @{ $self->files ($pkgname)->src }, Fcm::ExtractSrc->new (
          cache   => $cache,
          id      => $layer->tag,
          pkgname => $pkgname,
          rev     => ($layer->user ? (stat ($cache))[9] : $layer->commit),
          uri     => join ('/', $layer->location, $file),
        );
      }

      # List of removed files in this layer (relative to base layer)
      if ($i > 0) {
        for my $pkgname (keys %pkgnames0) {
          push @{ $self->files ($pkgname)->src }, Fcm::ExtractSrc->new (
            id      => $layer->tag,
            pkgname => $pkgname,
          ) if not exists $pkgnames{$pkgname}
        }
      }
    }
  }

  # Compare with old settings
  # ----------------------------------------------------------------------------
  my %new = ();
  for my $key (sort keys %{ $self->files }) {
    # Set up value for cache
    my @sources = ();
    for my $src (@{ $self->files ($key)->src }) {
      push @sources, (defined ($src->uri) ? ($src->uri . '@' . $src->rev) : '');
    }

    my $value = join ($Fcm::Config::DELIMITER, @sources);

    # Set Fcm::ExtractFile->dest_status to "unchanged" if value is unchanged
    if (exists($old{$key}) && $old{$key} eq $value && !grep {!$_} @sources) {
      $self->files($key)->dest_status('');
    }

    # Write current settings
    $new{$key} = $value;
  }

  # Delete those that exist in previous extract but not in current
  # ----------------------------------------------------------------------------
  for my $key (sort keys %old) {
    next if exists $new{$key};
    $self->files ($key, Fcm::ExtractFile->new (
      dest    => $self->dest->srcpath,
      pkgname => $key,
    ));
  }

  # Extract each file, if necessary
  # ----------------------------------------------------------------------------
  for my $key (sort keys %{ $self->files }) {
    $rc = $self->files ($key)->run if defined ($rc);
    last if not defined ($rc);
  }

  # Report status
  # ----------------------------------------------------------------------------
  if (defined ($rc) and $self->verbose) {
    my %src_status_count = ();
    my %dest_status_count = ();
    for my $key (sort keys %{ $self->files }) {
      # Report changes in destination in verbose 1 or above
      my $dest_status = $self->files ($key)->dest_status;
      my $src_status = $self->files ($key)->src_status;
      next unless $self->verbose and $dest_status;

      if ($dest_status and $dest_status ne '?') {
        if (exists $dest_status_count{$dest_status}) {
          $dest_status_count{$dest_status}++;

        } else {
          $dest_status_count{$dest_status} = 1;
        }
      }

      if ($src_status and $src_status ne '?') {
        if (exists $src_status_count{$src_status}) {
          $src_status_count{$src_status}++;

        } else {
          $src_status_count{$src_status} = 1;
        }
      }

      # Destination status in column 1, source status in column 2
      if ($self->verbose > 1) {
        my @srcs = @{$self->files ($key)->src_actual};
        print ($dest_status ? $dest_status : ' ');
        print ($src_status ? $src_status : ' ');
        print ' ' x 5, $key;
        print ' (', join (', ', map {$_->id} @srcs), ')' if @srcs;
        print "\n";
      }
    }

    # Report number of files in each dest_status category
    if (%dest_status_count) {
      print 'Column 1: ' if $self->verbose > 1;
      print 'Destination status summary:', "\n";
      for my $key (sort keys %Fcm::ExtractFile::DEST_STATUS_CODE) {
        next unless $key;
        next if not exists ($dest_status_count{$key});
        print '  No of files ';
        print '[', $key, '] ' if $self->verbose > 1;
        print $Fcm::ExtractFile::DEST_STATUS_CODE{$key}, ': ',
              $dest_status_count{$key}, "\n";
      }
    }

    # Report number of files in each dest_status category
    if (%src_status_count) {
      print 'Column 2: ' if $self->verbose > 1;
      print 'Source status summary:', "\n";
      for my $key (sort keys %Fcm::ExtractFile::SRC_STATUS_CODE) {
        next unless $key;
        next if not exists ($src_status_count{$key});
        print '  No of files ';
        print '[', $key, '] ' if $self->verbose > 1;
        print $Fcm::ExtractFile::SRC_STATUS_CODE{$key}, ': ',
              $src_status_count{$key}, "\n";
      }
    }
  }

  # Record configuration of current extract for each file
  # ----------------------------------------------------------------------------
  my @new_lines;
  if (defined ($rc)) {
    for my $key (sort keys %new) {
      push @new_lines, Fcm::CfgLine->new (label => $key, value => $new{$key});
    }
  }

  return ($rc, \@new_lines);
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @array = $self->sort_bdeclare ();
#
# DESCRIPTION
#   This method returns sorted build declarations, filtering out repeated
#   entries, where possible.
# ------------------------------------------------------------------------------

sub sort_bdeclare {
  my $self = shift;

  # Get list of build configuration labels that can be declared multiple times
  my %cfg_keyword = map {
    ($self->cfglabel ($_), 1)
  } split (/$Fcm::Config::DELIMITER_LIST/, $self->setting ('CFG_KEYWORD'));

  my @bdeclares = ();
  for my $d (reverse @{ $self->bdeclare }) {
    # Reconstruct array from bottom up
    # * always add declarations that can be declared multiple times
    # * otherwise add only if it is declared below
    unshift @bdeclares, $d
      if exists $cfg_keyword{uc (($d->slabel_fields)[0])} or
         not grep {$_->slabel eq $d->slabel} @bdeclares;
  }

  return (sort {$a->slabel cmp $b->slabel} @bdeclares);
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @cfglines = $obj->to_cfglines ();
#
# DESCRIPTION
#   See description of Fcm::ConfigSystem->to_cfglines for further information.
# ------------------------------------------------------------------------------

sub to_cfglines {
  my ($self) = @_;

  return (
    Fcm::ConfigSystem::to_cfglines($self),

    $self->rdest->to_cfglines (),
    Fcm::CfgLine->new (),

    @{ $self->bdeclare } ? (
      Fcm::CfgLine::comment_block ('Build declarations'),
      map {
        Fcm::CfgLine->new (label => $_->label, value => $_->value)
      } ($self->sort_bdeclare),
      Fcm::CfgLine->new (),
    ) : (),

    Fcm::CfgLine::comment_block ('Project and branches'),
    (map {($_->to_cfglines ())} @{ $self->branches }),

    ($self->conflict ne 'merge') ? (
      Fcm::CfgLine->new (
        label => $self->cfglabel ('CONFLICT'), value => $self->conflict,
      ),
      Fcm::CfgLine->new (),
    ) : (),
  );
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @cfglines = $obj->to_cfglines_bld ();
#
# DESCRIPTION
#   Returns a list of configuration lines of the current extract suitable for
#   feeding into the build system.
# ------------------------------------------------------------------------------

sub to_cfglines_bld {
  my ($self) = @_;

  my $dest = $self->rdest->rootdir ? 'rdest' : 'dest';
  my $root = File::Spec->catfile ('$HERE', '..');

  my @inherits;
  my @no_inherits;
  if (@{ $self->inherit }) {
    # List of inherited builds
    for (@{ $self->inherit }) {
      push @inherits, Fcm::CfgLine->new (
        label => $self->cfglabel ('USE'), value => $_->$dest->rootdir
      );
    }

    # List of files that should not be inherited
    for my $key (sort keys %{ $self->files }) {
      next unless $self->files ($key)->dest_status eq 'd';
      my $label = join ('::', (
        $self->cfglabel ('INHERIT'),
        $self->cfglabel ('FILE'),
        split (m#/#, $self->files ($key)->pkgname),
      ));
      push @no_inherits, Fcm::CfgLine->new (label => $label, value => 'false');
    }
  }

  return (
    Fcm::CfgLine::comment_block ('File header'),
    (map
      {my ($lbl, $val) = @{$_}; Fcm::CfgLine->new(label => $lbl, value => $val)}
      (
        [$self->cfglabel('CFGFILE') . $Fcm::Config::DELIMITER . 'TYPE'   , 'bld'],
        [$self->cfglabel('CFGFILE') . $Fcm::Config::DELIMITER . 'VERSION', '1.0'],
        [],
      )
    ),

    @{ $self->inherit } ? (
      @inherits,
      @no_inherits,
      Fcm::CfgLine->new (),
    ) : (),

    Fcm::CfgLine::comment_block ('Destination'),
    Fcm::CfgLine->new (label => $self->cfglabel ('DEST'), value => $root),
    Fcm::CfgLine->new (),

    @{ $self->bdeclare } ? (
      Fcm::CfgLine::comment_block ('Build declarations'),
      map {
        Fcm::CfgLine->new (label => $_->slabel, value => $_->value)
      } ($self->sort_bdeclare),
      Fcm::CfgLine->new (),
    ) : (),
  );
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->write_cfg ();
#
# DESCRIPTION
#   This method writes the configuration file at the end of the run. It calls
#   $self->write_cfg_system ($cfg) to write any system specific settings.
# ------------------------------------------------------------------------------

sub write_cfg {
  my $self = shift;

  my $cfg = Fcm::CfgFile->new (TYPE => $self->type);
  $cfg->lines ([$self->to_cfglines()]);
  $cfg->print_cfg ($self->dest->extcfg);

  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $self->write_cfg_bld ();
#
# DESCRIPTION
#   This internal method writes the build configuration file.
# ------------------------------------------------------------------------------

sub write_cfg_bld {
  my $self = shift;

  my $cfg = Fcm::CfgFile->new (TYPE => 'bld');
  $cfg->lines ([$self->to_cfglines_bld()]);
  $cfg->print_cfg ($self->dest->bldcfg);

  return 1;
}

# ------------------------------------------------------------------------------

1;

__END__
