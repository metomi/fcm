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
#   FCM1::Base
#
# DESCRIPTION
#   This is base class for all FCM OO packages.
#
# ------------------------------------------------------------------------------

package FCM1::Base;

# Standard pragma
use strict;
use warnings;

use FCM1::Config;

my @scalar_properties = (
  'config', # instance of FCM1::Config, configuration setting
);

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $obj = FCM1::Base->new;
#
# DESCRIPTION
#   This method constructs a new instance of the FCM1::Base class.
# ------------------------------------------------------------------------------

sub new {
  my $this  = shift;
  my %args  = @_;
  my $class = ref $this || $this;

  my $self  = {};
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
      if ($name eq 'config') {
        # Configuration setting of the main program
        $self->{$name} = FCM1::Config->instance();
      }
    }

    return $self->{$name};
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $value = $self->setting (@args); # $self->config->setting
#   $value = $self->verbose (@args); # $self->config->verbose
# ------------------------------------------------------------------------------

for my $name (qw/setting verbose/) {
  no strict 'refs';

  *$name = sub {
    my $self = shift;
    return $self->config->$name (@_);
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $value = $self->cfglabel (@args);
#
# DESCRIPTION
#   This is an alias to $self->config->setting ('CFG_LABEL', @args);
# ------------------------------------------------------------------------------

sub cfglabel {
  my $self = shift;
  return $self->setting ('CFG_LABEL', @_);
}

# ------------------------------------------------------------------------------

1;

__END__
