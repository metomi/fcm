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
# ------------------------------------------------------------------------------
package FCM::System::Make;
use base qw{FCM::Class::CODE};

use FCM::Context::ConfigEntry;
use FCM::Context::Event;
use FCM::System::Exception;
use FCM::System::Make::Build;
use FCM::System::Make::Extract;
use FCM::System::Make::Mirror;
use FCM::System::Make::Preprocess;
use FCM::System::Make::Share::Config;
use FCM::System::Make::Share::Dest;
use File::Path qw{rmtree};
use File::Spec::Functions qw{catfile};
use File::Copy qw{copy};
use File::Temp;
use POSIX qw{strftime};
use Sys::Hostname qw{hostname};

# Actions of the named common steps
my %ACTION_OF = (
    'config-parse' => \&_config_parse,
    'dest-init'    => \&_dest_init   ,
);
# Alias to class name
my $E = 'FCM::System::Exception';
# The initial steps to run
my @INIT_STEPS = (qw{config-parse dest-init});
# The name of the system
our $NAME = 'make';
# Base name of common configuration file
our $CFG_BASE = 'make.cfg';
# A map of named helper utilities
our %SHARED_UTIL_OF = (
    'config' => 'FCM::System::Make::Share::Config',
    'dest'   => 'FCM::System::Make::Share::Dest'  ,
);
# A map of named subsystems
our %SUBSYSTEM_OF = (
    'build'      => 'FCM::System::Make::Build'     ,
    'extract'    => 'FCM::System::Make::Extract'   ,
    'mirror'     => 'FCM::System::Make::Mirror'    ,
    'preprocess' => 'FCM::System::Make::Preprocess',
);

# Creates the class.
__PACKAGE__->class(
    {   cfg_base       => {isa => '$', default => $CFG_BASE},
        name           => {isa => '$', default => $NAME},
        shared_util_of => '%',
        subsystem_of   => '%',
        util           => '&',
    },
    {init => \&_init, action_of => {main => \&_main}},
);

# Initialises an instance.
sub _init {
    my $attrib_ref = shift();
    for (
        ['shared_util_of', \%SHARED_UTIL_OF],
        ['subsystem_of'  , \%SUBSYSTEM_OF  ],
    ) {
        my ($key, $hash_ref) = @{$_};
        while (my ($id, $class) = each(%{$hash_ref})) {
            if (!exists($attrib_ref->{$key}{$id})) {
                $attrib_ref->{$key}{$id} = $class->new({
                    'shared_util_of' => $attrib_ref->{'shared_util_of'},
                    'subsystem_of'   => $attrib_ref->{'subsystem_of'},
                    'util'           => $attrib_ref->{'util'},
                });
            }
        }
    }
    for my $path (
        grep {-f $_ && -r _}
            map {catfile($_, $attrib_ref->{cfg_base})}
                $attrib_ref->{util}->cfg_paths()
    ) {
        my $config_reader_ref = $attrib_ref->{util}->config_reader(
            FCM::Context::Locator->new($path),
        );
        my @unknown_entries;
        while (defined(my $entry = $config_reader_ref->())) {
            my ($id, $label) = split(qr{\.}msx, $entry->get_label(), 2);
            if (exists($attrib_ref->{subsystem_of}{$id})) {
                my $subsystem = $attrib_ref->{subsystem_of}{$id};
                if (!$subsystem->config_parse_class_prop($entry, $label)) {
                    push(@unknown_entries, $entry);
                }
            }
            else {
                push(@unknown_entries, $entry);
            }
        }
        if (@unknown_entries) {
            return $E->throw($E->CONFIG_UNKNOWN, \@unknown_entries);
        }
    }
}

# Sets up the destination.
sub _config_parse {
    my ($attrib_ref, $m_ctx, @args) = @_;
    my $entry_callback_ref = sub {
        my ($entry) = @_;
        print({$attrib_ref->{handle_cfg}} $entry->as_string(), "\n");
    };
    $attrib_ref->{shared_util_of}{config}->parse(
        $entry_callback_ref, $m_ctx, @args,
    );
}

