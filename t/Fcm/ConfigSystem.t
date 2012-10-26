#!/usr/bin/perl
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

use Fcm::CfgLine;
use Fcm::Config;
use Scalar::Util qw{reftype};
use Test::More (tests => 90);

BEGIN: {
    use_ok('Fcm::ConfigSystem');
}

my $CONFIG = undef;

# ------------------------------------------------------------------------------
if (!caller()) {
    main(@ARGV);
}

# ------------------------------------------------------------------------------
sub main {
    local @ARGV = @_;
    test_compare_setting_in_config();
}

# ------------------------------------------------------------------------------
# Tests "compare_setting_in_config".
sub test_compare_setting_in_config {
    my $PREFIX = 'TEST';
    my %S = (egg => [qw{boiled poached}], ham => 'roasted', bacon => 'fried');
    my %S_MOD = (ham => 'boiled');
    my %S_MOD_ARRAY = (egg => [qw{scrambled omelette}]);
    my %S_ADD = (mushroom => 'sauteed');
    my %S_DEL = (bacon => undef);

    my @ITEMS = (
        {
            name     => 'empty',
            original => {},
            added    => {},
            removed  => {},
            modified => {},
        },
        {
            name     => 'add keys to empty',
            original => {},
            added    => {%S},
            removed  => {},
            modified => {%S},
        },
        {
            name     => 'remove all',
            original => {%S},
            added    => {},
            removed  => {},
            modified => {map {($_, undef)} keys(%S)},
        },
        {
            name     => 'no change',
            original => {%S},
            added    => {%S},
            removed  => {},
            modified => {},
        },
        {
            name     => 'modify key',
            original => {%S},
            added    => {%S, %S_MOD},
            removed  => {},
            modified => {%S_MOD},
        },
        {
            name     => 'modify an array key',
            original => {%S},
            added    => {%S, %S_MOD_ARRAY},
            removed  => {},
            modified => {%S_MOD_ARRAY},
        },
        {
            name     => 'add a key',
            original => {%S},
            added    => {%S, %S_ADD},
            removed  => {},
            modified => {%S_ADD},
        },
        {
            name     => 'delete a key',
            original => {%S},
            added    => {%S},
            removed  => {%S_DEL},
            modified => {%S_DEL},
        },
        {
            name     => 'modify a key and delete a key',
            original => {%S},
            added    => {%S, %S_MOD},
            removed  => {%S_DEL},
            modified => {%S_MOD, %S_DEL},
        },
        {
            name     => 'add a key and delete a key',
            original => {%S},
            added    => {%S, %S_ADD},
            removed  => {%S_DEL},
            modified => {%S_ADD, %S_DEL},
        },
    );

    # A naive function to serialise an array reference
    my $flatten = sub {
        if (ref($_[0]) && reftype($_[0]) eq 'ARRAY') {
            join(q{ }, sort(@{$_[0]}))
        }
        else {
            $_[0];
        }
    };

    my $CONFIG = Fcm::Config->instance();
    for my $item (@ITEMS) {
        # New settings
        $CONFIG->{setting}{$PREFIX} = {%{$item->{added}}};
        for my $key (keys(%{$item->{removed}})) {
            delete($CONFIG->{setting}{$PREFIX}{$key});
        }

        # Old lines
        my @old_lines = map {
            Fcm::CfgLine->new(
                LABEL => $PREFIX . $Fcm::Config::DELIMITER . $_,
                VALUE => $flatten->($item->{original}{$_}),
            )
        } keys(%{$item->{original}});

        # Invokes the method
        my $system = Fcm::ConfigSystem->new();
        my ($changed_hash_ref, $new_cfg_lines_ref)
            = $system->compare_setting_in_config($PREFIX, \@old_lines);

        # Tests the return values
        my $T = $item->{name};
        is_deeply(
            $changed_hash_ref, $item->{modified},
            "$T: \$changed_hash_ref content",
        );
        is(
            scalar(@{$new_cfg_lines_ref}),
            scalar(keys(%{$item->{added}})) - scalar(keys(%{$item->{removed}})),
            "$T: \$new_cfg_lines_ref length",
        );
        for my $line (@{$new_cfg_lines_ref}) {
            my $key = $line->label_from_field(1);
            ok(exists($item->{added}{$key}), "$T: expected label $key");
            ok(!exists($item->{removed}{$key}), "$T: unexpected label $key");
            is(
                $line->value(), $flatten->($item->{added}{$key}),
                "$T: line content $key",
            );
        }
    }
}

__END__
