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
package FCM::System::Make::Build::Task::Link;
use base qw{FCM::Class::CODE};

use FCM::Context::Event;
use FCM::System::Exception;
use FCM::System::Make::Build::Task::Archive;
use FCM::System::Make::Build::Task::Share qw{_props_to_opts};
use File::Basename qw{basename};
use File::Path qw{mkpath rmtree};
use File::Spec::Functions qw{abs2rel catfile};
use File::Temp qw{tempdir};
use List::Util qw{first};
use Text::ParseWords qw{shellwords};

my $E = 'FCM::System::Exception';

our %PROP_OF = (
    %FCM::System::Make::Build::Task::Archive::PROP_OF,
    'ld' => '',
    'keep-lib-o' => '',
);

__PACKAGE__->class(
    {name => '$', prop_of => '%', util => '&'},
    {action_of => {main => \&_main, prop_of => sub {$_[0]->{prop_of}}}},
);

sub _main {
    my ($attrib_ref, $target) = @_;
    my $NAME  = $attrib_ref->{name};
    my $P     = sub {$target->get_prop_of($_[0])};
    # Selects the correct dependent objects
    my @paths = @{$target->get_info_of('paths')};
    my %dep_keys_of = %{$target->get_info_of('deps')};
    my %paths_of = (o => [], 'o.special' => []);
    my $abs2rel_func
        = sub {index($_[0], $paths[0]) == 0 ? abs2rel($_[0], $paths[0]) : $_[0]};
    while (my ($type, $key_list_ref) = each(%dep_keys_of)) {
        for my $key (@{$key_list_ref}) {
            my $path = first {-e} map {catfile($_, 'o', $key)} @paths;
            if ($path) {
                push(@{$paths_of{$type}}, $abs2rel_func->($path));
            }
        }
    }
    my $path_of_main_o = shift(@{$paths_of{o}});
    my $keep_lib_o = $P->('keep-lib-o');
    my $lib_o_dir;
    if ($keep_lib_o) {
        $lib_o_dir = $target->CT_LIB;
        mkpath($lib_o_dir);
    }
    else {
        $lib_o_dir = tempdir(CLEANUP => 1);
    }
    my ($extension, $root)
        = $attrib_ref->{util}->file_ext(basename($target->get_key()));
    my $lib_o = catfile($lib_o_dir, "lib$root.a");
    my %opt_of = (
        o => $P->($NAME . '.flag-output'),
        L => $P->($NAME . '.flag-lib-path'),
        l => $P->($NAME . '.flag-lib'),
    );
    for my $command_list_ref (
        # Archive (when linking multiple objects)
        (   @{$paths_of{o}}
            ?   [   shellwords($P->('ar')),
                    shellwords($P->('ar.flags')),
                    $lib_o,
                    @{$paths_of{o}},
                ]
            :   ()
        ),
        # Link
        [   ($P->('ld') ? shellwords($P->('ld')) : shellwords($P->($NAME))),
            _props_to_opts($opt_of{o}, $abs2rel_func->($target->get_path())),
            $path_of_main_o,
            @{$paths_of{'o.special'}},
            (   @{$paths_of{o}}
                ?   (   _props_to_opts($opt_of{L}, $lib_o_dir),
                        _props_to_opts($opt_of{l}, $root),
                    )
                :   ()
            ),
            _props_to_opts($opt_of{L}, shellwords($P->($NAME .  '.lib-paths'))),
            _props_to_opts($opt_of{l}, shellwords($P->($NAME .  '.libs'))),
            shellwords($P->($NAME . '.flag-omp')),
            shellwords($P->($NAME . '.flags-ld')),
        ],
    ) {
        my %value_of = %{$attrib_ref->{util}->shell_simple($command_list_ref)};
        if ($value_of{rc}) {
            return $E->throw(
                $E->SHELL,
                {command_list => $command_list_ref, %value_of},
                $value_of{e},
            );
        }
        $attrib_ref->{util}->event(
            FCM::Context::Event->MAKE_BUILD_SHELL_OUT, @value_of{qw{o e}},
        );
    }
    if (!$keep_lib_o) {
        unlink($lib_o);
        rmtree($lib_o_dir);
    }
    $target;
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::Task::Link

=head1 SYNOPSIS

    use FCM::System::Make::Build::Task::Link;
    my $build_task = FCM::System::Make::Build::Task::Link->new(\%attrib);
    $build_task->main($target);

=head1 DESCRIPTION

Invokes the linker to create the target executable.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Creates and returns a new instance. %attrib should contain:

=over 4

=item {name}

The property name of the linker.

=item {prop_of}

A HASH to map the property names (used by this task) to their default values.

=item {util}

An instance of L<FCM::Util|FCM::Util>.

=back

=item $instance->main($target)

Invokes the linker to create the $target executable. It uses the
$target->get_info_of('deps')->{o} ARRAY and
$target->get_info_of('deps')->{"o.special"} ARRAY as dependencies. The first
type "o" dependency item is expected to be the object file containing the main
program. All other "o" dependency items are placed in a temporary archive
before invoking the linker command. The main object and "o.special" dependency
items are entered into the command line of the linker to produce the
executable.

=item $instance->prop_of()

Returns the HASH that maps the property names (used by this task) to their
default values.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
