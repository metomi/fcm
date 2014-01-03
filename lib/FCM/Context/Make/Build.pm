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
package FCM::Context::Make::Build;
use base qw{FCM::Class::HASH};

use FCM::Context::Make;

use constant {
    CTX_SOURCE  => 'FCM::Context::Make::Build::Source',
    CTX_TARGET  => 'FCM::Context::Make::Build::Target',
    ID_OF_CLASS => 'build',
};

my $ST_UNKNOWN = FCM::Context::Make->ST_UNKNOWN;

__PACKAGE__->class(
    {   dest             => '$',
        dests            => '@',
        id               => {isa => '$' , default => ID_OF_CLASS},
        id_of_class      => {isa => '$' , default => ID_OF_CLASS},
        input_ns_excl    => '@',
        input_ns_incl    => '@',
        input_source_of  => '%',
        prop_of          => '%',
        source_of        => '%',
        status           => {isa => '$' , default => $ST_UNKNOWN},
        target_of        => '%',
        target_key_of    => '%',
        target_select_by => '%',
    },
);

# ------------------------------------------------------------------------------
package FCM::Context::Make::Build::Source;
use base qw{FCM::Class::HASH};

__PACKAGE__->class({
    checksum   => '$',
    deps       => '@',
    info_of    => '%',
    ns         => '$',
    path       => '$',
    prop_of    => '%',
    type       => '$',
    up_to_date => '$',
});

# ------------------------------------------------------------------------------
package FCM::Context::Make::Build::Target;
use base qw{FCM::Class::HASH};

use constant {
    CT_BIN                  => 'bin',
    CT_ETC                  => 'etc',
    CT_INCLUDE              => 'include',
    CT_LIB                  => 'lib',
    CT_O                    => 'o',
    CT_SRC                  => 'src',
    POLICY_CAPTURE          => 'POLICY_CAPTURE',
    POLICY_FILTER           => 'POLICY_FILTER',
    POLICY_FILTER_IMMEDIATE => 'POLICY_FILTER_IMMEDIATE',
    ST_MODIFIED             => 'ST_MODIFIED',
    ST_OOD                  => 'ST_OOD',
    ST_UNCHANGED            => 'ST_UNCHANGED',
    ST_UNKNOWN              => 'ST_UNKNOWN',
};

__PACKAGE__->class(
    {   category        => '$',
        checksum        => '$',
        deps            => '@',
        dep_policy_of   => '%',
        info_of         => '%',
        key             => '$',
        ns              => '$',
        path            => '$',
        path_of_prev    => '$',
        path_of_source  => '$',
        prop_of         => '%',
        prop_of_prev_of => '%',
        status          => {isa => '$', default => ST_UNKNOWN},
        status_of       => '%',
        task            => '$',
        triggers        => '@',
        type            => '$',
    },
);

# Returns true if target has a usable dest status.
sub can_be_source {
    my ($self) = @_;
    $self->get_category() && $self->get_category() eq CT_SRC;
}

# Returns true if target has an OK status.
sub is_ok {
    my ($self) = @_;
    $self->get_status() eq ST_MODIFIED || $self->get_status() eq ST_UNCHANGED;
}

# Shorthand for $target->get_status() eq $target->ST_MODIFIED.
sub is_modified {
    $_[0]->get_status() eq ST_MODIFIED;
}

