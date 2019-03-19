# ------------------------------------------------------------------------------
# Copyright (C) 2006-2019 British Crown (Met Office) & Contributors.
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
package FCM::Util::ConfigUpgrade;
use base qw{FCM::Class::CODE};

use FCM::Context::ConfigEntry;

my %DECL_PATTERN_OF = (
    browser_mapping => qr{\A set::browser_mapping(?:_default|:: ([^:]+)):: (.+) \z}ixms,
    keyword_loc     => qr{\A set::(?:repos|url):: (.+) \z}ixms,
    keyword_rev     => qr{\A set::revision:: ([^:]+) :: (.+) \z}ixms,
);
my @UPGRADE_FUNCS = (
    \&_upgrade_browser_mapping_decl,
    \&_upgrade_keyword_loc_decl,
    \&_upgrade_keyword_rev_decl,
);

# Creates the class.
__PACKAGE__->class({}, {action_of => {upgrade => \&_upgrade}});

sub _upgrade {
    my ($attrib_ref, $config_entry) = @_;
    if (!defined($config_entry)) {
        return;
    }
    for my $func (@UPGRADE_FUNCS) {
        $func->($config_entry);
        if ($func->($config_entry)) {
            return $config_entry;
        }
    }
    return $config_entry;
}

# Upgrades a browser mapping declaration.
sub _upgrade_browser_mapping_decl {
    my ($config_entry) = @_;
    my ($ns, $key)
        = $config_entry->get_label() =~ $DECL_PATTERN_OF{browser_mapping};
    if (!$key) {
        return;
    }
    $config_entry->set_label(
          $key eq 'browser_url_template' ? 'browser.loc-tmpl'
        : $key eq 'browser_rev_template' ? 'browser.rev-tmpl'
        :                                  'browser.comp-pat'
    );
    if ($ns) {
        $config_entry->set_ns_list([$ns]);
    }
}

# Upgrades a location keyword declaration.
sub _upgrade_keyword_loc_decl {
    my ($config_entry) = @_;
    my ($ns) = $config_entry->get_label() =~ $DECL_PATTERN_OF{keyword_loc};
    if (!$ns) {
        return;
    }
    $config_entry->set_label('location');
    $config_entry->get_modifier_of()->{primary} = 1;
    $config_entry->set_ns_list([$ns]);
}

# Upgrades a revision keyword declaration.
sub _upgrade_keyword_rev_decl {
    my ($config_entry) = @_;
    my ($ns, $key) = $config_entry->get_label() =~ $DECL_PATTERN_OF{keyword_rev};
    if (!$ns || !$key) {
        return;
    }
    $config_entry->set_label('revision');
    $config_entry->set_ns_list([$ns, $key]);
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Util::ConfigUpgrade

=head1 SYNOPSIS

    use FCM::Util::ConfigUpgrade;
    $upgrade = FCM::Util::ConfigUpgrade->new();
    if (!$upgrade->($entry)) {
        die($entry->get_label(), ": cannot upgrade.\n");
    }
    # ... do something with $entry

=head1 DESCRIPTION

Provides a utility to upgrade FCM 1 configuration to FCM 2 configuration.

=head1 METHODS

=over 4

=item $class->new()

Creates and returns a new instance of this utility.

=item $util->($entry)

Upgrades the content of $entry, where possible. Only keyword related
declarations in the FCM 1 common configuration files are currently supported.

=back

=head1 COPYRIGHT

Copyright (C) 2006-2019 British Crown (Met Office) & Contributors..

=cut
