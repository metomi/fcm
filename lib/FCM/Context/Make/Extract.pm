# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-16 Met Office.
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
package FCM::Context::Make::Extract;
use base qw{FCM::Class::HASH};

use FCM::Context::Make;

use constant {
    CTX_PROJECT => 'FCM::Context::Make::Extract::Project',
    CTX_SOURCE  => 'FCM::Context::Make::Extract::Source',
    CTX_TARGET  => 'FCM::Context::Make::Extract::Target',
    CTX_TREE    => 'FCM::Context::Make::Extract::Tree',
    ID_OF_CLASS => 'extract',
    MIRROR      => 1,
};

__PACKAGE__->class({
    dest         => '$',
    id           => {isa => '$', default => ID_OF_CLASS},
    id_of_class  => {isa => '$', default => ID_OF_CLASS},
    ns_list      => '@',
    project_of   => '%',
    status       => {isa => '$', default => FCM::Context::Make->ST_UNKNOWN},
    target_of    => '%',
    prop_of      => '%',
});

# ------------------------------------------------------------------------------
package FCM::Context::Make::Extract::Project;
use base qw{FCM::Class::HASH};

__PACKAGE__->class({
    cache     => '$',
    inherited => '$',
    locator   => 'FCM::Context::Locator',
    ns        => '$',
    path_excl => '@',
    path_incl => '@',
    path_root => {isa => '$', default => q{}},
    trees     => '@',
});

# ------------------------------------------------------------------------------
package FCM::Context::Make::Extract::Tree;
use base qw{FCM::Class::HASH};

__PACKAGE__->class({
    cache     => '$',
    inherited => '$',
    key       => '$',
    locator   => 'FCM::Context::Locator',
    ns        => '$',
    sources   => '@',
});

# ------------------------------------------------------------------------------
package FCM::Context::Make::Extract::Source;
use base qw{FCM::Class::HASH};

use constant {
    ST_NORMAL    => 'ST_NORMAL',
    ST_UNCHANGED => 'ST_UNCHANGED',
    ST_MISSING   => 'ST_MISSING',
};

__PACKAGE__->class({
    cache       => '$',
    key_of_tree => '$',
    locator     => 'FCM::Context::Locator',
    ns          => '$',
    ns_in_tree  => '$',
    status      => {isa => '$', default => ST_NORMAL},
});

# Shorthand for $source->get_status() eq $source->ST_MISSING.
sub is_missing {
    $_[0]->get_status() eq ST_MISSING;
}

# Shorthand for $source->get_status() eq $source->ST_UNCHANGED.
sub is_unchanged {
    $_[0]->get_status() eq ST_UNCHANGED;
}

# ------------------------------------------------------------------------------
package FCM::Context::Make::Extract::Target;
use base qw{FCM::Class::HASH};

use constant {
    ST_ADDED      => 'ST_ADDED',
    ST_DELETED    => 'ST_DELETED',
    ST_MERGED     => 'ST_MERGED',
    ST_MODIFIED   => 'ST_MODIFIED',
    ST_O_ADDED    => 'ST_O_ADDED',
    ST_O_DELETED  => 'ST_O_DELETED',
    ST_UNCHANGED  => 'ST_UNCHANGED',
    ST_UNKNOWN    => 'ST_UNKNOWN',
    can_be_source => 1,
};

__PACKAGE__->class({
    dests            => '@',
    ns               => '$',
    path             => '$',
    source_of        => '%',
    status           => {isa => '$', default => ST_UNKNOWN},
    status_of_source => {isa => '$', default => ST_UNKNOWN},
});

# Returns true if target has an OK status.
sub is_ok {
    my ($self) = @_;
    my $status = $self->get_status();
    grep {$_ eq $status}
        (ST_ADDED, ST_MERGED, ST_MODIFIED, ST_O_ADDED, ST_UNCHANGED);
}

