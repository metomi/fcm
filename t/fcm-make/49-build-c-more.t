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
# Test build C source file with mixed case name and has main function.
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
#-------------------------------------------------------------------------------
tests 8
cp -r "${TEST_SOURCE_DIR}/${TEST_KEY_BASE}/"* '.'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}"
run_pass "${TEST_KEY}" fcm make
grep '^\[info\] target ' fcm-make.log >"${TEST_KEY}.target.log"
file_cmp "${TEST_KEY}.target.log" "${TEST_KEY}.target.log" <<'__LOG__'
[info] target hi
[info] target  - hi.o
[info] target hello
[info] target  - hello.o
[info] target greet
[info] target  - greet.o
__LOG__

"${PWD}/build/bin/greet" >"${TEST_KEY}.greet.out"
run_pass "${TEST_KEY}.greet.rc" test $? -eq 12
file_cmp "${TEST_KEY}.greet.out" "${TEST_KEY}.greet.out" <<<'Greet World'

run_pass "${TEST_KEY}.hello" "${PWD}/build/bin/hello"
file_cmp "${TEST_KEY}.hello.out" "${TEST_KEY}.hello.out" <<<'Hello World'

"${PWD}/build/bin/hi" >"${TEST_KEY}.hi.out"
run_pass "${TEST_KEY}.hi.rc" test $? -eq 9
file_cmp "${TEST_KEY}.hi.out" "${TEST_KEY}.hi.out" <<<'Hi World'
#-------------------------------------------------------------------------------
exit 0
