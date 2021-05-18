#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------
use strict;
use warnings;

#-------------------------------------------------------------------------------
package FCM::Class::HASH;
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
            add     => undef, # isa eq 'HASH' only, class of HASH element
            default => undef, # default value or CODE to return it
            isa     => undef, # attribute type
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
    no strict qw{refs};
    # $class->new(\%attrib)
    *{$class . '::new'} = sub {
        my $class = shift();
        my ($attrib_ref) = $class_opt{init_attrib}->(@_);
        my $caller_ref = [caller()];
        my %attrib = (defined($attrib_ref) ? %{$attrib_ref} : ());
        while (my ($key, $value) = each(%attrib)) {
            $ATTRIB_CHECK->($class, $attrib_opt{$key}, $key, $value, $caller_ref);
        }
        my $self = bless(\%attrib, $class);
        KEY:
        while (my ($key, $opt_ref) = each(%attrib_opt)) {
            if (exists($self->{$key})) {
                next KEY;
            }
            for my $opt_name (qw{default isa}) {
                if (defined($opt_ref->{$opt_name})) {
                    $self->{$key} = $ATTRIB_DEFAULT_BY{$opt_name}->($opt_ref);
                    next KEY;
                }
            }
        }
        $class_opt{init}->($self);
        return $self;
    };
    # $instance->$methods()
    while (my ($key, $opt_ref) = each(%attrib_opt)) {
        # $instance->get_$attrib()
        # $instance->get_$attrib($name)
        if ($opt_ref->{r}) {
            *{$class . '::get_' . $key}
                = defined($opt_ref->{isa}) && $opt_ref->{isa} eq 'HASH'
                ? sub {
                    my ($self, $name) = @_;
                    if (!defined($name)) {
                        return $self->{$key};
                    }
                    if (exists($self->{$key}{$name})) {
                        return $self->{$key}{$name};
                    }
                    return;
                }
                : sub {$_[0]->{$key}}
                ;
        }
        # $instance->set_$attrib($value)
        if ($opt_ref->{w}) {
            *{$class . '::set_' . $key} = sub {
                my ($self, $value) = @_;
                $ATTRIB_CHECK->(
                    $class, $attrib_opt{$key}, $key, $value, [caller()],
                );
                $self->{$key} = $value;
                return $self;
            };
        }
        # $instance->add_$attrib($name,\%option)
        if (   defined($opt_ref->{isa}) && $opt_ref->{isa} eq 'HASH'
            && defined($opt_ref->{add})
        ) {
            *{$class . '::add_' . $key} = sub {
                my ($self, $name, @args) = @_;
                if (defined($self->{$key}{$name})) {
                    return $self->{$key}{$name};
                }
                $self->{$key}{$name} = $opt_ref->{add}->new(@args);
            };
        }
    }
    return 1;
}

#-------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Class::HASH

=head1 SYNOPSIS

    package Breakfast;
    use base qw{FCM::Class::HASH};
    __PACKAGE__->class(
        {
            eggs  => {isa => '@'},
            ham   => {isa => '%'},
            bacon => '$',
            # ...
        },
    );
    # Some time later...
    $breakfast = Breakfast->new(\%attrib);
    @eggs = @{$breakfast->get_eggs()};
    $breakfast->set_ham(\%ham);

=head1 DESCRIPTION

Provides a simple method to create HASH-based classes.

The class() method creates the new() method for initiating a new instance. It
also provides a get_$attrib() and set_$attrib() accessors for each attribute.
Basic type checkings are performed on writing to the attributes to ensure
correct usage.

=head1 METHODS

=over 4

=item $class->class(\%attrib_opt,\%class_opt)

Creates the class, using the attribute options in %attrib_opt and %class_opt.

The %attrib_opt is used to configure the attributes of an instance of the class.
The key of each element is the name of the attribute, and the value is a HASH
containing the options of the attribute, or a SCALAR. (If a SCALAR is specified,
it is equivalent to {isa => value}.). The options may contain:

=over 4

=item r

(Default=true) If true, the attribute is readable.

=item w

(Default=true) If true, the attribute is writable.

=item add

(Default=undef) This is only useful for a HASH attribute. If defined, it should
be the name of a class (e.g. $attrib_class). The HASH attribute will receive an
extra method $instance->add_$attrib($key,@args). The method will assign the
$name element of the HASH attribute to the result of $attrib_class->new(@args).

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

If the default options is not defined, and if the attribute "isa" is ARRAY, HASH
or CODE, then the default value is [], {} and sub {} respectively.

=item isa

(Default=undef) The expected type of the attribute. If this optioin is defined
as $type, a new $value of the attribute is only accepted if $value is undef,
UNIVERSAL::isa($value,$type) returns true or if $type is C<SCALAR> and the new
value is not a reference.

The attribute accepts $, @, %, & and * as aliases to SCALAR, ARRAY, HASH, CODE
and GLOB.

=back

The argument %class_opt can have the following elements:

=over 4

=item init

If $class_opt{init} is defined, it should be a CODE reference. If specified, it
will be called just after the instance is blessed in the $class->new() method,
with an interface $f->($instance) where $instance is the new instance.

=item init_attrib

The value of this option must be a CODE. The $class->new() normally expects a
single HASH reference argument. If an alternate interface to the $class->new()
is required, this CODE can be used to turn the input argument list to the
expected HASH reference.

=back

=item $class->new(\%attrib)

Creates a new instance with %attrib. Initial values of the attributes can be
specified using %attrib. Otherwise, the method will attempt to assign the
default values, as specified in the class() method, to the newly created
instance.

=item $instance->get_$attrib()

Returns a readable attribute.

=item $instance->get_$attrib($key)

These are available for HASH attributes only. Returns the value of an element in
a readable attribute.

=item $instance->set_$attrib($value)

Sets the value of a writable attribute. Returns $instance.

=item $instance->add_$attrib($key,@args)

These are available for HASH attributes (with the C<add> attribute option
defined) only. Adds a new $key element to the HASH attribute. Returns the newly
added element.

=back

=head1 DIAGNOSTICS

L<FCM::Class::Exception|FCM::Class::Exception> is thrown on error.

=head1 SEE ALSO

Inspired by the standard module L<Class::Struct|Class::Struct> and CPAN modules
such as L<Class::Accessor|Class::Accessor>.

=head1 COPYRIGHT

Copyright (C) British Crown (Met Office) & Contributors..

=cut
