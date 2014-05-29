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

package FCM::Admin::System;

use Config::IniFiles;
use DBI; # See also: DBD::SQLite
use Exporter qw{import};
use FCM::Admin::Config;
use FCM::Admin::Project;
use FCM::Admin::Runner;
use FCM::Admin::User;
use FCM::Admin::Util qw{
    read_file
    run_copy
    run_create_archive
    run_extract_archive
    run_mkpath
    run_rename
    run_rmtree
    run_rsync
    run_symlink
    write_file
};
use Fcntl qw{:mode}; # for S_IRGRP, S_IWGRP, S_IROTH, etc
use File::Basename qw{basename dirname};
use File::Find qw{find};
use File::Spec;
use File::Temp qw{tempdir tempfile};
use IO::Dir;
use IO::Pipe;
use IO::Zlib;
use List::Util qw{first};
use Text::ParseWords qw{shellwords};

our @EXPORT_OK = qw{
    add_trac_environment
    backup_svn_repository
    backup_trac_environment
    backup_trac_files
    distribute_wc
    filter_projects
    get_projects_from_svn_backup
    get_projects_from_svn_live
    get_projects_from_trac_backup
    get_projects_from_trac_live
    get_users
    install_svn_hook
    manage_users_in_svn_passwd
    manage_users_in_trac_passwd
    manage_users_in_trac_db_of
    recover_svn_repository
    recover_trac_environment
    recover_trac_files
    vacuum_trac_env_db
};

our $NO_OVERWRITE = 1;
our $BUFFER_SIZE = 4096;

# ------------------------------------------------------------------------------
# Adds a new Trac environment.
sub add_trac_environment {
    my ($project_name, $admin_user_list_ref, $authorised_option) = @_;
    my $project = FCM::Admin::Project->new({name => $project_name});
    if (-e $project->get_trac_live_path()) {
        die(sprintf(
            "%s: Trac environment already exists at %s.\n",
            $project_name,
            $project->get_trac_live_path(),
        ));
    }
    my @repository_arguments = (q{}, q{});
    if (-d $project->get_svn_live_path()) {
        @repository_arguments = (q{svn}, $project->get_svn_live_path());
    }
    my $RUNNER = sub{FCM::Admin::Runner->instance()->run(@_)};
    my $TRAC_ADMIN = sub {
        my ($log, @args) = @_;
        my @command = (q{trac-admin}, $project->get_trac_live_path(), @args);
        $RUNNER->($log, sub {!system(@command)});
    };
    $TRAC_ADMIN->(
        "initialising Trac environment",
        q{initenv},
        $project_name,
        q{sqlite:db/trac.db},
        @repository_arguments,
        q{--inherit=../../trac.ini},
    );
    _chgrp_and_chmod_trac_environment_for($project);
    for my $item (qw{component1 component2}) {
        $TRAC_ADMIN->(
            "removing example component $item", q{component remove}, $item,
        );
    }
    for my $item (qw{1.0 2.0}) {
        $TRAC_ADMIN->(
            "removing example version $item", q{version remove}, $item,
        );
    }
    for my $item (qw{milestone1 milestone2 milestone3 milestone4}) {
        $TRAC_ADMIN->(
            "removing example milestone $item", q{milestone remove}, $item,
        );
    }
    for my $item (
        ['major'    => 'normal'  ],
        ['critical' => 'major'   ],
        ['blocker'  => 'critical'],
    ) {
        my ($old, $new) = @{$item};
        $TRAC_ADMIN->(
            "changing priority $old to $new", qw{priority change}, $old, $new,
        );
    }
    $TRAC_ADMIN->(
        "adding admin permission", qw{permission add admin TRAC_ADMIN},
    );
    if (ref($admin_user_list_ref) eq 'ARRAY') {
        for my $item (@{$admin_user_list_ref}) {
            $TRAC_ADMIN->(
                "adding admin user $item", qw{permission add}, $item, q{admin},
            );
        }
    }
    if ($authorised_option) {
        for my $item (qw{TICKET_CREATE TICKET_MODIFY WIKI_CREATE WIKI_MODIFY}) {
            $TRAC_ADMIN->(
                "removing authenticated write permission",
                qw{permission remove authenticated}, $item,
            );
            $TRAC_ADMIN->(
                "adding authorised write permission",
                qw{permission add authorised}, $item,
            );
	}
    }
    my $auth = $authorised_option ? q{authorised} : q{authenticated};
    $TRAC_ADMIN->(
        "adding TICKET_EDIT_CC permission to $auth",
        qw{permission add}, $auth, qw{TICKET_EDIT_CC},
    );
    $TRAC_ADMIN->(
        "adding TICKET_EDIT_DESCRIPTION permission to $auth",
        qw{permission add}, $auth, qw{TICKET_EDIT_DESCRIPTION},
    );
    $RUNNER->(
        "updating configuration file",
        sub {
            my $trac_ini_path = $project->get_trac_live_ini_path();
            my $trac_ini = Config::IniFiles->new(q{-file} => $trac_ini_path);
            if (!$trac_ini) {
                die("$trac_ini_path: cannot open.\n");
            }
            for (
                #section    #key        #value
                ['project', 'descr'   , $project->get_name()         ],
                ['trac'   , 'base_url', $project->get_trac_live_url()],
            ) {
                my ($section, $key, $value) = @{$_};
                if (!$trac_ini->SectionExists($section)) {
                    $trac_ini->AddSection($section);
                }
                if (!$trac_ini->newval($section, $key, $value)) {
                    die("$trac_ini_path: $section:$key: cannot set value.\n");
                }
            }
            return $trac_ini->RewriteConfig();
        },
    );
    $RUNNER->(
        "updating InterTrac",
        sub {
            my $trac_ini_path = File::Spec->catfile(
                FCM::Admin::Config->instance()->get_trac_live_dir(),
                FCM::Admin::Config->instance()->get_trac_ini_file(),
            );
            my $trac_ini = Config::IniFiles->new(q{-file} => $trac_ini_path);
            if (!$trac_ini) {
                die("$trac_ini_path: cannot open.\n");
            }
            if (!$trac_ini->SectionExists(q{intertrac})) {
                $trac_ini->AddSection(q{intertrac});
            }
            my $name = $project->get_name();
            for (
                [q{title} , $name                        ],
                [q{url}   , $project->get_trac_live_url()],
                [q{compat}, 'false'                      ],
            ) {
                my ($key, $value) = @{$_};
                my $option = lc($name) . q{.} . $key;
                if (!$trac_ini->newval(q{intertrac}, $option, $value)) {
                    die("$trac_ini_path: intertrac:$option: cannot set value.\n");
                }
            }
            return $trac_ini->RewriteConfig();
        },
    );
    return 1;
}

