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
#-------------------------------------------------------------------------------

package FCM::System::Make::Share::Config;
use base qw{FCM::Class::CODE};

use FCM::Context::ConfigEntry;
use FCM::Context::Locator;
use FCM::System::Exception;
use File::Temp;
use Scalar::Util qw{blessed};

# Alias to class name
my $E = 'FCM::System::Exception';

# Configuration parser label to action map
my %CONFIG_PARSER_OF = (
    'dest'       => \&_parse_dest,
    'use'        => \&_parse_use,
    'step.class' => \&_parse_step_class,
    'steps'      => \&_parse_steps,
);

__PACKAGE__->class(
    {shared_util_of => '%', subsystem_of => '%', util => '&'},
    {action_of => {parse => \&_parse, unparse => \&_unparse}},
);

# Get configuration file entries from an iterator, and use the entries to
# populate the context of the current make.
sub _parse {
    my ($attrib_ref, $entry_callback_ref, $m_ctx, @args) = @_;
    my $path = $m_ctx->get_option_of('config-file');
    if (!defined($path)) {
        my $dir = $m_ctx->get_option_of('directory');
        $path = $attrib_ref->{shared_util_of}{dest}->path($dir, 'config');
    }
    my $locator = FCM::Context::Locator->new($path);
    my $config_reader_ref = $attrib_ref->{util}->config_reader(
        $locator, {event_level => $attrib_ref->{util}->util_of_report()->LOW},
    );
    my ($args_config_handle, $args_config_reader_ref);
    if (@args) {
        $args_config_handle = File::Temp->new();
        for my $arg (@args) {
            print($args_config_handle "$arg\n");
        }
        $args_config_handle->seek(0, 0);
        my $locator = FCM::Context::Locator->new($args_config_handle->filename());
        $args_config_reader_ref = $attrib_ref->{util}->config_reader(
            FCM::Context::Locator->new($args_config_handle->filename()),
            {event_level => $attrib_ref->{util}->util_of_report()->LOW},
        );
    }
    my $entry_iter_ref = sub {
        my $entry;
        if (defined($config_reader_ref)) {
            $entry = $config_reader_ref->();
            if (!defined($entry)) {
                $config_reader_ref = undef;
            }
        }
        if (!defined($entry) && defined($args_config_reader_ref)) {
            $entry = $args_config_reader_ref->();
            if (!defined($entry)) {
                $args_config_reader_ref = undef;
            }
        }
        $entry;
    };
    my @unknown_entries;
    while (defined(my $entry = $entry_iter_ref->())) {
        if (defined($entry_callback_ref)) {
            $entry_callback_ref->($entry);
        }
        if (exists($CONFIG_PARSER_OF{$entry->get_label()})) {
            $CONFIG_PARSER_OF{$entry->get_label()}->(
                $attrib_ref, $m_ctx, $entry,
            );
        }
        else {
            my ($id, $label) = split(qr{\.}msx, $entry->get_label(), 2);
            if (    $label eq 'prop'
                &&  exists($entry->get_modifier_of()->{'class'})
                &&  exists($attrib_ref->{subsystem_of}{$id})
            ) {
                my $subsystem = $attrib_ref->{subsystem_of}{$id};
                if (!$subsystem->config_parse_class_prop($entry, $label)) {
                    push(@unknown_entries, $entry);
                }
            }
            else {
                my $ctx = $m_ctx->get_ctx_of($id);
                if (    !defined($ctx)
                    &&  exists($attrib_ref->{subsystem_of}{$id})
                ) {
                    $ctx = $attrib_ref->{subsystem_of}{$id}->ctx($id, $id);
                    $m_ctx->get_ctx_of()->{$id} = $ctx;
                }
                my $rc;
                if (defined($ctx)) {
                    my $id_of_class = $ctx->get_id_of_class();
                    my $subsystem = $attrib_ref->{subsystem_of}{$id_of_class};
                    $rc = $subsystem->config_parse($ctx, $entry, $label);
                }
                if (!$rc) {
                    push(@unknown_entries, $entry);
                }
            }
        }
    }
    if (@unknown_entries) {
        return $E->throw($E->CONFIG_UNKNOWN, \@unknown_entries);
    }
    $m_ctx;
}

# Reads the dest declaration.
sub _parse_dest {
    my ($attrib_ref, $m_ctx, $entry) = @_;
    $m_ctx->set_dest($entry->get_value());
}

# Reads the step.class declaration from a config entry.
sub _parse_step_class {
    my ($attrib_ref, $m_ctx, $entry) = @_;
    my $id_of_class = $entry->get_value();
    if (!exists($attrib_ref->{subsystem_of}{$id_of_class})) {
        return $E->throw($E->CONFIG_VALUE, $entry);
    }
    my $subsystem = $attrib_ref->{subsystem_of}{$id_of_class};
    for my $id (@{$entry->get_ns_list()}) {
        if (!defined($m_ctx->get_ctx_of($id))) {
            $m_ctx->get_ctx_of()->{$id} = $subsystem->ctx($id_of_class, $id);
        }
    }
}

# Reads the steps declaration from a config entry.
sub _parse_steps {
    my ($attrib_ref, $m_ctx, $entry) = @_;
    my @steps = $entry->get_values();
    $m_ctx->set_steps(\@steps);
    for my $id (@steps) {
        if (!defined($m_ctx->get_ctx_of($id))) {
            if (!exists($attrib_ref->{subsystem_of}{$id})) {
                return $E->throw($E->CONFIG_VALUE, $entry);
            }
            my $subsystem = $attrib_ref->{subsystem_of}{$id};
            $m_ctx->get_ctx_of()->{$id} = $subsystem->ctx($id, $id);
        }
    }
}

