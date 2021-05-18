#!/bin/bash
#-------------------------------------------------------------------------------
# Copyright (C) British Crown (Met Office) & Contributors.
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
# Test build.prop{dep.o}[target], etc.
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
tests 7
#-------------------------------------------------------------------------------
cp -r "${TEST_SOURCE_DIR}/${TEST_KEY_BASE}/"* '.'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}"

run_fail "${TEST_KEY}-1" fcm make
run_pass "${TEST_KEY}-1-log-grep" \
    grep -F '[FAIL] ! greet.bin           : update task failed' 'fcm-make.log'

# Explicitly add dependency to target
run_pass "${TEST_KEY}-2" fcm make 'build.prop{dep.o}[greet.bin]=greet_world.o'
grep '^\[info\] target ' 'fcm-make.log' >"${TEST_KEY}.target.log"
file_cmp "${TEST_KEY}-2.target.log" "${TEST_KEY}.target.log" <<'__LOG__'
[info] target greet.bin
[info] target  - greet.o
[info] target  - greet_world.o
__LOG__

run_pass "${TEST_KEY}.greet" "${PWD}/build/bin/greet.bin"
file_cmp "${TEST_KEY}.greet.out" "${TEST_KEY}.greet.out" <<<'Greet World'
file_cmp "${TEST_KEY}.greet.err" "${TEST_KEY}.greet.err" <'/dev/null'
#-------------------------------------------------------------------------------
exit 0
