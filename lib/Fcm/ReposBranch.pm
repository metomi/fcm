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
#   Fcm::ReposBranch
#
# DESCRIPTION
#   This class contains methods for gathering information for a repository
#   branch. It currently supports Subversion repository and local user
#   directory.
#
# ------------------------------------------------------------------------------

use warnings;
use strict;

package Fcm::ReposBranch;
use base qw{Fcm::Base};

use Fcm::CfgLine;
use Fcm::Keyword;
use Fcm::Util      qw{expand_tilde is_url run_command w_report};
use File::Basename qw{dirname};
use File::Find     qw{find};
use File::Spec;

# List of scalar property methods for this class
my @scalar_properties = (
  'package',  # package name of which this repository belongs
  'repos',    # repository branch root URL/path
  'revision', # the revision of this branch
  'tag',      # "tag" name of this branch of the repository
  'type',     # repository type
);

# List of hash property methods for this class
my @hash_properties = (
  'dirs',    # list of non-recursive directories in this branch
  'expdirs', # list of recursive directories in this branch
);

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $obj = Fcm::ReposBranch->new (%args);
#
# DESCRIPTION
#   This method constructs a new instance of the Fcm::ReposBranch class. See
#   @scalar_properties above for allowed list of properties in the constructor.
#   (KEYS should be in uppercase.)
# ------------------------------------------------------------------------------