# Shorthand for $target->get_status() eq $target->ST_UNCHANGED.
sub is_unchanged {
    $_[0]->get_status() eq ST_UNCHANGED;
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Context::Make::Build

=head1 SYNOPSIS

    use FCM::Context::Make::Build;
    my $ctx = FCM::Context::Make::Build->new();

=head1 DESCRIPTION

Provides a context object for the FCM build system. All the classes described
below are sub-classes of L<FCM::Class::HASH|FCM::Class::HASH>.

=head1 OBJECTS

=head2 FCM::Context::Make::Build

An instance of this class represents a build. It has the following
attributes:

=over 4

=item dest

The destination of the build.

=item dests

An ARRAY containing the path for searching items in the current build.

=item id

The ID of the context. (default="build")

=item id_of_class

The class ID of the context. (default="build")

=item input_source_of

A HASH to map a name space to its ARRAY of input sources.

=item input_ns_excl

An ARRAY of source name-spaces to exclude.

=item input_ns_incl

An ARRAY of source name-spaces to include.

=item prop_of

A HASH containing the named properties (i.e. options and settings of named
external tools). Expects a value to be an instance of
L<FCM::Context::Make::Share::Property|FCM::Context::Make::Share::Property>.

=item prop_of_prev_of

A HASH containing the named properties (i.e. options and settings of named
external tools) in the latest successful update of this target. Expects a value
to be an instance of
L<FCM::Context::Make::Share::Property|FCM::Context::Make::Share::Property>.

=item source_of

A HASH to map the namespace to the source contexts. Each element is expected to
be an L</FCM::Context::Make::Build::Source> object.

=item status

The status of this context. See L<FCM::Context::Make|FCM::Context::Make> for the
status constants.

=item target_of

A HASH to map the namespace to the target contexts. Each element is expected to
be an L</FCM::Context::Make::Build::Target> object.

=item target_key_of

A HASH to map the automatic key of targets to their desired key.

=item target_select_by

A HASH to allow users to specify how to select from all the targets. The key can
be "category", "key", "ns" or "task". Each value should be a HASH that
represents the set of criteria.

=back

=head2 FCM::Context::Make::Build::Source

An instance of this class represents an actual source of the build. It has the
following attributes:

=over 4

=item checksum

The MD5 checksum of the source file.

=item deps

An ARRAY to contain the dependencies of the source file. Each element of the
ARRAY is expected to be a reference to a two-element ARRAY [$name, $type] where
$name is the name of the dependency and $type is its type.

=item info_of

A HASH to contain the extra information of the source file. E.g. If the {main}
element is true, the source contains a main program. If the {symbols} element
is defined, it contains a reference to an ARRAY of program unit symbols that has
been found in the source file.

=item ns

The name-space of the source file.

=item path

The path in the file system pointing to the source file.

=item prop_of

A HASH containing the keys and the values of the build properties (mainly on
dependency settings) of the source.

=item type

The file type of the source file.

=item up_to_date

A flag to indicate whether the source file is up to date, compared with a
previous build or the nearest inherited build.

=back

=head2 FCM::Context::Make::Build::Target

An instance of this class represents a target of the build. It has the following
attributes:

=over 4

=item category

The target category, e.g. bin, etc, include, lib, o, src

=item checksum

The MD5 checksum of the target.

=item deps

An ARRAY containing the dependencies of the target. Each element of the
ARRAY is expected to be a reference to a two-element ARRAY [$name, $type] where
$name is the name of the dependency and $type is its type.

=item dep_policy_of

A HASH to contain a map between each relevant dependency type of this target and
its policy to apply to the dependency type. The policy should take the value of
POLICY_CAPTURE, POLICY_FILTER or POLICY_FILTER_IMMEDIATE.

=item info_of

A HASH to contain the extra information of the target. E.g. The {paths} => ARRAY
reference of include/object search paths for the compile, link and preprocess
tasks; and {deps}{o} => ARRAY reference and {deps}{o.special} => ARRAY
reference of object dependency for the link tasks.

=item key

The key (i.e. the base name) of the target.

=item ns

The name-space (of the source file) associated with this target.

=item path

The path in the file system where the target can be located.

=item path_of_prev

The path in the file system where the target in a previous or inherited build
can be located.

=item path_of_source

The path in the file system where the source file associated with the target can
be located.

=item prop_of

A HASH containing the keys and the values of the build properties of the target.

=item status

The status of the target.

=item status_of

A HASH containing the status of dependency types that may be relevant to targets
higher up in the dependency tree.

=item task

The target type, (i.e. the name of the task to update with the target).

=item triggers

An ARRAY reference of the keys of targets that should be automatically triggered
by this target.

=item type

The type of the source that gives this target.

=back

In addition, an instance of FCM::Context::Make::Extract::Target has the
following methods:

=over 4

=item $target->can_be_source()

Returns true if the destination status indicates that the target is usable as a
source file of a subsequent a make (step).

=item $target->is_ok()

Returns true if the target has a OK destination status.

=item $target->is_modified()

Shorthand for $target->get_status() eq $target->ST_MODIFIED.

=item $target->is_unchanged()

Shorthand for $target->get_status() eq $target->ST_UNCHANGED.

=back

=head1 CONSTANTS

The following is a list of constants:

=over 4

=item FCM::Context::Make::Build->CTX_INPUT

Alias of FCM::Context::Make::Build::Input.

=item FCM::Context::Make::Build->CTX_SOURCE

Alias of FCM::Context::Make::Build::Source.

=item FCM::Context::Make::Build->ID_OF_CLASS

The default value of the "id" attribute (of an instance), and the ID of the
functional class. ("build")

=item FCM::Context::Make::Build::Target->CT_BIN

Target category, "bin", executable.

=item FCM::Context::Make::Build::Target->CT_ETC

Target category, "etc", data and misc file.

=item FCM::Context::Make::Build::Target->CT_INCLUDE

Target category, "include", include file.

=item FCM::Context::Make::Build::Target->CT_LIB

Target category, "lib", program library.

=item FCM::Context::Make::Build::Target->CT_O

Target category, "o", compiled object file.

=item FCM::Context::Make::Build::Target->CT_SRC

Target category, "src", generated source file.

=item FCM::Context::Make::Build::Target->POLICY_CAPTURE

Indicates that the dependency type is relevant to the target, and the build
engine should stop floating the dependency target up the dependency tree.

=item FCM::Context::Make::Build::Target->POLICY_FILTER

Indicates that the dependency type is relevant to the target, and the build
engine may float the dependency target up the dependency tree as well.

=item FCM::Context::Make::Build::Target->POLICY_FILTER_IMMEDIATE

Indicates that the dependency type is relevant to the target but only if the
dependency target is an immediate dependency of this target, and the build
engine may float the dependency target up the dependency tree as well.

=item FCM::Context::Make::Build::Target->ST_MODIFIED

Indicates that the target is out of date and has been modified by the build.

=item FCM::Context::Make::Build::Target->ST_OOD

Indicates that the target is out of date.

=item FCM::Context::Make::Build::Target->ST_UNCHANGED

Indicates that the target is up to date and unchanged by the build.

=item FCM::Context::Make::Build::Target->ST_UNKNOWN

Indicates an unknown target status.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
