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

package FCM::Admin::User;

use overload q{""} => \&get_name;

# The default values of the attributes
my %DEFAULT = (
    name         => undef,
    display_name => undef,
    email        => undef,
);

# ------------------------------------------------------------------------------
# Returns a new instance of this class.
sub new {
    my ($class, $args_ref) = @_;
    return bless({%DEFAULT, %{$args_ref}}, $class);
}

# ------------------------------------------------------------------------------
# Getters and setters.
for my $key (keys(%DEFAULT)) {
    no strict qw{refs};
    my $getter = qq{get_$key};
    my $setter = qq{set_$key};
    *$getter = sub {
        my ($self) = @_;
        return $self->{$key};
    };
    *$setter = sub {
        my ($self, $value) = @_;
        $self->{$key} = $value;
    };
}

1;
__END__

=head1 NAME

FCM::Admin::User

=head1 SYNOPSIS

    use FCM::Admin::User;
    $user = FCM::Admin::User->new({name => 'bob'});
    $user->set_display_name('Robert Smith');
    $user->set_email('robert.smith@somewhere.org');

=head1 DESCRIPTION

An object of this class is used to store the data model of a user.

=head1 METHODS

=over 4

=item FCM::Admin::User->new(\%arguments)

Creates a new instance. The keys of the %argument hash may contain "name",
"display_name", and/or "email".

=item $user->get_name()

Returns the name/ID of the user.

=item $user->get_display_name()

Returns the display name of the user.

=item $user->get_email()

Returns the e-mail address of the user.

=item $user->set_name($value)

Sets the name/ID of the user.

=item $user->set_display_name($value)

Sets the display name of the user.

=item $user->set_email($value)

Sets the e-mail address of the user.

=back

=head1 COPYRIGHT

E<169> Crown copyright Met Office. All rights reserved.

=cut
