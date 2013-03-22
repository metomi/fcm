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
#   Fcm::ExtractSrc
#
# DESCRIPTION
#   This class is used by the extract system to define the functionalities of a
#   source file (or directory) in a branch.
#
# ------------------------------------------------------------------------------

package Fcm::ExtractSrc;
@ISA = qw(Fcm::Base);

# Standard pragma
use warnings;
use strict;

# FCM component modules
use Fcm::Base;

# List of scalar property methods for this class
my @scalar_properties = (
  'cache',   # location of the cache of this file in the current extract
  'id',      # short ID of the branch where this file is from
  'ignore',  # if set to true, ignore this file from this source
  'pkgname', # package name of this file
  'rev',     # last changed revision/timestamp of this file
  'uri',     # URL/source path of this file
);

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $obj = Fcm::ExtractSrc->new (%args);
#
# DESCRIPTION
#   This method constructs a new instance of the Fcm::ExtractSrc class. See
#   @scalar_properties above for allowed list of properties in the constructor.
# ------------------------------------------------------------------------------

sub new {
  my $this  = shift;
  my %args  = @_;
  my $class = ref $this || $this;

  my $self = Fcm::Base->new (%args);

  for (@scalar_properties) {
    $self->{$_} = exists $args{$_} ? $args{$_} : undef;
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

    return $self->{$name};
  }
}

# ------------------------------------------------------------------------------

1;

__END__
