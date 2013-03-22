#-------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-2013 Met Office.
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

package FCM::Context::Event;
use base qw{FCM::Class::HASH};

use constant {
    CM_ABORT                      => 'CM_ABORT',
    CM_BRANCH_CREATE_SOURCE       => 'CM_BRANCH_CREATE_SOURCE',
    CM_BRANCH_LIST                => 'CM_BRANCH_LIST',
    CM_COMMIT_MESSAGE             => 'CM_COMMIT_MESSAGE',
    CM_CONFLICT_TEXT              => 'CM_CONFLICT_TEXT',
    CM_CONFLICT_TEXT_SKIP         => 'CM_CONFLICT_TEXT_SKIP',
    CM_CONFLICT_TREE              => 'CM_CONFLICT_TREE',
    CM_CONFLICT_TREE_SKIP         => 'CM_CONFLICT_TREE_SKIP',
    CM_CONFLICT_TREE_TIME_WARN    => 'CM_CONFLICT_TREE_TIME_WARN',
    CM_CREATE_TARGET              => 'CM_CREATE_TARGET',
    CM_LOG_EDIT                   => 'CM_LOG_EDIT',
    #CM_WC_STATUS                  => 'CM_WC_STATUS',
    #CM_WC_STATUS_PATH             => 'CM_WC_STATUS_PATH',
    CONFIG_OPEN                   => 'CONFIG_OPEN',
    CONFIG_ENTRY                  => 'CONFIG_ENTRY',
    CONFIG_VAR_UNDEF              => 'CONFIG_VAR_UNDEF',
    E                             => 'E',
    EXPORT_ITEM_CREATE            => 'EXPORT_ITEM_CREATE',
    EXPORT_ITEM_DELETE            => 'EXPORT_ITEM_DELETE',
    KEYWORD_ENTRY                 => 'KEYWORD_ENTRY',
    OUT                           => 'OUT',
    MAKE_BUILD_SHELL_OUT          => 'MAKE_BUILD_SHELL_OUT',
    MAKE_BUILD_SOURCE_ANALYSE     => 'MAKE_BUILD_SOURCE_ANALYSE',
    MAKE_BUILD_SOURCE_SUMMARY     => 'MAKE_BUILD_SOURCE_SUMMARY',
    MAKE_BUILD_TARGET_MISSING_DEP => 'MAKE_BUILD_TARGET_MISSING_DEP',
    MAKE_BUILD_TARGET_SELECT      => 'MAKE_BUILD_TARGET_SELECT',
    MAKE_BUILD_TARGET_SELECT_TIMER=> 'MAKE_BUILD_TARGET_SELECT_TIMER',
    MAKE_BUILD_TARGET_STACK       => 'MAKE_BUILD_TARGET_STACK',
    MAKE_BUILD_TARGET_SUMMARY     => 'MAKE_BUILD_TARGET_SUMMARY',
    MAKE_BUILD_TARGET_TASK_SUMMARY=> 'MAKE_BUILD_TARGET_TASK_SUMMARY',
    MAKE_BUILD_TARGET_UPDATED     => 'MAKE_BUILD_TARGET_UPDATED',
    MAKE_BUILD_TARGET_UP2DATE     => 'MAKE_BUILD_TARGET_UP2DATE',
    MAKE_DEST                     => 'MAKE_DEST',
    MAKE_EXTRACT_PROJECT_TREE     => 'MAKE_EXTRACT_PROJECT_TREE',
    MAKE_EXTRACT_RUNNER_SUMMARY   => 'MAKE_EXTRACT_RUNNER_SUMMARY',
    MAKE_EXTRACT_SYMLINK          => 'MAKE_EXTRACT_SYMLINK',
    MAKE_EXTRACT_TARGET           => 'MAKE_EXTRACT_TARGET',
    MAKE_EXTRACT_TARGET_SUMMARY   => 'MAKE_EXTRACT_TARGET_SUMMARY',
    MAKE_MIRROR                   => 'MAKE_MIRROR',
    SHELL                         => 'SHELL',
    TASK_WORKERS                  => 'TASK_WORKERS',
    TIMER                         => 'TIMER',
};

__PACKAGE__->class({args => '@', code => '$'});

#-------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Context::Event

=head1 SYNOPSIS

    use FCM::Context::Event;
    my $event_ctx = FCM::Context::Event->new($code, @args);

=head1 DESCRIPTION

An instance of this class represents the context of an event. This class is a
sub-class of L<FCM::Class::HASH|FCM::Class::HASH>.

=head1 ATTRIBUTES

=over 4

=item args

An ARRAY reference that represents the additional arguments/contexts of the
event.

=item code

The event code. See below

=back

=head1 EVENTS

The following is a list of event codes.

=over 4

=item FCM::Context::Event->CM_ABORT

