# ------------------------------------------------------------------------------
# Copyright (C) 2006-2019 British Crown (Met Office) & Contributors.
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
package FCM::System::Make::Mirror;
use base qw{FCM::Class::CODE};

use FCM::Context::ConfigEntry;
use FCM::Context::Event;
use FCM::Context::Make;
use FCM::Context::Make::Mirror;
use FCM::Context::Make::Share::Property;
use FCM::System::Make::Share::Subsystem;
use File::Basename qw{dirname};
use File::Path qw{mkpath};
use File::Spec::Functions qw{abs2rel file_name_is_absolute rel2abs};
use POSIX qw{strftime};
use Storable qw{dclone};
use Sys::Hostname qw{hostname};
use Text::ParseWords qw{shellwords};

# Alias
my $E = 'FCM::System::Exception';

# Configuration parser label to action map
our %CONFIG_PARSER_OF = (
    'target' => \&_config_parse_target,
);

# Default properties
our %PROP_OF = (
    'config-file.name'  => [q{}],
    'config-file.steps' => [q{}],
    'no-config-file'    => [q{}],
);

# Properties from FCM::Util
our @UTIL_PROP_KEYS = qw{ssh ssh.flags rsync rsync.flags};

# Creates the class.
__PACKAGE__->class(
    {   config_parser_of => {isa => '%', default => {%CONFIG_PARSER_OF}},
        prop_of          => {isa => '%', default => {%PROP_OF}},
        shared_util_of   => '%',
        util             => '&',
    },
    {   init => \&_init,
        action_of => {
            config_parse              => \&_config_parse,
            config_parse_class_prop   => \&_config_parse_class_prop,
            config_parse_inherit_hook => \&_config_parse_inherit_hook,
            config_unparse            => \&_config_unparse,
            config_unparse_class_prop => \&_config_unparse_class_prop,
            ctx                       => \&_ctx,
            main                      => \&_main,
        },
    },
);

# Initialises the helpers of the class.
sub _init {
    my ($attrib_ref) = @_;
    for my $util_prop_key (@UTIL_PROP_KEYS) {
        my $prop = $attrib_ref->{util}->external_cfg_get($util_prop_key);
        $attrib_ref->{prop_of}{$util_prop_key} = [$prop];
    }
}

# Reads the mirror.target declaration from a config entry.
sub _config_parse_target {
    my ($attrib_ref, $ctx, $entry) = @_;
    my $value = $entry->get_value();
    # Note: it is easier to parse the value in reverse because a target may look
    # like "path", "machine:path" or "logname@machine:path"
    my ($path, $auth) = reverse(split(':', $value, 2));
    my ($machine, $logname) = $auth ? reverse(split('@', $auth, 2)) : ();
    if (!$path || ($logname && !$machine)) {
        return $E->throw($E->CONFIG_VALUE, $entry);
    }
    $ctx->set_target_logname($logname);
    $ctx->set_target_machine($machine);
    $ctx->set_target_path($path);
}

# A hook command for the "inherit/use" declaration (extract).
sub _config_parse_inherit_hook {
    my ($attrib_ref, $ctx, $i_ctx) = @_;
    $ctx->set_target_machine($i_ctx->get_target_machine());
    _config_parse_inherit_hook_prop($attrib_ref, $ctx, $i_ctx);
}

# Turns a context into a list of configuration entries.
sub _config_unparse {
    my ($attrib_ref, $ctx) = @_;
    (   (   $ctx->get_target_path()
            ? FCM::Context::ConfigEntry->new({
                label => $ctx->get_id() . q{.} . 'target',
                value => (_target_and_authority($ctx))[0],
            })
            : ()
        ),
        _config_unparse_prop($attrib_ref, $ctx),
    );
}

# Returns a new context.
sub _ctx {
    my ($attrib_ref, $id_of_class, $id) = @_;
    FCM::Context::Make::Mirror->new({id => $id, id_of_class => $id_of_class});
}

# The main function.
sub _main {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    if (!$ctx->get_target_path()) {
        return $E->throw($E->MIRROR_NULL);
    }
    my $do_config_file = !_prop($attrib_ref, 'no-config-file', $ctx);
    my @sources;
    my @bad_step_list;
    for my $step (@{$m_ctx->get_steps()}) {
        my $ctx = $m_ctx->get_ctx_of($step);
        if (    $ctx->get_status() eq $m_ctx->ST_OK
            &&  $ctx->can('get_dest')
            &&  -e $ctx->get_dest()
        ) {
            if ($do_config_file && !$ctx->can('MIRROR')) {
                push(@bad_step_list, $step);
            }
            else {
                push(@sources, $ctx->get_dest());
            }
        }
    }
    if (@bad_step_list) {
        return $E->throw($E->MIRROR_SOURCE, \@bad_step_list);
    }
    for my $action (
        \&_mirror_mkdir,
        (@sources        ? \&_mirror             : ()),
        ($do_config_file ? \&_mirror_config_file : ()),
        \&_mirror_orig_config_file,
    ) {
        $action->($attrib_ref, $m_ctx, $ctx, \@sources);
    }
}

