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

package Fcm::Util::ClassLoader;
use base qw{Exporter};

our @EXPORT_OK = qw{load};

use Carp qw{croak};
use Fcm::Exception;

sub load {
    my ($class, $test_method) = @_;
    if (!$test_method) {
        $test_method = 'new';
    }
    if (!UNIVERSAL::can($class, $test_method)) {
        eval('require ' . $class);
        if ($@) {
            croak(Fcm::Exception->new({message => sprintf(
                "%s: class loading failed: %s", $class, $@,
            )}));
        }
    }
    return $class;
}

1;
__END__

=head1 NAME

Fcm::ClassLoader

=head1 SYNOPSIS

    use Fcm::Util::ClassLoader;
    $load_ok = Fcm::Util::ClassLoader::load($class);

=head1 DESCRIPTION

A wrapper for loading a class dynamically.

=head1 FUNCTIONS

=over 4

=item load($class,$test_method)

If $class can call $test_method, returns $class. Otherwise, attempts to
require() $class and returns it. If this fails, croak() with a
L<Fcm::Exception|Fcm::Exception>.

=item load($class)

Shorthand for C<load($class, 'new')>.

=back

=head1 DIAGNOSTICS

=over 4

=item L<Fcm::Exception|Fcm::Exception>

The load($class,$test_method) function croak() with this exception if it fails
to load the specified class.

=back

=head1 COPYRIGHT

E<169> Crown copyright Met Office. All rights reserved.

=cut
