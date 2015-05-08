# ------------------------------------------------------------------------------
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
# ------------------------------------------------------------------------------
use strict;
use warnings;

# ------------------------------------------------------------------------------
package FCM::System::Make::Share::Dest;
use base qw{FCM::Class::CODE};

use Cwd qw{cwd};
use FCM::Context::Event;
use FCM::System::Exception;
use File::Basename qw{dirname};
use File::Path qw{mkpath rmtree};
use File::Spec::Functions qw{catfile rel2abs};
use IO::File;
use IO::Uncompress::Gunzip qw{gunzip};
use IO::Compress::Gzip qw{gzip};
use Scalar::Util qw{blessed reftype};
use Storable qw{fd_retrieve nstore_fd};
use Sys::Hostname qw{hostname};

# The relative paths for locating files in a destination
our %PATH_OF = (
    'config'                        => 'fcm-make%s.cfg',
    'config-orig'                   => 'fcm-make%s.cfg.orig',
    'sys'                           => '.fcm-make%s',
    'sys-cache'                     => '.fcm-make%s/cache',
    'sys-config-as-parsed'          => '.fcm-make%s/config-as-parsed.cfg',
    'sys-config-as-parsed-symlink'  => 'fcm-make%s-as-parsed.cfg',
    'sys-config-on-success'         => '.fcm-make%s/config-on-success.cfg',
    'sys-config-on-success-symlink' => 'fcm-make%s-on-success.cfg',
    'sys-ctx-uncompressed'          => '.fcm-make%s/ctx',
    'sys-ctx'                       => '.fcm-make%s/ctx.gz',
    'sys-log'                       => '.fcm-make%s/log',
    'sys-log-symlink'               => 'fcm-make%s.log',
    'sys-lock'                      => 'fcm-make%s.lock',
    'sys-lock-info'                 => 'fcm-make%s.lock/info.txt',
    'target'                        => '',
);

# Aliases to exception classes
my $E = 'FCM::System::Exception';
# List of actions
my %ACTION_OF = (
    ctx_load  => \&_ctx_load,
    dest_done => \&_dest_done,
    dest_init => \&_dest_init,
    path      => \&_path,
    paths     => \&_paths,
    path_of   => sub {$_[0]->{'path_of'}{$_[1]}},
    save      => \&_save,
    tidy      => \&_tidy,
);

# Creates the class.
__PACKAGE__->class(
    {   path_of        => {isa => '%', default => {%PATH_OF}},
        shared_util_of => '%',
        subsystem_of   => '%',
        util           => '&',
    },
    {action_of => \%ACTION_OF},
);

# Loads a storable context from a path.
sub _ctx_load {
    my ($attrib_ref, $m_ctx, $from) = @_;
    my $path;
    my $dest;
    if ($from) {
        NAME:
        for my $name ($m_ctx->get_name(), undef) {
            $path = _path(
                $attrib_ref, {'dest' => $from, 'name' => $name}, 'sys-ctx');

            if (-f $path) {
                $dest = $from;
                last NAME;
            }
        }
    }
    else {
        $path = _path($attrib_ref, $m_ctx, 'sys-ctx');
        $dest = $m_ctx->get_dest();
    }
    my $old_m_ctx = eval {
        my $handle = IO::File->new_tmpfile();
        gunzip($path, $handle) || die($!);
        $handle->seek(0, 0);
        fd_retrieve($handle);
    };
    if (my $e = $@) {
        return $E->throw($E->CACHE_LOAD, $path, $e);
    }
    if (    !$old_m_ctx
        ||  !$old_m_ctx->isa(blessed($m_ctx))
        ||  (       defined($old_m_ctx->get_name())
                &&  $old_m_ctx->get_name() ne $m_ctx->get_name()
            )
    ) {
        return $E->throw($E->CACHE_TYPE, $path);
    }
    my $new_m_dest = rel2abs($dest);
    if ($new_m_dest ne $old_m_ctx->get_dest()) {
        my $old_m_dest = $old_m_ctx->get_dest();
        $old_m_ctx->set_dest($new_m_dest);
        $old_m_ctx->set_dest_lock(undef);
        SUBSYSTEM:
        while (my ($id, $old_ctx) = each(%{$old_m_ctx->get_ctx_of()})) {
            my $id_of_class = $old_ctx->get_id_of_class();
            if (exists($attrib_ref->{'subsystem_of'}{$id_of_class})) {
                my $subsystem = $attrib_ref->{'subsystem_of'}{$id_of_class};
                if (!$old_ctx->can('set_dest')) {
                    next SUBSYSTEM;
                }
                my $old_dest = $old_ctx->get_dest();
                $old_ctx->set_dest(_path(
                    $attrib_ref,
                    {'dest' => $new_m_dest, 'name' => $m_ctx->get_name()},
                    'target',
                    $old_ctx->get_id(),
                ));
                if ($subsystem->can('ctx_load_hook')) {
                    $subsystem->ctx_load_hook(
                        $old_m_ctx, $old_ctx, $old_m_dest, $old_dest);
                }
            }
        }
    }
    return $old_m_ctx;
}

