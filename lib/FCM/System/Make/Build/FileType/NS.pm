#-------------------------------------------------------------------------------
# Copyright (C) British Crown (Met Office) & Contributors.
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

package FCM::System::Make::Build::FileType::NS;
use base qw{FCM::Class::CODE};

use FCM::Context::Make::Build;    # for FCM::Context::Make::Build::Target
use FCM::System::Make::Build::Task::Archive;
use FCM::System::Make::Build::Task::Install;
use File::Spec::Functions qw{catfile};

my $ID = '/';

my %TARGET_FILE_EXT_OF = (a => '.a', etc => '.etc');

my %TASK_CLASS_OF = (
    'archive' => 'FCM::System::Make::Build::Task::Archive',
    'install' => 'FCM::System::Make::Build::Task::Install',
);

# Creates the class.
__PACKAGE__->class(
    {   id                 => {isa => '$', default => $ID},
        target_file_ext_of => {isa => '%', default => {%TARGET_FILE_EXT_OF}},
        target_file_name_option_of => '%',
        task_class_of      => {isa => '%', default => {%TASK_CLASS_OF}},
        shared_util_of     => '%',
        task_of            => '%',
        util               => '&',
    },
    {   init => \&_init,
        action_of => {
            (map {my $key = $_; ($key => sub {$_[0]->{$key}})}
                qw{id target_file_ext_of target_file_name_option_of task_of}
            ),
            ns_targets_deps => sub {('o')},
            ns_targets      => \&_ns_targets,
        },
    },
);

# Initialises some attributes.
sub _init {
    my ($attrib_ref) = @_;
    while (my ($key, $class) = each(%{$attrib_ref->{task_class_of}})) {
        $attrib_ref->{util}->class_load($class);
        $attrib_ref->{task_of}{$key}
            = $class->new({util => $attrib_ref->{util}});
    }
}

# Returns a list of targets for a given build source.
sub _ns_targets {
    my ($attrib_ref, $targets_ref, $prop_hash_ref) = @_;
    my %target_of;
    TARGET:
    for my $target (@{$targets_ref}) {
        my @ns_targets;
        for (
            [sub {!$_[0]->get_type()}          , \&_ns_target_new_etc],
            [sub {$_[0]->get_category() eq 'o'}, \&_ns_target_new_lib],
        ) {
            my ($test, $new) = @{$_};
            if ($test->($target)) {
                my $ns_iter = $attrib_ref->{util}->ns_iter(
                    $target->get_ns(), $attrib_ref->{util}->NS_ITER_UP,
                );
                $ns_iter->(); # discard
                while (defined(my $ns = $ns_iter->())) {
                    my $ns_target = $new->($ns, $prop_hash_ref);
                    my $key = $ns_target->get_key();
                    if (!exists($target_of{$key})) {
                        $target_of{$key} = $ns_target;
                    }
                    push(
                        @{$target_of{$key}->get_deps()},
                        [$target->get_key(), $target->get_category()],
                    );
                }
                next TARGET;
            }
        }
    }
    values(%target_of);
}

# Returns a new etc target for building data files in a namespace.
sub _ns_target_new_etc {
    my ($ns, $prop_hash_ref) = @_;
    my $DOT_ETC = $prop_hash_ref->{etc};
    my $TARGET = 'FCM::Context::Make::Build::Target';
    $TARGET->new(
        {   category      => $TARGET->CT_ETC,
            dep_policy_of => {'etc' => $TARGET->POLICY_CAPTURE},
            key           => ($ns ? catfile($ns, $DOT_ETC) : $DOT_ETC),
            ns            => $ns,
            task          => 'install',
        }
    );
}

# Returns a new archive target for building an object library for a namespace.
sub _ns_target_new_lib {
    my ($ns, $prop_hash_ref) = @_;
    my $NAME = 'libo' . $prop_hash_ref->{a}; # FIXME: libo hard-coded
    my $TARGET = 'FCM::Context::Make::Build::Target';
    $TARGET->new(
        {   category      => $TARGET->CT_LIB,
            dep_policy_of => {'o' => $TARGET->POLICY_CAPTURE},
            info_of       => {paths => [], deps => {o => []}},
            key           => ($ns ? catfile($ns, $NAME) : $NAME),
            ns            => $ns,
            task          => 'archive',
        }
    );
}

#-------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::FileType::NS

=head1 SYNOPSIS

    use FCM::System::Make::Build::FileType::NS;
    my $file_type_util = FCM::System::Make::Build::FileType->new(\%attrib);
    $file_type_util->ns_targets($m_ctx, $ctx, @targets);

=head1 DESCRIPTION

Generates name space level targets.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Creates and returns a new instance.

=item $instance->id()

Returns the recommended ID of this file type.

=item $instance->ns_targets(\@targets,\%prop_of)

Using the information in the original list of targets, creates and returns the
contexts of a list of extra targets based on the name spaces of the original
list. In the current settings, a target with no type (i.e. a data file target)
will generate a C<.etc> target for the container name spaces; a target in the
C<o> category will generate a C<libo.a> target for the container name spaces.

=item $instance->ns_targets_deps()

Returns a list of dependency types used by
$instance->ns_targets(\@targets,\%prop_of).

=item $instance->target_file_ext_of()

Returns a HASH reference containing a map between the named types of file
extensions used by the $instance->ns_targets(\@targets,\%prop_of) method
and their default values.

=item $instance->target_file_name_option_of()

Returns a HASH reference containing a map between the named types of files
used by the $instance->source_to_targets($source,\%prop_of) method
and their default settings for other file naming options.

=item $instance->task_of()

Returns a HASH reference containing a map between the named tasks for this file
type and their implementation objects. Each task should have a
$task->main($target) method to update a target and optionally a $task->prop_of()
method to return a HASH reference containing a map between the named properties
used by the task and their default values.

=back

=head1 TODO

The configuration in this module is a bit hard coded. It can do with a refactor.

=head1 COPYRIGHT

Copyright (C) British Crown (Met Office) & Contributors..

=cut
