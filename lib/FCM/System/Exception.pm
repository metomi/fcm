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

package FCM::System::Exception;
use base qw{FCM::Exception};
use Scalar::Util qw{blessed};

use constant {
    BUILD_SOURCE     => 'BUILD_SOURCE',
    BUILD_SOURCE_SYN => 'BUILD_SOURCE_SYN',
    BUILD_TARGET     => 'BUILD_TARGET',
    BUILD_TARGET_BAD => 'BUILD_TARGET_BAD',
    BUILD_TARGET_CYC => 'BUILD_TARGET_CYC',
    BUILD_TARGET_DEP => 'BUILD_TARGET_DEP',
    BUILD_TARGET_DUP => 'BUILD_TARGET_DUP',
    CACHE_LOAD       => 'CACHE_LOAD',
    CACHE_TYPE       => 'CACHE_TYPE',
    CM_ALREADY_EXIST => 'CM_ALREADY_EXIST',
    CM_ARG           => 'CM_ARG',
    CM_BRANCH_NAME   => 'CM_BRANCH_NAME',
    CM_BRANCH_SOURCE => 'CM_BRANCH_SOURCE',
    CM_CHECKOUT      => 'CM_CHECKOUT',
    CM_LOG_EDIT_DELIMITER => 'CM_LOG_EDIT_DELIMITER',
    CM_LOG_EDIT_NULL => 'CM_LOG_EDIT_NULL',
    CM_OPT_ARG       => 'CM_OPT_ARG',
    CM_PROJECT_NAME  => 'CM_PROJECT_NAME',
    CM_REPOSITORY    => 'CM_REPOSITORY',
    CONFIG_CONFLICT  => 'CONFIG_CONFLICT',
    CONFIG_INHERIT   => 'CONFIG_INHERIT',
    CONFIG_MODIFIER  => 'CONFIG_MODIFIER',
    CONFIG_NS        => 'CONFIG_NS',
    CONFIG_NS_VALUE  => 'CONFIG_NS_VALUE',
    CONFIG_UNKNOWN   => 'CONFIG_UNKNOWN',
    CONFIG_VALUE     => 'CONFIG_VALUE',
    COPY             => 'COPY',
    DEST_CLEAN       => 'DEST_CLEAN',
    DEST_CREATE      => 'DEST_CREATE',
    DEST_LOCKED      => 'DEST_LOCKED',
    EXPORT_ITEMS_SRC => 'EXPORT_ITEMS_SRC',
    EXTRACT_LOC_BASE => 'EXTRACT_LOC_BASE',
    EXTRACT_MERGE    => 'EXTRACT_MERGE',
    EXTRACT_NS       => 'EXTRACT_NS',
    MIRROR           => 'MIRROR',
    MIRROR_NULL      => 'MIRROR_NULL',
    MIRROR_SOURCE    => 'MIRROR_SOURCE',
    MIRROR_TARGET    => 'MIRROR_TARGET',
    MAKE             => 'MAKE',
    MAKE_ARG         => 'MAKE_ARG',
    MAKE_CFG         => 'MAKE_CFG',
    MAKE_CFG_FILE    => 'MAKE_CFG_FILE',
    MAKE_PROP_NS     => 'MAKE_PROP_NS',
    MAKE_PROP_VALUE  => 'MAKE_PROP_VALUE',
    SHELL            => 'SHELL',
};

1;
__END__

=head1 NAME

FCM::System::Exception

=head1 SYNOPSIS

    eval {
        # ...
        FCM::System::Exception->throw($code, $ctx);
        # ...
        FCM::System::Exception->throw($code, $ctx, {exception => $e});
        # ...
    };
    if (my $e = $@) {
        if (FCM::System::Exception->caught($e)) {
            # do something ...
        }
        else {
            # do something else ...
        }
    }

=head1 DESCRIPTION

This exception represents an error condition in an FCM sub-system. It is a
sub-class of L<FCM::Exception|FCM::Exception>.

=head1 CONSTANTS

The following are known error code:

=over 4

=item FCM::System::Exception->BUILD_SOURCE

The build sub-system fails because a specified source does not exist. Expects
$e->get_ctx() to return the source path.

=item FCM::System::Exception->BUILD_SOURCE_SYN

The build sub-system fails because a specified source has a syntax error.
Expects $e->get_ctx() to return an ARRAY reference containing the source path
and the line number where the error occurs.

=item FCM::System::Exception->BUILD_TARGET

The build sub-system fails because a target does not exist when it is supposed
to be updated. Expects $e->get_ctx() to return an instance of
L<FCM::Context::Make::Build::Target|FCM::Context::Make::Build/FCM::Context::Make::Build::Target>.

=item FCM::System::Exception->BUILD_TARGET_BAD

The build sub-system fails because the user has specified invalid targets.
Expects $e->get_ctx() to return an ARRAY reference of the bad target keys.

=item FCM::System::Exception->BUILD_TARGET_CYC

