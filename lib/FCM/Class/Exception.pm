#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------
use strict;
use warnings;

#-------------------------------------------------------------------------------
package FCM::Class::Exception;

use constant {
    CODE_TYPE => 'CODE_TYPE',
};

sub caught {
    my ($class, $e) = @_;
    blessed($e) && $e->isa($class);
}

sub throw {
    my ($class, $attrib_ref) = @_;
    my %e = (
        'caller'  => [],
        'code'    => undef,
        'key'     => undef,
        'package' => undef,
        'type'    => undef,
        'value'   => undef,
        (defined($attrib_ref) ? %{$attrib_ref} : ()),
    );
    die(bless(\%e, $class));
}

for my $key (qw{caller code key package type value}) {
    no strict qw{refs};
    *{"get_$key"} = sub {$_[0]->{$key}};
}

#-------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Class::Exception

=head1 SYNOPSIS

    eval {
        FCM::Class::Exception->throw({
            'caller'  => [caller()],
            'code'    => $code,
            'key'     => $key,
            'package' => $package,
            'type'    => $type,
            'value'   => $value,
        });
    };
    if (my $e = $@) {
        if (FCM::Class::Exception->caught($e)) {
            # ... handle this exception class
        }
        else {
            # ... do something else
        }
    }

=head1 DESCRIPTION

This exception is thrown on incorrect usage of an instance of a sub-class. An
instance of this exception has the following attributes, which can be accessed
via $e->get_$attrib():

=head1 ATTRIBUTES

=over 4

=item caller

Returns an ARRAY reference containing the caller (as returned by the built-in
function in ARRAY context) that triggers the exception. Note: for a CODE-based
class, this is always the caller when the instance is created.

=item code

The error code, which can be one of the following:

=over 4

=item $e->CODE_TYPE

Attempt to set the value of an attribute to an incorrect type.

=back

=item key

The key of the attribute that triggers this exception.

=item type

The expected data type (for an attempt to set the value of an attribute to an
incorrect type).

=item value

The value of the attribute that triggers this exception.

=back

=head1 SEE ALSO

L<FCM::Class::CODE|FCM::Class::CODE>
L<FCM::Class::HASH|FCM::Class::HASH>

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
