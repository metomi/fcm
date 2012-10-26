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
use strict;
use warnings;

# ------------------------------------------------------------------------------
package FCM::System::Make::Build::Task::ExtractInterface;
use base qw{FCM::Class::CODE};

use Text::Balanced qw{extract_bracketed extract_delimited};
use Text::ParseWords qw{shellwords};

# Regular expressions
my $RE_ATTR = qr{
    allocatable|dimension|external|intent|optional|parameter|pointer|save|target
}imsx;
my $RE_FILE = qr{[\w\-+.]+}imsx;
my $RE_NAME = qr{[A-Za-z]\w*}imsx;
my $RE_SPEC = qr{
    character|complex|double\s*precision|integer|logical|real|type
}imsx;
my $RE_UNIT_BASE = qr{block\s*data|module|program}imsx;
my $RE_UNIT_CALL = qr{function|subroutine}imsx;
my $RE_UNIT      = qr{$RE_UNIT_BASE|$RE_UNIT_CALL}msx;
my %RE           = (
    COMMENT     => qr{\A\s*(?:!|\z)}msx,
    COMMENT_END => qr{\A([^'"]*?)\s*!.*\z}msx,
    CONT        => qr{\A(.*)&\s*\z}msx,
    CONT_LEAD   => qr{\A(\s*&)(.*)\z}msx,
    INCLUDE     => qr{(?:\#|\s*)include\s*}imsx,
    NAME_COMP   => qr{\b($RE_NAME)(?:\s*\%\s*$RE_NAME)*\b}msx,
    NAME_LEAD   => qr{\A\s*$RE_NAME\s*}msx,
    NAME_LIST   => qr{\A(?:.*?)\s*,\s*($RE_NAME)\b(.*)\z}msx,
    QUOTE       => qr{\A[^'"]*(['"])}msx,
    TYPE_ATTR   => qr{\A\s*($RE_ATTR)\b}msx,
    TYPE_SPEC   => qr{\A\s*($RE_SPEC)\b}msx,
    UNIT_ATTR   => qr{\A\s*(?:(?:elemental|recursive|pure)\s+)+(.*)\z}imsx,
    UNIT_BASE   => qr{\A\s*($RE_UNIT_BASE)\s+($RE_NAME)\s*\z}imsx,
    UNIT_CALL   => qr{\A\s*($RE_UNIT_CALL)\s+($RE_NAME)\b}imsx,
    UNIT_END  => qr{\A\s*(end)(?:\s+($RE_NAME)(?:\s+($RE_NAME))?)?\s*\z}imsx,
    UNIT_SPEC => qr{\A\s*$RE_SPEC\b(.*)\z}imsx,
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

__PACKAGE__->class({util => '&'}, {action_of => {main => \&_main}});

sub _main {
    my ($attrib_ref, $target) = @_;
    my $handle
        = $attrib_ref->{util}->file_load_handle($target->get_path_of_source());
    $attrib_ref->{util}->file_save(
        $target->get_path(),
        [   map { s{\s+}{ }gmsx; s{\s+\z}{\n}msx; $_ }
                map { @{$_->{lines}} }
                @{_reduce_to_interface(_extract_statements($handle))}
        ],
    );
    close($handle);
    $target;
}

# Reads $handle for the next Fortran statement, handling continuations.
sub _extract_statements {
    my ($handle) = @_;
    my $context = {signature_token_set_of => {}, statements => []};
    my $state = {
        in_contains  => undef,
        in_interface => undef,
        in_quote     => undef,
        in_type      => undef,
        stack        => [],
    };
    my $NEW_STATEMENT = sub {
        {   name        => q{},
            lines       => [],
            line_number => 0,
            symbol      => q{},
            type        => q{},
            value       => q{},
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
        if (!$statement->{line_number} && index($value, '#') == 0) {
            $statement->{line_number} = $.;
            $statement->{name}        = 'cpp';
        }
        if ($statement->{name} eq 'cpp') {
            push(@{$statement->{lines}}, $line);
            $statement->{value} .= $value;
            if (rindex($value, '\\') != length($value) - 1) {

                #push(@{$context->{statements}}, $statement);
                $statement = undef;
            }
            next LINE;
        }
        if ($value =~ $RE{COMMENT}) {
            next LINE;
        }
        if (!$statement->{line_number}) {
            $statement->{line_number} = $.;
        }
        my ($cont_head, $cont_tail);
        if ($statement->{line_number} != $.) {    # is a continuation
            ($cont_head, $cont_tail) = $value =~ $RE{CONT_LEAD};
            if ($cont_head) {
                $value = $cont_tail;
            }
        }
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
                            = _extract_statement_quote($head, $tail);
                    }
                }
                else {
                    while (index($tail, q{'}) > 0
                        || index($tail, q{"}) > 0)
                    {
                        ($head, $tail, $state->{in_quote})
                            = _extract_statement_quote($head, $tail);
                    }
                    $head .= $tail;
                    $tail = q{};
                }
            }
        }
        $cont_head ||= q{};
        push(@{$statement->{lines}}, $cont_head . $head . $tail . "\n");
        $statement->{value} .= $head . $tail;
        if (!($statement->{value} =~ s/$RE{CONT}/$1/)) {
            $statement->{value} =~ s{\s+\z}{}msx;
            if (_process($statement, $context, $state)) {
                push(@{$context->{statements}}, $statement);
            }
            $statement = undef;
        }
    }
    return $context;
}

# Helper, removes a quoted string from $tail.
sub _extract_statement_quote {
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
    my ($statement, $context, $state) = @_;
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
        $context->{signature_token_set_of}{$symbol}
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
    }
}

# Parse a statement for program unit header. Returns a list containing the type,
# the symbol and the signature tokens of the program unit.
sub _process_prog_unit {
    my ($string) = @_;
    my ($type, $symbol, @args) = (q{}, q{});
    ($type, $symbol) = $string =~ $RE{UNIT_BASE};
    if ($type) {
        $type = lc($type);
        $type =~ s{\s*}{}gmsx;
        return ($type, $symbol);
    }
    $string =~ s/$RE{UNIT_ATTR}/$1/;
    my ($match) = $string =~ $RE{UNIT_SPEC};
    if ($match) {
        $string = $match;
        extract_bracketed($string);
    }
    ($type, $symbol) = lc($string) =~ $RE{UNIT_CALL};
    if (!$type) {
        return;
    }
    my $extracted = extract_bracketed($string, q{()}, qr{[^(]*}msx);

    # Get arguments/keywords from SUBROUTINE/FUNCTION
    if ($extracted) {
        $extracted =~ s{\s}{}gmsx;
        @args = split(q{,}, substr($extracted, 1, length($extracted) - 2));
        if ($type eq 'function') {
            my $result = extract_bracketed($string, q{()}, qr{[^(]*}msx);
            if ($result) {
                $result =~ s{\A\(\s*(.*?)\s*\)\z}{$1}msx;    # remove braces
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
    my ($context) = @_;
    my (%token_set, @interface_statements);
STATEMENT:
    for my $statement (reverse(@{$context->{statements}})) {
        if ($statement->{type} eq 'end'
            && grep { $_ eq $statement->{name} } qw{subroutine function})
        {
            push(@interface_statements, $statement);
            %token_set
                = %{$context->{signature_token_set_of}{$statement->{symbol}}};
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
                $variable_string =~ s{$RE{NAME_LEAD}}{}msx;
                $spec_string = extract_bracketed($variable_string, '()',
                    qr{[\s\*]*}msx);
            }
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

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::Task::ExtractInterface

=head1 SYNOPSIS

    use FCM::System::Make::Build::Task::ExtractInterface;
    my $task = FCM::System::Make::Build::Task::ExtractInterface->new(\%attrib);
    $task->main($target);

=head1 DESCRIPTION

Extracts the calling interfaces of top level functions and subroutines in the
Fortran source file of the target.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Creates and returns a new instance. %attrib should contain:

=over 4

=item {util}

An instance of L<FCM::Util|FCM::Util>.

=back

=item $instance->main($target)

Extracts the calling interfaces of top level functions and subroutines in the
Fortran source file of the target, and writes the results to the path of the
target.

=back

=head1 ACKNOWLEDGEMENT

This module is inspired by the logic developed by the European Centre
for Medium-Range Weather Forecasts (ECMWF).

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