sub new {
  my $this  = shift;
  my %args  = @_;
  my $class = ref $this || $this;

  my $self = Fcm::Base->new (%args);

  for (@scalar_properties) {
    $self->{$_} = exists $args{uc ($_)} ? $args{uc ($_)} : undef;
  }

  $self->{$_} = {} for (@hash_properties);

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
#   $rc = $obj->expand_revision;
#
# DESCRIPTION
#   This method expands the revision keywords of the current branch to a
#   revision number. It returns true on success.
# ------------------------------------------------------------------------------

sub expand_revision {
  my $self = shift;

  my $rc = 1;
  if ($self->type eq 'svn') {
    # Expand revision keyword
    my $rev = (Fcm::Keyword::expand($self->repos(), $self->revision()))[1];

    # Get last changed revision of the specified revision
    my $info_ref = $self->_svn_info($self->repos(), $rev);
    if (!defined($info_ref->{'Revision'})) {
      my $url = $self->repos() . ($rev ? '@' . $rev : q{});
      w_report("ERROR: $url: not a valid URL\n");
      return 0;
    }
    my $lc_rev = $info_ref->{'Last Changed Rev'};
    $rev       = $info_ref->{'Revision'};

    # Print info if specified revision is not the last commit revision
    if (uc($self->revision()) ne 'HEAD' && $lc_rev != $rev) {
      my $message = $self->repos . '@' . $rev . ': last changed at [' .
                    $lc_rev . '].';
      if ($self->setting ('EXT_REVMATCH') and uc ($self->revision) ne 'HEAD') {
        w_report "ERROR: specified and last changed revisions differ:\n",
                 '       ', $message, "\n";
        $rc = 0;

      } else {
        print 'INFO: ', $message, "\n";
      }
    }

    if ($self->verbose > 1 and uc ($self->revision) ne 'HEAD') {
      # See if there is a later change of the branch at the HEAD
      my $head_lc_rev = $self->_svn_info($self->repos())->{'Last Changed Rev'};

      if (defined($head_lc_rev) && $head_lc_rev != $lc_rev) {
        # Ensure that this is the same branch by checking its history
        my @lines = &run_command (
          [qw/svn log -q --incremental -r/, $lc_rev, $self->repos . '@HEAD'],
          METHOD => 'qx', TIME => $self->verbose > 2, ERROR => 'ignore',
        );

        print 'INFO: ', $self->repos, '@', $rev,
              ': newest commit at [', $head_lc_rev, '].', "\n"
          if @lines;
      }
    }

    $self->revision ($rev) if $rev ne $self->revision;

  } elsif ($self->type eq 'user') {
    1; # Do nothing

  } else {
    w_report 'ERROR: ', $self->repos, ': repository type "', $self->type,
             '" not supported.';
    $rc = 0;
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->expand_path;
#
# DESCRIPTION
#   This method expands the relative path names of sub-directories to full
#   path names. It returns true on success.
# ------------------------------------------------------------------------------

sub expand_path {
  my $self = shift;

  my $rc = 1;
  if ($self->type eq 'svn') {
    # SVN repository
    # Do nothing unless there is a declared repository for this branch
    return unless $self->repos;

    # Remove trailing /
    my $repos = $self->repos;
    $self->repos ($repos) if $repos =~ s#/+$##;

    # Consider all declared (expandable) sub-directories
    for my $name (qw/dirs expdirs/) {
      for my $dir (keys %{ $self->$name }) {
        # Do nothing if declared sub-directory is quoted as a full URL
        next if &is_url ($self->$name ($dir));

        # Expand sub-directory to full URL
        $self->$name ($dir, $self->repos . (
          $self->$name ($dir) ? ('/' . $self->$name ($dir)) : ''
        ));
      }
    }
    # Note: "catfile" cannot be used in the above statement because it has
    #       the tendency of removing a slash from double slashes.

  } elsif ($self->type eq 'user') {
    # Local user directories

    # Expand leading ~ for all declared (expandable) sub-directories
    for my $name (qw/dirs expdirs/) {
      for my $dir (keys %{ $self->$name }) {
        $self->$name ($dir, expand_tilde $self->$name ($dir));
      }
    }

    # A top directory for the source is declared
    if ($self->repos) {
      # Expand leading ~ for the top directory
      $self->repos (expand_tilde $self->repos);

      # Get the root directory of the file system
      my $rootdir = File::Spec->rootdir ();

      # Expand top directory to absolute path, if necessary
      $self->repos (File::Spec->rel2abs ($self->repos))
        if $self->repos !~ m/^$rootdir/;

      # Remove trailing /
      my $repos = $self->repos;
      $self->repos ($repos) if $repos =~ s#/+$##;

      # Consider all declared (expandable) sub-directories
      for my $name (qw/dirs expdirs/) {
        for my $dir (keys %{ $self->$name }) {
          # Do nothing if declared sub-directory is quoted as a full path
          next if $self->$name ($dir) =~ m#^$rootdir#;

          # Expand sub-directory to full path
          $self->$name (
            $dir, $self->$name ($dir)
                  ? File::Spec->catfile ($self->repos, $self->$name ($dir))
                  : $self->repos
          );
        }
      }
    }

  } else {
    w_report 'ERROR: ', $self->repos, ': repository type "', $self->type,
             '" not supported.';
    $rc = 0;
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = $obj->expand_all();
#
# DESCRIPTION
#   This method searches the expandable source directories recursively for
#   source directories containing regular files. The namespaces and the locators
#   of these sub-directories are then added to the source directory hash table.
#   Returns true on success.
# ------------------------------------------------------------------------------

sub expand_all {
  my ($self) = @_;
  my %finder_of = (
    user => sub {
      my ($root_locator) = @_;
      my %ns_of;
      my $wanted = sub {
        my $base_name = $_;
        my $path = $File::Find::name;
        if (-f $path && -r $path && !-l $path) {
          my $dir_path      = dirname($path);
          my $rel_dir_path  = File::Spec->abs2rel($dir_path, $root_locator);
          if ($rel_dir_path eq q{.}) {
             $rel_dir_path = q{};
          }
          if (!exists($ns_of{$dir_path})) {
            $ns_of{$dir_path} = [File::Spec->splitdir($rel_dir_path)];
          }
        }
      };
      find($wanted, $root_locator);
      return \%ns_of;
    },
    svn  => sub {
      my ($root_locator) = @_;
      my $runner = sub {
        map {chomp($_); $_} run_command(
          ['svn', @_,  '-R', join('@', $root_locator, $self->revision())],
          METHOD => 'qx', TIME => $self->config()->verbose() > 2,
        );
      };
      # FIXME: check for symlink switched off due to "svn pg" being very slow
      #my %symlink_in
      #  = map {($_ =~ qr{\A(.+)\s-\s(\*)\z}xms)} ($runner->(qw{pg svn:special}));
      #my @locators
      #  = grep {$_ !~ qr{/\z}xms && !$symlink_in{$_}} ($runner->('ls'));
      my @locators = grep {$_ !~ qr{/\z}xms} ($runner->('ls'));
      my %ns_of;
      for my $locator (@locators) {
        my ($rel_dir_locator) = $locator =~ qr{\A(.*)/[^/]+\z}xms; # dirname
        $rel_dir_locator ||= q{};
        my $dir_locator
          = $rel_dir_locator ? join(q{/}, $root_locator, $rel_dir_locator)
          :                    $root_locator
          ;
        if (!exists($ns_of{$dir_locator})) {
          $ns_of{$dir_locator} = [split(q{/}, $rel_dir_locator)];
        }
      }
      return \%ns_of;
    },
  );

  if (!defined($finder_of{$self->type()})) {
    w_report(sprintf(
        qq{ERROR: %s: resource type "%s" not supported},
        $self->repos(),
        $self->type(),
    ));
    return;
  }
  while (my ($root_ns, $root_locator) = each(%{$self->expdirs()})) {
    my @root_ns_list = split(qr{$Fcm::Config::DELIMITER}xms, $root_ns);
    my $ns_hash_ref = $finder_of{$self->type()}->($root_locator);
    while (my ($dir_path, $ns_list_ref) = each(%{$ns_hash_ref})) {
      if (!grep {$_ =~ qr{\A\.}xms || $_ =~ qr{~\z}xms} @{$ns_list_ref}) {
        my $ns = join($Fcm::Config::DELIMITER, @root_ns_list, @{$ns_list_ref});
        $self->dirs($ns, $dir_path);
      }
    }
  }
  return 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $n = $obj->add_base_dirs ($base);
#
# DESCRIPTION
#   Add a list of source directories to the current branch based on the set
#   provided by $base, which must be a reference to a Fcm::ReposBranch
#   instance. It returns the total number of used sub-directories in the
#   current repositories.
# ------------------------------------------------------------------------------

sub add_base_dirs {
  my $self = shift;
  my $base = shift;

  my %base_dirs = %{ $base->dirs };

  for my $key (keys %base_dirs) {
    # Remove repository root from base directories
    if ($base_dirs{$key} eq $base->repos) {
      $base_dirs{$key} = '';

    } else {
      $base_dirs{$key} = substr $base_dirs{$key}, length ($base->repos) + 1;
    }

    # Append base directories to current repository root
    $self->dirs ($key, $base_dirs{$key});
  }

  # Expand relative path names of sub-directories
  $self->expand_path;

  return scalar keys %{ $self->dirs };
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @cfglines = $obj->to_cfglines ();
#
# DESCRIPTION
#   This method returns a list of configuration lines for the current branch.
# ------------------------------------------------------------------------------

sub to_cfglines {
  my ($self) = @_;
  my @return = ();

  my $suffix = $self->package . $Fcm::Config::DELIMITER . $self->tag;
  push @return, Fcm::CfgLine->new (
    label => $self->cfglabel ('REPOS') . $Fcm::Config::DELIMITER . $suffix,
    value => $self->repos,
  ) if $self->repos;

  push @return, Fcm::CfgLine->new (
    label => $self->cfglabel ('REVISION') . $Fcm::Config::DELIMITER . $suffix,
    value => $self->revision,
  ) if $self->revision;

  for my $key (sort keys %{ $self->dirs }) {
    my $value = $self->dirs ($key);

    # Use relative path where possible
    if ($self->repos) {
      if ($value eq $self->repos) {
        $value = '';

      } elsif (index ($value, $self->repos) == 0) {
        $value = substr ($value, length ($self->repos) + 1);
      }
    }

    # Use top package name where possible
    my $dsuffix = $key . $Fcm::Config::DELIMITER . $self->tag;
    $dsuffix = $suffix if $value ne $self->dirs ($key) and $key eq join (
      $Fcm::Config::DELIMITER, $self->package, File::Spec->splitdir ($value)
    );

    push @return, Fcm::CfgLine->new (
      label => $self->cfglabel ('DIRS') . $Fcm::Config::DELIMITER . $dsuffix,
      value => $value,
    );
  }

  push @return, Fcm::CfgLine->new ();

  return @return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   my $hash_ref = $self->_svn_info($url[, $rev]);
#
# DESCRIPTION
#   Executes "svn info" and returns each field in a hash.
# ------------------------------------------------------------------------------
sub _svn_info {
  my ($self, $url, $rev) = @_;
  return {
    map {
      chomp();
      my ($key, $value) = split(qr{\s*:\s*}xms, $_, 2);
      $key ? ($key, $value) : ();
    } run_command(
      [qw{svn info}, ($rev ? ('-r', $rev, join('@', $url, $rev)) : $url)], 
      DEVNULL => 1,
      ERROR   => 'ignore',
      METHOD  => 'qx',
      TIME    => $self->verbose() > 2,
    )
  };
}

# ------------------------------------------------------------------------------

1;

__END__
