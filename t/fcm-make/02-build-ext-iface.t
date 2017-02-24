#!/bin/bash
#-------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-17 Met Office.
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
# Tests build ext-iface for "fcm make".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 4
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
#-------------------------------------------------------------------------------
# Normal operation. Lots of examples in a single source file.
TEST_KEY="$TEST_KEY_BASE-t1"
TARGETS=t1.interface run_pass "$TEST_KEY" fcm make --new
file_cmp "$TEST_KEY.interface" build/include/t1.interface expected/t1.interface
#-------------------------------------------------------------------------------
# Bad syntax 1: missing close bracket ) in a local declaration statement.
# Hang at FCM-2-3-1.
# We can ignore this problem, as it does not add to the interface
TEST_KEY="$TEST_KEY_BASE-t2"
TARGETS=t2.interface run_fail "$TEST_KEY" fcm make --new
# Time may not be 0.0 on a very very slow computer
sed -i '2s/ [0-9][0-9]*\.[0-9][0-9]* / ?.? /' "$TEST_KEY.err"
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" <<__ERR__
[FAIL] $PWD/src/t2.f90(2): syntax error
[FAIL] ext-iface  ?.? ! t2.interface         <- t2.f90
[FAIL] ! t2.interface        : update task failed

__ERR__
#-------------------------------------------------------------------------------
exit 0
