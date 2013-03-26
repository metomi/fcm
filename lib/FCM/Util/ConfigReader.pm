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
package FCM::Util::ConfigReader;
use base qw{FCM::Class::CODE};

use FCM::Context::ConfigEntry;
use FCM::Context::Event;
use FCM::Context::Locator;
use FCM::Util::Exception;
use Text::Balanced   qw{extract_bracketed};
use Text::ParseWords qw{parse_line shellwords};

# Alias
our $EVENT;
# Alias to exception class
my $E = 'FCM::Util::Exception';
# The variable name, which means the container of the current configuration file
my $HERE = 'HERE';
# Element indices in a stack item
my ($I_LOCATOR, $I_LINE_NUM, $I_HANDLE, $I_HERE_FUNC) = (0 .. 3);
# Patterns for extracting/matching strings
my %PATTERN_OF = (
    # Config: comment delimiter, e.g. "... #comment"
    comment => qr/\s+ \#/xms,
    # Config: continue, start of next line
    cont_next => qr/
        \A (.*?)        (?# start and capture 1, shortest of anything)
        (\\*)           (?# capture 2, a number of backslashes)
        \s* \z          (?# optional space until the end)
    /xms,
    # Config: continue, end of previous line
    cont_prev => qr/\A \s* \\? (.*) \z/xms,
    # Config: removal of the assignment operator at start of string
    fcm2_equal => qr/
        \A \s*          (?# start and optional spaces)
        (=)             (?# capture 1, equal sign)
        (.*) \z         (?# capture 2, rest of string)
    /xms,
    # Config: label of an inc statement
    fcm1_include => qr/\Ainc\z/ixms,
    # Config: label of an include statement
    fcm2_include => qr/\Ainclude\z/ixms,
    # Config: label
    fcm2_label => qr/
        \A \s*          (?# start and optional spaces)
        (\$?[\w\-\.]+)  (?# capture 1, optional dollar, then valid label)
        (.*) \z         (?# capture 2, rest of string)
    /xms,
    # Config: a variable identifier in a value, e.g. "... ${var}", "$var"
    fcm1_var => qr/
        \A              (?# start)
        (.*?)           (?# capture 1, shortest of anything)
        ([\$\%])        (?# capture 2, variable sigil, dollar or percent)
        (\{)?           (?# capture 3, curly brace start, optional)
        ([A-z]\w+(?:::[A-z]\w+)*) (?# capture 4, variable name)
        ((?(3)\}))      (?# capture 5, curly brace end, if started in capture 4)
        (.*)            (?# capture 6, rest of string)
        \z              (?# end)
    /xms,
    # Config: a variable identifier in a value, e.g. "... ${var}", "$var"
    fcm2_var => qr/
        \A              (?# start)
        (.*?)           (?# capture 1, shortest of anything)
        (\\*)           (?# capture 2, escapes)
        (\$)            (?# capture 3, variable sigil, dollar)
        (\{)?           (?# capture 4, curly brace start, optional)
        ([A-z]\w+)      (?# capture 5, variable name)
        ((?(4)\}))      (?# capture 6, curly brace end, if started in capture 4)
        (.*)            (?# capture 7, rest of string)
        \z              (?# end)
    /xms,
    # Config: a $HERE, ${HERE} in the beginning of a string
    here => qr/
        \A                  (?# start)
        (\$HERE|\$\{HERE\}) (?# capture 1, \$HERE)
        (\/.*)?             (?# capture 2, rest of string)
        \z                  (?# end)
    /xms,
    # Config: an empty or comment line
    ignore => qr/\A \s* (?:\#|\z)/xms,
    # Config: comma separator
    delim_csv => qr/\s*,\s*/xms,
    # Config: modifier key:value separator
    delim_mod => qr/\s*:\s*/xms,
    # A variable name
    var_name => qr/\A [A-Za-z_]\w* \z/xms,
    # Config: trim value
    trim => qr/\A \s* (.*?) \s* \z/xms,
    # Config: trim value within braces
    trim_brace => qr/\A [\[\{] \s* (.*?) \s* [\]\}] \z/xms,
);
# Default (post-)processors for a configuration entry
our %FCM1_ATTRIB = (
    parser    => _parse_func(\&_parse_fcm1_label, \&_parse_fcm1_var),
    processor => sub {
        _process_assign_func('%')->(@_)
        ||
        _process_include_func('fcm1_include')->(@_)
        ||
        _process_fcm1_label(@_)
        ;
    },
);
# Default (post-)processors for a configuration entry
our %FCM2_ATTRIB = (
    parser    => _parse_func(\&_parse_fcm2_label, \&_parse_fcm2_var),
    processor => sub {
        _process_assign_func('$', '?')->(@_)
        ||
        _process_include_func('fcm2_include')->(@_)
        ;
    },
);

# Creates the class.
__PACKAGE__->class(
    {   event_level => '$',
        parser      => {isa => '&', default => sub {$FCM2_ATTRIB{parser}}   },
        processor   => {isa => '&', default => sub {$FCM2_ATTRIB{processor}}},
        util        => '&',
    },
    {action_of => {main => \&_main}},
);

# Returns a configuration reader.
sub _main {
    my ($attrib_ref, $locator, $reader_attrib_ref) = @_;
    if (!defined($locator)) {
        return;
    }
    my %state = (
        cont  => undef,
        ctx   => undef,
        line  => undef,
        stack => [[$locator, 0]],
        var   => {},
    );
    my %attrib = (
        %{$attrib_ref},
        (defined($reader_attrib_ref) ? %{$reader_attrib_ref} : ()),
    );
    sub {_read(\%attrib, \%state)};
}

# Returns a parser for a configuration line (FCM 1 or FCM 2 format).
sub _parse_func {
    my ($parse_label_func, $parse_var_func) = @_;
    sub {
        my ($state_ref) = @_;
        my $line
            = $state_ref->{cont} ? $state_ref->{line}
            :                      $parse_label_func->($state_ref)
            ;
        my $value
            = $parse_var_func->($state_ref, _parse_value($state_ref, $line));
        if ($state_ref->{ctx}->get_value()) {
            $value = $state_ref->{ctx}->get_value() . $value;
        }
        $state_ref->{ctx}->set_value($value);
        if (!$state_ref->{cont}) {
            _parse_var_here($state_ref);
        }
    };
}

# Parses a configuration line label (FCM 1 format).
sub _parse_fcm1_label {
    my ($state_ref) = @_;
    my ($label, $line) = split(qr{\s+}xms, $state_ref->{line}, 2);
    $state_ref->{ctx}->set_label($label);
    return $line;
}

# Parses a configuration line label (FCM 2 format).
sub _parse_fcm2_label {
    my ($state_ref) = @_;
    my %EXTRACTOR_OF = (
        equal    => sub {($_[0] =~ $PATTERN_OF{fcm2_equal})},
        label    => sub {($_[0] =~ $PATTERN_OF{fcm2_label})},
        modifier => sub {extract_bracketed($_[0], '{}')} ,
        ns       => sub {extract_bracketed($_[0], '["]')},
    );
    my %ACTION_OF = (
        equal    => sub {$_[1] || $E->throw($E->CONFIG_SYNTAX, $_[0])},
        label    => sub {$_[0]->set_label($_[1])},
        modifier => \&_parse_fcm2_label_modifier,
        ns       => \&_parse_fcm2_label_ns,
    );
    my %EXPAND_VAR_IN = (modifier => 1, ns => 1);
    my $line = $state_ref->{line};
    for my $key (qw{label modifier ns equal}) {
        $line ||= q{};
        (my $content, $line) = $EXTRACTOR_OF{$key}->($line);
        if ($EXPAND_VAR_IN{$key}) {
            $content = _parse_fcm2_var($state_ref, $content);
        }
        $ACTION_OF{$key}->($state_ref->{ctx}, $content);
    }
    return $line;
}

# Parses the modifier part in a configuration line label (FCM 2 format).
sub _parse_fcm2_label_modifier {
    my ($ctx, $content) = @_;
    if ($content) {
        my ($str) = $content =~ $PATTERN_OF{trim_brace};
        my %hash;
        for my $item (parse_line($PATTERN_OF{delim_csv}, 0, $str)) {
            my ($key, $value) = split($PATTERN_OF{delim_mod}, $item, 2);
            # Note: "key1, key2: value2, ..." == "key1: 1, key2: value2, ..."
            $hash{$key} = ($value ? $value : 1);
        }
        $ctx->set_modifier_of(\%hash);
    }
}

# Parses the ns part in a configuration line label (FCM 2 format).
sub _parse_fcm2_label_ns {
    my ($ctx, $content) = @_;
    if ($content) {
        my ($str) = $content =~ $PATTERN_OF{trim_brace};
        my @ns = map {$_ eq q{/} ? q{} : $_} parse_line(q{ }, 0, $str);
        $ctx->set_ns_list(\@ns);
    }
}

# Expands variables in a string in a FCM 1 configuration file.
sub _parse_fcm1_var {
    my ($state_ref, $value) = @_;
    my %V = %{$state_ref->{var}};
    my $lead = q{};
    my $tail = $value;
    MATCH:
    while (defined($tail) && length($tail) > 0) {
        my ($pre, $sigil, $br_open, $name, $br_close, $post)
            = map {defined($_) ? $_ : q{}} ($tail =~ $PATTERN_OF{fcm1_var});
        if (!$name) {
            return $lead . $tail;
        }
        $tail = $post;
        my $symbol = $sigil . $br_open . $name . $br_close;
        my $substitute
            = $name eq $HERE                       ? $symbol
            : $sigil eq '$' && exists($ENV{$name}) ? $ENV{$name}
            : $sigil eq '%' && exists($V{$name})   ? $V{$name}
            :                                        undef
            ;
        if (!defined($substitute)) {
            $EVENT->(
                FCM::Context::Event->CONFIG_VAR_UNDEF,
                $state_ref->{ctx},
                $symbol,
            );
        }
        $substitute ||= $symbol;
        $lead .= $pre . $substitute;
    }
    return $lead;
}

# Expands variables in a string in a FCM 2 configuration file.
sub _parse_fcm2_var {
    my ($state_ref, $value) = @_;
    my %V = (%ENV, %{$state_ref->{var}});
    my $lead = q{};
    my $tail = $value;
    while (defined($tail) && length($tail) > 0) {
        my ($pre, $esc, $sigil, $br_open, $name, $br_close, $post)
            = map {defined($_) ? $_ : q{}} ($tail =~ $PATTERN_OF{fcm2_var});
        if (!$name) {
            return $lead . $tail;
        }
        $tail = $post;
        my $symbol = $sigil . $br_open . $name . $br_close;
        my $substitute
            = $name eq $HERE           ? $symbol
            : $esc && length($esc) % 2 ? $symbol
            : exists($V{$name})        ? $V{$name}
            :                            undef
            ;
        if (!defined($substitute)) {
            return $E->throw(
                $E->CONFIG_VAR_UNDEF, $state_ref->{ctx}, "undef($symbol)",
            );
        }
        $substitute ||= q{};
        $lead .= $pre . substr($esc, 0, length($esc) / 2) . $substitute;
    }
    return $lead;
}

# Parses the value part of a configuration line.
sub _parse_value {
    my ($state_ref, $line) = @_;
    $line ||= q{};
    my ($value) = parse_line($PATTERN_OF{comment}, 1, $line);
    $value ||= q{};
    chomp($value);
    ($value) = $value =~ $PATTERN_OF{$state_ref->{cont} ? 'cont_prev' : 'trim'};
    $state_ref->{cont} = q{};
    if ($value) {
        my ($lead, $tail) = $value =~ $PATTERN_OF{cont_next};
        if ($tail && length($tail) % 2) {
            $value = $lead;
            $state_ref->{cont} = $tail;
        }
    }
    return $value;
}

# Expands the leading $HERE variable in the value of a configuration entry.
sub _parse_var_here {
    my ($state_ref) = @_;
    my @values = shellwords($state_ref->{ctx}->get_value());
    if (!grep {$_ =~ $PATTERN_OF{here}} @values) {
        return;
    }
    VALUE:
    for my $value (@values) {
        my ($head, $tail)
            = map {defined($_) ? $_ : q{}} $value =~ $PATTERN_OF{here};
        if (!$head) {
            next VALUE;
        }
        $tail = index($tail, '/') == 0 ? substr($tail, 1) : q{}; # FIXME
        my ($locator, $here_func)
            = @{$state_ref->{stack}->[-1]}[$I_LOCATOR, $I_HERE_FUNC];
        $value = $here_func->($tail)->get_value();
    }
    $state_ref->{ctx}->set_value(join(
        q{ },
        map {my $s = $_; $s =~ s{(['"\s])}{\\$1}gmsx; $s} @values,
    ));
}

# Returns a function to process a variable assignment. If
# $assign_if_undef_modifier is specified and is present in the declaration, only
# assign a variable if it is not yet defined.
sub _process_assign_func {
    my ($sigil, $assign_if_undef_modifier) = @_;
    sub {
        my ($state_ref) = @_;
        my $ctx = $state_ref->{ctx};
        if (index($ctx->get_label(), $sigil) != 0) { # not a variable assignment
            return;
        }
        my $name = substr($ctx->get_label(), length($sigil));
        if ($name !~ $PATTERN_OF{var_name}) {
            return $E->throw($E->CONFIG_SYNTAX, $state_ref->{ctx});
        }
        if ($name eq $HERE) {
            return $E->throw($E->CONFIG_USAGE, $state_ref->{ctx});
        }
        if (    !$assign_if_undef_modifier
            ||  !exists($ctx->get_modifier_of()->{$assign_if_undef_modifier})
            ||  !exists($ENV{$name}) && !exists($state_ref->{var}{$name})
        ) {
            $state_ref->{var}{$name} = $ctx->get_value();
        }
        return 1;
    }
}

# Processes a FCM 1 label.
sub _process_fcm1_label {
    my ($state_ref) = @_;
    $state_ref->{var}{$state_ref->{ctx}->get_label()}
        = $state_ref->{ctx}->get_value();
    return;
}

# Processes an include declaration.
sub _process_include_func {
    my ($key) = @_;
    my $PATTERN = $PATTERN_OF{$key};
    sub {
        my ($state_ref) = @_;
        if ($state_ref->{ctx}->get_label() !~ $PATTERN) {
            return;
        }
        my $M = $state_ref->{ctx}->get_modifier_of();
        my $type = exists($M->{type}) ? $M->{type} : undef;
        push(
            @{$state_ref->{stack}},
            (   map {
                    my $locator = FCM::Context::Locator->new($_, {type => $type});
                    [$locator, 0, undef, undef];
                } shellwords($state_ref->{ctx}->get_value())
            ),
        );
        return 1;
    };
}

# Reads the next entry of a configuration file.
sub _read {
    my ($attrib_ref, $state_ref) = @_;
    my $UTIL = $attrib_ref->{util};
    local($EVENT) = sub {$UTIL->event(@_)};
    STACK:
    while (@{$state_ref->{stack}}) {
        my $S = $state_ref->{stack}->[-1];
        # Open a file handle for the top of the stack, if necessary
        if (!defined($S->[$I_HANDLE])) {
            eval {
                # Check for cyclic dependency
                for my $i (-scalar(@{$state_ref->{stack}}) .. -2) {
                    my $value = $UTIL->loc_as_invariant(
                        $state_ref->{stack}->[$i]->[$I_LOCATOR],
                    );
                    if ($value eq $UTIL->loc_as_invariant($S->[$I_LOCATOR])) {
                        return $E->throw($E->CONFIG_CYCLIC, $state_ref->{stack});
                    }
                }
                $S->[$I_HANDLE] = $UTIL->loc_reader($S->[$I_LOCATOR]);
                $S->[$I_HERE_FUNC]
                    = sub {$UTIL->loc_cat($UTIL->loc_dir($S->[$I_LOCATOR]), @_)};
            };
            if (my $e = $@) {
                if ($E->caught($e) && $e->get_code() eq $E->CONFIG_CYCLIC) {
                    die($e);
                }
                return $E->throw($E->CONFIG_LOAD, $state_ref->{stack}, $e);
            }
            $EVENT->(
                FCM::Context::Event->CONFIG_OPEN,
                _stack_cp($state_ref->{stack}),
                $attrib_ref->{event_level},
            );
        }
        # Read a line and parse it
        LINE:
        while ($state_ref->{line} = readline($S->[$I_HANDLE])) {
            if ($state_ref->{line} =~ $PATTERN_OF{ignore}) {
                next LINE;
            }
            $S->[$I_LINE_NUM] = $.;
            if (!$state_ref->{cont}) {
                $state_ref->{ctx} = FCM::Context::ConfigEntry->new({
                    stack => _stack_cp($state_ref->{stack}),
                });
            }
            $attrib_ref->{parser}->($state_ref);
            if (!$state_ref->{cont}) {
                if ($attrib_ref->{processor}->($state_ref)) {
                    next STACK;
                }
                return $state_ref->{ctx};
            }
        }
        # At end of file
        if ($state_ref->{cont}) {
            return $E->throw($E->CONFIG_CONT_EOF, $state_ref->{ctx});
        }
        close($state_ref->{stack}->[-1]->[$I_HANDLE]);
        $state_ref->{stack}->[-1]->[$I_HANDLE] = undef; # free the memory
        pop(@{$state_ref->{stack}});
    }
    return;
}

# Copies a stack, selecting only the and the line number.
sub _stack_cp {
    [map {[@{$_}[$I_LOCATOR, $I_LINE_NUM]]} @{$_[0]}];
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Util::Config

=head1 SYNOPSIS

    use FCM::Util;
    my $util = FCM::Util->new(\%attrib);
    # ... time passes, and now we want to read a FCM 1 config
    my ($locator, $reader);
    $locator = FCM::Context::Locator->new($path_to_an_fcm1_config);
    $reader
        = $util->config_reader($locator, \%FCM::Util::ConfigReader::FCM1_ATTRIB);
    while (my $entry = $reader->()) {
        # ...
    }
    # ... time passes, and now we want to read a FCM 2 config
    $locator = FCM::Context::Locator->new($path_to_an_fcm2_config);
    $reader = $util->config_reader($locator);
    while (my $entry = $reader->()) {
        # ...
    }

=head1 DESCRIPTION

This module is part of L<FCM::Util|FCM::Util>. Provides a function to generate
configuration file readers.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Returns a new new instance. The %attrib must contain the following:

=over 4

=item {parser}

A CODE reference to parse the lines in a configuration file into entry contexts.
It should have a calling interface $f->(\%state). (See L</STATE> for a
description of %state.) The return value is ignored.

=item {processor}

A CODE reference to post-process each entry context. It should have a calling
interface $f->(\%state). (See L</STATE> for a description of %state.) The
processor should return true if the current entry has been processed and is no
longer considered useful for the user.

=item {util}

The L<FCM::Util|FCM::Util> object, which initialises this class.

=back

=back

See the description of the config_reader() method in L<FCM::Util|FCM::Util> for
detail.

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