# Finalises the destination of a make context.
sub _dest_done {
    my ($attrib_ref, $m_ctx) = @_;
    if (!$m_ctx->get_dest()) {
        return;
    }
    my $dest = _path($attrib_ref, $m_ctx, 'sys-ctx-uncompressed');
    my $dest_parent = dirname($dest);
    my $dest_lock = $m_ctx->get_dest_lock();
    $m_ctx->set_dest_lock(undef);
    if (-d $dest_parent) {
        eval {
            my $handle = IO::File->new_tmpfile();
            nstore_fd($m_ctx, $handle) || die($!);
            $handle->seek(0, 0) || die($!);
            gzip($handle, _path($attrib_ref, $m_ctx, 'sys-ctx')) || die($!);
        };
        if (my $e = $@) {
            return $E->throw($E->DEST_CREATE, $dest, $e);
        }
    }
    my %ctx_of = %{$m_ctx->get_ctx_of()};
    for my $path (
        _path($attrib_ref, $m_ctx, 'sys'),
        (map {_path($attrib_ref, $m_ctx, 'target', $_)} keys(%ctx_of)),
    ) {
        _tidy($attrib_ref, $path);
    }
    if ($dest_lock) {
        rmtree($dest_lock);
    }
}

# Initialises the destination of a make context.
sub _dest_init {
    my ($attrib_ref, $m_ctx) = @_;
    my %OPTION_OF = %{$m_ctx->get_option_of()};
    # Select destination
    my $dest
        = $OPTION_OF{directory} ? $OPTION_OF{directory}
        : $m_ctx->get_dest()    ? $m_ctx->get_dest()
        :                         cwd()
        ;
    $m_ctx->set_dest(rel2abs($dest));
    # Check lock
    my $lock = _path($attrib_ref, $m_ctx, 'sys-lock');
    if (!$OPTION_OF{'ignore-lock'} && -e $lock) {
        return $E->throw($E->DEST_LOCKED, $lock);
    }
    # Creates the lock (and the destination), if necessary
    if (!-e $lock) {
        eval {mkpath($lock)};
        if (my $e = $@) {
            return $E->throw($E->DEST_CREATE, $lock, $e);
        }
        my $lock_info = scalar(getpwuid($<)) . '@' . hostname() .  ':' . $$;
        _save($attrib_ref, $lock_info, $m_ctx, 'sys-lock-info');
    }
    $m_ctx->set_dest_lock($lock);
    # Cleans items created by previous make, if necessary
    for my $path (
        _path($attrib_ref, $m_ctx, 'sys-config-as-parsed-symlink'),
        _path($attrib_ref, $m_ctx, 'sys-config-on-success-symlink'),
        _path($attrib_ref, $m_ctx, 'sys-config-on-success'),
        _path($attrib_ref, $m_ctx, 'sys-log-symlink'),
    ) {
        eval {rmtree($path)};
        if (my $e = $@) {
            return $E->throw($E->DEST_CLEAN, $path, $e);
        }
    }
    if ($OPTION_OF{new}) {
        my @steps = @{$m_ctx->get_steps()};
        for my $path (
            _path($attrib_ref, $m_ctx, 'sys'),
            (map {_path($attrib_ref, $m_ctx, 'target', $_)} @steps),
        ) {
            eval {rmtree($path)};
            if (my $e = $@) {
                return $E->throw($E->DEST_CLEAN, $path, $e);
            }
        }
    }
    # Loads context of previous make, if possible
    my $prev_m_ctx = eval {_ctx_load($attrib_ref, $m_ctx)};
    if (my $e = $@) {
        if (    !$E->caught($e)
            ||  !grep {$_ eq $e->get_code()} ($E->CACHE_LOAD, $E->CACHE_TYPE)
        ) {
            die($e);
        }
        $@ = undef;
    }
    if (defined($prev_m_ctx)) {
        $m_ctx->set_prev_ctx($prev_m_ctx);
    }
    else {
        # Creates the system directory
        my $sys_dir_path = _path($attrib_ref, $m_ctx, 'sys');
        eval {mkpath($sys_dir_path)};
        if (my $e = $@) {
            return $E->throw($E->DEST_CREATE, $sys_dir_path, $e);
        }
    }
    # Diagnostic
    $attrib_ref->{util}->event(
        FCM::Context::Event->MAKE_DEST,
        $m_ctx, join('@', scalar(getpwuid($<)), hostname()),
    );
    1;
}

