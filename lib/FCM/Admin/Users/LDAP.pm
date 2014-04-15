
#-------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-14 Met Office.
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

package FCM::Admin::Users::LDAP;
use base qw{FCM::Class::CODE};

use FCM::Admin::Config;
use FCM::Admin::User;
use Net::LDAP;
use Text::ParseWords qw{shellwords};

my %ACTION_OF = (
    get_users_info => \&_get_users_info,
    verify_users   => \&_verify_users,
);

__PACKAGE__->class({util => '&'}, {action_of => {%ACTION_OF}});

my $CONFIG = FCM::Admin::Config->instance();

# Gets a HASH of users using the mail aliases and the POSIX password DB.
# %user_of = ($name => <FCM::Admin::User instance>, ...)
sub _get_users_info {
    my ($attrib_ref, @only_users) = @_;
    my $res = _ldap_search($attrib_ref, undef, @only_users);
    my ($uid_attr, $cn_attr, $mail_attr)
        = shellwords($CONFIG->get_ldap_attrs());
    my %user_of;
    for my $entry ($res->entries()) {
        my $name = $entry->get_value($uid_attr);
        $user_of{$name} = FCM::Admin::User->new({
            name         => $name,
            display_name => $entry->get_value($cn_attr),
            email        => $entry->get_value($mail_attr),
        });
    }
    return (wantarray() ? %user_of : \%user_of);
}

# Return a list of bad users.
sub _verify_users {
    my ($attrib_ref, @users) = @_;
    my $res = _ldap_search($attrib_ref, 0, @users); # 0 == $uid_attr
    my ($uid_attr, $cn_attr, $mail_attr)
        = shellwords($CONFIG->get_ldap_attrs());
    my %bad_users = map {($_ => 1)} @users;
    for my $entry ($res->entries()) {
        my $name = $entry->get_value($uid_attr);
        if (exists($bad_users{$name})) {
            delete($bad_users{$name});
        }
    }
    return sort(keys(%bad_users));
}

# Bind to the LDAP server. Return a Net::LDAP instance.
sub _ldap_search {
    my ($attrib_ref, $attr_index, @users) = @_;

    my $ldap_uri = $CONFIG->get_ldap_uri();
    my $ldap = Net::LDAP->new($CONFIG->get_ldap_uri());
    my $password_file = $CONFIG->get_ldappw();
    $password_file = $attrib_ref->{util}->file_tilde_expand($password_file);
    my $password = $password_file
        ? $attrib_ref->{util}->file_load($password_file)
        : undef;
    my %ldap_options = $password ? (password => $password) : ();
    $ldap->bind($CONFIG->get_ldap_binddn(), %ldap_options);

    my @attrs = shellwords($CONFIG->get_ldap_attrs());
    my ($uid_attr) = @attrs;
    my $filter = @users
        ? "(|($uid_attr=" . join(")($uid_attr=", @users) . '))'
        : "&($uid_attr=*)";
    my $res = $ldap->search(
        base   => $CONFIG->get_ldap_basedn(),
        filter => $filter,
        attrs  => [$attr_index ? ($attrs[$attr_index]) : @attrs],
    );
    $ldap->unbind();
    return $res;
}

1;
__END__

=head1 NAME

FCM::Admin::Users::LDAP

=head1 SYNOPSIS

    use FCM::Admin::Users::LDAP;
    my $users_info_util = FCM::Admin::Users::LDAP->new();
    $users_info_util->get_users();

=head1 DESCRIPTION

Utility for obtaining user information via LDAP.

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
