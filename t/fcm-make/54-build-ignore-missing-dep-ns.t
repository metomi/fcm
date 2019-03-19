#!/bin/bash
#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------
# Test build.prop{ignore-missing-dep-ns}
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
tests 7
#-------------------------------------------------------------------------------
cp -r "${TEST_SOURCE_DIR}/${TEST_KEY_BASE}/"* '.'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}"

run_fail "${TEST_KEY}-1" fcm make
sed -n '/bad or missing/p; /required by/p' 'fcm-make.log' >'fcm-make.log.edited'
file_cmp "${TEST_KEY}-1-log-edited" 'fcm-make.log.edited' <<'__LOG__'
[FAIL] hello_mod.mod: bad or missing dependency (type=1.include)
[FAIL]     required by: greet_mod.o
[FAIL]     required by: greet_mod.mod
[FAIL]     required by: greet.o
[FAIL]     required by: greet.bin
__LOG__

# Remove dependency from target
mkdir 'hello'
(cd 'hello'; gfortran -c '../src2/hello_mod.f90')
(cd 'hello'; ar rs 'libhello.a' 'hello_mod.o' 2>'/dev/null')
run_pass "${TEST_KEY}-2" fcm make \
    'build.prop{ignore-missing-dep-ns}=/'
sed -n '/^\[info\] target /p; /ignore-missing-dep:/p' 'fcm-make.log' \
    >"${TEST_KEY}.target.log"
file_cmp "${TEST_KEY}-2.target.log" "${TEST_KEY}.target.log" <<'__LOG__'
[WARN] greet_mod.o                   : ignore-missing-dep: (  include) hello_mod.mod
[info] target greet.bin
[info] target  - greet.o
[info] target  -  - greet_mod.mod
[info] target  -  -  - greet_mod.o
[info] target  - greet_mod.o
__LOG__

run_pass "${TEST_KEY}.greet" "${PWD}/build/bin/greet.bin"
file_cmp "${TEST_KEY}.greet.out" "${TEST_KEY}.greet.out" <<<'Greet world!'
file_cmp "${TEST_KEY}.greet.err" "${TEST_KEY}.greet.err" <'/dev/null'
#-------------------------------------------------------------------------------
exit 0
