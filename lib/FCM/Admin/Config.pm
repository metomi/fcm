# ------------------------------------------------------------------------------
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
# ------------------------------------------------------------------------------

use strict;
use warnings;

package FCM::Admin::Config;
use base qw{FCM::Class::HASH};

use FCM::Context::Locator;
use FCM::Util;
use File::Basename qw{dirname};
use File::Spec::Functions qw{catfile};
use FindBin;

our $UTIL = FCM::Util->new();

my $TRAC_LIVE_URL_TMPL = 'https://{host}/trac/{project}';
my $USER_ID = (getpwuid($<))[0];

__PACKAGE__->class({
    # Emails
    admin_email         => {isa => '$', default => $USER_ID},
    notification_from   => {isa => '$'},

    # Location for log files
    log_dir             => {isa => '$', default => '/var/log/fcm'},

    # FCM installation locations
    fcm_home            => {isa => '$', default => dirname($FindBin::Bin)},
    fcm_site_home       => {isa => '$', default => q{}},

    # FCM installation mirror locations
    mirror_dests        => {isa => '$', default => q{}},
    mirror_keys         => {isa => '$', default => q{}},

    # Subversion repositories settings
    svn_backup_dir      => {isa => '$', default => '/var/svn/backups'},
    svn_dump_dir        => {isa => '$', default => '/var/svn/dumps'},
    svn_group           => {isa => '$', default => q{}},
    svn_hook_path_env   => {isa => '$', default => q{}},
    svn_live_dir        => {isa => '$', default => '/srv/svn'},
    svn_passwd_file     => {isa => '$', default => q{}},
    svn_project_suffix  => {isa => '$', default => q{}},

    # Trac environments settings
    trac_admin_users    => {isa => '$', default => q{}},
    trac_backup_dir     => {isa => '$', default => '/var/trac/backups'},
    trac_group          => {isa => '$', default => q{}},
    trac_host_name      => {isa => '$', default => 'localhost'},
    trac_ini_file       => {isa => '$', default => 'trac.ini'},
    trac_live_dir       => {isa => '$', default => '/srv/trac'},
    trac_live_url_tmpl  => {isa => '$', default => $TRAC_LIVE_URL_TMPL},
    trac_passwd_file    => {isa => '$', default => q{}},

    # User information tool settings
    user_info_tool      => {isa => '$', default => 'passwd'},

    # User information tool, LDAP settings
    ldappw              => {isa => '$', default => '~/.ldappw'},
    ldap_uri            => {isa => '$', default => q{}},
    ldap_binddn         => {isa => '$', default => q{}},
    ldap_basedn         => {isa => '$', default => q{}},
    ldap_attrs          => {isa => '$', default => q{uid cn mail}},
    ldap_filter_more    => {isa => '$', default => q{}},

    # User information tool, passwd settings
    passwd_email_domain => {isa => '$', default => q{}},
    passwd_gid_max      => {isa => '$'},
    passwd_uid_max      => {isa => '$'},
    passwd_gid_min      => {isa => '$', default => 1000},
    passwd_uid_min      => {isa => '$', default => 1000},
});


# Returns a unique instance of this class.
my $INSTANCE;
sub instance {
    my ($class) = @_;
    if (!defined($INSTANCE)) {
        $INSTANCE = $class->new();
        # Load $FCM_HOME/etc/fcm/admin.cfg and $HOME/.metomi/fcm/admin.cfg
        $UTIL->cfg_init(
            'admin.cfg',
            sub {
                my $config_reader = shift();
                while (defined(my $entry = $config_reader->())) {
                    my $label = $entry->get_label();
                    if (exists($INSTANCE->{$label})) {
                        $INSTANCE->{$label} = $entry->get_value();
                    }
                }
            },
        );
    }
    return $INSTANCE;
}

1;
__END__

=head1 NAME

FCM::Admin::Config

=head1 SYNOPSIS

    $config = FCM::Admin::Config->instance();
    $dir = $config->get_svn_backup_dir();
    # ...

=head1 DESCRIPTION

This class is used to retrieve/store configurations required by FCM
admininstration scripts.

It is a sub-class of L<FCM::Class::HASH|FCM::Class::HASH>.

=head1 METHODS

=over 4

=item FCM::Admin::Config->instance()

Returns a unique instance of this class. On first call, creates the instance
with the configurations set to their default values; and loads from the
site/user configuration at $FCM_HOME/etc/fcm/admin.cfg and
$HOME/.metomi/fcm/admin.cfg.

=back

=head1 ATTRIBUTES

Email addresses.

=over 4

=item admin_email

The e-mail address of the FCM administrator.

=item notification_from

Notification email address (for the "From:" field in notification emails).

=back

Location for log files.

=over 4

=item log_dir

The location for log files.

=back

Locations of FCM installation.

=over 4

=item fcm_home

The source path of the default FCM distribution.

=item fcm_site_home

The source path of the default FCM site distribution.

=back

Settings on how to mirror FCM installation.

=over 4

=item mirror_dests

A space-delimited list of destinations to mirror FCM installation.

=item mirror_keys

A string containing a list of source keys. Each source key should point
to a source location in this $config. The source locations will be distributed
to the list of destinations in C<mirror_dests>.

=back

Subversion repositories settings.

=over 4

=item svn_backup_dir

The path to a directory containing the backups of SVN repositories.

=item svn_dump_dir

The path to a directory containing the revision dumps of SVN
repositories.

=item svn_group

The group name in which Subversion repositories should be created in.

=item svn_hook_dir

The path to a directory containing source files of SVN hook scripts.

=item svn_hook_path_env

The value of the PATH environment variable, in which SVN hook scripts
should run with.

=item svn_live_dir

The path to a directory containing the live SVN repositories.

=item svn_passwd_file

The base name of the SVN password file.

=item svn_project_suffix

The suffix added to the name of each SVN repository.

=back

Trac environment settings.

=over 4

=item trac_admin_users

A space-delimited list of admin users for all Trac environments.

=item trac_backup_dir

The path to a directory containing the backups of Trac environments.

=item trac_group

The group name in which Trac environment files should be created in.

=item trac_host_name

The host name of the Trac server, from the user's perspective.

=item trac_ini_file

The base name of the Trac INI file.

=item trac_live_dir

The path to a directory containing the live Trac environments.

=item trac_live_url_tmpl

The template string for determining the URL of the Trac environment of a
project.

=item trac_passwd_file

The base name of the Trac password file.

=back

=over 4

User information tool settings.

=item user_info_tool

The name of the tool for obtaining user information.

=back

LDAP settings, only relevant if C<user_info_tool = ldap>

=over 4

=item ldappw

File containing the password to the LDAP server, if required.

=item ldap_uri

The URI of the LDAP server.

=item ldap_binddn

The DN in the LDAP server to bind with to search the directory.

=item ldap_basedn

The DN in the LDAP server that is the base for a search.

=item ldap_attrs

The attributes for UID, common name and email in the LDAP directory.

=item ldap_filter_more

If specified, use the value as extra (AND) filters to an LDAP search.

=back

PASSWD settings, only relevant if user_info_tool = passwd

=over 4

=item passwd_email_domain

Domain name to suffix user IDs to create an email address.

=item passwd_gid_max

Maximum GID considered to be a normal user group.

=item passwd_uid_max

Maximum UID considered to be a normal user.

=item passwd_gid_min

Minimum GID considered to be a normal user group. (default=1000)

=item passwd_uid_min

Minimum UID considered to be a normal user. (default=1000)

=back

=head1 COPYRIGHT

Copyright (C) British Crown (Met Office) & Contributors..

=cut