# Shorthand for $target->get_status() eq $target->ST_UNCHANGED.
sub is_unchanged {
    $_[0]->get_status() eq ST_UNCHANGED;
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Context::Make::Extract

=head1 SYNOPSIS

    use FCM::Context::Make::Extract;
    my $ctx = FCM::Context::Make::Extract->new();

=head1 DESCRIPTION

Provides a context object for the FCM extract system. All the classes described
below are sub-classes of L<FCM::Class::HASH|FCM::Class::HASH>.

=head1 OBJECTS

=head2 FCM::Context::Make::Extract

An instance of this class represents an extract. It has the following
attributes:

=over 4

=item dest

The destination of the extract.

=item id

The ID of the current context. (default="extract")

=item id_of_class

The class ID of the current context. (default="extract")

=item ns_list

An ARRAY of name-spaces of the projects to extract.

=item project_of

A HASH to map (key) the name-spaces of the projects in this extract to (value)
their corresponding contexts.

=item prop_of

A HASH containing the named properties (i.e. options and settings of named
external tools). Expects a value to be an instance of
L<FCM::Context::Make::Share::Property|FCM::Context::Make::Share::Property>.

=item status

The status of the extract. See L<FCM::Context::Make|FCM::Context::Make> for the
status constants.

=item target_of

A HASH to map (key) the name-spaces of the targets in this extract to (value)
their corresponding contexts.

=back

=head2 FCM::Context::Make::Extract::Project

An instance of this class represents a project in an extract. It has the
following attributes:

=over 4

=item cache

The file system location (cache) of this project.

=item inherited

This project is inherited?

=item locator

An instance of L<FCM::Context::Locator|FCM::Context::Locator> that represents
the locator of this project.

=item ns

The name-space of this project.

=item path_excl

An ARRAY of patterns to match the names of the paths that will be excluded in
this project.

=item path_incl

An ARRAY of patterns to match the names of the paths that will always be
included in this project.

=item path_root

The relative path in a project tree for the root name-space. If this is
specified, the system will extract only files under this path, and their
name-spaces will be adjusted to be relative to this path.

=item trees

An ARRAY of the tree contexts in this project. By convention, the 0th element is
the base tree.

=back

=head2 FCM::Context::Make::Extract::Tree

An instance of this class represents a tree in a project. It has the following
attributes:

=over 4

=item cache

The file system location (cache) of this tree.

=item inherited

A flag to indicate whether this tree is provided by an inherited extract.

=item key

The key of this tree. By convention, the base tree is the 0th key.

=item locator

An instance of L<FCM::Context::Locator|FCM::Context::Locator> that represents
the locator of this tree.

=item ns

The name-space of the project in which this tree belongs.

=item sources

An ARRAY of source file contexts provided by this tree.

=back

=head2 FCM::Context::Make::Extract::Source

An instance of this class represents a source file provided by a project tree.
It has the following attributes:

=over 4

=item cache

The file system location (cache) of this source file.

=item key_of_tree

The key of the tree that provides this source file.

=item locator

An instance of L<FCM::Context::Locator|FCM::Context::Locator> that represents
the locator of the source file.

=item ns

The full (mapped) name-space of the source file, (including the leading project
name-space).

=item ns_in_tree

The original name-space of the source file, relative to its path in the tree.

=item status

The status of the source file. It can take the value of one of the
FCM::Context::Make::Extract::Source->ST_* constants. See </CONSTANTS> for detail.

=back

In addition, an instance of FCM::Context::Make::Extract::Source has the
following methods:

=over 4

=item $source->is_missing()

Shorthand for $source->get_status() eq $source->ST_MISSING.

=item $source->is_unchanged()

Shorthand for $source->get_status() eq $source->ST_UNCHANGED.

=back

=head2 FCM::Context::Make::Extract::Target

An instance of this class represents an extract target. It has the following
attributes:

=over 4

=item dests

An ARRAY containing the destination search path of this target. The first
element is the path to the destination of the current extract, and the rest are
destinations to inherited extracts.

=item ns

The full name-space of this target.

=item path

Returns the actual destination path of this target.

=item source_of

A HASH for mapping (key) the keys of the trees to (value) the corresponding
contexts of the source files provided by the trees to this target.

=item status

The status of the target destination. It can take the value of one of the
FCM::Context::Make::Extract::Target->ST_* constants. See </CONSTANTS> for detail.

=item status_of_source

The status of the target, with respect to its sources. It can take the value of
one of the FCM::Context::Make::Extract::Target->ST_* constants. See </CONSTANTS>
for detail.

=back

In addition, an instance of FCM::Context::Make::Extract::Target has the
following methods:

=over 4

=item $target->can_be_source()

Returns true if the destination status indicates that the target is usable as a
source file of a subsequent a make (step).

=item $target->is_ok()

Returns true if the target has a OK destination status.

=item $target->is_unchanged()

Shorthand for $target->get_status() eq $target->ST_UNCHANGED.

=back

=head1 CONSTANTS

The following is a list of constants:

=over 4

=item FCM::Context::Make::Extract->CTX_PROJECT

An alias to FCM::Context::Make::Extract::Project.

=item FCM::Context::Make::Extract->CTX_SOURCE

An alias to FCM::Context::Make::Extract::Source.

=item FCM::Context::Make::Extract->CTX_TARGET

An alias to FCM::Context::Make::Extract::Target.

=item FCM::Context::Make::Extract->CTX_TREE

An alias to FCM::Context::Make::Extract::Tree.

=item FCM::Context::Make::Extract->ID_OF_CLASS

The default value of the "id" attribute (of an instance), and the ID of the
functional class. ("extract")

=item FCM::Context::Make::Extract->MIRROR

A flag to tell the mirror sub-system that the targets of this context can be
used as inputs sources to subsequent steps for the configuration file in the
mirror destination.

=item FCM::Context::Make::Extract::Source->ST_NORMAL

Source status: normal.

=item FCM::Context::Make::Extract::Source->ST_UNCHANGED

Source status: source is unchanged (against base).

=item FCM::Context::Make::Extract::Source->ST_MISSING

Source status: source is a placeholder in a target. It does not actually exist
in the source tree.

=item FCM::Context::Make::Extract::Target->ST_ADDED

As destination status: new file in the target destination. As source status:
added by a source in a diff tree.

=item FCM::Context::Make::Extract::Target->ST_DELETED

As destination status: file removed from the target destination. As source
status: target removed by a diff tree.

=item FCM::Context::Make::Extract::Target->ST_MERGED

As source status: modified by 2 or more diff trees.

=item FCM::Context::Make::Extract::Target->ST_MODIFIED

As destination status: target destination is modified. As source status:
modified by 1 diff tree.

=item FCM::Context::Make::Extract::Target->ST_O_ADDED

As destination status: new file in the target destination, overriding a file in
an inherited destination.

=item FCM::Context::Make::Extract::Target->ST_O_DELETED

As destination status: target destination should be removed, but there is still
a file in an inherited destination.

=item FCM::Context::Make::Extract::Target->ST_UNCHANGED

As destination status: target destination is unchanged. As source status:
unchanged by a diff tree.

=item FCM::Context::Make::Extract::Target->ST_UNKNOWN

Status is unknown.

=back

=head1 SEE ALSO

L<FCM::System::Make::Extract|FCM::System::Make::Extract>

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