# Returns the path of a named item relative to the context destination.
sub _path {
    my ($attrib_ref, $m_ctx, $key, @paths) = @_;
    my %ctx = reftype($m_ctx) && reftype($m_ctx) eq 'HASH'
        ? %{$m_ctx} : ('dest' => $m_ctx, 'name' => q{});
    $ctx{'dest'} ||= q{};
    $ctx{'name'} ||= q{};
    catfile(
        ($ctx{'dest'} ? $ctx{'dest'} : ()),
        split(q{/}, sprintf($attrib_ref->{path_of}{$key}, $ctx{'name'})),
        @paths,
    );
}

# Returns an ARRAY reference containing the search paths of a named item
# relative to the destinations of the context and its inherited contexts.
sub _paths {
    my ($attrib_ref, $m_ctx, $key, @paths) = @_;
    my @dests;
    my @ctx_list = ($m_ctx);
    # Adds destinations from inherited contexts recursively
    # Note: if A inherits from B and C, B from B1 and B2, and C from C1 and C2,
    #       the search path will be A, C, C2, C1, B, B2, B1.
    while (my $current_ctx = pop(@ctx_list)) {
        push(@ctx_list, @{$current_ctx->get_inherit_ctx_list()});
        push(@dests, _path($attrib_ref, $current_ctx, $key, @paths));
    }
    return \@dests;
}

# Saves $item in a path given by _path($attrib_ref, $m_ctx, $key, @paths).
sub _save {
    my ($attrib_ref, $item, $m_ctx, $key, @paths) = @_;
    my $path = _path($attrib_ref, $m_ctx, $key, @paths);
    my @contents
        = (ref($item) && ref($item) eq 'ARRAY') ? (map {$_ . "\n"} @{$item})
        :                                         ($item . "\n")
        ;
    $attrib_ref->{util}->file_save($path, \@contents);
}

