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

use FCM::System::Exception;
my $E = 'FCM::System::Exception';

# ------------------------------------------------------------------------------
package FCM::System::Make::Build::Task::Compile;
use base qw{FCM::Class::CODE};

use FCM::Context::Event;
use FCM::System::Make::Build::Task::Share qw{_props_to_opts};
use File::Spec::Functions qw{abs2rel catfile};
use Text::ParseWords qw{shellwords};

__PACKAGE__->class(
    {name => '$', prop_of => '&', util => '&'},
    {action_of => {main => \&_main, prop_of => \&_prop_of}},
);

sub _main {
    my ($attrib_ref, $target) = @_;
    my $NAME  = $attrib_ref->{name};
    my $P     = sub {scalar($target->get_prop_of($_[0]))};
    my @paths = @{$target->get_info_of('paths')};
    my $abs2rel_func
        = sub {index($_[0], $paths[0]) == 0 ? abs2rel($_[0], $paths[0]) : $_[0]};
    my @include_paths
        = map {catfile(($_ eq $paths[0] ? q{.} : $_), 'include')} @paths;
    my %opt_of = (
        c   => $P->($NAME . '.flag-compile'),
        D   => $P->($NAME . '.flag-define'),
        I   => $P->($NAME . '.flag-include'),
        M   => $P->($NAME . '.flag-module'),    # FIXME
        o   => $P->($NAME . '.flag-output'),
    );
    my @command_list = (
        shellwords($P->($NAME)),
        _props_to_opts($opt_of{o}, $abs2rel_func->($target->get_path())),
        $opt_of{c},
        _props_to_opts($opt_of{D}, shellwords($P->($NAME .  '.defs'))),
        _props_to_opts($opt_of{I}, @include_paths),
        _props_to_opts($opt_of{I}, shellwords($P->($NAME .  '.include-paths'))),
        _props_to_opts($opt_of{M}, @include_paths),
        shellwords($P->($NAME . '.flag-omp')),
        shellwords($P->($NAME . '.flags')),
        $target->get_path_of_source(),
    );
    my %value_of = %{$attrib_ref->{util}->shell_simple(\@command_list)};
    if ($value_of{rc}) {
        return $E->throw(
            $E->SHELL, {command_list => \@command_list, %value_of}, $value_of{e},
        );
    }
    $attrib_ref->{util}->event(
        FCM::Context::Event->MAKE_BUILD_SHELL_OUT, @value_of{qw{o e}},
    );
    $target;
}

sub _prop_of {
    my ($attrib_ref) = @_;
    $attrib_ref->{prop_of}->(@_);
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::Task::Compile

=head1 SYNOPSIS

    use FCM::System::Make::Build::Task::Compile;
    my $build_task = FCM::System::Make::Build::Task::Compile->new(\%attrib);
    $build_task->main($target);

=head1 DESCRIPTION

Invokes the compiler command on the source of a target to generate the path of
the target.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Creates and returns a new instance. %attrib should contain:

=over 4

=item {name}

The property name of the compiler command.

=item {prop_of}

A CODE to implement the $instance->prop_of($target) method.

=item {util}

An instance of L<FCM::Util|FCM::Util>.

=back

=item $instance->main($target)

Invokes the compiler command in a shell to compile the source path of the
$target into an object file in the path of the $target.

=item $instance->prop_of($target)

Returns the HASH that maps the property names (used by this task) to their
default values.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
