# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-2012 Met Office.
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
package FCM::Context::Keyword;
use base qw{FCM::Class::HASH};

use constant {
    BROWSER_CONFIG    => 'FCM::Context::Keyword::BrowserConfig',
    ENTRY             => 'FCM::Context::Keyword::Entry',
    ENTRY_OF_LOCATION => 'FCM::Context::Keyword::Entry::Location',
};

use Scalar::Util qw{blessed};

__PACKAGE__->class({
    entry_class    => {w => 0, isa => '$', default => ENTRY_OF_LOCATION},
    entry_by_key   => {w => 0, isa => '%'},
    entry_by_value => {w => 0, isa => '%'},
});

sub add_entry {
    my $self = shift();
    my ($key, $value, $entry);
    if (blessed($_[0])) {
        $entry = $_[0];
        $key   = $entry->get_key();
        $value = $entry->get_value();
    }
    else {
        ($key, $value, my $attrib_ref) = @_;
        $attrib_ref ||= {};
        $entry = $self->get_entry_class()->new({
            key => lc($key), value => $value, %{$attrib_ref},
        });
    }
    $self->{entry_by_key}{lc($key)} = $entry;
    $self->{entry_by_value}{$value} = $entry;
    return $entry;
}

# ------------------------------------------------------------------------------
package FCM::Context::Keyword::BrowserConfig;
use base qw{FCM::Class::HASH};

__PACKAGE__->class({comp_pat => undef, loc_tmpl => '$', rev_tmpl => '$'});

# ------------------------------------------------------------------------------
package FCM::Context::Keyword::Entry;
use base qw{FCM::Class::HASH};

__PACKAGE__->class({
    key   => {w => 0, isa => '$'},
    value => {w => 0, isa => '$'},
});

# ------------------------------------------------------------------------------
package FCM::Context::Keyword::Entry::Location;
use base qw{FCM::Context::Keyword::Entry};

my $CTX = 'FCM::Context::Keyword';

__PACKAGE__->class(
    {   browser_config  => $CTX->BROWSER_CONFIG,
        ctx_of_implied  => $CTX,
        ctx_of_rev      => $CTX,
        implied         => {isa => '$', default => 0},
        key             => {isa => '$', w => 0},
        loaded_rev_prop => '$',
        type            => '$',
        value           => {isa => '$', w => 0},
    },
    {   init => sub {
            my ($self) = @_;
            if (!$self->get_implied()) {
                $self->{browser_config} = $CTX->BROWSER_CONFIG->new();
                $self->{ctx_of_implied} = $CTX->new();
                $self->{ctx_of_rev} = $CTX->new({entry_class => $CTX->ENTRY});
            }
        },
    },
);

# Returns true if this is an implied entry
sub is_implied {
    $_[0]->{implied};
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Context::Keyword

=head1 SYNOPSIS

    use FCM::Context::Keyword;

=head1 DESCRIPTION

Provides a context object for the FCM keyword utility. All the classes described
below are sub-classes of L<FCM::Class::HASH|FCM::Class::HASH>.

=head1 OBJECTS

=head2 FCM::Context::Keyword

An object of this class is used to store a list of keyword entries. It has the
following methods:

=over 4

=item $instance->add_entry($key,$value,\%attrib)

Creates and adds a new entry.

=item $instance->add_entry($entry)

Adds a new entry.

=item $instance->get_entry_class()

Returns the class of the entry stored by this context.

=item $instance->get_entry_by_key()

Returns a HASH reference to map the entry keys with the entry objects.

=item $instance->get_entry_by_value()

Returns a HASH reference to map the entry values with the entry objects.

=back

=head2 FCM::Context::Keyword::BrowserConfig

An object of this class is used to store the configuration for mapping a
location to a browser URL. It has the following attributes:

=over 4

=item comp_pat

The pattern for extracting components from a locator, for putting into the
browser location template.

=item loc_tmpl

The browser location template.

=item rev_tmpl

The browser revision template.

=back

=head2 FCM::Context::Keyword::Entry

This is used to store a simple keyword entry (e.g. for revision keywords). It
has 2 attributes, the I<key> and the I<value>.

=head2 FCM::Context::Keyword::Entry::Location

This is a sub-class of FCM::Context::Keyword::Entry, and is used to store a
location keyword entry. It has the following additional attributes:

=over 4

=item browser_config

The configuration L</FCM::Context::Keyword::BrowserConfig> for mapping this
location to a browser URL.

=item ctx_of_implied

The context </FCM::Context::Keyword> object of the implied entries, if this
entry is a primary location.

=item ctx_of_rev

The context </FCM::Context::Keyword> object of the revision keywords.

=item implied

A flag to indicate that this is an entry implied by a primary location.

=item loaded_rev_prop

A flag to indicate that a previous attempt is made to load revision keywords
from the I<property> of the location.

=item type

The location type.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