The build sub-system fails due to cyclic dependency in a target. Expects
$e->get_ctx() to return a HASH {$key => {'keys' => \@stack}, ...}, where each
$key is the ID of a problematic target and the @stack is an ARRAY reference of a
stack of target keys where the problem is detected.

=item FCM::System::Exception->BUILD_TARGET_DEP

The build sub-system fails because some targets have missing dependencies.
Expects $e->get_ctx() to return a HASH
{$key => {'keys' => \@stack, 'values' => [$dep_key, $dep_type]}, ...}, where each
$key is the ID of a problematic target, the @stack is an ARRAY reference of a
stack of target keys where the problem is detected, and the
[$dep_key, $dep_type] ARRAY contains the key and type of the dependency.

=item FCM::System::Exception->BUILD_TARGET_DUP

The build sub-system fails because there are multiple versions of a build
target. Expects $e->get_ctx() to return a HASH
{$key => {'keys' => \@stack, 'values' => \@ns}, ...} where each $key is the ID of a
problematic target, the @stack is an ARRAY
reference of a stack of target keys where the problem is detected,
and @ns contains the name-spaces of the sources that give the same target key.

=item FCM::System::Exception->CACHE_LOAD

The system is unable to load a cache from a make destination. Expects
$e->get_ctx() to return the path it fails to load; and the $e->get_exception()
to return the original exception that triggers this failure.

=item FCM::System::Exception->CACHE_TYPE

The system loaded a cache into a data structure, but the data structure is not
the expected object type. Expects $e->get_ctx() to return the path to the cache.

=item FCM::System::Exception->CM_ALREADY_EXIST

Attempt to create a target that already exists. Expects $e->get_ctx() to return the
target URL.

=item FCM::System::Exception->CM_ARG

Attempt to supply a bad argument. Expects $e->get_ctx() to return the bad value.

=item FCM::System::Exception->CM_BRANCH_NAME

Attempt to create a branch with a bad name. Expects $e->get_ctx() to return the
bad name.

=item FCM::System::Exception->CM_BRANCH_SOURCE

Attempt to create a branch with an invalid source. Expects $e->get_ctx() to
return the source.

=item FCM::System::Exception->CM_CHECKOUT

Attempt to checkout to an existing working copy. Expects $e->get_ctx() to return
an ARRAY containing the target path and the URL it is pointing to.

=item FCM::System::Exception->CM_LOG_EDIT_DELIMITER

The commit message delimiter is modified after an edit.

=item FCM::System::Exception->CM_LOG_EDIT_NULL

The commit message is empty after an edit.

=item FCM::System::Exception->CM_OPT_ARG

Attempt to supply a bad argument to a valid option. Expects $e->get_ctx() to
return the option key and the bad value.

=item FCM::System::Exception->CM_PROJECT_NAME

Attempt to create a project with a bad name. Expects $e->get_ctx() to return the
bad name.

=item FCM::System::Exception->CM_REPOSITORY

Attempt to access an invalid repository. Expects $e->get_ctx() to return the
bad repository.

=item FCM::System::Exception->CONFIG_CONFLICT

In a make configuration file, a declaration attempts to modify a value that is
inherited from a previous make, and considered read-only. Expects $e->get_ctx()
to return a L<FCM::Context::ConfigEntry|FCM::Context::ConfigEntry> object.

=item FCM::System::Exception->CONFIG_INHERIT

In a make configuration file, a declaration attempts to inherit from a make that
is either incomplete or failed. Expects $e->get_ctx() to return a
L<FCM::Context::ConfigEntry|FCM::Context::ConfigEntry> object.

=item FCM::System::Exception->CONFIG_MODIFIER

In a make configuration file, a modifier of in a declaration is incorrect.
Expects $e->get_ctx() to return a
L<FCM::Context::ConfigEntry|FCM::Context::ConfigEntry> object and
$e->get_exception() to return (if any) the original exception that triggers this
failure.

=item FCM::System::Exception->CONFIG_NS

In a make configuration file, a declaration is missing a required name-space, or
the name-space declaration is incorrect. Expects $e->get_ctx() to return a
L<FCM::Context::ConfigEntry|FCM::Context::ConfigEntry> object and
$e->get_exception() to return (if any) the original exception that triggers this
failure.

=item FCM::System::Exception->CONFIG_NS_VALUE

In a make configuration file, the name-space of a declaration is incompatible
with the value. (E.g. the number of name-space elements does not match with the
number of words in a value.) Expects $e->get_ctx() to return a
L<FCM::Context::ConfigEntry|FCM::Context::ConfigEntry> object and
$e->get_exception() to return (if any) the original exception that triggers this
failure.

=item FCM::System::Exception->CONFIG_UNKNOWN

In a make configuration file, the label of a declaration is unrecognised by the
system. Expects $e->get_ctx() to return a reference to an ARRAY containing
L<FCM::Context::ConfigEntry|FCM::Context::ConfigEntry> objects.

