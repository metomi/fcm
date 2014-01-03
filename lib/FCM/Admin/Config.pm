# ------------------------------------------------------------------------------
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
# ------------------------------------------------------------------------------

use strict;
use warnings;

package FCM::Admin::Config;

use FCM::Context::Locator;
use FCM::Util;
use File::Spec::Functions qw{catfile};

my $USER = (getpwuid($<))[0];
my $HOME = (getpwuid($<))[7];

# Default values for read-only attributes
my %DEFAULT_R = (
    admin_email     => $USER,
    fcm_home        => $HOME,
    fcm_wc          => catfile($HOME, qw{fcm}),
    fcm_site_wc     => catfile($HOME, qw{fcm_admin}),
    mirror_dests    => q{},
    mirror_keys     => q{fcm_wc fcm_site_wc},
    trac_gid        => scalar(getgrnam(q{apache})),
    user_number_min => 500,
);

# Default values for read-write attributes
my %DEFAULT_RW = (
    svn_backup_dir     => catfile($HOME, qw{svn backups}),
    svn_dump_dir       => catfile($HOME, qw{svn dumps}),
    svn_live_dir       => catfile($HOME, qw{svn live}),
    svn_passwd_file    => q{passwd},
    svn_project_suffix => q{_svn},
    trac_backup_dir    => catfile($HOME, qw{trac backups}),
    trac_host_id       => q{localhost},
    trac_ini_file      => q{trac.ini},
    trac_live_dir      => catfile($HOME, qw{trac live}),
    trac_passwd_file   => q{trac.htpasswd},
);

my $INSTANCE;

# ------------------------------------------------------------------------------
# Returns a unique instance of this class.
sub instance {
    my ($class) = @_;
    if (!$INSTANCE) {
        $INSTANCE = bless({%DEFAULT_R, %DEFAULT_RW}, $class);
        # Load $FCM_HOME/etc/fcm/admin.cfg and $HOME/.metomi/fcm/admin.cfg
        my $UTIL = FCM::Util->new();
        my @paths = map {catfile($_, 'admin.cfg')} ($UTIL->cfg_paths());
        for my $path (grep {-f $_ && -r _} @paths) {
            my $config_reader
                = $UTIL->config_reader(FCM::Context::Locator->new($path));
            while (defined(my $entry = $config_reader->())) {
                my $label = $entry->get_label();
                if (exists($INSTANCE->{$label})) {
                    $INSTANCE->{$label} = $entry->get_value();
                }
            }
        }
    }
    return $INSTANCE;
}

# ------------------------------------------------------------------------------
# Getters
for my $name (keys(%DEFAULT_R), keys(%DEFAULT_RW)) {
    no strict qw{refs};
    my $getter = qq{get_$name};
    *$getter = sub {
        my ($self) = @_;
        return $self->{$name};
    };
}

# ------------------------------------------------------------------------------
# Setters
for my $name (keys(%DEFAULT_RW)) {
    no strict qw{refs};
    my $setter = qq{set_$name};
    *$setter = sub {
        my ($self, $value) = @_;
        $self->{$name} = $value;
    };
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

=head1 METHODS

=over 4

=item FCM::Admin::Config->instance()

Returns a unique instance of this class. On first call, creates the instance
with the configurations set to their default values; and loads from the
site/user configuration at $FCM_HOME/etc/fcm/admin.cfg and
$HOME/.metomi/fcm/admin.cfg.

=item $config->get_admin_email()

Returns the e-mail address of the FCM administrator.

=item $config->get_fcm_home()

Returns the HOME directory of the FCM administrator.

=item $config->get_mirror_dests()

Returns a string containing a list of destinations to mirror FCM installation.

=item $config->get_mirror_keys()

Returns a string containing a list of source keys. Each source key should point
to a source location in this $config. The source locations will be distributed
to the list of destinations in $config->get_mirror_dests().

=item $config->get_fcm_wc()

Returns the (working copy) source path of the default FCM distribution.

=item $config->get_fcm_site_wc()

Returns the (working copy) source path of the default FCM site distribution.

=item $config->get_svn_backup_dir()

Returns the path to a directory containing the backups of SVN repositories.

=item $config->get_svn_dump_dir()

Returns the path to a directory containing the revision dumps of SVN
repositories.

=item $config->get_svn_hook_dir()

Returns the path to a directory containing source files of SVN hook scripts.

=item $config->get_svn_live_dir()

Returns the path to a directory containing the live SVN repositories.

=item $config->get_svn_passwd_file()

Returns the base name of the SVN password file.

=item $config->get_svn_project_suffix()

Returns the suffix added to the name of each SVN repository.

=item $config->get_trac_backup_dir()

Returns the path to a directory containing the backups of Trac environments.

=item $config->get_trac_gid()

Returns the group ID of the Trac server.

=item $config->get_trac_host_id()

Returns the host ID of the Trac server.

=item $config->get_trac_ini_file()

Returns the base name of the Trac INI file.

=item $config->get_trac_live_dir()

Returns the path to a directory containing the live Trac environments.

=item $config->get_trac_passwd_file()

Returns the base name of the Trac password file.

=item $config->get_user_number_min()

Returns the expected minimum number of users.

=item $config->set_svn_backup_dir($value)

Sets the path to a directory containing the backups of SVN repositories.

=item $config->set_svn_dump_dir($value)

Sets the path to a directory containing the revision dumps of SVN
repositories.

=item $config->set_svn_hook_dir($value)

Sets the path to a directory containing source files of SVN hook scripts.

=item $config->set_svn_live_dir($value)

Sets the path to a directory containing the live SVN repositories.

=item $config->set_svn_passwd_file($value)

Sets the base name of the SVN password file.

=item $config->set_svn_project_suffix($value)

Sets the suffix added to the name of each SVN repository.

=item $config->set_trac_backup_dir($value)

Sets the path to a directory containing the backups of Trac environments.

=item $config->set_trac_host_id($id)

Sets the host ID of the Trac server.

=item $config->set_trac_ini_file($value)

Sets the base name of the Trac INI file.

=item $config->set_trac_live_dir($value)

Sets the path to a directory containing the live Trac environments.

=item $config->set_trac_passwd_file($value)

Sets the base name of the Trac password file.

=back

=head1 COPYRIGHT

E<169> Crown copyright Met Office. All rights reserved.

=cut
