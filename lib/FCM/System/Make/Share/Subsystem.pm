# ------------------------------------------------------------------------------
# Copyright (C) British Crown (Met Office) & Contributors.
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
package FCM::System::Make::Share::Subsystem;
use base qw{Exporter};

our @EXPORT = qw{
    _config_parse
    _config_parse_class_prop
    _config_parse_prop
    _config_parse_inherit_hook_prop
    _config_unparse_class_prop
    _config_unparse_join
    _config_unparse_prop
    _prop
    _prop0
    _props
};

use FCM::Context::ConfigEntry;
use FCM::Context::Make::Share::Property;
use FCM::System::Exception;
use Storable qw{dclone};
use Text::ParseWords qw{shellwords};

use constant {PROP_DEFAULT => 0, PROP_NS_OK => 1};

# Aliases
my $E = 'FCM::System::Exception';

# Parses a configuration entry into the context.
sub _config_parse {
    my ($attrib_ref, $ctx, $entry, $label) = @_;
    my %config_parser_of = (
        'prop' => \&_config_parse_prop,
        %{$attrib_ref->{config_parser_of}},
    );
    if (!$label || !exists($config_parser_of{$label})) {
        return;
    }
    $config_parser_of{$label}->($attrib_ref, $ctx, $entry);
    1;
}

# Parses a configuration entry into the subsystem property.
sub _config_parse_class_prop {
    my ($attrib_ref, $entry, $label) = @_;
    if ($label ne 'prop') {
        return;
    }
    if (@{$entry->get_ns_list()}) {
        return $E->throw($E->CONFIG_NS, $entry);
    }
    my @keys = grep {$_ ne 'class'} keys(%{$entry->get_modifier_of()});
    if (grep {!exists($attrib_ref->{prop_of}{$_})} @keys) {
        return $E->throw($E->CONFIG_MODIFIER, $entry);
    }
    for my $key (@keys) {
        $attrib_ref->{prop_of}{$key}[PROP_DEFAULT] = $entry->get_value();
    }
    1;
}

# Reads the ?.prop declaration from a config entry.
sub _config_parse_prop {
    my ($attrib_ref, $ctx, $entry) = @_;
    for my $key (keys(%{$entry->get_modifier_of()})) {
        my $prop = $ctx->get_prop_of($key);
        if (!defined($prop)) {
            if (!defined(_prop_default($attrib_ref, $key))) {
                return $E->throw($E->CONFIG_MODIFIER, $entry);
            }
            $prop = FCM::Context::Make::Share::Property->new({id => $key});
            $ctx->get_prop_of()->{$key} = $prop;
        }
        my $prop_ctx;
        if (defined($entry->get_value())) {
            $prop_ctx = $prop->CTX_VALUE->new({value => $entry->get_value()});
        }
        if (!@{$entry->get_ns_list()}) {
            @{$entry->get_ns_list()} = (q{});
        }
        for my $ns (@{$entry->get_ns_list()}) {
            if ($ns && !_prop_ns_ok($attrib_ref, $key)) {
                return $E->throw($E->CONFIG_NS, $entry);
            }
            if (defined($prop_ctx)) {
                $prop->get_ctx_of()->{$ns} = $prop_ctx;
            }
            elsif (exists($prop->get_ctx_of()->{$ns})) {
                delete($prop->get_ctx_of()->{$ns});
            }
        }
    }
}

# A hook command for the "inherit/use" declaration, inherit properties.
sub _config_parse_inherit_hook_prop {
    my ($attrib_ref, $ctx, $i_ctx) = @_;
    while (my ($key, $i_prop) = each(%{$i_ctx->get_prop_of()})) {
        if (!defined($ctx->get_prop_of($key))) {
            $ctx->get_prop_of()->{$key} = dclone($i_prop);
        }
        my %prop_ctx_of = %{$ctx->get_prop_of($key)->get_ctx_of()};
        while (my ($ns, $i_prop_ctx) = each(%{$i_prop->get_ctx_of()})) {
            if (    !exists($prop_ctx_of{$ns})
                ||  $prop_ctx_of{$ns}->get_inherited()
            ) {
                my $prop_ctx = dclone($i_prop_ctx);
                $prop_ctx->set_inherited(1);
                $ctx->get_prop_of($key)->get_ctx_of()->{$ns} = $prop_ctx;
            }
        }
    }
}

