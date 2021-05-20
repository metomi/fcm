# ------------------------------------------------------------------------------
# Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.
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
package FCM::System::Make::Build::Task::Archive;
use base qw{FCM::Class::CODE};

use FCM::Context::Event;
use FCM::System::Exception;
use File::Spec::Functions qw{abs2rel catfile};
use List::Util qw{first};
use Text::ParseWords qw{shellwords};

our %PROP_OF = (ar => 'ar', 'ar.flags' => 'rs');
my $E = 'FCM::System::Exception';

__PACKAGE__->class(
    {prop_of => {isa => '%', default => {%PROP_OF}}, util => '&'},
    {action_of => {main => \&_main, prop_of => sub {\%PROP_OF}}},
);

sub _main {
    my ($attrib_ref, $target) = @_;
    # Selects the correct dependent objects
    my @paths = @{$target->get_info_of('paths')};
    my %dep_keys_of = %{$target->get_info_of('deps')};
    my @paths_of_o = ();
    my $abs2rel_func
        = sub {index($_[0], $paths[0]) == 0 ? abs2rel($_[0], $paths[0]) : $_[0]};
    while (my ($type, $key_list_ref) = each(%dep_keys_of)) {
        for my $key (@{$key_list_ref}) {
            my $path = first {-e} map {catfile($_, 'o', $key)} @paths;
            if ($path) {
                push(@paths_of_o, $abs2rel_func->($path));
            }
        }
    }
    my @command_list = (
        (map {shellwords($target->get_prop_of($_))} qw{ar ar.flags}),
        $target->get_path(),
        @paths_of_o,
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

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::Task::Archive

=head1 SYNOPSIS

    use FCM::System::Make::Build::Task::Archive;
    my $build_task = FCM::System::Make::Build::Task::Archive->new(\%attrib);
    $build_task->main($target);

=head1 DESCRIPTION

Invokes the archive to create the target archive library.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Creates and returns a new instance. %attrib should contain:

=over 4

=item {prop_of}

A HASH that maps the property names (used by this task) to their default values.

=item {util}

An instance of L<FCM::Util|FCM::Util>.

=back

=item $instance->main($target)

Invokes the "ar" command to create the $target object archive. It uses the
$target->get_info_of('deps')->{o} ARRAY. All "o" dependency items are placed in
the archive.

=item $instance->prop_of()

Returns the HASH that maps the property names (used by this task) to their
default values.

=back

=head1 CONSTANTS

=item %FCM::System::Make::Build::Task::Archive::PROP_OF

A map containing the property names and their default values.

=head1 COPYRIGHT

Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.

=cut