# Creates a configuration file at the destination.
sub _mirror_config_file {
    my ($attrib_ref, $m_ctx, $ctx, $sources_ref) = @_;
    my ($target) = _target_and_authority($ctx);
    my $mirror_m_ctx = FCM::Context::Make->new({dest => '$HERE'});
    $mirror_m_ctx->set_name(_prop($attrib_ref, 'config-file.name', $ctx));
    my %no_inherit_from;
    if (@{$m_ctx->get_inherit_ctx_list()}) {
        # Inherited destinations
        for my $i_m_ctx (@{$m_ctx->get_inherit_ctx_list()}) {
            my $i_ctx = $i_m_ctx->get_ctx_of($ctx->get_id());
            if (defined($i_ctx)) {
                push(
                    @{$mirror_m_ctx->get_inherit_ctx_list()},
                    FCM::Context::Make->new({dest => $i_ctx->get_target_path()}),
                );
            }
        }
        # Completed steps, from which the targets can be sourced
        DONE_STEP:
        for my $step (@{$m_ctx->get_steps()}) {
            my $step_ctx = $m_ctx->get_ctx_of($step);
            if (    !defined($step_ctx)
                ||  $step_ctx->get_status() ne $m_ctx->ST_OK
                ||  !$step_ctx->can('get_target_of')
            ) {
                next DONE_STEP;
            }
            while (my ($key, $target) = each(%{$step_ctx->get_target_of()})) {
                if (!$target->is_ok()) {
                    $no_inherit_from{$target->get_ns()} = 1;
                }
            }
        }
    }
    # Steps to include in the configuration file
    for my $step (_props($attrib_ref, 'config-file.steps', $ctx)) {
        my $step_ctx = $m_ctx->get_ctx_of($step);
        if (    !defined($step_ctx)
            ||  $step_ctx->get_status() ne $m_ctx->ST_UNKNOWN
        ) {
            return $E->throw(
                $E->MAKE_PROP_VALUE,
                [[$ctx->get_id(), 'config-file.steps', q{}, $step]],
            );
        }
        push(@{$mirror_m_ctx->get_steps()}, $step);
        $mirror_m_ctx->get_ctx_of()->{$step} = dclone($step_ctx);
        my $mirror_ctx = $mirror_m_ctx->get_ctx_of()->{$step};
        if ($mirror_ctx->can('get_input_source_of')) {
            %{$mirror_ctx->get_input_source_of()} = (
                q{} => [map {abs2rel($_, $m_ctx->get_dest())} @{$sources_ref}],
            );
        }
        if (keys(%no_inherit_from)) {
            my @no_inherit_from_ns_list = sort keys(%no_inherit_from);
            push(
                @no_inherit_from_ns_list,
                _props($attrib_ref, 'no-inherit-source', $mirror_ctx),
            );
            my $prop_value = FCM::Context::Make::Share::Property::Value->new({
                value => join(
                    q{ },
                    map {s{['"\s]}{\\$1}gmsx; $_} @no_inherit_from_ns_list,
                ),
            });
            my $prop = FCM::Context::Make::Share::Property->new({
                id => 'no-inherit-source',
                ctx_of => {q{} => $prop_value},
            });
            $mirror_ctx->get_prop_of()->{'no-inherit-source'} = $prop;
        }
    }
    # Saves the configuration file
    my @lines = map {$_ . "\n"}
        $attrib_ref->{shared_util_of}{config}->unparse($mirror_m_ctx);
    my $DEST_UTIL = $attrib_ref->{shared_util_of}{dest};
    my $path = $DEST_UTIL->path(
        {   'dest' => $ctx->get_dest(),
            'name' => _prop($attrib_ref, 'config-file.name', $ctx),
        },
        'config',
    );
    $attrib_ref->{util}->file_save($path, \@lines);
    _mirror(
        $attrib_ref, $m_ctx, $ctx,
        [$path], $DEST_UTIL->path(
            {   'dest' => $target,
                'name' => _prop($attrib_ref, 'config-file.name', $ctx),
            },
            'config',
        ),
    );
}

# Creates mirror destination.
sub _mirror_mkdir {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    my ($target, $authority, $path) = _target_and_authority($ctx);
    eval {
        if ($authority) {
            my @ssh
                = (_shell_cmd_list($attrib_ref, 'ssh', $ctx), $authority);
            if (!file_name_is_absolute($path)) {
                my $value_hash_ref = _shell($attrib_ref, [@ssh, 'pwd']);
                my $path_root = $value_hash_ref->{'o'};
                chomp($path_root);
                $ctx->set_target_path(rel2abs($path, $path_root));
            }
            _shell($attrib_ref, [@ssh, 'mkdir', '-p', $path]);
        }
        else {
            if (!file_name_is_absolute($path)) {
                $ctx->set_target_path(rel2abs($path));
            }
            if (!-d $path) {
                mkpath($path);
            }
        }
    };
    if (my $e = $@) {
        return $E->throw($E->MIRROR_TARGET, $target, $e);
    }
    1;
}

# Mirror original configuration (by unparsing $m_ctx).
sub _mirror_orig_config_file {
    my ($attrib_ref, $m_ctx, $ctx) = @_;
    my @lines = (
        "# Original fcm make configuration.\n",
        sprintf("# Generated by %s@%s at %s.\n",
            scalar(getpwuid($<)),
            hostname(),
            strftime("%Y-%m-%dT%H:%M:%S%z", localtime()),
        ),
        map {$_ . "\n"} $attrib_ref->{shared_util_of}{config}->unparse($m_ctx),
    );
    my $DEST_UTIL = $attrib_ref->{shared_util_of}{dest};
    my $path = $DEST_UTIL->path(
        {   'dest' => $ctx->get_dest(),
            'name' => _prop($attrib_ref, 'config-file.name', $ctx),
        },
        'config-orig',
    );
    $attrib_ref->{util}->file_save($path, \@lines);
    my ($target) = _target_and_authority($ctx);
    _mirror(
        $attrib_ref, $m_ctx, $ctx,
        [$path],
        $DEST_UTIL->path(
            {   'dest' => $target,
                'name' => _prop($attrib_ref, 'config-file.name', $ctx),
            },
            'config-orig',
        ),
    );
}

# Mirrors.
sub _mirror {
    my ($attrib_ref, $m_ctx, $ctx, $sources_ref, $target) = @_;
    $target ||= (_target_and_authority($ctx))[0];
    $attrib_ref->{util}->event(
        FCM::Context::Event->MAKE_MIRROR, $target, @{$sources_ref},
    );
    eval {
        _shell(
            $attrib_ref,
            [   _shell_cmd_list($attrib_ref, 'rsync', $ctx),
                @{$sources_ref},
                $target,
            ],
        );
    };
    if (my $e = $@) {
        return $E->throw($E->MIRROR, [$target, @{$sources_ref}], $e);
    }
    1;
}

# Invokes a known shell command.
sub _shell {
    my ($attrib_ref, $command_list_ref) = @_;
    my $value_hash_ref = $attrib_ref->{util}->shell_simple($command_list_ref);
    if ($value_hash_ref->{rc}) {
        return $E->throw(
            $E->SHELL,
            {command_list => $command_list_ref, %{$value_hash_ref}},
            $value_hash_ref->{e},
        );
    }
    $value_hash_ref;
}

# Returns a shell command and its flags from a named property.
sub _shell_cmd_list {
    my ($attrib_ref, $id, $ctx) = @_;
    map {_props($attrib_ref, $_, $ctx)} ($id, $id . '.flags');
}

# Returns the authority and the target.
sub _target_and_authority {
    my ($ctx) = @_;
    my $logname = $ctx->get_target_logname();
    my $machine = $ctx->get_target_machine();
    my $path    = $ctx->get_target_path();
    my $authority
        = $logname && $machine ? $logname . '@' . $machine
        : $logname             ? $logname . '@' . 'localhost'
        : $machine             ?                  $machine
        :                        undef
        ;
    my $target = $authority ? $authority . ':' . $path : $path;
    ($target, $authority, $path);
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Mirror

=head1 SYNOPSIS

    use FCM::System::Make::Mirror;
    my $subsystem = FCM::System::Make::Mirror->new(\%attrib);
    $subsystem->main($m_ctx, $ctx);

=head1 DESCRIPTION

Implements the mirror sub-system. An instance of this class is expected to be
initialised and called by L<FCM::System::Make|FCM::System::Make>.

=head1 METHODS

See L<FCM::System::Make|FCM::System::Make> for detail.

=head1 ATTRIBUTES

The $class->new(\%attrib) method of this class supports the following
attributes:

=over 4

=item config_parser_of

A HASH to map the labels in a configuration file to their parsers. (default =
%FCM::System::Make::Mirror::CONFIG_PARSER_OF)

=item prop_of

A HASH to map the names of the properties to their settings. Each setting
is a 2-element ARRAY reference, where element [0] is the default setting
and element [1] is a flag to indicate whether the property accepts a name-space
or not. (default = %FCM::System::Make::Mirror::PROP_OF)

=item shared_util_of

See L<FCM::System::Make|FCM::System::Make> for detail.

=item util

See L<FCM::System::Make|FCM::System::Make> for detail.

=back

=head1 COPYRIGHT

Copyright (C) 2006-2019 British Crown (Met Office) & Contributors..

=cut
