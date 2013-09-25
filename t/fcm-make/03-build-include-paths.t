#!/bin/bash
#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------
# Tests for "fcm make", "build.prop{fc.include-paths}".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 8
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-control"
run_fail "$TEST_KEY" fcm make
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
FCM_TEST_FC_INCLUDE_PATHS="$PWD/include/world1 $PWD/include/world2" \
    run_pass "$TEST_KEY" fcm make
$PWD/build/bin/hello.exe >"$TEST_KEY.command.out"
file_cmp "$TEST_KEY.command.out" "$TEST_KEY.command.out" <<<'Hello Earth'
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-incr0"
find build -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime.old"
FCM_TEST_FC_INCLUDE_PATHS="$PWD/include/world1 $PWD/include/world2" \
    run_pass "$TEST_KEY" fcm make
find build -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime"
file_cmp "$TEST_KEY.mtime" "$TEST_KEY.mtime.old" "$TEST_KEY.mtime"
$PWD/build/bin/hello.exe >"$TEST_KEY.command.out"
file_cmp "$TEST_KEY.command.out" "$TEST_KEY.command.out" <<<'Hello Earth'
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-incr1"
FCM_TEST_FC_INCLUDE_PATHS="$PWD/include/world2 $PWD/include/world1" \
    run_pass "$TEST_KEY" fcm make
$PWD/build/bin/hello.exe >"$TEST_KEY.command.out"
file_cmp "$TEST_KEY.command.out" "$TEST_KEY.command.out" <<<'Hello Moon'
#-------------------------------------------------------------------------------
exit 0
