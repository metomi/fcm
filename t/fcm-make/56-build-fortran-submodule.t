#!/bin/bash
#-------------------------------------------------------------------------------
# Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.
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
# Test build, handle Fortran submodule
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
tests 5
#-------------------------------------------------------------------------------
cp -r "${TEST_SOURCE_DIR}/${TEST_KEY_BASE}/"* '.'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}"

run_pass "${TEST_KEY}" fcm make
sed -n '/\[info\] target /p' 'fcm-make.log' >'fcm-make.log.edited'
file_cmp "${TEST_KEY}.target.log" 'fcm-make.log.edited' <<'__LOG__'
[info] target test.exe
[info] target  - class_impl.o
[info] target  - class_mod.o
[info] target  - simple_impl.o
[info] target  - simple_mod.o
[info] target  - test.o
[info] target  -  - class_mod.mod
[info] target  -  -  - class_mod.o
[info] target  -  - simple_mod.mod
[info] target  -  -  - simple_mod.o
__LOG__

run_pass "${TEST_KEY}.test" "${PWD}/build/bin/test.exe"
file_cmp "${TEST_KEY}.test.out" "${TEST_KEY}.test.out" <<'__OUT__'
Returner 14

Start with 12
After mangle 29
__OUT__
file_cmp "${TEST_KEY}.test.err" "${TEST_KEY}.test.err" <'/dev/null'
#-------------------------------------------------------------------------------
exit 0
