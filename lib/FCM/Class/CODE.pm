#-------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-15 Met Office.
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
#-------------------------------------------------------------------------------
use strict;
use warnings;

#-------------------------------------------------------------------------------
package FCM::Class::CODE;
use FCM::Class::Exception;
use Scalar::Util qw{reftype};

# Methods for working out the default value of an attribute.
my %ATTRIB_DEFAULT_BY = (
    default => sub {
        my $opt_ref = shift();
        my $ret = $opt_ref->{default};
        return (ref($ret) && reftype($ret) eq 'CODE' ? $ret->() : $ret);
    },
    isa     => sub {
        my $opt_ref = shift();
        return
              $opt_ref->{isa} eq 'ARRAY' ? []
            : $opt_ref->{isa} eq 'HASH'  ? {}
            : $opt_ref->{isa} eq 'CODE'  ? sub {}
            :                              undef
            ;
    },
);

# Checks the value of an attribute.
my $ATTRIB_CHECK = sub {
    my ($class, $opt_ref, $key, $value, $caller_ref) = @_;
    # Note: undef is always OK?
    if (!defined($value)) {
        return;
    }
    my $expected_isa = $opt_ref->{isa};
    if (!$expected_isa || $expected_isa eq 'SCALAR' && !ref($value)) {
        return;
    }
    if (!UNIVERSAL::isa($value, $expected_isa)) {
        return FCM::Class::Exception->throw({
            'code'    => FCM::Class::Exception->CODE_TYPE,
            'caller'  => $caller_ref,
            'package' => $class,
            'key'     => $key,
            'type'    => $expected_isa,
            'value'   => $value,
        });
    }
};

# Creates the methods of the class.
sub class {
    my ($class, $attrib_opt_ref, $class_opt_ref) = @_;
    my %class_opt = (
        init        => sub {},
        init_attrib => sub {@_},
        action_of   => {},
        (defined($class_opt_ref) ? %{$class_opt_ref} : ()),
    );
    if (!defined($attrib_opt_ref)) {
        $attrib_opt_ref = {};
    }
    my %attrib_opt;
    while (my ($key, $item) = each(%{$attrib_opt_ref})) {
        my %option = (
            r       => 1,     # readable?
            w       => 1,     # writable?
            default => undef, # default value or CODE to return it
            isa     => undef, # attribute isa 
            (     defined($item) && ref($item) ? %{$item}
                : defined($item)               ? (isa => $item)
                :                                ()
            ),
        );
        if (defined($option{isa})) {
            $option{isa}
                = $option{isa} eq '$' ? 'SCALAR'
                : $option{isa} eq '@' ? 'ARRAY'
                : $option{isa} eq '%' ? 'HASH'
                : $option{isa} eq '&' ? 'CODE'
                : $option{isa} eq '*' ? 'GLOB'
                :                       $option{isa}
                ;
        }
        $attrib_opt{$key} = \%option;
    }
    my $main_ref = sub {
        my ($attrib_ref, $key, @args) = @_;
        if (!exists($class_opt{action_of}{$key})) {
            return;
        }
        $class_opt{action_of}{$key}->($attrib_ref, @args);
    };
    no strict qw{refs};
    # $class->new(\%attrib)
    *{$class . '::new'} = sub {
        my $class = shift();
        my ($attrib_ref) = $class_opt{init_attrib}->(@_);
        my $caller_ref = [caller()];
        my %attrib = (defined($attrib_ref) ? %{$attrib_ref} : ());
        while (my ($key, $value) = each(%attrib)) {
            if (exists($attrib_opt{$key})) {
                $ATTRIB_CHECK->(
                    $class, $attrib_opt{$key}, $key, $value, $caller_ref,
                );
            }
            #else {
            #    delete($attrib{$key});
            #}
        }
        my $self = bless(sub {$main_ref->(\%attrib, @_)}, $class);
        KEY:
        while (my ($key, $opt_ref) = each(%attrib_opt)) {
            if (exists($attrib{$key})) {
                next KEY;
            }
            for my $opt_name (qw{default isa}) {
                if (defined($opt_ref->{$opt_name})) {
                    $attrib{$key} = $ATTRIB_DEFAULT_BY{$opt_name}->($opt_ref);
                    next KEY;
                }
            }
        }
        $class_opt{init}->(\%attrib, $self);
        return $self;
    };
    # $instance->$key()
    for my $key (keys(%{$class_opt{action_of}})) {
        *{$class . '::' . $key}
            = sub {my $self = shift(); $self->($key, @_)};
    }
    return 1;
}