# ------------------------------------------------------------------------------
# Backup the SVN repository of a project.
sub backup_svn_repository {
    my ($option_hash_ref, $project) = @_;
    my $RUNNER = sub {FCM::Admin::Runner->instance()->run(@_)};
    if (!exists($option_hash_ref->{'no-pack'})) {
        $RUNNER->(
            sprintf("packing %s", $project->get_svn_live_path()),
            sub {!system(qw{svnadmin pack}, $project->get_svn_live_path())},
        );
    }
    my $work_dir = tempdir(CLEANUP => 1);
    my $work_path
        = File::Spec->catfile($work_dir, $project->get_svn_base_name());
    $RUNNER->(
        sprintf(
            "hotcopying %s to %s", $project->get_svn_live_path(), $work_path,
        ),
        sub {!system(
            qw{svnadmin hotcopy}, $project->get_svn_live_path(), $work_path,
        )},
        # Note: "hotcopy" is not yet possible via SVN::Repos
    );
    if (!exists($option_hash_ref->{'no-verify-integrity'})) {
        my $VERIFIED_REVISION_REGEX = qr{\A\*\s+Verified\s+revision\s+\d+\.}xms;
        $RUNNER->(
            "verifying integrity of SVN repository of $project",
            sub {
                my $pipe = IO::Pipe->new();
                $pipe->reader(sprintf(
                    qq{svnadmin verify %s 2>&1}, $work_path,
                ));
                while (my $line = $pipe->getline()) {
                    if ($line !~ $VERIFIED_REVISION_REGEX) { # don't print
                        print($line);
                    }
                }
                return $pipe->close();
                # Note: "verify" is not yet possible via SVN::Repos
            },
        );
    }
    _create_backup_archive(
        $work_path,
        FCM::Admin::Config->instance()->get_svn_backup_dir(),
        $project->get_svn_archive_base_name(),
    );
    if (!exists($option_hash_ref->{'no-housekeep-dumps'})) {
        my $dump_path = $project->get_svn_dump_path();
        my $youngest = _svnlook_youngest($work_path);
        # Note: could use SVN::Repos for "youngest"
        $RUNNER->(
            "housekeeping dumps in $dump_path",
            sub {
                my @rev_dump_paths;
                _get_files_from(
                    $dump_path,
                    sub {
                        my ($base_name, $path) = @_;
                        my $rev = basename($base_name, '.gz');
                        if ($rev > $youngest) {
                            return;
                        }
                        push(@rev_dump_paths, $path);
                    },
                );
                for my $rev_dump_path (@rev_dump_paths) {
                    run_rmtree($rev_dump_path);
                }
                return 1;
            }
        );
    }
    return 1;
}

