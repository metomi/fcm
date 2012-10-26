#!/usr/bin/perl
#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../../lib";
use Test::More (tests => 3);

#-------------------------------------------------------------------------------
package Meal;
use base qw{FCM::Class::HASH};
__PACKAGE__->class({
    eggs => {isa => 'ARRAY', default => [qw{fried fried}]},
    ham  => {isa => 'HASH' , default => {boiled => 1, roasted => 2}},
});

#-------------------------------------------------------------------------------
package main;

if (!caller()) {
    test_simple();
}

# Tests simple class.
sub test_simple {
    my $meal = Meal->new();
    isa_ok($meal, 'Meal');
    is_deeply(
        $meal, {eggs => [qw{fried fried}], ham => {boiled => 1, roasted => 2}},
        'simple: new',
    );
    $meal->set_eggs([qw{boiled boiled}]);
    is_deeply(
        $meal,
        {
            eggs  => [qw{boiled boiled}],
            ham   => {boiled => 1, roasted => 2},
        },
        'simple: set',
    );
}