#-------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Class::CODE

=head1 SYNOPSIS

    # Example
    package Bar;
    use base qw{FCM::Class::CODE};
    __PACKAGE__->class(
        {
            # ...
        },
        {
            action_of => {
                bend => sub {
                    my ($attrib_ref, @args) = @_;
                    # ...
                },
                stretch => sub {
                    my ($attrib_ref, @args) = @_;
                    # ...
                },
            },
        },
    );
    # Some time later...
    $bar = Bar->new(\%attrib);
    $bar->bend(@args);
    $bar->stretch(@args);

=head1 DESCRIPTION

Provides a simple method to create CODE-based classes.

=head1 METHODS

=over 4

=item $class->class(\%attrib_opt,\%class_opt)

Creates common methods for a CODE-based class.

The %attrib_opt is used to configure the attributes of an instance of the class.
The key of each element is the name of the attribute, and the value is a HASH
containing the options of the attribute, or a SCALAR. (If a SCALAR is specified,
it is equivalent to {isa => value}.) The options may contain:

=over 4

=item r

(Default=true) If true, the attribute is readable.

=item w

(Default=true) If true, the attribute is writable.

=item default

(Default=undef) The default value of the attribute.

If this option is defined, the attribute will be initialised to the specified
value when the new() method is called. In the special case where the value of
this option is a CODE reference, it will be invoked as $code->(\%attrib), and
the default value will be the returned value of the CODE reference. This is
useful, for example, if the default value needs to be a new instance of a class.
If a genuine CODE reference is required as the default, this option should be
set to a CODE reference that returns the required CODE reference itself.

For example:

    Foo->class({
        foo => {default => 'foo'},          # 'foo'
        bar => {default => sub {get_id()}}, # the next id
        baz => {default => sub {\&code}},   # &code
    });
    {
        my $id = 0;
        sub get_id {$id++}
    }

If a default option is not defined, and if the attribute "isa" is ARRAY, HASH or
CODE, then the default value is [], {} and sub {} respectively.

=item isa

(Default=undef) The expected type of the attribute. If this optioin is defined
as $type, a new $value of the attribute is only accepted if $value is undef,
UNIVERSAL::isa($value,$type) returns true or if $type is C<SCALAR> and the new
value is not a reference.

The attribute accepts $, @, %, & and * as aliases to SCALAR, ARRAY, HASH, CODE
and GLOB.

=back

The %class_opt is used to configure what methods are created for the class, as
well as other options for the $class->new() method. It may contain the
following:

=over 4

=item init

If $class_opt{init} is defined, it should be a CODE reference. If specified, it
will be called once when $instance->new() is called, with the interface
$init->(\%attrib,$self).

=item init_attrib

The value of this option must be a CODE. The $class->new() normally expects a
single HASH reference argument. If an alternate interface to the $class->new()
is required, this CODE can be used to turn the input argument list to the
expected HASH reference.

=item action_of

This provides the actions of the class. It should be a HASH. Each $key in the
HASH will be turned into a method implemented by the CODE reference in the
corresponding $value: $instance->$key(@args) will call $instance->($key,@args),
which will call $value->(\%attrib,@args).

=back

=item $class->new(\%attrib)

Creates a new instance with %attrib. Initial values of the attributes can be
specified using %attrib. Otherwise, the method will attempt to assign the
default values, as specified in the class() method, to the newly created
instance.

=item $instance->$key(@args)

A method is created for each $key of the %{$attrib{action_of}}.

=back

=head1 DIAGNOSTICS

L<FCM::Class::Exception|FCM::Class::Exception> is thrown on error.

=head1 SEE ALSO

Inspired by the standard module L<Class::Struct|Class::Struct> and CPAN modules
such as L<Class::Accessor|Class::Accessor>.

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