# ------------------------------------------------------------------------------
# Backup the Trac environment of a project.
sub backup_trac_environment {
    my ($option_hash_ref, $project) = @_;
    my $trac_live_path = $project->get_trac_live_path();
    # Make sure the project INI file is owned by the correct group
    #my $project_trac_ini_file = $project->get_trac_live_ini_path();
    #my $gid = FCM::Admin::Config->instance()->get_trac_gid();
    #FCM::Admin::Runner->instance()->run(
    #    "changing group ownership for $project_trac_ini_file",
    #    sub {return chown(-1, $gid, $project_trac_ini_file)},
    #);
    my $work_dir = tempdir(CLEANUP => 1);
    my $work_path = File::Spec->catfile($work_dir, $project->get_name());
    FCM::Admin::Runner->instance()->run_with_retries(
        sprintf(
            qq{hotcopying %s to %s},
            $project->get_trac_live_path(),
            $work_path,
        ),
        sub {
            return !system(
                q{trac-admin},
                $project->get_trac_live_path(),
                q{hotcopy},
                $work_path,
            );
        },
    );
    if (!exists($option_hash_ref->{'no-verify-integrity'})) {
        my $db_path = File::Spec->catfile($work_path, qw{db trac.db});
        my $db_name = File::Spec->catfile($project->get_name(), qw{db trac.db});
        FCM::Admin::Runner->instance()->run(
            "checking $db_name for integrity",
            sub {
                my $db_handle
                    = DBI->connect(qq{dbi:SQLite:dbname=$db_path}, q{}, q{});
                if (!$db_handle) {
                    return;
                }
                my $rc = defined($db_handle->do(q{pragma integrity_check;}));
                $db_handle->disconnect();
                return $rc;
            },
        );
    }
    _create_backup_archive(
        $work_path,
        FCM::Admin::Config->instance()->get_trac_backup_dir(),
        $project->get_trac_archive_base_name(),
    );
    return 1;
}

# ------------------------------------------------------------------------------
# Backup misc files in the Trac live directory to the Trac backup directory.
sub backup_trac_files {
    # (no argument)
    my $CONFIG = FCM::Admin::Config->instance();
    _copy_files($CONFIG->get_trac_live_dir(), $CONFIG->get_trac_backup_dir());
}

# ------------------------------------------------------------------------------
# Distributes the central FCM working copy to standard locations.
sub distribute_wc {
    my $rc = 1;
    my $CONFIG = FCM::Admin::Config->instance();
    my $RUNNER = FCM::Admin::Runner->instance();
    my @RSYNC_OPTS = qw{--timeout=1800 --exclude=.*};
    my @sources;
    for my $source_key (shellwords($CONFIG->get_mirror_keys())) {
        my $method = "get_$source_key";
        push(@sources, $CONFIG->$method());
    }
    for my $dest (shellwords($CONFIG->get_mirror_dests())) {
        $rc = $RUNNER->run_continue(
            "distributing FCM to $dest",
            sub {
                run_rsync(
                    \@sources, $dest,
                    [@RSYNC_OPTS, qw{-a --delete-excluded}],
                );
            },
        ) && $rc;
    }
    return $rc;
}

# ------------------------------------------------------------------------------
# Returns a filtered list of projects matching names in a list.
sub filter_projects {
    my ($project_list_ref, $filter_list_ref) = @_;
    if (!@{$filter_list_ref}) {
        return @{$project_list_ref};
    }
    my %project_of = map {($_->get_name(), $_)} @{$project_list_ref};
    my @projects;
    my @unmatched_names;
    for my $name (@{$filter_list_ref}) {
        if (exists($project_of{$name})) {
            push(@projects, $project_of{$name});
        }
        else {
            push(@unmatched_names, $name);
        }
    }
    if (@unmatched_names) {
        die("@unmatched_names: not found\n");
    }
    return @projects;
}

# ------------------------------------------------------------------------------
# Returns a list of projects by searching the backup SVN directory.
sub get_projects_from_svn_backup {
    # (no dummy argument)
    my $SVN_PROJECT_SUFFIX
        = FCM::Admin::Config->instance()->get_svn_project_suffix();
    my @projects;
    _get_files_from(
        FCM::Admin::Config->instance()->get_svn_backup_dir(),
        sub {
            my ($base_name, $path) = @_;
            my $name = $base_name;
            if ($name !~ s{$SVN_PROJECT_SUFFIX\.tgz\z}{}xms) {
                return;
            }
            if (!-f $path) {
                return;
            }
            push(@projects, FCM::Admin::Project->new({name => $name}));
        },
    );
    return @projects;
}

# ------------------------------------------------------------------------------
# Returns a list of projects by searching the live SVN directory.
sub get_projects_from_svn_live {
    # (no dummy argument)
    my $SVN_PROJECT_SUFFIX
        = FCM::Admin::Config->instance()->get_svn_project_suffix();
    my @projects;
    _get_files_from(
        FCM::Admin::Config->instance()->get_svn_live_dir(),
        sub {
            my ($base_name, $path) = @_;
            my $name = $base_name;
            $name =~ s{$SVN_PROJECT_SUFFIX\z}{}xms;
            if (!-d $path) {
                return;
            }
            push(@projects, FCM::Admin::Project->new({name => $name}));
        },
    );
    return @projects;
}

# ------------------------------------------------------------------------------
# Returns a list of projects by searching the backup Trac directory.
sub get_projects_from_trac_backup {
    # (no dummy argument)
    my @projects;
    _get_files_from(
        FCM::Admin::Config->instance()->get_trac_backup_dir(),
        sub {
            my ($base_name, $path) = @_;
            my $name = $base_name;
            if ($name !~ s{\.tgz\z}{}xms) {
                return;
            }
            if (!-f $path) {
                return;
            }
            push(@projects, FCM::Admin::Project->new({name => $name}));
        },
    );
    return @projects;
}

