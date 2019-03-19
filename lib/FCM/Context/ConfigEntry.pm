# ------------------------------------------------------------------------------
# Copyright (C) 2006-2019 British Crown (Met Office) & Contributors.
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
use strict;
use warnings;

# ------------------------------------------------------------------------------
package FCM::Context::ConfigEntry;
use base qw{FCM::Class::HASH};

use Text::ParseWords qw{shellwords};

__PACKAGE__->class({
    label       => '$',
    modifier_of => '%',
    ns_list     => '@',
    stack       => '@',
    value       => '$',
});

# A shorthand for shellwords($entry->get_value()).
sub get_values {
    shellwords($_[0]->get_value());
}

# The config entry's left hand side of the equal sign.
sub get_lhs {
    my ($self) = @_;
    my $modifier = join(
        q{, },
        (   map
            {   my $value = $self->{modifier_of}{$_};
                join(q{:}, $_, (($value && $value eq 1) ? () : $value));
            }
            sort keys(%{$self->{modifier_of}})
        ),
    );
    my $ns = join(
        q{ },
        (map {my $s = $_; $s =~ s{(["'\s])}{\\$1}gxms; $s} @{$self->{ns_list}}),
    );
    sprintf(
        '%s%s%s',
        $self->{label},
        ($modifier ? "{$modifier}" : q{}),
        ($ns ? "[$ns]" : q{}),
    );
}

# The config entry, as a string.
sub as_string {
    my ($self, $in_fcm1) = @_;
    my $value = $self->{value};
    $value ||= q{};
    $value =~ s{(\\)+(\$)}{$1$1\\$2}gxms;
    sprintf(($in_fcm1 ? '%s %s' : '%s = %s'), $self->get_lhs(), $value);
}

# ------------------------------------------------------------------------------

1;
__END__

=head1 NAME

FCM::Context::ConfigEntry;

=head1 SYNOPSIS

    my $c_entry = FCM::Context::ConfigEntry->new({
        label       => 'egg',
        modifier_of => {fried => 1},
        ns_list     => [qw{all day breakfast}],
        stack       => [[$breakfast_menu, 10], [$menu, 20]],
        value       => 2,
    });

    # ... some time later
    $label       = $c_entry->get_label();
    %modifier_of = %{$c_entry->get_modifier_of()};
    @ns_list     = @{$c_entry->get_ns_list()};
    @stack       = @{$c_entry->get_stack()};
    $value       = $c_entry->get_value();

    print($c_entry->as_string());
    # should print: egg{fried: 1}[all day breakfast] = 2

=head1 DESCRIPTION

This class is based on L<FCM::Class::HASH|FCM::Class::HASH> for representing an
entry in a FCM configuration file. All attributes can be read using the
$instance->get_$attrib() methods.

=head1 ATTRIBUTES

=over 4

=item label

The label of the entry.

=item modifier_of

A HASH containing the modifiers of this entry.

=item ns_list

An ARRAY containing the namespaces of this entry.

=item stack

An ARRAY containing the locator stack that provides this entry. The first
element represents the top of the stack. Each element should be a reference to a
2-element array [RESOURCE, LINE_NUMBER].

=item value

The value of this entry.

=back

=head1 METHODS

=over 4

=item $instance->as_string($in_fcm1)

Returns a string representation of the config entry. If the optional argument
$in_fcm1 is specified, it will return the config entry in FCM 1 format.

=item $instance->get_lhs()

Returns a string representation of the left hand side of the config entry.

=item $instance->get_values()

A shorthand for shellwords($instance->get_value()).

=back

=head1 COPYRIGHT

Copyright (C) 2006-2019 British Crown (Met Office) & Contributors..

=cut