This event is raised when a code management command aborts. The 1st argument
should be either "user" (user abort) or "null" (null command).

=item FCM::Context::Event->CM_BRANCH_CREATE_SOURCE

This event is raised to notify the source of a branch create. The 1st argument
should be the expected source URL, and the 2nd argument is the specified peg
revision.

=item FCM::Context::Event->CM_BRANCH_LIST

This event is raised when doing a branch listing. The 1st argument should be the
project location and the rest of the arguments are the branches discovered.

=item FCM::Context::Event->CM_COMMIT_MESSAGE

This event is raised to notify the user the log message to be used for a commit.
The 1st argument of the event should be an instance of
FCM::System::CM::CommitMessage::State.

=item FCM::Context::Event->CM_CONFLICT_TEXT

This event is raised to notify the path of a file with a text conflict.

=item FCM::Context::Event->CM_CONFLICT_TEXT_SKIP

This event is raised to notify the path of a file with a text conflict that
cannot be resolved using a merge tool. E.g. it may be a binary file.

=item FCM::Context::Event->CM_CONFLICT_TREE

This event is raised to notify the path of a node with a tree conflict.

=item FCM::Context::Event->CM_CONFLICT_TREE_SKIP

This event is raised to notify the path of a node with a tree conflict that
cannot be resolved automatically under current functionality. For example, it
may be a directory containing multiple conflicts.

=item FCM::Context::Event->CM_CREATE_TARGET

This event is raised to notify the target of a newly created URL. The 1st argument
should be the target URL.

=item FCM::Context::Event->CM_LOG_EDIT

This event is raised before the system launches an editor to edit a commit log
message. The 1st argument of the event should be the editor command.

=item FCM::Context::Event->CONFIG_ENTRY

This entry is raised to notify the reading of a configuration file entry. The
1st argument should be a blessed reference of a
L<FCM::Context::ConfigEntry|FCM::Context::ConfigEntry>. The second argument
should be a boolean flag to indicate whether this entry is in FCM 1 format or
not.

=item FCM::Context::Event->CONFIG_OPEN

This event is raised when a new configuration file is opened for reading. The
1st argument of this event is an ARRAY that represents the include file stack,
where the last element is the top of the stack. Each element of the stack is a
2-element ARRAY reference, where the first element is a
L<FCM::Context::Locator|FCM::Context::Locator> object and the second element is
the line number. (At the top of the stack, the line number is set to 0.) The 2nd
optional argument of this event is a number to adjust the verbosity level of the
event.

=item FCM::Context::Event->CONFIG_VAR_UNDEF

This event is raised when a variable is undefined. The arguments of this event
contain 2 elements. The 1st element is the configuration entry as a blessed
reference of L<FCM::Context::ConfigEntry|FCM::Context::ConfigEntry>. The 2nd
element is the name of the variable.

=item FCM::Context::Event->E

This event is raised when to notify an exception. The 1st argument of this event
should be the exception.

=item FCM::Context::Event->EXPORT_ITEM_CREATE

This event is raised when the export-items system creates a link to an item.
The 1st argument is the namespace of the item, the 2nd argument is the revision
of the item and the 3rd argument is the name of the link.

=item FCM::Context::Event->EXPORT_ITEM_DELETE

This event is raised when the export-items system deletes a link to an item.
The 1st argument is the namespace of the item, the 2nd argument is the revision
of the item and the 3rd argument is the name of the link.

=item FCM::Context::Event->KEYWORD_ENTRY

This event is raised to notify a keyword entry. The 1st argument is the keyword
entry as a blessed reference of FCM::Context::Keyword::Entry as described in
L<FCM::Context::Keyword|FCM::Context::Keyword>.

=item FCM::Context::Event->OUT

This event is raised to notify (shell command) output. The 1st argument should
be the STDOUT, and the 2nd argument should be the STDERR.

=item FCM::Context::Event->MAKE_BUILD_SHELL_OUT

This event is raised to notify (shell command) output from make/build. The 1st
argument should be the STDOUT, and the 2nd argument should be the STDERR.

=item FCM::Context::Event->MAKE_BUILD_SOURCE_ANALYSE

This event is raised when the make/build system has analysed a source file. The
1st argument should be a blessed reference of FCM::Context::Make::Build::Source
as described in L<FCM::Context::Make::Build|FCM::Context::Make::Build>. The 2nd
argument should be the time it takes for the analysis.

=item FCM::Context::Event->MAKE_BUILD_SOURCE_SUMMARY

This event is raised when the make/build system has analysed all its source
files. The 1st argument should be the total number of files. The 2nd argument
should be the number analysed. The 3rd argument should be the elapsed time. The
4th argument should be the total time, which may differ from the elapsed time if
the analysis is run on more than 1 process.

=item FCM::Context::Event->MAKE_BUILD_TARGET_MISSING_DEP