# ------------------------------------------------------------------------------
# Returns a list of projects by searching the live Trac directory.
sub get_projects_from_trac_live {
    # (no dummy argument)
    my @projects;
    _get_files_from(
        FCM::Admin::Config->instance()->get_trac_live_dir(),
        sub {
            my ($name, $path) = @_;
            if (!-d $path) {
                return;
            }
            push(@projects, FCM::Admin::Project->new({name => $name}));
        },
    );
    return @projects;
}

# ------------------------------------------------------------------------------
# Gets a list of users using the mail aliases and the POSIX password DB.
sub get_users {
    # (no dummy argument)
    my %email_of;
    FCM::Admin::Runner->instance()->run(
        "retrieving entries from the mail aliases",
        sub {
            my $pipe = IO::Pipe->new();
            $pipe->reader(qw{getent aliases});
            ALIASES_LINE:
            while (my $line = $pipe->getline()) {
                chomp($line);
                my ($name, @emails) = split(qr{\s*[:,]\s*}xms, $line);
                if (scalar(@emails) != 1) {
                    next ALIASES_LINE;
                }
                $emails[0] =~ s{\s}{}gxms;
                $emails[0] =~ s{\@metoffice\.com\z}{\@metoffice.gov.uk}xms;
                if ($emails[0] !~ qr{\.uk\z}xms) { # is a .uk e-mail address
                    next ALIASES_LINE;
                }
                $email_of{$name} = $emails[0];
            }
            return $pipe->close();
        },
    );
    my %user_of;
    USER:
    while (my ($name, $gecos, $dir, $shell) = (getpwent())[0, 6, 7, 8]) {
        if (exists($user_of{$name})) {
            next USER;
        }
        if (!$dir || index($dir, '/home') != 0) {
            next USER;
        }
        if (!$shell || $shell =~ qr{false\z}xms) { # ends with "false"
            next USER;
        }
        my $email = $email_of{$name};
        if (!$email && $name =~ qr{\A([a-z]+(?:\.[a-z]+)+)\z}xms) {
            # Handles user IDs such as john.smith
            $email = $name . q{@metoffice.gov.uk};
        }
        if (!$email) {
            next USER;
        }
        $user_of{$name} = FCM::Admin::User->new({
            name         => $name,
            display_name => (split(qr{\s*,\s*}xms, $gecos))[0],
                            # $gecos contains "display name, location, phone"
            email        => $email,
        });
    }
    endpwent();
    if (keys(%user_of) < FCM::Admin::Config->instance()->get_user_number_min()) {
        die("Number of users below minimum threshold.\n");
    }
    return (wantarray() ? %user_of : \%user_of);
}

# ------------------------------------------------------------------------------
# Installs hook scripts to a SVN project.
sub install_svn_hook {
    my ($project) = @_;
    my %path_of;
    my $CONFIG = FCM::Admin::Config->instance();
    for (
        [$CONFIG->get_fcm_wc(), 'svn-hooks'],
        [$CONFIG->get_fcm_site_wc(), 'svn-hooks'],
        [$CONFIG->get_fcm_site_wc(), 'svn-hooks', $project->get_name()],
    ) {
        my $dir = File::Spec->catfile(@{$_});
        _get_files_from(
            $dir,
            sub {
                my ($base_name, $path) = @_;
                if (index($base_name, q{.}) == 0 || -d $path) {
                    return;
                }
                $path_of{$base_name} = $path;
            },
        );
    }
    for my $key (keys(%path_of)) {
        my $hook_source = $path_of{$key};
        my $hook_dest
            = File::Spec->catfile($project->get_svn_live_hook_path(), $key);
        if (-l $hook_dest) {
            my $symlink = readlink($hook_dest);
            if ($symlink ne $hook_source) {
                run_rmtree($hook_dest);
                run_symlink($hook_source, $hook_dest);
            }
        }
        else {
            if (-e $hook_dest) {
                run_rename($hook_dest, "$hook_dest.old");
            }
            run_symlink($hook_source, $hook_dest);
        }
    }
    return 1;
}

# ------------------------------------------------------------------------------
# Updates the SVN password file.
sub manage_users_in_svn_passwd {
    my ($user_ref) = @_;
    my $svn_passwd_file = File::Spec->catfile(
        FCM::Admin::Config->instance()->get_svn_live_dir(),
        FCM::Admin::Config->instance()->get_svn_passwd_file(),
    );
    FCM::Admin::Runner->instance()->run(
        "updating $svn_passwd_file",
        sub {
            my $USERS_SECTION = q{users};
            my $svn_passwd_ini;
            my $is_changed;
            if (-f $svn_passwd_file) {
                $svn_passwd_ini
                    = Config::IniFiles->new(q{-file} => $svn_passwd_file);
            }
            else {
                $svn_passwd_ini = Config::IniFiles->new();
                $svn_passwd_ini->SetFileName($svn_passwd_file);
                $svn_passwd_ini->AddSection($USERS_SECTION);
                $is_changed = 1;
            }
            for my $name (($svn_passwd_ini->Parameters($USERS_SECTION))) {
                if (!exists($user_ref->{$name})) {
                    FCM::Admin::Runner->instance()->run(
                        "removing $name from $svn_passwd_file",
                        sub {
                            return
                                $svn_passwd_ini->delval($USERS_SECTION, $name);
                        },
                    );
                    $is_changed = 1;
                }
            }
            for my $user (values(%{$user_ref})) {
                if (!defined($svn_passwd_ini->val($USERS_SECTION, "$user"))) {
                    FCM::Admin::Runner->instance()->run(
                        "adding $user to $svn_passwd_file",
                        sub {return $svn_passwd_ini->newval(
                            $USERS_SECTION, $user->get_name(), q{},
                        )},
                    );
                    $is_changed = 1;
                }
            }
            return ($is_changed ? $svn_passwd_ini->RewriteConfig() : 1);
        },
    );
    return 1;
}