# Serializes a list of words.
sub _config_unparse_join {
    join(
        q{ },
        (map {my $s = $_; $s =~ s{(["'\s])}{\\$1}gxms; $s} grep {defined()} @_),
    );
}

# Entries of the class prop settings.
sub _config_unparse_class_prop {
    my ($attrib_ref, $id) = @_;
    map {
        my $key = $_;
        FCM::Context::ConfigEntry->new({
            label       => join(q{.}, $id, 'prop'),
            modifier_of => {'class' => 1, $key => 1},
            value       => $attrib_ref->{prop_of}{$key}[PROP_DEFAULT],
        });
    } sort keys(%{$attrib_ref->{prop_of}});
}

# Entries of the prop settings.
sub _config_unparse_prop {
    my ($attrib_ref, $ctx) = @_;
    my $label = join(q{.}, $ctx->get_id(), 'prop');
    my %prop_of = %{$ctx->get_prop_of()};
    map {
        my $key = $_;
        my $setting = $prop_of{$key};
        map {
            my $ns = $_;
            my $prop_ctx = $setting->get_ctx_of()->{$ns};
            $prop_ctx->get_inherited()
            ? ()
            : FCM::Context::ConfigEntry->new({
                label       => $label,
                modifier_of => {$key => 1},
                ns_list     => ($ns ? [$ns] : []),
                value       => $prop_ctx->get_value(),
            });
        } sort(keys(%{$setting->get_ctx_of()}));
    } sort(keys(%prop_of));
}

# Returns the value of a named property (for a given $ns).
sub _prop {
    my ($attrib_ref, $id, $ctx, $ns) = @_;
    my $setting = defined($ctx) ? $ctx->get_prop_of()->{$id} : undef;
    if (!defined($ctx) || !defined($setting)) {
        return _prop_default($attrib_ref, $id);
    }
    if (!_prop_ns_ok($attrib_ref, $id) || !$ns) {
        my $prop_ctx = $setting->get_ctx();
        return (
              defined($prop_ctx) ? $prop_ctx->get_value()
            :                      _prop_default($attrib_ref, $id)
        );
    }
    my %prop_ctx_of = %{$setting->get_ctx_of()};
    my $iter_ref
        = $attrib_ref->{util}->ns_iter($ns, $attrib_ref->{util}->NS_ITER_UP);
    while (defined(my $item = $iter_ref->())) {
        if (exists($prop_ctx_of{$item}) && defined($prop_ctx_of{$item})) {
            return $prop_ctx_of{$item}->get_value();
        }
    }
    return _prop_default($attrib_ref, $id);
}

# Returns the first non-space value of a $setting for a given $ns.
sub _prop0 {
    (_props(@_))[0];
}

# Returns all suitable values of a $setting for a given $ns.
sub _props {
    my $prop = _prop(@_);
    shellwords($prop ? $prop : q{});
}

# Returns the default value of a named property.
sub _prop_default {
    my ($attrib_ref, $id) = @_;
    if (!exists($attrib_ref->{prop_of}{$id})) {
        return;
    }
    $attrib_ref->{prop_of}{$id}[PROP_DEFAULT];
}

# Returns true if the given property can accept a name-space.
sub _prop_ns_ok {
    my ($attrib_ref, $id) = @_;
        exists($attrib_ref->{prop_of}{$id})
    &&  exists($attrib_ref->{prop_of}{$id}[PROP_NS_OK])
    &&  $attrib_ref->{prop_of}{$id}[PROP_NS_OK]
    ;
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Share::Subsystem

=head1 SYNOPSIS

    use FCM::System::Make::Share::Subsystem;

=head1 DESCRIPTION

Provides common "local" functions for a make subsystem.

=head1 FUNCTIONS

The following functions are automatically exported by this module.

=over 4

=item _config_parse(\%attrib,$ctx,$entry,$label)

Reads a configuration $entry into the $ctx context. The $label is the label of
the $entry, but with the prefix (which should be the same as $ctx->get_id() plus
a dot) removed.

=item _config_parse_class_prop(\%attrib,$entry,$label)

Reads a configuration $entry into the subsystem default property
$attrib{prop_of}. The $label is the label of the $entry, but with the prefix
(the subsystem ID plus a dot) removed.

=item _config_parse_prop(\%attrib,$ctx,$entry)

Reads a property configuration $entry into the $ctx context. This method may
die() with a FCM::System::Exception on error. If the property modifier is
invalid for the given subsystem, it returns an exception with the CODE
FCM::System::Exception->CONFIG_MODIFIER. If the property does not support a
namespace, it returns an exception with the CODE
FCM::System::Exception->CONFIG_NS.

=item _config_parse_inherit_hook_prop(\%attrib,$ctx,$i_ctx)

The $ctx context is the current subsystem context and the $i_ctx context is the
inherited subsystem context. Inherits property settings from $i_ctx into $ctx.

=item _config_unparse_join(@list)

Joins the @list into a string that can be parsed again by shellwords.

=item _config_unparse_class_prop(\%attrib,$id)

Turns the default properties in the current subsystem into a list of
configuration entries. $id is the ID of the current subsystem.

=item _config_unparse_prop(\%attrib,$ctx)

Turns the properties in $ctx into a list of configuration entries.

=item _prop(\%attrib,$id,$ctx,$ns)

Returns the value of property $id. If the property does not exist, it returns
undef. If the property is not defined in $ctx, it returns the default value. If
the property is defined in $ctx, it returns the defined value in $ctx. If $ns is
set and a name-space is allowed for the property, it walks the name-space to
attempt to return the nearest value of the property for the given name-space.

=item _prop0(\%attrib,$id,$ctx,$ns)

Shorthand for (_props(\%attrib,$id,$ctx,$ns))[0].

=item _props(\%attrib,$id,$ctx,$ns)

Shorthand for shellwords(_prop(\%attrib,$id,$ctx,$ns)).

=back

=head1 DEPENDENCIES

The %attrib argument to the functions in this module may require the following
keys to be set correctly: {config_parser_of}, {prop_of}, {util}.

=head1 COPYRIGHT

Copyright (C) British Crown (Met Office) & Contributors..

=cut
