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
# Test build, handle Fortran program unit with tail comments
# https://github.com/metomi/fcm/issues/252
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
tests 5
#-------------------------------------------------------------------------------
cp -r "${TEST_SOURCE_DIR}/${TEST_KEY_BASE}/"* '.'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}"

run_pass "${TEST_KEY}" fcm make
sed -n '/source->target greet_mod.f90/p' 'fcm-make.log' >'fcm-make.log.edited'
file_cmp "${TEST_KEY}.target.log" 'fcm-make.log.edited' <<'__LOG__'
[info] source->target greet_mod.f90 -> (install) include/ greet_mod.f90
[info] source->target greet_mod.f90 -> (compile+) include/ greet_mod.mod
[info] source->target greet_mod.f90 -> (compile) o/ greet_mod.o
__LOG__

run_pass "${TEST_KEY}.greet" "${PWD}/build/bin/greet.exe"
file_cmp "${TEST_KEY}.greet.out" "${TEST_KEY}.greet.out" <<<'Greet World'
file_cmp "${TEST_KEY}.greet.err" "${TEST_KEY}.greet.err" <'/dev/null'
#-------------------------------------------------------------------------------
exit 0