This event is raised when the make/build system has discarded a missing
dependency from a target. The 1st argument is the target ID, the 2nd argument is
the dependency ID, and the 3rd argument is the dependency type.

=item FCM::Context::Event->MAKE_BUILD_TARGET_SELECT

This event is raised when the make/build system has selected a set of targets to
build. The 1st argument is a HASH reference of the target set.

=item FCM::Context::Event->MAKE_BUILD_TARGET_SELECT_TIMER

This event is raised when the make/build system has completed the target select
and dependency tree analysis. The only argument is the elapsed time.

=item FCM::Context::Event->MAKE_BUILD_TARGET_STACK

This event is raised when make/build system checks a target for cyclic
dependency.  The 1st argument is the key of the task. The 2nd argument is rank
of the task in the dependency hierarchy. The 3rd argument is the number of
dependencies the task has if the task has already been checked, or undef if this
is the first check for the task.

=item FCM::Context::Event->MAKE_BUILD_TARGET_SUMMARY

This event is raised when the make/build system has finished updating its
targets, and is ready to give a total summary. The 1st argument is the number of
modified targets, the 2nd argument is the number unchanged, and the 3rd argument
is the elapsed time.

=item FCM::Context::Event->MAKE_BUILD_TARGET_TASK_SUMMARY

This event is raised when the make/build system has finished updating its
targets, and is ready to give a summary of each type of task. The 1st argument
is the task type name, the 2nd argument is the number of modified targets, the
3rd argument is the number unchanged, and the 4th argument is the total time
spent on this task type.

=item FCM::Context::Event->MAKE_BUILD_TARGET_UPDATED

This event is raised when the make/build system updates a target. The 1st
argument is the task ID, the 2nd argument is the elapsed time. The 3rd argument
is the target name. The 4th argument is the target namespace.

=item FCM::Context::Event->MAKE_BUILD_TARGET_UP2DATE

This event is raised when the make/build system detects an up-to-date target. The
1st argument is the task ID, the 2nd argument is the target name. The 3rd
argument is the target namespace.

=item FCM::Context::Event->MAKE_DEST

This event is raised when the make system sets up the destination. The 1st
argument of this event is the make system context.

=item FCM::Context::Event->MAKE_EXTRACT_PROJECT_TREE

This event is raised after the make/extract system has finished gathering
information for the source trees of each project. The 1st argument is a HASH of
the (keys) project name-spaces and the (values) list (ARRAY) of source tree
locators L<FCM::Context::Locator|FCM::Context::Locator> in the project.

=item FCM::Context::Event->MAKE_EXTRACT_RUNNER_SUMMARY

This event is raised after the make/extract system has finished using the task
runner to perform some tasks. The 1st argument is an identifier for the tasks
performed. The 2nd argument is the number of tasks. The 2nd argument is the
elapsed time. The 3rd argument is the total time in all processes.

=item FCM::Context::Event->MAKE_EXTRACT_SYMLINK

This event is raised as the make/extract system ignores a source that is a
symbolic link. The 1st argument of this event should be a blessed reference of
FCM::Context::Make::Extract::Source as described in
L<FCM::Context::Make::Extract|FCM::Context::Make::Extract>.

=item FCM::Context::Event->MAKE_EXTRACT_TARGET

This event is raised as the make/extract system updates a target destination. The
1st argument of this event should be a blessed reference of
FCM::Context::Make::Extract::Target as described in
L<FCM::Context::Make::Extract|FCM::Context::Make::Extract>.

=item FCM::Context::Event->MAKE_EXTRACT_TARGET_SUMMARY

This event is raised after the make/extract system has updated all target
destinations. The 1st argument of this event is a HASH reference, which contains
2 keys: status and status_of_source, i.e. the destination status of the targets
and the source status of the targets respectively. The values of both are HASH
references. The keys are the names of the status, and the values are the number
of targets with the corresponding status.

=item FCM::Context::Event->MAKE_MIRROR

This event is raised as the make/mirror system updates a target destination. The
1st argument of this event should be the target URI. The remaining arguments
should be the source paths.

=item FCM::Context::Event->SHELL

This event is raised to notify the completion of a shell command. The 1st
argument is an ARRAY reference of the shell command. The 2nd argument is an
integer to override the verbosity level. The 3rd argument is the return code and
the 4th argument is the elapsed time.

=item FCM::Context::Event->TASK_WORKERS

This event is raised on initialisation and destruction of worker processes for
the utility task runner. The 1st argument should either be "init" or "destroy".
The 2nd argument should be the number of workers initialised/destroyed.

=item FCM::Context::Event->TIMER

This event is raised at the start and end of the utility timer. The 1st
argument is the name of the piece of code to time. The 2nd argument is the start
the timer. The 3rd argument is the elapsed time at the end. If the 3rd argument
is not specified, it is the start of the timer.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
