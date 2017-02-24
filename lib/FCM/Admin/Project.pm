# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-17 Met Office.
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

package FCM::Admin::Project;

use overload q{""} => \&get_name;
use FCM::Admin::Config;
use File::Spec;

my $ARCHIVE_EXTENSION = q{.tgz};

# ------------------------------------------------------------------------------
# Creates a new instance of this class.
sub new {
    my ($class, $args_ref) = @_;
    return bless({%{$args_ref}}, $class);
}

# ------------------------------------------------------------------------------
# Returns the name of the project.
sub get_name {
    my ($self) = @_;
    return $self->{name};
}

# ------------------------------------------------------------------------------
# Returns the base name of the backup archive of the project's SVN repository.
sub get_svn_archive_base_name {
    my ($self) = @_;
    return $self->get_svn_base_name() . $ARCHIVE_EXTENSION;
}

# ------------------------------------------------------------------------------
# Returns the path of the backup archive of the project's SVN repository.
sub get_svn_backup_path {
    my ($self) = @_;
    return File::Spec->catfile(
        FCM::Admin::Config->instance()->get_svn_backup_dir(),
        $self->get_svn_archive_base_name(),
    );
}

# ------------------------------------------------------------------------------
# Returns the base name of the project's Subversion repository.
sub get_svn_base_name {
    my ($self) = @_;
    return
        $self->get_name()
        . FCM::Admin::Config->instance()->get_svn_project_suffix();
}

# ------------------------------------------------------------------------------
# Returns the path to the revision dumps of the project's SVN repository.
sub get_svn_dump_path {
    my ($self) = @_;
    return File::Spec->catfile(
        FCM::Admin::Config->instance()->get_svn_dump_dir(),
        $self->get_svn_base_name(),
    );
}

# ------------------------------------------------------------------------------
# Returns the path to the project's SVN live repository's hooks directory.
sub get_svn_live_hook_path {
    my ($self) = @_;
    return File::Spec->catfile($self->get_svn_live_path(), q{hooks});
}

# ------------------------------------------------------------------------------
# Returns the path to the project's SVN live repository.
sub get_svn_live_path {
    my ($self) = @_;
    return File::Spec->catfile(
        FCM::Admin::Config->instance()->get_svn_live_dir(),
        $self->get_svn_base_name(),
    );
}

# ------------------------------------------------------------------------------
# Returns the file:// URI to the project's SVN live repository.
sub get_svn_file_uri {
    my ($self) = @_;
    return q{file://} . $self->get_svn_live_path();
    # Note: can use URI::file in theory, but it returns file:/path (instead of
    #       file:///path) which Subversion does not like.
}

# ------------------------------------------------------------------------------
# Returns the base name of the project's Trac environment backup archive.
sub get_trac_archive_base_name {
    my ($self) = @_;
    return $self->get_name() . $ARCHIVE_EXTENSION;
}

# ------------------------------------------------------------------------------
# Returns the path to the project's Trac backup archive.
sub get_trac_backup_path {
    my ($self) = @_;
    return File::Spec->catfile(
        FCM::Admin::Config->instance()->get_trac_backup_dir(),
        $self->get_trac_archive_base_name(),
    );
}

# ------------------------------------------------------------------------------
# Returns the path to the project's Trac live environment's database.
sub get_trac_live_db_path {
    my ($self) = @_;
    return File::Spec->catfile($self->get_trac_live_path(), qw{db trac.db});
}

# ------------------------------------------------------------------------------
# Returns the path to the project's Trac live environment's INI file.
sub get_trac_live_ini_path {
    my ($self) = @_;
    return File::Spec->catfile($self->get_trac_live_path(), qw{conf trac.ini});
}

# ------------------------------------------------------------------------------
# Returns the path to the project's Trac live environment.
sub get_trac_live_path {
    my ($self) = @_;
    return File::Spec->catfile(
        FCM::Admin::Config->instance()->get_trac_live_dir(),
        $self->get_name(),
    );
}

# ------------------------------------------------------------------------------
# Returns the URL to the project's Trac live environment.
sub get_trac_live_url {
    my ($self) = @_;
    my $return = FCM::Admin::Config->instance()->get_trac_live_url_tmpl();
    for (
        ['{host}', FCM::Admin::Config->instance()->get_trac_host_name()],
        ['{project}', $self->get_name()],
    ) {
        my ($key, $value) = @{$_};
        my $index = index($return, $key);
        if ($index > -1) {
            substr($return, $index, length($key), $value);
        }
    }
    $return;
}

1;
__END__

=head1 NAME

FCM::Admin::Project

=head1 SYNOPSIS

    use FCM::Admin::Project;
    $project = FCM::Admin::Project->new({name => 'foo'});
    $path = $project->get_svn_live_path();

=head1 DESCRIPTION

An object of this class represents a project hosted/managed by FCM. The methods
of this class relies on L<FCM::Admin::Config|FCM::Admin::Config> for many of the
configurations.

=head1 METHODS

=over 4

=item FCM::Admin::Project->new({name => $name})

Returns a new instance. A name of the project must be specified.

=item $project->get_name()

Returns the name of the project.

=item $project->get_svn_archive_base_name()

Returns the base name of the backup archive of the project's Subversion
repository.

=item $project->get_svn_backup_path()

Returns the path to the backup archive of the project's Subversion repository.

=item $project->get_svn_base_name()

Returns the base name of the project's Subversion repository.

=item $project->get_svn_dump_path()

Returns the path to the revision dumps of the project's Subversion repository.

=item $project->get_svn_live_hook_path()

Returns the path to the project's SVN live repository's hooks directory.

=item $project->get_svn_live_path()

Returns the path to the project's SVN live repository.

=item $project->get_svn_file_uri()

Returns the file:// URI to the project's SVN live repository.

=item $project->get_trac_archive_base_name()

Returns the base name of the project's Trac environment backup archive.

=item $project->get_trac_backup_path()

Returns the path to the project's Trac backup archive.

=item $project->get_trac_live_db_path()

Returns the path to the project's Trac live environment's database.

=item $project->get_trac_live_ini_path()

Returns the path to the project's Trac live environment's INI file.

=item $project->get_trac_live_path()

Returns the path to the project's Trac live environment.

=item $project->get_trac_live_url()

Returns the URL to the project's Trac live environment.

=back

=head1 SEE ALSO

L<FCM::Admin::Config|FCM::Admin::Config>

=head1 COPYRIGHT

E<169> Crown copyright Met Office. All rights reserved.

=cut
