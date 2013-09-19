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
package FCM1::Build::Fortran;

use Text::Balanced qw{extract_bracketed extract_delimited};

# Actions of this class
my %ACTION_OF = (extract_interface => \&_extract_interface);

# Regular expressions
# Matches a variable attribute
my $RE_ATTR = qr{
    allocatable|dimension|external|intent|optional|parameter|pointer|save|target
}imsx;
# Matches a name
my $RE_NAME = qr{[A-Za-z]\w*}imsx;
# Matches a specification type
my $RE_SPEC = qr{
    character|complex|double\s*precision|integer|logical|real|type
}imsx;
# Matches the identifier of a program unit that does not have arguments
my $RE_UNIT_BASE = qr{block\s*data|module|program}imsx;
# Matches the identifier of a program unit that has arguments
my $RE_UNIT_CALL = qr{function|subroutine}imsx;
# Matches the identifier of any program unit
my $RE_UNIT      = qr{$RE_UNIT_BASE|$RE_UNIT_CALL}msx;
my %RE = (
    # A comment line
    COMMENT     => qr{\A\s*(?:!|\z)}msx,
    # A trailing comment, capture the expression before the comment
    COMMENT_END => qr{\A([^'"]*?)\s*!.*\z}msx,
    # A contination marker, capture the expression before the marker
    CONT        => qr{\A(.*)&\s*\z}msx,
    # A contination marker at the beginning of a line, capture the marker and
    # the expression after the marker
    CONT_LEAD   => qr{\A(\s*&)(.*)\z}msx,
    # Capture a variable identifier, removing any type component expression
    NAME_COMP   => qr{\b($RE_NAME)(?:\s*\%\s*$RE_NAME)*\b}msx,
    # Matches the first identifier in a line
    NAME_LEAD   => qr{\A\s*$RE_NAME\s*}msx,
    # Captures a name identifier after a comma, and the expression after
    NAME_LIST   => qr{\A(?:.*?)\s*,\s*($RE_NAME)\b(.*)\z}msx,
    # Captures the next quote character
    QUOTE       => qr{\A[^'"]*(['"])}msx,
    # Matches an attribute declaration
    TYPE_ATTR   => qr{\A\s*($RE_ATTR)\b}msx,
    # Matches a type declaration
    TYPE_SPEC   => qr{\A\s*($RE_SPEC)\b}msx,
    # Captures the expression after one or more program unit attributes
    UNIT_ATTR   => qr{\A\s*(?:(?:elemental|recursive|pure)\s+)+(.*)\z}imsx,
    # Captures the identifier and the symbol of a program unit with no arguments
    UNIT_BASE   => qr{\A\s*($RE_UNIT_BASE)\s+($RE_NAME)\s*\z}imsx,
    # Captures the identifier and the symbol of a program unit with arguments
    UNIT_CALL   => qr{\A\s*($RE_UNIT_CALL)\s+($RE_NAME)\b}imsx,
    # Captures the end of a program unit, its identifier and its symbol
    UNIT_END    => qr{\A\s*(end)(?:\s+($RE_NAME)(?:\s+($RE_NAME))?)?\s*\z}imsx,
    # Captures the expression after a program unit type specification
    UNIT_SPEC   => qr{\A\s*$RE_SPEC\b(.*)\z}imsx,
);

# Keywords in type declaration statements
my %TYPE_DECL_KEYWORD_SET = map { ($_, 1) } qw{
    allocatable
    dimension
    in
    inout
    intent
    kind
    len
    optional
    out
    parameter
    pointer
    save
    target
};

# Creates and returns an instance of this class.
sub new {
    my ($class) = @_;
    bless(
        sub {
            my $key = shift();
            if (!exists($ACTION_OF{$key})) {
                return;
            }
            $ACTION_OF{$key}->(@_);
        },
        $class,
    );
}

# Methods.
for my $key (keys(%ACTION_OF)) {
    no strict qw{refs};
    *{$key} = sub { my $self = shift(); $self->($key, @_) };
}

# Extracts the calling interfaces of top level subroutines and functions from
# the $handle for reading Fortran sources.
sub _extract_interface {
    my ($handle) = @_;
    map { _present_line($_) } @{_reduce_to_interface(_load($handle))};
}

# Reads $handle for the next Fortran statement, handling continuations.
sub _load {
    my ($handle) = @_;
    my $ctx = {signature_token_set_of => {}, statements => []};
    my $state = {
        in_contains  => undef, # in a "contains" section of a program unit
        in_interface => undef, # in an "interface" block
        in_quote     => undef, # in a multi-line quote
        stack        => [],    # program unit stack
    };
    my $NEW_STATEMENT = sub {
        {   name        => q{}, # statement name, e.g. function, integer, ...
            lines       => [],  # original lines in the statement
            line_number => 0,   # line number (start) in the original source
            symbol      => q{}, # name of a program unit (signature, end)
            type        => q{}, # e.g. signature, use, type, attr, end
            value       => q{}, # the actual value of the statement
        };
    };
    my $statement;
LINE:
    while (my $line = readline($handle)) {
        if (!defined($statement)) {
            $statement = $NEW_STATEMENT->();
        }
        my $value = $line;
        chomp($value);
        # Pre-processor directives and continuation
        if (!$statement->{line_number} && index($value, '#') == 0) {
            $statement->{line_number} = $.;
            $statement->{name}        = 'cpp';
        }
        if ($statement->{name} eq 'cpp') {
            push(@{$statement->{lines}}, $line);
            $statement->{value} .= $value;
            if (rindex($value, '\\') != length($value) - 1) {
                $statement = undef;
            }
            next LINE;
        }
        # Normal Fortran
        if ($value =~ $RE{COMMENT}) {
            next LINE;
        }
        if (!$statement->{line_number}) {
            $statement->{line_number} = $.;
        }
        my ($cont_head, $cont_tail);
        if ($statement->{line_number} != $.) { # is a continuation
            ($cont_head, $cont_tail) = $value =~ $RE{CONT_LEAD};
            if ($cont_head) {
                $value = $cont_tail;
            }
        }
        # Correctly handle ! and & in quotes
        my ($head, $tail) = (q{}, $value);
        if ($state->{in_quote} && index($value, $state->{in_quote}) >= 0) {
            my $index = index($value, $state->{in_quote});
            $head = substr($value, 0, $index + 1);
            $tail
                = length($value) > $index + 1
                ? substr($value, $index + 2)
                : q{};
            $state->{in_quote} = undef;
        }
        if (!$state->{in_quote}) {
            while ($tail) {
                if (index($tail, q{!}) >= 0) {
                    if (!($tail =~ s/$RE{COMMENT_END}/$1/)) {
                        ($head, $tail, $state->{in_quote})
                            = _load_extract_quote($head, $tail);
                    }
                }
                else {
                    while (index($tail, q{'}) > 0
                        || index($tail, q{"}) > 0)
                    {
                        ($head, $tail, $state->{in_quote})
                            = _load_extract_quote($head, $tail);
                    }
                    $head .= $tail;
                    $tail = q{};
                }
            }
        }
        $cont_head ||= q{};
        push(@{$statement->{lines}}, $cont_head . $head . $tail . "\n");
        $statement->{value} .= $head . $tail;
        # Process a statement only if it is marked with a continuation
        if (!($statement->{value} =~ s/$RE{CONT}/$1/)) {
            $statement->{value} =~ s{\s+\z}{}msx;
            if (_process($statement, $ctx, $state)) {
                push(@{$ctx->{statements}}, $statement);
            }
            $statement = undef;
        }
    }
    return $ctx;
}

# Helper, removes a quoted string from $tail.
sub _load_extract_quote {
    my ($head, $tail) = @_;
    my ($extracted, $remainder, $prefix)
        = extract_delimited($tail, q{'"}, qr{[^'"]*}msx, q{});
    if ($extracted) {
        return ($head . $prefix . $extracted, $remainder);
    }
    else {
        my ($quote) = $tail =~ $RE{QUOTE};
        return ($head . $tail, q{}, $quote);
    }
}

# Study statements and put attributes into array $statements
sub _process {
    my ($statement, $ctx, $state) = @_;
    my $name;

    # End Interface
    if ($state->{in_interface}) {
        if ($statement->{value} =~ qr{\A\s*end\s*interface\b}imsx) {
            $state->{in_interface} = 0;
        }
        return;
    }

    # End Program Unit
    if (@{$state->{stack}} && $statement->{value} =~ qr{\A\s*end\b}imsx) {
        my ($end, $type, $symbol) = lc($statement->{value}) =~ $RE{UNIT_END};
        if (!$end) {
            return;
        }
        my ($top_type, $top_symbol) = @{$state->{stack}->[-1]};
        if (!$type
            || $top_type eq $type && (!$symbol || $top_symbol eq $symbol))
        {
            pop(@{$state->{stack}});
            if ($state->{in_contains} && !@{$state->{stack}}) {
                $state->{in_contains} = 0;
            }
            if (!$state->{in_contains}) {
                $statement->{name}   = $top_type;
                $statement->{symbol} = $top_symbol;
                $statement->{type}   = 'end';
                return $statement;
            }
        }
        return;
    }

    # Interface/Contains
    ($name) = $statement->{value} =~ qr{\A\s*(contains|interface)\b}imsx;
    if ($name) {
        $state->{'in_' . lc($name)} = 1;
        return;
    }

    # Program Unit
    my ($type, $symbol, @tokens) = _process_prog_unit($statement->{value});
    if ($type) {
        push(@{$state->{stack}}, [$type, $symbol]);
        if ($state->{in_contains}) {
            return;
        }
        $statement->{name}   = lc($type);
        $statement->{type}   = 'signature';
        $statement->{symbol} = lc($symbol);
        $ctx->{signature_token_set_of}{$symbol}
            = {map { (lc($_) => 1) } @tokens};
        return $statement;
    }
    if ($state->{in_contains}) {
        return;
    }

    # Use
    if ($statement->{value} =~ qr{\A\s*(use)\b}imsx) {
        $statement->{name} = 'use';
        $statement->{type} = 'use';
        return $statement;
    }

    # Type Declarations
    ($name) = $statement->{value} =~ $RE{TYPE_SPEC};
    if ($name) {
        $name =~ s{\s}{}gmsx;
        $statement->{name} = lc($name);
        $statement->{type} = 'type';
        return $statement;
    }

    # Attribute Statements
    ($name) = $statement->{value} =~ $RE{TYPE_ATTR};
    if ($name) {
        $statement->{name} = $name;
        $statement->{type} = 'attr';
        return $statement;
    }
}

# Parse a statement for program unit header. Returns a list containing the type,
# the symbol and the signature tokens of the program unit.
sub _process_prog_unit {
    my ($string) = @_;
    my ($type, $symbol, @args) = (q{}, q{});
    # Is it a blockdata, module or program?
    ($type, $symbol) = $string =~ $RE{UNIT_BASE};
    if ($type) {
        $type = lc($type);
        $type =~ s{\s*}{}gmsx;
        return ($type, $symbol);
    }
    # Remove the attribute and type declaration of a procedure
    $string =~ s/$RE{UNIT_ATTR}/$1/;
    my ($match) = $string =~ $RE{UNIT_SPEC};
    if ($match) {
        $string = $match;
        extract_bracketed($string);
    }
    # Is it a function or subroutine?
    ($type, $symbol) = lc($string) =~ $RE{UNIT_CALL};
    if (!$type) {
        return;
    }
    my $extracted = extract_bracketed($string, q{()}, qr{[^(]*}msx);

    # Get signature tokens from SUBROUTINE/FUNCTION
    if ($extracted) {
        $extracted =~ s{\s}{}gmsx;
        @args = split(q{,}, substr($extracted, 1, length($extracted) - 2));
        if ($type eq 'function') {
            my $result = extract_bracketed($string, q{()}, qr{[^(]*}msx);
            if ($result) {
                $result =~ s{\A\(\s*(.*?)\s*\)\z}{$1}msx; # remove braces
                push(@args, $result);
            }
            else {
                push(@args, $symbol);
            }
        }
    }
    return (lc($type), lc($symbol), map { lc($_) } @args);
}

# Reduces the list of statements to contain only the interface block.
sub _reduce_to_interface {
    my ($ctx) = @_;
    my (%token_set, @interface_statements);
STATEMENT:
    for my $statement (reverse(@{$ctx->{statements}})) {
        if ($statement->{type} eq 'end'
            && grep { $_ eq $statement->{name} } qw{subroutine function})
        {
            push(@interface_statements, $statement);
            %token_set
                = %{$ctx->{signature_token_set_of}{$statement->{symbol}}};
            next STATEMENT;
        }
        if ($statement->{type} eq 'signature'
            && grep { $_ eq $statement->{name} } qw{subroutine function})
        {
            push(@interface_statements, $statement);
            %token_set = ();
            next STATEMENT;
        }
        if ($statement->{type} eq 'use') {
            my ($head, $tail)
                = split(qr{\s*:\s*}msx, lc($statement->{value}), 2);
            if ($tail) {
                my @imports = map { [split(qr{\s*=>\s*}msx, $_, 2)] }
                    split(qr{\s*,\s*}msx, $tail);
                my @useful_imports
                    = grep { exists($token_set{$_->[0]}) } @imports;
                if (!@useful_imports) {
                    next STATEMENT;
                }
                if (@imports != @useful_imports) {
                    my @token_strings
                        = map { $_->[0] . ($_->[1] ? ' => ' . $_->[1] : q{}) }
                        @useful_imports;
                    my ($last, @rest) = reverse(@token_strings);
                    my @token_lines
                        = (reverse(map { $_ . q{,&} } @rest), $last);
                    push(
                        @interface_statements,
                        {   lines => [
                                sprintf("%s:&\n", $head),
                                (map { sprintf(" & %s\n", $_) } @token_lines),
                            ]
                        },
                    );
                    next STATEMENT;
                }
            }
            push(@interface_statements, $statement);
            next STATEMENT;
        }
        if ($statement->{type} eq 'attr') {
            my ($spec, @tokens) = ($statement->{value} =~ /$RE{NAME_COMP}/g);
            if (grep { exists($token_set{$_}) } @tokens) {
                for my $token (@tokens) {
                    $token_set{$token} = 1;
                }
                push(@interface_statements, $statement);
                next STATEMENT;
            }
        }
        if ($statement->{type} eq 'type') {
            my ($variable_string, $spec_string)
                = reverse(split('::', lc($statement->{value}), 2));
            if ($spec_string) {
                $spec_string =~ s{$RE{NAME_LEAD}}{}msx;
            }
            else {
                # The first expression in the statement is the type + attrib
                $variable_string =~ s{$RE{NAME_LEAD}}{}msx;
                $spec_string = extract_bracketed($variable_string, '()',
                    qr{[\s\*]*}msx);
            }
            # Useful tokens are those that comes after a comma
            my $tail = q{,} . lc($variable_string);
            my @tokens;
            while ($tail) {
                if ($tail =~ qr{\A\s*['"]}msx) {
                    extract_delimited($tail, q{'"}, qr{\A[^'"]*}msx, q{});
                }
                elsif ($tail =~ qr{\A\s*\(}msx) {
                    extract_bracketed($tail, '()', qr{\A[^(]*}msx);
                }
                else {
                    my $token;
                    ($token, $tail) = $tail =~ $RE{NAME_LIST};
                    if ($token && $token_set{$token}) {
                        @tokens = ($variable_string =~ /$RE{NAME_COMP}/g);
                        $tail = q{};
                    }
                }
            }
            if (@tokens && $spec_string) {
                my @spec_tokens = (lc($spec_string) =~ /$RE{NAME_COMP}/g);
                push(
                    @tokens,
                    (   grep { !exists($TYPE_DECL_KEYWORD_SET{$_}) }
                            @spec_tokens
                    ),
                );
            }
            if (grep { exists($token_set{$_}) } @tokens) {
                for my $token (@tokens) {
                    $token_set{$token} = 1;
                }
                push(@interface_statements, $statement);
                next STATEMENT;
            }
        }
    }
    if (!@interface_statements) {
        return [];
    }
    [   {lines => ["interface\n"]},
        reverse(@interface_statements),
        {lines => ["end interface\n"]},
    ];
}

# Processes and returns the line of the statement.
sub _present_line {
    my ($statement) = @_;
    map {
        s{\s+}{ }gmsx;      # collapse multiple spaces
        s{\s+\z}{\n}msx;    # remove trailing spaces
        $_;
    } @{$statement->{lines}};
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM1::Build::Fortran

=head1 SYNOPSIS

    use FCM1::Build::Fortran;
    my $fortran_util = FCM1::Build::Fortran->new();
    open(my($handle), '<', $path_to_a_fortran_source_file);
    print($fortran_util->extract_interface($handle)); # prints interface
    close($handle);

=head1 DESCRIPTION

A class to analyse Fortran source. Currently, it has a single method to extract
the calling interfaces of top level subroutines and functions in a Fortran
source.

=head1 METHODS

=over 4

=item $class->new()

Creates and returns an instance of this class.

=item $instance->extract_interface($handle)

Extracts the calling interfaces of top level subroutines and functions in a
Fortran source that can be read from $handle. Returns an interface block as a
list of lines.

=back

=head1 ACKNOWLEDGEMENT

This module is inspired by the logic developed by the European Centre
for Medium-Range Weather Forecasts (ECMWF).

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
