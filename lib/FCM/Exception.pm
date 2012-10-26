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
package FCM::Exception;

use Data::Dumper qw{Dumper};
use Scalar::Util qw{blessed};
use overload (q{""} => \&Dumper);

use constant {
    DEFAULT => 'DEFAULT',
};

# Returns true if $e is a blessed instance of $class.
sub caught {
    my ($class, $e) = @_;
    return (blessed($e) && $e->isa($class));
}

# Throws the exception.
sub throw {
    my ($class, $code, $ctx, $e) = @_;
    if (defined($e) && !ref($e) && $e =~ qr{\A\s*\z}msx) {
        $e = undef;
    }
    die(bless({code => $code, ctx => $ctx, exception => $e}, $class));
}

# Attribute accessors.
for my $name (qw{code ctx exception}) {
    no strict qw{refs};
    *{"get_$name"} = sub {$_[0]->{$name}};
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Exception

=head1 SYNOPSIS

    use FCM::Exception;
    my $E = 'FCM::Exception';
    eval {
        # ...
        if ($some_error_condition) {
            return $E->throw($code, $ctx);
        }
        # ...
    };
    if (my $e = $@) {
        if ($E->caught($e)) {
            # ...
        }
    }

=head1 DESCRIPTION

Exception associated with an FCM operation.

=head1 METHODS

=over 4

=item $class->caught($e)

Returns true if $e is a blessed object of $class.

=item $class->throw($code,$ctx,$e)

Creates an instance and die() with it.

=item $e->get_code()

Returns the code associated with this exception.

=item $e->get_ctx()

Returns the context associated with this exception.

=item $e->get_exception()

Returns the exception that generates this exception.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