=item FCM::System::Exception->CONFIG_VALUE

In a make configuration file, the value of a declaration is incorrect. Expects
$e->get_ctx() to return a L<FCM::Context::ConfigEntry|FCM::Context::ConfigEntry>
object and $e->get_exception() to return (if any) the original exception that
triggers this failure.

=item FCM::System::Exception->COPY

The system fails to perform a file copy. Expects $e->get_ctx() to return a
2-element ARRAY reference to represent the source and the target, and the
$e->get_exception() to return the original exception that triggers this failure.

=item FCM::System::Exception->DEST_CLEAN

A destination path cannot be removed. Expects $e->get_ctx() to return the path
that the system fails to remove, and $e->get_exception() to return the original
exception that triggers this failure.

=item FCM::System::Exception->DEST_CREATE

The system is unable to create a path at a make destination. Expects
$e->get_ctx() to return the path it fails to create; and the $e->get_exception()
to return the original exception that triggers this failure.

=item FCM::System::Exception->DEST_LOCKED

A lock file exists at the destination. Expects $e->get_ctx() to return the
path to the lock file.

=item FCM::System::Exception->EXPORT_ITEMS_SRC

The system fails because the source location is not specified.

=item FCM::System::Exception->EXTRACT_LOC_BASE

The system fails to determine the location of a base tree of a project. Expects
$e->get_ctx() to return the name-space of the project.

=item FCM::System::Exception->EXTRACT_MERGE

The system fails to merge the sources of an extract target. Expects
$e->get_ctx() to return a HASH reference with the following keys:

=over 4

=item target

The FCM::Context::Make::Extract::Target object associated with this failure.

=item output

The path to a file containing the failed merge output.

=item keys_done

The keys of the source trees providing the source files for this target that
have already been merged.

=item key

The key of the source tree providing the source file for this target that causes
the merge conflict.

=item keys_left

The keys of the source trees providing the source files for this target that are
yet to be merged.

=back

=item FCM::System::Exception->EXTRACT_NS

The system fails because there are some extract declarations for the name-spaces
but the settings are not used. Expects $e->get_ctx() to return an ARRAY of bad
name-spaces.

=item FCM::System::Exception->MIRROR

The mirror operation failed. Expects $e->get_ctx() to return a reference of a
2-element ARRAY containing the source and the target of the mirror, and
$e->get_exception() to return the original exception that triggers this failure.

=item FCM::System::Exception->MIRROR_NULL

The mirror step failed because a target is not specified. The $e->get_ctx() is
undefined.

=item FCM::System::Exception->MIRROR_SOURCE

The mirror step failed because the destination of a completed step in the make
is not suitable for mirroring. Expects $e->get_ctx() to return an ARRAY
reference containing the names of the unsuitable steps.

=item FCM::System::Exception->MIRROR_TARGET

The mirror step failed to create the target. Expects $e->get_ctx() to
return the target of the mirror, and $e->get_exception() to return the original
exception that triggers this failure.

=item FCM::System::Exception->MAKE

A named step in a make is not implemented. Expects $e->get_ctx() to return the
name of the step.

=item FCM::System::Exception->MAKE_ARG

A make sub-system fails because of bad command line arguments. Expects
$e->get_ctx() to return an ARRAY reference of something like this:

    my @list = @{$e->get_ctx()};
    for (@list) {
        my ($arg_index, $arg) = @{$_};
        warn("Argument $arg_index ($arg) is invalid\n");
    }

=item FCM::System::Exception->MAKE_CFG

A make sub-system fails because it can find no configuration.

=item FCM::System::Exception->MAKE_CFG_FILE

A make sub-system fails because it cannot file a named configuration file.
Expects $e->get_ctx() to return the configuration file name.

=item FCM::System::Exception->MAKE_PROP_NS

A make sub-system fails because a property is specified with an invalid
name-space. Expects $e->get_ctx() to return an ARRAY reference of something like
this:

    my @list = @{$e->get_ctx()};
    for (@list) {
        my ($step_name, $prop_name, $ns, $value) = @{$_};
        warn("{$prop_name}[$ns]: prop ns is invalid\n");
    }

=item FCM::System::Exception->MAKE_PROP_VALUE

A make sub-system fails because a property is specified with an invalid
value. Expects $e->get_ctx() to return an ARRAY reference of something like
this:

    my @list = @{$e->get_ctx()};
    for (@list) {
        my ($step_name, $prop_name, $ns, $value) = @{$_};
        warn("{$prop_name}[$ns] = $value: prop value is bad\n");
    }

=item FCM::System::Exception->SHELL

A shell command returns an error. Expects $e->get_ctx() to return a HASH
reference containing {command_list}, an ARRAY reference representing the
command; {rc}, the return code; {out}, the standard output of the command and
{err}, the standard error of the command. Expects $e->get_exception() to return
the standard error of the command.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
