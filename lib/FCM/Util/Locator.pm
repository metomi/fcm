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
use strict;
use warnings;

# ------------------------------------------------------------------------------
package FCM::Util::Locator;
use base qw{FCM::Class::CODE};

use FCM::Context::Keyword;
use FCM::Context::Locator;
use FCM::Util::Exception;
use FCM::Util::Locator::FS;
use FCM::Util::Locator::SVN;

# URI prefix for FCM scheme
use constant PREFIX => 'fcm';

# Methods of an instance of this class
my %ACTION_OF = (
    as_invariant     => \&_as_invariant,
    as_keyword       => \&_as_keyword,
    as_normalised    => \&_as_normalised,
    as_parsed        => \&_as_parsed,
    browser_url      => \&_browser_url,
    cat              => _locator_func(sub {$_[0]->cat(@_[1 .. $#_])}),
    dir              => _locator_func(sub {$_[0]->dir($_[1])}),
    export           => \&_export,
    export_ok        => \&_export_ok,
    find             => \&_find,
    kw_ctx           => sub {$_[0]->{kw_ctx}},
    kw_ctx_load      => \&_kw_ctx_load,
    kw_iter          => \&_kw_iter,
    kw_load_rev_prop => \&_kw_load_rev_prop,
    kw_prefix        => sub {PREFIX},
    origin           => _locator_func(sub {$_[0]->origin($_[1])}),
    reader           => \&_reader,
    rel2abs          => \&_rel2abs,
    trunk_at_head    => \&_trunk_at_head,
    what_type        => \&_what_type,
    up_iter          => \&_up_iter,
);
# Default browser config
our %BROWSER_CONFIG = (
    comp_pat => qr{\A // ([^/]+) /+ ([^/]+)_svn /*(.*) \z}xms,
    rev_tmpl => '@{1}',
    loc_tmpl => 'http://{1}/projects/{2}/intertrac/source:/{3}{4}',
);
# Alias to the exception class
my $E = 'FCM::Util::Exception';
# Loaders for keyword context from configuration entries
my %KEYWORD_CFG_LOADER_FOR = (
    'location'
    => \&_kw_ctx_load_loc,
    'revision'
    => \&_kw_ctx_load_rev,
    'browser.comp-pat'
    => _kw_ctx_load_browser_func(sub {$_[0]->set_comp_pat($_[1])}),
    'browser.loc-tmpl'
    => _kw_ctx_load_browser_func(sub {$_[0]->set_loc_tmpl($_[1])}),
    'browser.rev-tmpl'
    => _kw_ctx_load_browser_func(sub {$_[0]->set_rev_tmpl($_[1])}),
);
my @KEYWORD_IMPLIED_SUFFICES = (
    [branches => [qw{-br _br}]],
    [tags     => [qw{-tg _tg}]],
    [trunk    => [qw{-tr _tr}]],
);
# Patterns for parsing keyword configurations, etc
my %PATTERN_OF = (
    # Assignment delimiter, e.g. "label = value"
    delim_of_assign  => qr/\s* = \s*/xms,
    # Key of a FCM location keyword, e.g. "um" in "fcm:um"
    parse => qr/
        \A              (?# start)
        ([\w\+\-\.]+)   (?# capture 1, 1 or more word, plus, minus or dot)
        (.*) \z         (?# capture 2, rest of string)
    /xms,
);
# The name of the property where revision keywords are set in primary locations
our $REV_PROP_NAME = 'fcm:revision';
# The known types
our @TYPES = qw{svn fs};
# The classes for the known types
our %TYPE_UTIL_CLASS_OF = (
    fs  => 'FCM::Util::Locator::FS',
    svn => 'FCM::Util::Locator::SVN',
);

# Creates the class.
__PACKAGE__->class(
    {   types              => {isa => '@', default => [@TYPES]},
        type_util_class_of => {isa => '%', default => {%TYPE_UTIL_CLASS_OF}},
        type_util_of       => '%',
        util               => '&',
    },
    {   init => sub {
            my ($attrib_ref) = @_;
            my $K = 'FCM::Context::Keyword';
            $attrib_ref->{browser_config}
                = $K->BROWSER_CONFIG->new(\%BROWSER_CONFIG);
            $attrib_ref->{kw_ctx} = $K->new();
            for my $type (@{$attrib_ref->{types}}) {
                if (!exists($attrib_ref->{type_util_of}{$type})) {
                    my $class = $attrib_ref->{type_util_class_of}{$type};
                    $attrib_ref->{type_util_of}{$type} = $class->new({
                        type_util_of => $attrib_ref->{type_util_of},
                        util         => $attrib_ref->{util},
                    });
                }
            }
        },
        action_of => \%ACTION_OF,
    },
);

# Determines the invariant value of the $locator.
sub _as_invariant {
    my ($attrib_ref, $locator) = @_;
    if ($locator->get_value_level() < $locator->L_INVARIANT) {
        _as_normalised($attrib_ref, $locator);
        my $util_of_type = _util_of_type($attrib_ref, $locator);
        if ($util_of_type->can('as_invariant')) {
            my $value = eval {
                $util_of_type->as_invariant($locator->get_value());
            };
            if (my $e = $@) {
                return $E->throw($E->LOCATOR_AS_INVARIANT, $locator, $e);
            }
            if ($value) {
                $locator->set_value($value);
                $locator->set_value_level($locator->L_INVARIANT);
            }
        }
    }
    $locator->get_value();
}

# Determines the keyword value of the $locator.
sub _as_keyword {
    my ($attrib_ref, $locator) = @_;
    _as_normalised($attrib_ref, $locator);
    my $util_of_type = _util_of_type($attrib_ref, $locator);
    my ($target, $rev) = $util_of_type->parse($locator->get_value());
    my $kw_iter = _kw_iter($attrib_ref, $locator);
    my $entry;
    while (!defined($entry) && defined($entry = $kw_iter->())) {
        if ($entry->is_implied()) {
            $entry = undef;
        }
    }
    if (defined($entry)) {
        $target
            = PREFIX . ':' . $entry->get_key()
            . substr($target, length($entry->get_value()));
    }
    if (defined($rev) && $util_of_type->can_work_with_rev($rev)) {
        my $transformed_rev = _transform_rev_keyword(
            $attrib_ref, $locator, $rev,
            sub {$_[0]->get_entry_by_value($_[1])},
            sub {$_[0]->get_key()},
        );
        if ($transformed_rev) {
            $rev = $transformed_rev;
        }
    }
    scalar($util_of_type->parse($target, $rev));
}

# Determines the normalised value of the $locator.
sub _as_normalised {
    my ($attrib_ref, $locator) = @_;
    if ($locator->get_value_level() < $locator->L_NORMALISED) {
        _as_parsed($attrib_ref, $locator);
        my $util_of_type = _util_of_type($attrib_ref, $locator);
        my ($target, $rev) = $util_of_type->parse($locator->get_value());
        if (defined($rev) && !$util_of_type->can_work_with_rev($rev)) {
            my $origin = $ACTION_OF{origin}->(
                $attrib_ref, FCM::Context::Locator->new($target),
            );
            $rev = _transform_rev_keyword(
                $attrib_ref, $origin, lc($rev),
                sub {$_[0]->get_entry_by_key($_[1])},
                sub {$_[0]->get_value()},
            );
            if (!$rev) {
                return $E->throw($E->LOCATOR_KEYWORD_REV, $locator);
            }
        }
        $locator->set_value(scalar($util_of_type->parse($target, $rev)));
        $locator->set_value_level($locator->L_NORMALISED);
    }
    $locator->get_value();
}

# Determines the parsed value of the $locator.
sub _as_parsed {
    my ($attrib_ref, $locator) = @_;
    if ($locator->get_value_level() < $locator->L_PARSED) {
        my $value = $locator->get_value();
        my ($scheme, $sps) = $attrib_ref->{util}->uri_match($value);
        if ($scheme && $scheme eq PREFIX) {
            my ($key, $trail) = $sps =~ $PATTERN_OF{parse};
            my $entry = $attrib_ref->{kw_ctx}->get_entry_by_key(lc($key));
            if (!defined($entry)) {
                return $E->throw($E->LOCATOR_KEYWORD_LOC, $locator);
            }
            $value = $entry->get_value() . $trail;
        }
        $locator->set_value($value);
        $locator->set_value_level($locator->L_PARSED);
    }
    $locator->get_value();
}

# Determines the browser URL of the $locator.
sub _browser_url {
    my ($attrib_ref, $locator) = @_;
    _as_normalised($attrib_ref, $locator);
    my %GET = (
        comp_pat => sub {$_[0]->get_comp_pat()},
        loc_tmpl => sub {$_[0]->get_loc_tmpl()},
        rev_tmpl => sub {$_[0]->get_rev_tmpl()},
    );
    my %value_of = map {($_, undef)} keys(%GET);
    my $iter = _kw_iter($attrib_ref, $locator);
    while (my $entry = $iter->()) {
        if (defined($entry->get_browser_config())) {
            for my $key (keys(%value_of)) {
                if (!defined($value_of{$key})) {
                    my $value = $GET{$key}->($entry->get_browser_config());
                    if (defined($value)) {
                        $value_of{$key} = $value;
                    }
                }
            }
        }
    }
    for my $key (keys(%value_of)) {
        if (!$value_of{$key}) {
            $value_of{$key} = $GET{$key}->($attrib_ref->{browser_config});
        }
    }
    # Extracts components from the locator
    my $origin = $ACTION_OF{origin}->($attrib_ref, $locator);
    my ($target, $rev)
        = _util_of_type($attrib_ref, $origin)->parse($origin->get_value());
    my ($scheme, $sps) = $attrib_ref->{util}->uri_match($target);
    if (!$sps) {
        return $E->throw($E->LOCATOR_BROWSER_URL, $locator);
    }
    my @matches = $sps =~ $value_of{comp_pat};
    if (!@matches) {
        return $E->throw($E->LOCATOR_BROWSER_URL, $locator);
    }
    # Places the components into the template
    my $result = $value_of{loc_tmpl};
    for my $field_number (1 .. @matches) {
        my $match = $matches[$field_number - 1];
        $result =~ s/\{ $field_number \}/$match/xms;
    }
    my $rev_field_number = scalar(@matches) + 1;
    my $rev_string = q{};
    if ($rev) {
        $rev_string = $value_of{rev_tmpl};
        $rev_string =~ s/\{1\}/$rev/xms;
    }
    $result =~ s/\{ $rev_field_number \}/$rev_string/xms;
    return $result;
}

# Exports $locator to a $dest.
sub _export {
    my ($attrib_ref, $locator, $dest) = @_;
    if (_util_of_type($attrib_ref, $locator)->can('export')) {
        _as_normalised($attrib_ref, $locator);
        my $util_of_type = _util_of_type($attrib_ref, $locator);
        $util_of_type->export($locator->get_value(), $dest);
    }
}

# Returns true if it is possible to safely export $locator.
sub _export_ok {
    my ($attrib_ref, $locator) = @_;
    my $util_of_type = _util_of_type($attrib_ref, $locator);
    _as_parsed($attrib_ref, $locator);
    $util_of_type->can('export_ok')
        && $util_of_type->export_ok($locator->get_value());
}

# Searches the directory tree of $locator. Calls a function for each node.
sub _find {
    my ($attrib_ref, $locator, $callback) = @_;
    _as_invariant($attrib_ref, $locator);
    my $type = $locator->get_type();
    my $util_of_type = _util_of_type($attrib_ref, $locator);
    my $found = $util_of_type->find(
        $locator->get_value(),
        sub {
            my ($value, $target_attrib_ref) = @_;
            my $new_locator;
            if ($value eq $locator->get_value()) {
                $locator->set_last_mod_rev($target_attrib_ref->{last_mod_rev});
                $locator->set_last_mod_time($target_attrib_ref->{last_mod_time});
                $new_locator = $locator;
            }
            else {
                $new_locator = FCM::Context::Locator->new($value, {
                    last_mod_rev  => $target_attrib_ref->{last_mod_rev},
                    last_mod_time => $target_attrib_ref->{last_mod_time},
                    type          => $type,
                    value_level   => FCM::Context::Locator->L_INVARIANT,
                });
            }
            $callback->($new_locator, $target_attrib_ref);
        },
    );
    return ($found ? $found : $E->throw($E->LOCATOR_FIND, $locator));
}

# Loads the keyword context from configuration entries.
sub _kw_ctx_load {
    my ($attrib_ref, @config_entry_iterators) = @_;
    for my $config_entry_iterator (@config_entry_iterators) {
        while (my $config_entry = $config_entry_iterator->()) {
            my $handler = $KEYWORD_CFG_LOADER_FOR{$config_entry->get_label()};
            if (defined($handler)) {
                $handler->($attrib_ref, $config_entry);
            }
        }
    }
}

# Loads a location keyword browser config from a configuration entry.
sub _kw_ctx_load_browser_func {
    my ($setter_ref) = @_;
    sub {
        my ($attrib_ref, $c_entry) = @_;
        my %entry_by_key = %{$attrib_ref->{kw_ctx}->get_entry_by_key()};
        if (@{$c_entry->get_ns_list()}) {
            for my $key (@{$c_entry->get_ns_list()}) {
                if (exists($entry_by_key{$key})) {
                    $setter_ref->(
                        $entry_by_key{$key}->get_browser_config(),
                        $c_entry->get_value(),
                    );
                }
            }
        }
        else {
            $setter_ref->($attrib_ref->{browser_config}, $c_entry->get_value());
        }
    }
}

# Loads the location keyword context from a configuration entry.
sub _kw_ctx_load_loc {
    my ($attrib_ref, $c_entry) = @_;
    my $key   = lc($c_entry->get_ns_list()->[0]);
    my $value = $c_entry->get_value();
    my $M     = $c_entry->get_modifier_of();
    my $type  = (exists($M->{type}) ? $M->{type} : undef);
    my $entry
        = $attrib_ref->{kw_ctx}->add_entry($key, $value, {type => $type});
    if (exists($M->{primary}) && $M->{primary}) {
        my $locator = FCM::Context::Locator->new($value, {type => $type});
        my $util_of_type = _util_of_type($attrib_ref, $locator);
        for (@KEYWORD_IMPLIED_SUFFICES) {
            my ($value_suffix, $key_suffix_ref) = @{$_};
            my $locator = $ACTION_OF{cat}->($attrib_ref, $locator, $value_suffix);
            my $value = $locator->get_value();
            for my $key_suffix (@{$key_suffix_ref}) {
                my $implied_entry = $entry->get_ctx_of_implied()->add_entry(
                    $key . $key_suffix, $value, {implied => 1, type => $type},
                );
                $attrib_ref->{kw_ctx}->add_entry($implied_entry);
            }
        }
    }
}

# Loads the revision keyword context from a configuration entry.
sub _kw_ctx_load_rev {
    my ($attrib_ref, $c_entry) = @_;
    for my $ns (map {lc($_)} @{$c_entry->get_ns_list()}) {
        my ($key, $r_key) = split(qr{:}msx, $ns);
        my $entry = $attrib_ref->{kw_ctx}->get_entry_by_key($key);
        if (defined($entry)) {
            $entry->get_ctx_of_rev()->add_entry($r_key, $c_entry->get_value());
        }
    }
}

# Returns an iterator that returns location keyword entry context for $locator.
sub _kw_iter {
    my ($attrib_ref, $locator, $callback_ref) = @_;
    my $origin = $ACTION_OF{origin}->($attrib_ref, $locator);
    my $iter = _up_iter($attrib_ref, $origin);
    sub {
        while (my ($leader) = $iter->()) {
            my $entry = $attrib_ref->{kw_ctx}->get_entry_by_value($leader);
            if (defined($entry)) {
                if (defined($callback_ref)) {
                    $callback_ref->($entry);
                }
                return $entry;
            }
        }
        return;
    }
}

# Loads revision keywords from the "fcm:revision" property of the locator value
# of a location keyword entry.
sub _kw_load_rev_prop {
    my ($attrib_ref, $entry) = @_;
    if ($entry->get_loaded_rev_prop() || $entry->get_implied()) {
        return;
    }
    $entry->set_loaded_rev_prop(1);
    my $locator = FCM::Context::Locator->new(
        $entry->get_value(), {type => $entry->get_type()},
    );
    my $property = _read_property($attrib_ref, $locator, $REV_PROP_NAME);
    if (!$property) {
        return;
    }
    for my $line (split(qr{\s*\n\s*}xms, $property)) {
        my ($key, $value) = split($PATTERN_OF{delim_of_assign}, $line, 2);
        $entry->get_ctx_of_rev()->add_entry($key, $value);
    }
}

# Returns a function to "transform" a $locator to another locator.
sub _locator_func {
    my ($impl_ref) = @_;
    sub {
        my ($attrib_ref, $locator, @args) = @_;
        _as_parsed($attrib_ref, $locator);
        my $util_of_type = _util_of_type($attrib_ref, $locator);
        FCM::Context::Locator->new(
            scalar($impl_ref->($util_of_type, $locator->get_value(), @args)),
            {type => $locator->get_type()},
        );
    }
}

# Returns a file handle to read the content of $locator.
sub _reader {
    my ($attrib_ref, $locator) = @_;
    _as_normalised($attrib_ref, $locator);
    my $reader = eval {
        _util_of_type($attrib_ref, $locator)->reader($locator->get_value());
    };
    if (my $e = $@) {
        return $E->throw($E->LOCATOR_READER, $locator, $e);
    }
    if (!defined($reader)) {
        return $E->throw($E->LOCATOR_READER, $locator);
    }
    return $reader;
}

# Returns the contents in a named property of $locator
sub _read_property {
    my ($attrib_ref, $locator, $prop_name) = @_;
    _as_normalised($attrib_ref, $locator);
    my $util_of_type = _util_of_type($attrib_ref, $locator);
    eval {$util_of_type->read_property($locator->get_value(), $prop_name)};
}

# If $locator->get_value() is a relative path, set it to a absolute path
# base on $locator_base->get_value(), if $locator->get_type() does not differ
# from $locator_base->get_type().
sub _rel2abs {
    my ($attrib_ref, $locator, $locator_base) = @_;
    _as_normalised($attrib_ref, $locator_base);
    if (    $locator->get_type()
        &&  $locator->get_type() ne $locator_base->get_type()
    ) {
        return $locator;
    }
    my $value = $locator->get_value();
    if (    $attrib_ref->{util}->uri_match($value)
        ||  index($value, '/') == 0
        ||  index($value, '~') == 0
    ) {
        return $locator;
    }
    my $new_locator = $ACTION_OF{cat}->($attrib_ref, $locator_base, $value);
    $locator->set_value($new_locator->get_value());
    $locator->set_value_level($new_locator->get_value_level());
    $locator;
}

# Transforms a revision from/to a keyword, and returns the result.
sub _transform_rev_keyword {
    my ($attrib_ref, $locator, $rev, $rev_entry_func, $result_func) = @_;
    my $iter = _kw_iter($attrib_ref, $locator);
    while (my $entry = $iter->()) {
        # $entry->get_ctx_of_rev()->get_entry_by_key($rev)
        # $entry->get_ctx_of_rev()->get_entry_by_value($rev)
        if (defined($entry->get_ctx_of_rev())) {
            if (!$rev_entry_func->($entry->get_ctx_of_rev(), $rev)) {
                _kw_load_rev_prop($attrib_ref, $entry);
            }
        }
        if (defined($entry->get_ctx_of_rev())) {
            my $rev_entry = $rev_entry_func->($entry->get_ctx_of_rev(), $rev);
            if (defined($rev_entry)) {
                # $rev_entry->get_value()
                # $rev_entry->get_key()
                return $result_func->($rev_entry);
            }
        }
    }
    return;
}

# Returns a string to represent the relative path to the latest main tree.
sub _trunk_at_head {
    my ($attrib_ref, $locator) = @_;
    _util_of_type($attrib_ref, $locator)->trunk_at_head($locator->get_value());
}

# Determines the type of the $locator.
sub _what_type {
    my ($attrib_ref, $locator) = @_;
    if (!defined($locator->get_type())) {
        _as_parsed($attrib_ref, $locator);
        TYPE:
        for my $key (@{$attrib_ref->{types}}) {
            if (!exists($attrib_ref->{type_util_of}{$key})) {
                next TYPE;
            }
            my $util_of_type = $attrib_ref->{type_util_of}{$key};
            if ($util_of_type->can_work_with($locator->get_value())) {
                $locator->set_type($key);
                last TYPE;
            }
        }
    }
    return $locator->get_type();
}

# Returns an iterator that walks up the hierarchy of the $locator.
sub _up_iter {
    my ($attrib_ref, $locator) = @_;
    my $util_of_type = _util_of_type($attrib_ref, $locator);
    my ($target, $revision) = $util_of_type->parse($locator->get_value());
    my $leader = $target;
    sub {
        if (!defined($leader)) {
            $leader = $target;
            return;
        }
        my $return = $leader;
        $leader = $util_of_type->dir($return);
        if ($return eq $leader) {
            $leader = undef;
        }
        return $util_of_type->parse($return, $revision);
    };
}

# Returns the utility that implements the functionality for the $locator's type.
sub _util_of_type {
    my ($attrib_ref, $locator) = @_;
    my $type = _what_type($attrib_ref, $locator);
    if (exists($attrib_ref->{type_util_of}{$type})) {
        return $attrib_ref->{type_util_of}{$type};
    }
    return $E->throw($E->LOCATOR_TYPE, $locator);
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Util::Locator

=head1 SYNOPSIS

    use FCM::Util;
    my $util = FCM::Util->new(\%attrib);

    # Usage
    $ctx = $util->loc_kw_ctx();
    @location_keyword_ctx_list = $util->loc_kw_ctx($locator);

    $type = $util->loc_what_type($locator);
    ($time, $rev) = $util->loc_when_modified($locator);

    $locator_value = $util->loc_as_normalised($locator);
    $locator_value = $util->loc_as_invariant( $locator);
    $locator_value = $util->loc_as_keyword(   $locator);

    $url = $util->loc_browser_url($locator);

    $locator_of_parent = $util->loc_dir($locator);
    $locator_of_child  = $util->loc_cat($locator, @paths);
    $locator_of_origin = $util->loc_origin($locator);

    $iter = $util->loc_up_iter($locator);
    while (my $value = $iter->()) {
        # ...
    }

    $reader = $util->loc_reader($locator);

=head1 DESCRIPTION

This module is part of L<FCM::Util|FCM::Util>. It implements the loc_* methods.

=head1 IMPLEMENTATION

The manipulations of locator values rely on objects with the following
interface:

=over 4

=item $util_of_type->as_invariant($locator_value)

Should return the invariant form of $locator_value.

=item $util_of_type->can_work_with($locator_value)

Should return true if it can work with $locator_value, i.e. $locator_value is a
valid type of locator for the utility.

=item $util_of_type->can_work_with_rev($revision_value)

Should return true if it can work with $revision_value, i.e. $revision_value is
a valid revision for the utility.

=item $util_of_type->cat($locator_value, @paths)

Should concatenate $locator_value and @paths with appropriate separators and
returns the result.

=item $util_of_type->dir($locator_value)

Should return the parent (directory) of $locator_value.

=item $util_of_type->export($locator_value,$dest)

Optional. Exports a clean directory tree from $locator_value to $dest.

=item $util_of_type->export_ok($locator_value)

Optional. Returns true if it is safe to export $locator_value. E.g. it is not
safe to export a SVN working copy, because it may contain unversioned items.

=item $util_of_type->find($locator_value,$callback)

Should search the directory tree in $locator_value and for each node (directory
or file, inclusive of $locator_value), invoke
$callback->($locator_value_of_child,\%attrib_of_child). %attrib_of_child should
contain the elements as described by $util->find($locator,$callback).

=item $util_of_type->origin($locator_value)

Should return the origin of $locator_value. E.g. the URL of a Subversion working
copy.

=item $util_of_type->parse($locator_value)

Should return an absolute and tidied version of $locator_value. In list context,
should return a 2-element list, separate the scalar context return value into
the components (PATH,REV).

=item $util_of_type->reader($locator_value)

Should return a file handle for reading the content of $locator_value.

=item $util_of_type->read_property($locator_value,$property_name)

Should return the value of the named property in $locator_value, or undef if
not relevant for the $locator_value.

=item $util_of_type->trunk_at_head($locator_value)

If relevant, should return a string that represents the recommended relative
path to the latest version of the main tree of a project of this type. E.g. for
"svn", this should be "trunk@HEAD".

=back

=head1 CONSTANTS

These global variables are for reference only. Their values should not be
modified. Instead, use the appropriate attributes of the $class->new(\%attrib)
method to modify the behaviour.

=over 4

=item %FCM::Util::Locator::BROWSER_CONFIG

The default browser configuration.

=item FCM::Util::Locator::PREFIX

The URI prefix for a FCM location keyword.

=item $FCM::Util::Locator::REV_PROP_NAME

The name of the property where revision keywords are set in primary locations.

=item @FCM::Util::Locator::TYPES

The known locator types.

=item %FCM::Util::Locator::TYPE_UTIL_CLASS_OF

Maps the known locator types with their utility classes.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