# Sets up the destination.
sub _dest_init {
    my ($attrib_ref, $m_ctx) = @_;
    $attrib_ref->{shared_util_of}{dest}->dest_init($m_ctx);

    # Move temporary log file to destination
    my $now = strftime("%Y%m%dT%H%M%S", gmtime());
    my $log = $attrib_ref->{shared_util_of}{dest}->path($m_ctx, 'sys-log');
    my $log_actual = sprintf("%s-%s", $log, $now);
    _symlink($log_actual, $log);
    (       close($attrib_ref->{handle_log})
        &&  copy($attrib_ref->{handle_log}->filename(), $log)
        &&  open(my $handle_log, '>>', $log)
    ) || return $E->throw($E->DEST_CREATE, $log, $!);
    _symlink(
        $FCM::System::Make::Share::Dest::PATH_OF{'sys-log'},
        $attrib_ref->{shared_util_of}{dest}->path($m_ctx, 'sys-log-symlink'),
    );
    my $log_ctx = $attrib_ref->{util}->util_of_report()->get_ctx($m_ctx);
    $log_ctx->set_handle($handle_log);

    # Saves as parsed config
    my $cfg = $attrib_ref->{shared_util_of}{dest}->path(
        $m_ctx, 'sys-config-as-parsed',
    );
    (       close($attrib_ref->{handle_cfg})
        &&  copy($attrib_ref->{handle_cfg}->filename(), $cfg)
    ) || return $E->throw($E->DEST_CREATE, $cfg, $!);
    _symlink(
        $FCM::System::Make::Share::Dest::PATH_OF{'sys-config-as-parsed'},
        $attrib_ref->{shared_util_of}{dest}->path(
            $m_ctx,
            'sys-config-as-parsed-symlink',
        ),
    );
}

# The main function of an instance of this class.
sub _main {
    my ($attrib_ref, $option_hash_ref, @args) = @_;
    # Starts the system
    my $m_ctx = FCM::Context::Make->new({option_of => $option_hash_ref});
    my $T = sub {_timer_wrap($attrib_ref, @_)};
    eval {$T->(
        sub {
            my %attrib = (
                %{$attrib_ref},
                handle_log => File::Temp->new(),
                handle_cfg => File::Temp->new(),
            );
            $attrib_ref->{util}->util_of_report()->add_ctx(
                $m_ctx, # key
                {   handle    => $attrib{handle_log},
                    type      => undef,
                    verbosity => $attrib_ref->{util}->util_of_report()->HIGH,
                },
            );
            $attrib_ref->{util}->event(
                FCM::Context::Event->FCM_VERSION,
                $attrib_ref->{util}->version(),
            );
            for my $step (@INIT_STEPS) {
                $T->(sub {$ACTION_OF{$step}->(\%attrib, $m_ctx, @args)}, $step);
            }
            for my $step (@{$m_ctx->get_steps()}) {
                my $ctx = $m_ctx->get_ctx_of($step);
                if (!defined($ctx)) {
                    return $E->throw($E->MAKE, $step);
                }
                my $id_of_class = $ctx->get_id_of_class();
                if (!exists($attrib_ref->{subsystem_of}{$id_of_class})) {
                    return $E->throw($E->MAKE, $step);
                }
                my $impl = $attrib_ref->{subsystem_of}{$id_of_class};
                $ctx->set_status($m_ctx->ST_INIT);
                if ($ctx->can('set_dest')) {
                    $ctx->set_dest(
                        $attrib_ref->{shared_util_of}{dest}->path(
                            $m_ctx, 'target', $ctx->get_id(),
                        ),
                    );
                }
                eval {$T->(sub {$impl->main($m_ctx, $ctx)}, $step)};
                if (my $e = $@) {
                    $ctx->set_status($m_ctx->ST_FAILED);
                    die($e);
                }
                $ctx->set_status($m_ctx->ST_OK);
            }
        },
    )};
    if (my $e = $@) {
        $m_ctx->set_status($m_ctx->ST_FAILED);
        $m_ctx->set_error($e);
        $attrib_ref->{util}->event(FCM::Context::Event->E, $e);
        _main_finally($attrib_ref, $m_ctx);
        die("\n");
    }
    $m_ctx->set_status($m_ctx->ST_OK);
    $attrib_ref->{shared_util_of}{dest}->save(
        [$attrib_ref->{shared_util_of}{config}->unparse($m_ctx)],
        $m_ctx,
        'sys-config-on-success',
    );
    _symlink(
        $FCM::System::Make::Share::Dest::PATH_OF{'sys-config-on-success'},
        $attrib_ref->{shared_util_of}{dest}->path(
            $m_ctx,
            'sys-config-on-success-symlink',
        ),
    );
    _main_finally($attrib_ref, $m_ctx);
    return $m_ctx;
}