# ------------------------------------------------------------------------------
# Updates the Trac password file.
sub manage_users_in_trac_passwd {
    my ($user_ref) = @_;
    my $trac_passwd_file = File::Spec->catfile(
        FCM::Admin::Config->instance()->get_trac_live_dir(),
        FCM::Admin::Config->instance()->get_trac_passwd_file(),
    );
    FCM::Admin::Runner->instance()->run(
        "updating $trac_passwd_file",
        sub {
            my %old_names;
            my %new_names = %{$user_ref};
            if (-f $trac_passwd_file) {
                read_file(
                    $trac_passwd_file,
                    sub {
                        my ($line) = @_;
                        chomp($line);
                        if (
                            !$line || $line =~ qr{\A\s*\z}xms # blank line
                            || $line =~ qr{\A\s*\#}xms        # comment line
                        ) {
                            return;
                        }
                        my ($name, $passwd) = split(qr{\s*:\s*}xms, $line);
                        if (exists($new_names{$name})) {
                            delete($new_names{$name});
                        }
                        else {
                            $old_names{$name} = 1;
                        }
                    },
                ) || return;
            }
            else {
                write_file($trac_passwd_file) || return;
            }
            if (%old_names || %new_names) {
                for my $name (keys(%old_names)) {
                    FCM::Admin::Runner->instance()->run(
                        "removing $name from $trac_passwd_file",
                        sub {
                            return !system(
                                qw{htpasswd -D}, $trac_passwd_file, $name,
                            );
                        },
                    );
                }
                for my $name (keys(%new_names)) {
                    FCM::Admin::Runner->instance()->run(
                        "adding $name to $trac_passwd_file",
                        sub {
                            return !system(
                                qw{htpasswd -b}, $trac_passwd_file, $name, q{},
                            );
                        },
                    );
                    sleep(1); # ensure the random seed for htpasswd is changed
                }
            }
            return 1;
        },
        # Note: can use HTTPD::UserAdmin, if it is installed
    );
    return 1;
}

# ------------------------------------------------------------------------------
# Manages the session* tables in the DB of a Trac environment.
sub manage_users_in_trac_db_of {
    my ($project, $user_ref) = @_;
    return FCM::Admin::Runner->instance()->run_with_retries(
        sprintf(
            qq{checking/updating %s},
            $project->get_trac_live_db_path(),
        ),
        sub {return _manage_users_in_trac_db_of($project, $user_ref)},
    );
}

# ------------------------------------------------------------------------------
# Recovers a SVN repository from its backup.
sub recover_svn_repository {
    my ($project, $recover_dumps_option, $recover_hooks_option) = @_;
    my $config = FCM::Admin::Config->instance();
    if (-e $project->get_svn_live_path()) {
        die(sprintf(
            "%s: live repository exists.\n",
            $project->get_svn_live_path(),
        ));
    }
    run_mkpath($config->get_svn_live_dir());
    my $base_name = $project->get_svn_base_name();
    my $work_dir = tempdir(
        qq{$base_name.XXXXXX},
        DIR => $config->get_svn_live_dir(),
        CLEANUP => 1,
    );
    my $work_path = File::Spec->catfile($work_dir, $base_name);
    _extract_backup_archive($project->get_svn_backup_path(), $work_path);
    if ($recover_dumps_option) {
        my $youngest = _svnlook_youngest($work_path);
        my @rev_dump_paths;
        _get_files_from(
            $project->get_svn_dump_path(),
            sub {
                my ($base_name, $path) = @_;
                my $rev = basename($base_name, '.gz');
                if ($rev <= $youngest) {
                    return;
                }
                push(@rev_dump_paths, $path);
            },
        );
        # Note: sorts basenames of @rev_dump_paths into numeric ascending order
        # using a Schwartzian Transform
        @rev_dump_paths
            = map {$_->[0]}
              sort {$a->[1] <=> $b->[1]}
              map {[$_, basename($_, '.gz')]}
              @rev_dump_paths;
        for my $rev_dump_path (@rev_dump_paths) {
            FCM::Admin::Runner->instance()->run(
                "loading $rev_dump_path into $work_path",
                sub {
                    my $pipe = IO::Pipe->new();
                    $pipe->writer(qw{svnadmin load}, $work_path);
                    my $handle = IO::Zlib->new($rev_dump_path, 'rb');
                    if (!$handle) {
                        die("$rev_dump_path: $!\n");
                    }
                    while ($handle->read(my $buffer, $BUFFER_SIZE)) {
                        $pipe->print($buffer);
                    }
                    $handle->close();
                    return ($pipe->close());
                },
            );
        }
    }
    run_rename($work_path, $project->get_svn_live_path());
    if ($recover_hooks_option) {
        install_svn_hook($project);
    }
    return 1;
}

# ------------------------------------------------------------------------------
# Recovers a Trac environment from its backup.
sub recover_trac_environment {
    my ($project) = @_;
    if (-e $project->get_trac_live_path()) {
        die(sprintf(
            "%s: live environment exists.\n",
            $project->get_trac_live_path(),
        ));
    }
    my $config = FCM::Admin::Config->instance();
    run_mkpath($config->get_trac_live_dir());
    my $base_name = $project->get_name();
    my $work_dir = tempdir(
        qq{$base_name.XXXXXX},
        DIR => $config->get_trac_live_dir(),
        CLEANUP => 1,
    );
    my $work_path = File::Spec->catfile($work_dir, $base_name);
    _extract_backup_archive($project->get_trac_backup_path(), $work_path);
    run_rename($work_path, $project->get_trac_live_path());
    _chgrp_and_chmod_trac_environment_for($project);
}

# ------------------------------------------------------------------------------
# Recover a file from the Trac backup directory to the Trac live directory.
sub recover_trac_files {
    # (no argument)
    my $CONFIG = FCM::Admin::Config->instance();
    _copy_files(
        $CONFIG->get_trac_backup_dir(),
        $CONFIG->get_trac_live_dir(),
        $NO_OVERWRITE,
        qr{\.tgz\z}msx,
    );
}

# ------------------------------------------------------------------------------
# Vacuum the database of a Trac environment.
sub vacuum_trac_env_db {
    my ($project) = @_;
    FCM::Admin::Runner->instance()->run(
        "performing vacuum on database of Trac environment for $project",
        sub {
            my $db_handle = _get_trac_db_handle_for($project);
            if (!$db_handle) {
                return;
            }
            $db_handle->do(q{vacuum;}) && $db_handle->disconnect();
        },
    );
}

# ------------------------------------------------------------------------------
# Changes/restores ownership and permission of a project's Trac environment.
sub _chgrp_and_chmod_trac_environment_for {
    my ($project) = @_;
    my $gid  = FCM::Admin::Config->instance()->get_trac_gid();
    find(
        sub {
            my $file = $File::Find::name;
            FCM::Admin::Runner->instance()->run(
                "changing group ownership for $file",
                sub {return chown(-1, $gid, $file)},
            );
            my $mode = (stat($file))[2] | S_IWGRP;
            FCM::Admin::Runner->instance()->run(
                "adding group write permission for $file",
                sub {return chmod($mode, $file)},
            );
        },
        $project->get_trac_live_path(),
    );
    return 1;
}

# ------------------------------------------------------------------------------
# Copies files immediately under $source to $target.
sub _copy_files {
    my ($source, $target, $no_overwrite, $re_skip) = @_;
    my @bases;
    opendir(my $handle, $source) || die("$source: $!\n");
    while (my $base = readdir($handle)) {
        if (-f File::Spec->catfile($source, $base)) {
            if ($no_overwrite && -f File::Spec->catfile($target, $base)) {
                warn("[SKIP] $base: already exists in $target.\n");
            }
            elsif (!$re_skip || ($base !~ $re_skip)) {
                push(@bases, $base);
            }
        }
    }
    closedir($handle);
    run_mkpath($target);
    for my $base (@bases) {
        run_copy(map {File::Spec->catfile($_, $base)} ($source, $target));
    }
    return 1;
}

# ------------------------------------------------------------------------------
# Creates backup archive from a path.
sub _create_backup_archive {
    my ($source_path, $backup_dir, $archive_base_name) = @_;
    my $source_dir = dirname($source_path);
    my $source_base_name = basename($source_path);
    run_mkpath($backup_dir);
    my ($fh, $work_backup_path)
        = tempfile(qq{$archive_base_name.XXXXXX}, DIR => $backup_dir);
    close($fh);
    run_create_archive($work_backup_path, $source_dir, $source_base_name);
    my $backup_path = File::Spec->catfile($backup_dir, $archive_base_name);
    run_rename($work_backup_path, $backup_path);
    my $mode = (stat($backup_path))[2] | S_IRGRP | S_IROTH;
    return chmod($mode, $backup_path);
}

# ------------------------------------------------------------------------------
# Extracts from a backup archive to a work path.
sub _extract_backup_archive {
    my ($archive_path, $work_path) = @_;
    run_extract_archive($archive_path, dirname($work_path));
    if (! -e $work_path) {
        my ($base_name) = basename($work_path);
        die("$base_name: does not exist in archive $archive_path.\n");
    }
    return 1;
}

# ------------------------------------------------------------------------------
# Searches a directory for files and invokes a callback on each file.
sub _get_files_from {
    my ($dir_path, $callback_ref) = @_;
    my $dir_handle = IO::Dir->new($dir_path);
    if (!defined($dir_handle)) {
        return;
    }
    BASE_NAME:
    while (my $base_name = $dir_handle->read()) {
        my $path = File::Spec->catfile($dir_path, $base_name);
        if (index($base_name, q{.}) == 0) {
            next BASE_NAME;
        }
        $callback_ref->($base_name, $path);
    }
    return $dir_handle->close();
}

# ------------------------------------------------------------------------------
# Returns a database handle for the database of a Trac environment.
sub _get_trac_db_handle_for {
    my ($project) = @_;
    my $db_path = $project->get_trac_live_db_path();
    return DBI->connect(qq{dbi:SQLite:dbname=$db_path}, q{}, q{});
}

# ------------------------------------------------------------------------------
# Manages the session* tables in the DB of a Trac environment.
sub _manage_users_in_trac_db_of {
    my ($project, $user_ref) = @_;
    my $db_handle = _get_trac_db_handle_for($project);
    if (!$db_handle) {
        return;
    }
    SESSION: {
        my $session_select_statement = $db_handle->prepare(
            "SELECT sid FROM session WHERE authenticated == 1",
        );
        my $session_insert_statement = $db_handle->prepare(
            "INSERT INTO session VALUES (?, 1, 0)",
        );
        my $session_delete_statement = $db_handle->prepare(
            "DELETE FROM session WHERE sid == ?",
        );
        $session_select_statement->execute();
        my $is_changed = 0;
        my %session_old_users;
        while (my ($sid) = $session_select_statement->fetchrow_array()) {
            if (exists($user_ref->{$sid})) {
                $session_old_users{$sid} = 1;
            }
            else {
                FCM::Admin::Runner->instance()->run(
                    "session: removing $sid",
                    sub{return $session_delete_statement->execute($sid)},
                );
                $is_changed = 1;
            }
        }
        for my $sid (keys(%{$user_ref})) {
            if (!exists($session_old_users{$sid})) {
                FCM::Admin::Runner->instance()->run(
                    "session: adding $sid",
                    sub {return $session_insert_statement->execute($sid)},
                );
                $is_changed = 1;
            }
        }
        $session_select_statement->finish();
        $session_insert_statement->finish();
        $session_delete_statement->finish();
    }
    SESSION_ATTRIBUTE: {
        my $attribute_select_statement = $db_handle->prepare(
            "SELECT sid,name,value FROM session_attribute "
                . "WHERE authenticated == 1",
        );
        my $attribute_insert_statement = $db_handle->prepare(
            "INSERT INTO session_attribute VALUES (?, 1, ?, ?)",
        );
        my $attribute_update_statement = $db_handle->prepare(
            "UPDATE session_attribute SET value = ? "
                . "WHERE sid = ? and authenticated == 1 and name == ?",
        );
        my $attribute_delete_statement = $db_handle->prepare(
            "DELETE FROM session_attribute WHERE sid == ?",
        );
        $attribute_select_statement->execute();
        my %attribute_old_users;
        ROW:
        while (my @row = $attribute_select_statement->fetchrow_array()) {
            my ($sid, $name, $value) = @row;
            my $user = exists($user_ref->{$sid})? $user_ref->{$sid} : undef;
            if (defined($user)) {
                $attribute_old_users{$sid} = 1;
                my $getter
                    = $name eq 'name'  ? 'get_display_name'
                    : $name eq 'email' ? 'get_email'
                    :                    undef;
                if (!defined($getter)) {
                    next ROW;
                }
                if ($user->$getter() ne $value) {
                    my $new_value = $user->$getter();
                    FCM::Admin::Runner->instance()->run(
                        "session_attribute: updating $name: $sid: $new_value",
                        sub {return $attribute_update_statement->execute(
                            $new_value, $sid, $name,
                        )},
                    );
                }
            }
            else {
                FCM::Admin::Runner->instance()->run(
                    "session_attribute: removing $sid",
                    sub {return $attribute_delete_statement->execute($sid)},
                );
            }
        }
        USER:
        for my $sid (keys(%{$user_ref})) {
            if (exists($attribute_old_users{$sid})) {
                next USER;
            }
            my $user = $user_ref->{$sid};
            my $display_name = $user->get_display_name();
            my $email        = $user->get_email();
            FCM::Admin::Runner->instance()->run(
                "session_attribute: adding name: $sid: $display_name",
                sub {return $attribute_insert_statement->execute(
                    $sid, 'name', $display_name,
                )},
            );
            FCM::Admin::Runner->instance()->run(
                "session_attribute: adding email: $sid: $email",
                sub {return $attribute_insert_statement->execute(
                    $sid, 'email', $email,
                )},
            );
        }
        $attribute_select_statement->finish();
        $attribute_insert_statement->finish();
        $attribute_update_statement->finish();
        $attribute_delete_statement->finish();
    }
    return $db_handle->disconnect();
}

# ------------------------------------------------------------------------------
# Returns the youngest revision of a SVN repository.
sub _svnlook_youngest {
    my ($svn_repos_path) = @_;
    my ($youngest) = qx{svnlook youngest $svn_repos_path};
    chomp($youngest);
    return $youngest;
}

1;
__END__

=head1 NAME

FCM::Admin::System

=head1 SYNOPSIS

    use FCM::Admin::System qw{ ... };
    # ... see descriptions of individual functions for detail

=head1 DESCRIPTION

This module contains utility functions for the administration of Subversion
repositories and Trac environments hosted by the FCM team.

=head1 FUNCTIONS

=over 4

=item add_trac_environment($project_name, $admin_user_list_ref, $authorised_option)

Creates a new Trac environment.

=item backup_svn_repository(\%option,$project)

Creates an archived hotcopy of $project's live SVN repository, and put it in the
SVN backup directory. If $option{'no-verify-integrity'} does not exist, it
verifies the integrity of the live repository before creating the hotcopy. If
$option{'no-pack'} does not exist, it packs the live repository before creating
the hotcopy. If $option{'no-housekeep-dumps'} does not exist, it housekeeps the
revision dumps of $project following a successful backup.

$project should be a L<FCM::Admin::Project|FCM::Admin::Project> object.

=item backup_trac_environment(\%option,$project)

Creates an archived hotcopy of $project's live Trac environment, and put it in
the Trac backup directory. If $option{'no-verify-integrity'} does not exist, it
verifies the integrity of the database of the live environment before creating
the hotcopy.

$project should be a L<FCM::Admin::Project|FCM::Admin::Project> object.

=item backup_trac_files()

Copies regular files immediately under the live Trac directory to the Trac
backup directory.

=item distribute_wc()

Distributes the central FCM working copy to standard locations.

=item filter_projects($project_list_ref,$filter_list_ref)

Filters the project list in $project_list_ref using a list of names in
$filter_list_ref. Returns a list of projects with names matching those in
$filter_list_ref. Returns the full list if $filter_list_ref points to an empty
list.

=item get_projects_from_svn_backup()

Returns a list of L<FCM::Admin::Project|FCM::Admin::Project> objects by
searching the SVN backup directory. By default, all valid projects are returned.

=item get_projects_from_svn_live()

Similar to get_projects_from_svn_backup(), but it searches the SVN live
directory.

=item get_projects_from_trac_backup()

Similar to get_projects_from_svn_backup(), but it searches the Trac backup
directory.

=item get_projects_from_trac_live()

Similar to get_projects_from_svn_backup(), but it searches the Trac live
directory.

=item get_users()

Retrieves a list of users using the mail aliases and the POSIX password
database. It also makes a naive attempt to filter out admin accounts. In LIST
context, returns a hash with keys = user IDs and values = user details (as
L<FCM::Admin::System::User|FCM::Admin::System::User> objects). In SCALAR
context, returns a reference to the same hash.

=item install_svn_hook($project)

Searches for hook scripts in the standard location and install them (as symbolic
links) in the I<hooks> directory of the $project's SVN live repository.

$project should be a L<FCM::Admin::Project|FCM::Admin::Project> object.

=item manage_users_in_svn_passwd($user_ref)

Using entries in the hash reference $user_ref, sets up or updates the SVN and
Trac password files. The $user_ref argument should be a reference to a hash, as
returned by get_users().

=item manage_users_in_trac_passwd($user_ref)

Using entries in the hash reference $user_ref, sets up or updates the Trac
password files. The $user_ref argument should be a reference to a hash, as
returned by get_users().

=item manage_users_in_trac_db_of($project, $user_ref)

Using entries in $user_ref, sets up or updates the session/session_attribute
tables in the databases of the live Trac environments. The $project argument
should be a L<FCM::Admin::Project|FCM::Admin::Project> object
and $user_ref should be a reference to a hash, as returned by get_users().

=item recover_svn_repository($project,$recover_dumps_option,$recover_hooks_option)

Recovers a project's SVN repository using its backup. If $recover_dumps_option
is set to true, it will also attempt to load the latest revision dumps following
a successful recovery. If $recover_hooks_option is set to true, it will also
attempt to re-install the hook scripts following a successful recovery.

$project should be a L<FCM::Admin::Project|FCM::Admin::Project> object.

=item recover_trac_environment($project)

Recovers a project's Trac environment using its backup.

$project should be a L<FCM::Admin::Project|FCM::Admin::Project> object.

=item recover_trac_files()

Copies files immediately under the backup Trac directory to the Trac live
directory (if the files do not already exist).

=item vacuum_trac_env_db($project)

Connects to the database of a project's Trac environment, and issues the
"VACUUM" SQL command.

$project should be a L<FCM::Admin::Project|FCM::Admin::Project> object.

=back

=head1 SEE ALSO

L<FCM::Admin::Config|FCM::Admin::Config>,
L<FCM::Admin::Project|FCM::Admin::Project>,
L<FCM::Admin::Runner|FCM::Admin::Runner>,
L<FCM::Admin::User|FCM::Admin::User>,
L<FCM::Admin::Util|FCM::Admin::Util>

=head1 COPYRIGHT

E<169> Crown copyright Met Office. All rights reserved.

=cut