# Reads the use declaration.
sub _parse_use {
    my ($attrib_ref, $m_ctx, $entry) = @_;
    my $DEST = $attrib_ref->{shared_util_of}{dest};
    my $inherit_ctx_list_ref = $m_ctx->get_inherit_ctx_list();
    for my $value ($entry->get_values()) {
        $value =~ s{\A~([^/]*)}{$1 ? (getpwnam($1))[7] : (getpwuid($<))[7]}exms;
        my $i_m_ctx = eval {
            $DEST->ctx_load(
                $DEST->path($value, 'sys-ctx'),
                blessed($m_ctx),
            );
        };
        if (!defined($i_m_ctx) && (my $e = $@)) {
            return $E->throw($E->CONFIG_VALUE, $entry, $e);
        }
        if ($i_m_ctx->get_status() != $i_m_ctx->ST_OK) {
            return $E->throw($E->CONFIG_INHERIT, $entry);
        }
        push(@{$m_ctx->get_inherit_ctx_list()}, $i_m_ctx);
        while (my ($id, $i_ctx) = each(%{$i_m_ctx->get_ctx_of()})) {
            my $id_of_class = $i_ctx->get_id_of_class();
            if (exists($attrib_ref->{subsystem_of}{$id_of_class})) {
                my $subsystem = $attrib_ref->{subsystem_of}{$id_of_class};
                if (!defined($m_ctx->get_ctx_of($id))) {
                    $m_ctx->get_ctx_of()->{$id}
                        = $subsystem->ctx($id_of_class, $id);
                }
                if ($subsystem->can('config_parse_inherit_hook')) {
                    $subsystem->config_parse_inherit_hook(
                        $m_ctx->get_ctx_of($id), $i_ctx,
                    );
                }
            }
        }
        if (!@{$m_ctx->get_steps()}) {
            $m_ctx->set_steps([@{$i_m_ctx->get_steps()}]);
        }
    }
}

# Turns the context back into a config.
sub _unparse {
    my ($attrib_ref, $m_ctx) = @_;
    my %subsystem_of = map {
        my $id = $m_ctx->get_ctx_of()->{$_}->get_id_of_class();
        ($id, $attrib_ref->{subsystem_of}->{$id});
    } @{$m_ctx->get_steps()};
    map {$_->as_string()} (
        (   map {   FCM::Context::ConfigEntry->new({
                        label   => 'step.class',
                        ns_list => [$_->get_id()],
                        value   => $_->get_id_of_class(),
                    });
                }
            grep {$_->get_id() ne $_->get_id_of_class()}
            values(%{$m_ctx->get_ctx_of()})
        ),
        (   map {   my ($action_ref, $label) = @{$_};
                    my $value = $action_ref->($attrib_ref, $m_ctx);
                    defined($value)
                        ? FCM::Context::ConfigEntry->new(
                            {label => $label, value => $value},
                        )
                        : ()
                    ;
                }
            (   [\&_unparse_use     , 'use'  ],
                [\&_unparse_steps   , 'steps'],
                [sub {$m_ctx->get_dest()}, 'dest' ],
            ),
        ),
        (   map {   my $id = $_;
                    $subsystem_of{$id}->config_unparse_class_prop($id);
            }
            sort keys(%subsystem_of)
        ),
        (   map {   my $ctx = $m_ctx->get_ctx_of()->{$_};
                    my $id_of_class = $ctx->get_id_of_class();
                    $subsystem_of{$id_of_class}->config_unparse($ctx);
                }
            @{$m_ctx->get_steps()}
        ),
    );
}

# Serializes a list of words.
sub _unparse_join {
    join(q{ }, map {s{(["'\s])}{\\$1}xms; $_} grep {defined()} @_);
}

# The value of "steps" declaration from the context.
sub _unparse_steps {
    my ($attrib_ref, $m_ctx) = @_;
    if (!@{$m_ctx->get_steps()}) {
        return;
    }
    _unparse_join(@{$m_ctx->get_steps()});
}

# The value of "use" declaration from the context.
sub _unparse_use {
    my ($attrib_ref, $m_ctx) = @_;
    if (!@{$m_ctx->get_inherit_ctx_list()}) {
        return;
    }
    my @i_ctx_list = @{$m_ctx->get_inherit_ctx_list()};
    _unparse_join(map {$_->get_dest()} @i_ctx_list);
}

#-------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Share::Config

=head1 SYNOPSIS

    use FCM::System::Make::Share::Config;
    my $instance = FCM::System::Make::Share::Config->new(\%attrib);
    my $ok = $instance->parse($m_ctx, $entry_iter_ref);
    my @entries = $instance->unparse($m_ctx);

=head1 DESCRIPTION

A helper class for (un)parsing make config entries into the make context.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Returns a new instance. The allowed elements for %attrib are:

=over 4

=item {shared_util_of}{dest}

A helper object for manipulating the destination in a make context. Expects an
instance of L<FCM::System::Make::Share::Dest|FCM::System::Make::Share::Dest>.

=back

=item $instance->parse($m_ctx, $entry_iter_ref)

Parses entries returned by the $entry_iter_ref iterator into the $m_ctx.
Throws a variety of L<FCM::System::Exception|FCM::System::Exception> if some
data in the configuration file is incorrectly set.

=item $instance->unparse($m_ctx)

Turns $m_ctx back into a list of configuration entries.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
