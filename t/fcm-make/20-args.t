#!/bin/bash
#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------
# Tests "fcm make", CLI arguments.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 6
set -e
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
set +e
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-hello"
run_pass "$TEST_KEY" fcm make 'build.prop{file-ext.bin}=' 'build.target=hello'
grep '^\[info\] required-target:' .fcm-make/log >$TEST_KEY.log
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<'__LOG__'
[info] required-target: link      bin     hello
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-greet"
run_pass "$TEST_KEY" fcm make 'build.target=greet.exe'
grep '^\[info\] required-target:' .fcm-make/log >$TEST_KEY.log
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<'__LOG__'
[info] required-target: link      bin     greet.exe
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-new-greet"
run_pass "$TEST_KEY" fcm make --new 'build.target=greet.exe'
grep '^\[info\] required-target:' .fcm-make/log >$TEST_KEY.log
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<'__LOG__'
[info] required-target: link      bin     greet.exe
__LOG__
#-------------------------------------------------------------------------------
exit 0
