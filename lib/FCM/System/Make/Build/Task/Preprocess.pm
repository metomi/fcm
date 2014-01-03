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
package FCM::System::Make::Build::Task::Preprocess;
use base qw{FCM::Class::CODE};

use FCM::Context::Event;
use FCM::System::Exception;
use FCM::System::Make::Build::Task::Share qw{_props_to_opts};
use File::Spec::Functions qw{catfile};
use Text::ParseWords qw{shellwords};

use FCM::System::Exception;

my $E = 'FCM::System::Exception';

__PACKAGE__->class(
    {name => '$', prop_of => '%', util => '&'},
    {action_of => {main => \&_main, prop_of => sub {$_[0]->{prop_of}}}},
);

sub _main {
    my ($attrib_ref, $target) = @_;
    my $NAME = $attrib_ref->{name};
    my $P     = sub {$target->get_prop_of($_[0])};
    my @paths = @{$target->get_info_of('paths')};
    my @include_paths
        = map {catfile(($_ eq $paths[0] ? q{.} : $_), 'include')} @paths;
    my %opt_of = (
        D => $P->($NAME . '.flag-define'),
        I => $P->($NAME . '.flag-include'),
    );
    my @command = (
        shellwords($P->($NAME)),
        shellwords($P->($NAME . '.flags')),
        _props_to_opts($opt_of{D}, shellwords($P->($NAME .  '.defs'))),
        _props_to_opts($opt_of{I}, @include_paths),
        _props_to_opts($opt_of{I}, shellwords($P->($NAME .  '.include-paths'))),
        $target->get_path_of_source(),
    );
    my %value_of = %{$attrib_ref->{util}->shell_simple(\@command)};
    if ($value_of{rc}) {
        return $E->throw(
            $E->SHELL, {command_list => \@command, %value_of}, $value_of{e},
        );
    }
    $attrib_ref->{util}->event(
        FCM::Context::Event->MAKE_BUILD_SHELL_OUT, undef, $value_of{e},
    );
    $value_of{o} ||= q{};
    $attrib_ref->{util}->file_save($target->get_path(), $value_of{o});
    $target;
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::Task::Preprocess

=head1 SYNOPSIS

    use FCM::System::Make::Build::Task::Preprocess;
    my $build_task = FCM::System::Make::Build::Task::Preprocess->new(\%attrib);
    $build_task->main($target);

=head1 DESCRIPTION

Invokes the preprocessor on the target source to generate the target.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Creates and returns a new instance. %attrib should contain:

=over 4

=item {name}

The property name of the preprocessor.

=item {prop_of}

A HASH to map the property names and their default values.

=item {util}

An instance of L<FCM::Util|FCM::Util>.

=back

=item $instance->main($target)

Invokes the preprocessor shell command on the target source to generate the
target.

=item $instance->prop_of()

Returns the HASH that maps the property names (used by this task) to their
default values.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