# Helper to run the "finally" part of "_main".
sub _main_finally {
    my ($attrib_ref, $m_ctx) = @_;
    $m_ctx->set_inherit_ctx_list([]);
    $m_ctx->set_prev_ctx(undef);
    $attrib_ref->{shared_util_of}{dest}->dest_done($m_ctx);
    my $log_ctx = $attrib_ref->{util}->util_of_report()->del_ctx($m_ctx);
    close($log_ctx->get_handle());
}

# Wrap "symlink".
sub _symlink {
    my ($source, $target) = @_;
    if (-l $target && readlink($target) eq $source) {
        return;
    }
    if (-e $target || -l $target) {
        rmtree($target);
    }
    symlink($source, $target) || return $E->throw($E->DEST_CREATE, $target, $!);
}

# Wraps a piece of code with timer events.
sub _timer_wrap {
    my ($attrib_ref, $code_ref, @names) = @_;
    my @event_args = (
        FCM::Context::Event->TIMER,
        join(q{ }, $attrib_ref->{name}, @names),
        time(),
    );
    $attrib_ref->{util}->event(@event_args);
    my $timer = $attrib_ref->{util}->timer();
    my $return = eval {wantarray() ? [$code_ref->()] : $code_ref->()};
    my $e = $@;
    $attrib_ref->{util}->event(@event_args, $timer->(), $e);
    if ($e) {
        die($e);
    }
    return (wantarray() ? @{$return} : $return);
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make

=head1 SYNOPSIS

    use FCM::System::Make;
    my $system = FCM::System::Make->new(\%attrib);
    $system->(\%option);


=head1 DESCRIPTION

Invokes the FCM make system.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Creates and returns a new instance. The %attrib may contain the following:

=over 4

=item cfg_base

The base name of the common (site/user) configuration file. (default="make.cfg")

=item name

The name of this sub-system. (default="make")

=item shared_util_of

A HASH to map the names to the classes of the named helper utilities for the
make system and its sub-systems. (default = %FCM::System::Make::SHARED_UTIL_OF)

=item subsystem_of

A HASH to map the names to the classes of the subsystems. (default =
%FCM::System::Make::SUBSYSTEM_OF)

=item util

An instance of L<FCM::Util|FCM::Util>.

=back

=item $system->(\%option)

Invokes a make. The %option may contain the following:

=over 4

=item config-file

The path to the configuration file. (default = $PWD/fcm-make.cfg)

=item ignore-lock

This flag can be used to ignore the lock file. The system creates a lock file in
the destination to prevent another command from running in the same destination.
If this flag is set, the system will continue even if it encounters a lock file
in the destination. (default = false)

=item jobs

The number of (child) jobs that can be used to run parallel tasks.

=item new

A flag to tell the system to perform a new make. (default = false, i.e.
incremental make)

=back

Throws L<FCM::System::Exception|FCM::System::Exception> on error.

=back

=head1 SUBSYSTEMS

A subsystem of the make system should be a CODE-based class that implements a
particular set of methods. (Some of these methods can be imported from
L<FCM::System::Make::Share::Subsystem|FCM::System::Make::Share::Subsystem>.) The
methods that should be implemented are:

=over 4

=item $subsystem_class->new(\%attrib)

Creates a new instance of the subsystem. The make system passes the
I<shared_util_of>, I<subsystem_of> and I<util> attributes to this method.

=item $subsystem->config_parse($ctx,$entry,$label)

Reads the settings of $entry into the $ctx. The $label is the configuration
entry label in the context of the subsystem. (This is normally the
$entry->get_label() but with the context ID prefix removed.). Returns true on
success.

=item $subsystem->config_parse_inherit_hook($ctx,$i_ctx)

This method is called when the make inherits from an existing make. The $ctx is
the current subsystem context, and the $i_ctx is the inherited subsystem
context. This method allows the subsystem to make use of the inherited settings
in the current context.

=item $subsystem->config_unparse($ctx)

Returns a list of L<FCM::Context::ConfigEntry|FCM::Context::ConfigEntry> to
represent the settings of the $ctx.

=item $subsystem->ctx($id_of_class,$id)

Returns a new context for the subsystem. The $id_of_class is the ID of the
subsystem class. The $id is the step ID of the context.

=item $subsystem->config_parse_class_prop($entry,$label)

Reads a configuration $entry into the subsystem default property. The $label is
the label of the $entry, but with the prefix (the subsystem ID plus a dot)
removed.

=item $subsystem->main($m_ctx,$ctx)

Invokes the subsystem. The $m_ctx is the current context of the make (as a
blessed reference of L<FCM::Context::Make|FCM::Context::Make>). The $ctx is the
context of the subsystem.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
