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

package FCM::System;
use base qw{FCM::Class::CODE};

use FCM::Util;
use Scalar::Util qw{reftype};

# Alias
our $S;

# The (keys) named actions of this class and (values) their implementations.
our %ACTION_OF = (
    browse               => _func('misc', sub {$S->browse(@_)}),
    build                => _func('old' , sub {$S->build(@_)}),
    config_compare       => _func('old' , sub {$S->config_compare(@_)}),
    config_parse         => _func('misc', sub {$S->config_parse(@_)}),
    cm_branch_create     => _func('cm'  , sub {$S->cm_branch_create(@_)}),
    cm_branch_delete     => _func('cm'  , sub {$S->cm_branch_delete(@_)}),
    cm_branch_diff       => _func('cm'  , sub {$S->cm_branch_diff(@_)}),
    cm_branch_info       => _func('cm'  , sub {$S->cm_branch_info(@_)}),
    cm_branch_list       => _func('cm'  , sub {$S->cm_branch_list(@_)}),
    cm_commit            => _func('cm'  , sub {$S->cm_commit(@_)}),
    cm_checkout          => _func('cm'  , sub {$S->cm_checkout(@_)}),
    cm_check_missing     => _func('cm'  , sub {$S->cm_check_missing(@_)}),
    cm_check_unknown     => _func('cm'  , sub {$S->cm_check_unknown(@_)}),
    cm_diff              => _func('cm'  , sub {$S->cm_diff(@_)}),
    cm_loc_layout        => _func('cm'  , sub {$S->cm_loc_layout(@_)}),
    cm_merge             => _func('cm'  , sub {$S->cm_merge(@_)}),
    cm_mkpatch           => _func('cm'  , sub {$S->cm_mkpatch(@_)}),
    cm_project_create    => _func('cm'  , sub {$S->cm_project_create(@_)}),
    cm_resolve_conflicts => _func('cm'  , sub {$S->cm_resolve_conflicts(@_)}),
    cm_switch            => _func('cm'  , sub {$S->cm_switch(@_)}),
    cm_update            => _func('cm'  , sub {$S->cm_update(@_)}),
    export_items         => _func('misc', sub {$S->export_items(@_)}),
    extract              => _func('old' , sub {$S->extract(@_)}),
    keyword_find         => _func('misc', sub {$S->keyword_find(@_)}),
    make                 => _func('make', sub {$S->main(@_)}),
    svn                  => _func('cm'  , sub {$S->svn(@_)}),
    util                 => sub {$_[0]->{util}},
    version              => _func('misc', sub {$S->version(@_)}),
);
# The (keys) named system and their implementation classes.
our %SYSTEM_CLASS_OF = (
    cm   => 'FCM::System::CM',
    old  => 'FCM::System::Old',
    make => 'FCM::System::Make',
    misc => 'FCM::System::Misc',
);

# Creates the class.
__PACKAGE__->class(
    {   gui             => '$',
        system_class_of => {isa => '%', default => {%SYSTEM_CLASS_OF}},
        system_of       => '%',
        util            => '&',
    },
    {init => \&_init, action_of => {%ACTION_OF}},
);

# Initialises attributes.
sub _init {
    my $attrib_ref = shift();
    $attrib_ref->{util} = FCM::Util->new();
}

# Generates main functions.
sub _func  {
    my ($name, $code_ref) = @_;
    sub {
        my ($attrib_ref, @args) = @_;
        if (!defined($attrib_ref->{system_of}{$name})) {
            my $class_name = $attrib_ref->{system_class_of}{$name};
            $attrib_ref->{util}->class_load($class_name);
            $attrib_ref->{system_of}{$name} = $class_name->new({
                gui  => $attrib_ref->{gui},
                util => $attrib_ref->{util},
            });
        }
        local($S) = $attrib_ref->{system_of}{$name};
        $code_ref->(@args);
    };
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System

=head1 SYNOPSIS

    use FCM::System;
    $fcm = FCM::System->new();
    # ...
    $fcm->make(\%option, @args);

=head1 DESCRIPTION

Provides a top level interface to access the functionalities of the FCM system.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Returns a new instance. It also initialises the utility and sub-system classes.
The %attrib hash can be used configure the behaviour of the instance:

=over 4

=item event

A CODE to handle event.

=item gui

The GUI geometry of "fcm gui-internal".

=item system_class_of

A HASH to map (keys) sub-system names to (values) their implementation classes.
See %FCM::System::SYSTEM_CLASS_OF.

=item system_of

A HASH to map (keys) sub-system names to (values) their implementation instances.

=item util

An instance of L<FCM::Util|FCM::Util>.

=back

=item $fcm->browse(\%option,@args)

Invokes a browser to browse the sources in @args.

=item $fcm->build(\%option,@args)

(Obsolete) Invokes the FCM 1 build system.

=item $fcm->config_compare(\%option,@args)

(Obsolete) Compares 2 FCM 1 extract configuration files.

=item $fcm->config_parse(\%option,@args)

Parses a configuration file.

=item $fcm->cm_branch_create(\%option,@args)

Creates of a branch in a project in a Subversion repository with a standard FCM
layout.

=item $fcm->cm_branch_delete(\%option,@args)

Deletes of a branch in a project in a Subversion repository with a standard FCM
layout.

=item $fcm->cm_branch_diff(\%option,@args)

Displays the changes between a branch and its parent in a project in a
Subversion repository with a standard FCM layout.

=item $fcm->cm_branch_info(\%option,@args)

Displays information of a branch in a project in a Subversion repository with a
standard FCM layout.

=item $fcm->cm_branch_list(\%option,@args)

Lists branches in a project in a Subversion repository with a standard FCM
layout.

=item $fcm->cm_commit(\%option,@args)

Wraps C<svn commit>.

=item $fcm->cm_checkout(\%option,@args)

Wraps C<svn checkout>.

=item $fcm->cm_check_missing(\%option,@args)

Checks for missing status in a Subversion working copy.

=item $fcm->cm_check_unknown(\%option,@args)

Checks for unknown status in a Subversion working copy.

=item $fcm->cm_diff(\%option,@args)

Wraps C<svn diff>.

=item $fcm->cm_loc_layout(\%option,@args)

Parse and print layout information of each target in @args.

=item $fcm->cm_merge(\%option,@args)

Wraps C<svn merge>.

=item $fcm->cm_mkpatch(\%option,@args)

Creates FCM patches.

=item $fcm->cm_project_create(\%option,@args)

Create a new project in a Subversion repository.

=item $fcm->cm_resolve_conflicts(\%option,@args)

Invokes a graphic merge tool to resolve conflicts.

=item $fcm->cm_switch(\%option,@args)

Wraps C<svn switch>.

=item $fcm->cm_update(\%option,@args)

Wraps C<svn update>.

=item $fcm->export_items(\%option,@args)

Exports directories as versioned items in a branch of a project in a Subversion
repository with the standard FCM layout.

=item $fcm->extract(\%option,@args)

(Obsolete) Invokes the FCM 1 extract system.

=item $fcm->keyword_find(\%option,@args)

If @args is empty, search for all known FCM location keyword entries. Otherwise,
search for FCM location keyword entries matching the locations specified in
@args.

=item $fcm->make(\%option,@args)

Invokes the FCM make system.

=item $fcm->svn(\%option,@args)

Invokes C<svn> with @args. %option is ignored.

=item $fcm->util()

Returns the L<FCM::Util|FCM::Util> object.

=back

=head1 DIAGNOSTICS

=head2 FCM::System::Exception

This exception is a sub-class of L<FCM::Exception|FCM::Exception> and is thrown
by methods of this class on error.

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
