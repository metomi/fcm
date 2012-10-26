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
#   Fcm::CfgLine
#
# DESCRIPTION
#   This class is used for grouping the settings in each line of a FCM
#   configuration file.
#
# ------------------------------------------------------------------------------

package Fcm::CfgLine;
@ISA = qw(Fcm::Base);

# Standard pragma
use warnings;
use strict;

# Standard modules
use File::Basename;

# In-house modules
use Fcm::Base;
use Fcm::Config;
use Fcm::Util;

# List of property methods for this class
my @scalar_properties = (
  'bvalue',  # line value, in boolean
  'comment', # (in)line comment
  'error',   # error message for incorrect usage while parsing the line
  'label',   # line label
  'line',    # content of the line
  'number',  # line number in source file
  'parsed',  # has this line been parsed (by the extract/build system)?
  'prefix',  # optional prefix for line label
  'slabel',  # label without the optional prefix
  'src',     # name of source file
  'value',   # line value
  'warning', # warning message for deprecated usage
);

# Useful variables
our $COMMENT_RULER = '-' x 78;

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @cfglines = Fcm::CfgLine->comment_block (@comment);
#
# DESCRIPTION
#   This method returns a list of Fcm::CfgLine objects representing a comment
#   block with the comment string @comment.
# ------------------------------------------------------------------------------

sub comment_block {
  my @return = (
    Fcm::CfgLine->new (comment => $COMMENT_RULER),
    (map {Fcm::CfgLine->new (comment => $_)} @_),
    Fcm::CfgLine->new (comment => $COMMENT_RULER),
    Fcm::CfgLine->new (),
  );

  return @return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $obj = Fcm::CfgLine->new (%args);
#
# DESCRIPTION
#   This method constructs a new instance of the Fcm::CfgLine class. See above
#   for allowed list of properties. (KEYS should be in uppercase.)
# ------------------------------------------------------------------------------

sub new {
  my $this  = shift;
  my %args  = @_;
  my $class = ref $this || $this;

  my $self = Fcm::Base->new (%args);

  for (@scalar_properties) {
    $self->{$_} = exists $args{uc ($_)} ? $args{uc ($_)} : undef;
    $self->{$_} = $args{$_} if exists $args{$_};
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

    if (@_) {
      $self->{$name} = $_[0];

      if ($name eq 'line' or $name eq 'label') {
        $self->{slabel} = undef;

      } elsif ($name eq 'line' or $name eq 'value') {
        $self->{bvalue} = undef;
      }
    }

    # Default value for property
    if (not defined $self->{$name}) {
      if ($name =~ /^(?:comment|error|label|line|prefix|src|value)$/) {
        # Blank
        $self->{$name} = '';

      } elsif ($name eq 'slabel') {
        if ($self->prefix and $self->label_starts_with ($self->prefix)) {
          $self->{$name} = $self->label_from_field (1);

        } else {
          $self->{$name} = $self->label;
        }

      } elsif ($name eq 'bvalue') {
        if (defined ($self->value)) {
          $self->{$name} = ($self->value =~ /^(\s*|false|no|off|0*)$/i)
                           ? 0 : $self->value;
        }
      }
    }

    return $self->{$name};
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @fields = $obj->label_fields ();
#   @fields = $obj->slabel_fields ();
#
# DESCRIPTION
#   These method returns a list of fields in the (s)label.
# ------------------------------------------------------------------------------

for my $name (qw/label slabel/) {
  no strict 'refs';

  my $sub_name = $name . '_fields';
  *$sub_name = sub  {
    return (split (/$Fcm::Config::DELIMITER_PATTERN/, $_[0]->$name));
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = $obj->label_from_field ($index);
#   $string = $obj->slabel_from_field ($index);
#
# DESCRIPTION
#   These method returns the (s)label from field $index onwards.
# ------------------------------------------------------------------------------

for my $name (qw/label slabel/) {
  no strict 'refs';

  my $sub_name = $name . '_from_field';
  *$sub_name = sub  {
    my ($self, $index) = @_;
    my $method = $name . '_fields';
    my @fields = $self->$method;
    return join ($Fcm::Config::DELIMITER, @fields[$index .. $#fields]);
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $flag = $obj->label_starts_with (@fields);
#   $flag = $obj->slabel_starts_with (@fields);
#
# DESCRIPTION
#   These method returns a true if (s)label starts with the labels in @fields
#   (ignore case).
# ------------------------------------------------------------------------------

for my $name (qw/label slabel/) {
  no strict 'refs';

  my $sub_name = $name . '_starts_with';
  *$sub_name = sub  {
    my ($self, @fields) = @_;
    my $return = 1;

    my $method = $name . '_fields';
    my @all_fields = $self->$method;

    for my $i (0 .. $#fields) {
      next if lc ($fields[$i]) eq lc ($all_fields[$i]);
      $return = 0;
      last;
    }

    return $return;
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $flag = $obj->label_starts_with_cfg (@fields);
#   $flag = $obj->slabel_starts_with_cfg (@fields);
#
# DESCRIPTION
#   These method returns a true if (s)label starts with the configuration file
#   labels in @fields (ignore case).
# ------------------------------------------------------------------------------

for my $name (qw/label slabel/) {
  no strict 'refs';

  my $sub_name = $name . '_starts_with_cfg';
  *$sub_name = sub  {
    my ($self, @fields) = @_;

    for my $field (@fields) {
      $field = $self->cfglabel ($field);
    }

    my $method = $name . '_starts_with';
    return $self->$method (@fields);
  }
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $mesg = $obj->format_error ();
#
# DESCRIPTION
#   This method returns a string containing a formatted error message for
#   anything reported to the current line.
# ------------------------------------------------------------------------------

sub format_error {
  my ($self) = @_;
  my $mesg = '';

  $mesg .= $self->format_warning;

  if ($self->error or not $self->parsed) {
    $mesg = 'ERROR: ' . $self->src . ': LINE ' . $self->number . ':' . "\n";
    if ($self->error) {
      $mesg .= '       ' . $self->error;

    } else {
      $mesg .= '       ' . $self->label . ': label not recognised.';
    }
  }

  return $mesg;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $mesg = $obj->format_warning ();
#
# DESCRIPTION
#   This method returns a string containing a formatted warning message for
#   any warning reported to the current line.
# ------------------------------------------------------------------------------

sub format_warning {
  my ($self) = @_;
  my $mesg = '';

  if ($self->warning) {
    $mesg = 'WARNING: ' . $self->src . ': LINE ' . $self->number . ':' . "\n";
    $mesg .= '         ' . $self->warning;
  }

  return $mesg;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $line = $obj->print_line ([$space]);
#
# DESCRIPTION
#   This method returns a configuration line using $self->label, $self->value
#   and $self->comment. The value in $self->line is re-set. If $space is set
#   and is a positive integer, it sets the spacing between the label and the
#   value in the line. The default is 1.
# ------------------------------------------------------------------------------

sub print_line {
  my ($self, $space) = @_;

  # Set space between label and value, default to 1 character
  $space = 1 unless $space and $space =~ /^[1-9]\d*$/;

  my $line = '';

  # Add label and value, if label is set
  if ($self->label) {
    $line .= $self->label . ' ' x $space;
    $line .= $self->value if defined $self->value;
  }

  # Add comment if necessary
  my $comment = $self->comment;
  $comment =~ s/^\s*//;

  if ($comment) {
    $comment = '# ' . $comment if $comment !~ /^#/;
    $line .= ' ' if $line;
    $line .= $comment;
  }

  return $self->line ($line);
}

# ------------------------------------------------------------------------------

1;

__END__
