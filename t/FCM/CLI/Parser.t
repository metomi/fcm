#!/usr/bin/env perl
# ------------------------------------------------------------------------------
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
# ------------------------------------------------------------------------------
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../../lib";
use Test::More (tests => 8);

BEGIN {
    use_ok('FCM::CLI::Parser');
}

my @MAIN_TESTS = (
    [
        [qw{foo bar baz}],
        ['foo', {}, qw{bar baz}],
    ],
    [
        [qw{add --check}],
        ['add', {check => 1}],
    ],
    [
        [qw{ci --help}],
        ['help', {}, qw{commit}],
    ],
    [
        [qw{di -g}],
        ['diff', {}, qw{--diff-cmd fcm_graphic_diff}],
    ],
    [
        [qw{di -b -g}],
        ['diff', {branch => 1, 'diff-cmd' => 'fcm_graphic_diff'}],
    ],
    [
        [qw{sw --relocate foo bar}],
        ['switch', {}, qw{--relocate foo bar}],
    ],
    [
        [qw{sw -q -q foo bar}],
        ['switch', {quiet => 2}, qw{foo bar}],
    ],
);

if (!caller()) {
    main(@ARGV);
}

# ------------------------------------------------------------------------------
# The main logic.
sub main {
    my $parser = FCM::CLI::Parser->new();
    for (@MAIN_TESTS) {
        my ($input_ref, $output_ref, $is_err) = @{$_};
        my $name = join(q{ }, @{$input_ref});
        local($@);
        eval {
            is_deeply([$parser->parse(@{$input_ref})], $output_ref, $name);
        };
        if (my $e = $@) {
            fail("$name: $e");
        }
    }
}

__END__
