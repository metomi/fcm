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

package FCM::Admin::Users::Passwd;
use base qw{FCM::Class::CODE};

use FCM::Admin::Config;
use FCM::Admin::User;
use Text::ParseWords qw{shellwords};

my %ACTION_OF = (
    get_users_info => \&_get_users_info,
    verify_users   => \&_verify_users,
);

__PACKAGE__->class({}, {action_of => {%ACTION_OF}});

my $CONFIG = FCM::Admin::Config->instance();

# Gets a HASH of users using the POSIX password DB.
# %user_of = ($name => <FCM::Admin::User instance>, ...)
sub _get_users_info {
    my ($attrib_ref, @only_users) = @_;
    if (@only_users) {
        return _get_only_users_info($attrib_ref, @only_users);
    }
    my $gid_max = $CONFIG->get_passwd_gid_max();
    my $uid_max = $CONFIG->get_passwd_uid_max();
    my $gid_min = $CONFIG->get_passwd_gid_min();
    my $uid_min = $CONFIG->get_passwd_uid_min();
    my %user_of;
    USER:
    while (my ($name, $uid, $gid, $gecos) = (getpwent())[0, 2, 3, 6]) {
        if (    exists($user_of{$name})
            ||  defined($uid_max) && $uid > $uid_max || $uid < $uid_min
            ||  defined($gid_max) && $gid > $gid_max || $gid < $gid_min
            ||  !$gecos
            ||  (@only_users && grep {$_ eq $name} @only_users)
        ) {
            next USER;
        }
        my $email = _guess_email_from_gecos($attrib_ref, $gecos);
        if (!$email) {
            next USER;
        }
        $user_of{$name} = FCM::Admin::User->new({
            name         => $name,
            display_name => (split(q{,}, $gecos))[0],
            email        => $email,
        });
    }
    endpwent();
    return \%user_of;
}

# Gets a HASH of users matching @only_users using the POSIX password DB.
# %user_of = ($name => <FCM::Admin::User instance>, ...)
sub _get_only_users_info {
    my ($attrib_ref, @only_users) = @_;
    my %user_of;
    for my $user (@only_users) {
        my ($name, $gecos) = (getpwnam($user))[0, 6];
        if ($name && $gecos) {
            $user_of{$name} = FCM::Admin::User->new({
                name         => $name,
                display_name => (split(q{,}, $gecos))[0],
                email        => _guess_email_from_gecos($attrib_ref, $gecos),
            });
        }
    }
    return (wantarray() ? %user_of : \%user_of);
}

# Guess a user's email from gecos information
sub _guess_email_from_gecos {
    my ($attrib_ref, $gecos) = @_;
    my $domain = $CONFIG->get_passwd_email_domain();
    my $name = index($gecos, q{,}) > 0 ? (split(q{,}, $gecos))[0] : $gecos;
    return ($name =~ qr{\s}msx)
        ? undef : lc($name) . ($domain ? '@' . $domain : q{});
}

# Return a list of bad users in @users.
sub _verify_users {
    my ($attrib_ref, @users) = @_;
    grep {!getpwnam($_)} @users;
}

1;
__END__

=head1 NAME

FCM::Admin::Users::Passwd

=head1 SYNOPSIS

    use FCM::Admin::Users::Passwd;
    my $users_info_util = FCM::Admin::Users::Passwd->new();
    $users_info_util->get_users();

=head1 DESCRIPTION

Utility for obtaining user information from passwd information.

=head1 METHODS

=over 4

=item $util->get_users_info()

Return a HASH (in list context) or a reference to a HASH (in scalar context)
{name => <FCM::Admin::User instance>, ...}. The HASH should contain all entries
in the passwd database that appear to be real users.

=item $util->verify_users(@users)

Return a list of bad users in @users.

=back

=head1 COPYRIGHT

E<169> Crown copyright Met Office. All rights reserved.

=cut