# Removes empty directories in a tree.
sub _tidy {
    my ($attrib_ref, @paths) = @_;
    # Selects only directories which are not symbolic links
    my @items = map {[$_, undef, undef]} grep {-d && !-l} @paths;
    while (my $item = pop(@items)) {
        my ($path, $n_children_ref, $n_siblings_ref) = @{$item};
        if (!defined($n_children_ref)) {
            opendir(my $handle, $path)
                || return $E->throw($E->DEST_CLEAN, $path, $!);
            my @children = grep {$_ ne q{.} && $_ ne q{..}} (readdir($handle));
            closedir($handle);
            $n_children_ref = \scalar(@children);
            if (@children) {
                # Descends into directories
                my @sub_dirs
                    = grep {-d && !-l} map {catfile($path, $_)} @children;
                if (@sub_dirs == @children) {
                    # If all children are directories, it may be possible to
                    # remove this directory later if all children are empty
                    push(@items, [$path, $n_children_ref, $n_siblings_ref]);
                }
                push(@items, (map {[$_, undef, $n_children_ref]} @sub_dirs));
            }
        }
        if (!${$n_children_ref}) { # i.e. directory is empty
            rmdir($path) || return $E->throw($E->DEST_CLEAN, $path, $!);
            if (defined($n_siblings_ref)) {
                --${$n_siblings_ref};
            }
        }
    }
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Share::Dest

=head1 SYNOPSIS

    use FCM::System::Make::Share::Dest;
    my $helper = FCM::System::Make::Share::Dest->new(\%attrib);
    my $ctx = $helper->ctx_load($path, $expected_class);
    my $path = $helper->path($m_ctx, $key);
    # ...

=head1 DESCRIPTION

A helper class for manipulating the destination of a context in a FCM make
sub-system, e.g. extract.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Returns a new instance. The %attrib should contain the following:

=over 4

=item dest_items

An ARRAY containing the names of the items that can be created at the context
destination.

=item path_of

A HASH to map the (keys) names of the items and (values) their relative paths
(as ARRAY) in a context destination.

=back

=item $instance->ctx_load($path,$expected_class)

Loads a storable context from $path and returns the context. The $expected_class
is the expected class of the loaded context. The method die() if it fails to
load the context or if the loaded context does not belong to the expected class.

=item $instance->dest_done($ctx)

Finalises the destination of $ctx by freezing the $ctx in the system directory,
removing the lock file, and tidying up any empty directories created by the
system.

=item $instance->dest_init($ctx)

Initialises the destination of $ctx by checking for a lock directory in the
destination, creating a lock if possible, cleaning up items created by the
previous make of the system if necessary, and setting up the system directory.

=item $instance->path($ctx,$key,@paths)

Returns the path of a named item ($key) relative to $ctx, which can either be a
HASH reference with {'dest' => $dest, 'name' => $name}, or a scalar path
pointing to $dest, where $dest is the root of the path and $name is the name of
the context. If @paths are specified, they are concatenated at the end
of the path.

=item $instance->paths($ctx,$key,@paths)

Returns an ARRAY reference containing the search paths of a named item ($key)
relative to the destinations of $ctx and its inherited contexts. If @paths are
specified, they are concatenated at the end of each returned path.

=item $instance->path_of($key)

Returns the template value of the named item in a make destination.

=item $instance->save($item,$ctx,$key,@paths)

Saves $item in a path given by $instance->path($ctx,$key,@paths). $item can be a
string or a reference to an ARRAY of strings. A "\n" is added to the end of each
string.

=item $instance->tidy(@paths)

Recursively removes empty directories in @paths.

=back

=head1 CONSTANTS

=over 4

=item %FCM::System::Make::PATH_OF

A HASH containing the default values of named paths in a make destination. The
following keys are used by the system:

=over 4

=item config

The standard path to the configuration file.

=item sys

The path to the system directory.

=item sys-cache

The path to the system cache directory.

=item sys-config-as-parsed

The path to the as-parsed configuration file.

=item sys-config-on-success

The path to the on-success configuration file.

=item sys-ctx

The path to the frozen make context (for retrieval by incremental makes).

=item sys-ctx-uncompressed

The path to the uncompressed form of sys-ctx.

=item sys-lock

The path to the lock directory.

=item sys-lock-info

The path to the lock info file.

=item target

The target destination of a make.

=back

=back

=head1 DIAGNOSTICS

=head2 FCM::System::Exception

The methods of this class throws this exception on errors.

=head1 TODO

Time-stamp the as-parsed and the on-success configuration files.

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
