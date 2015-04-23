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
# Tests for "fcm make", "build.prop{ns-dep.o}".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 4
set -e
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
set +e
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-bad"
run_fail "$TEST_KEY" fcm make
tail -2 .fcm-make/log >"$TEST_KEY.log" 2>/dev/null
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<'__LOG__'
[FAIL] world.o: same target from [lib/earth.f90, lib/moon.f90]
[FAIL]     required by: hello.exe
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
rm src/lib/moon.f90
run_pass "$TEST_KEY" fcm make
sed '/^\[info\] \(source->target\|target\) /!d' .fcm-make/log >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<'__LOG__'
[info] source->target / -> (archive) lib/ libo.a
[info] source->target lib -> (archive) lib/ lib/libo.a
[info] source->target lib/earth.f90 -> (install) include/ earth.f90
[info] source->target lib/earth.f90 -> (ext-iface) include/ earth.interface
[info] source->target lib/earth.f90 -> (compile) o/ world.o
[info] source->target lib/greet.f90 -> (install) include/ greet.f90
[info] source->target lib/greet.f90 -> (ext-iface) include/ greet.interface
[info] source->target lib/greet.f90 -> (compile) o/ greet.o
[info] source->target main -> (archive) lib/ main/libo.a
[info] source->target main/hello.f90 -> (link) bin/ hello.exe
[info] source->target main/hello.f90 -> (install) include/ hello.f90
[info] source->target main/hello.f90 -> (compile) o/ hello.o
[info] target hello.exe
[info] target  - greet.o
[info] target  - hello.o
[info] target  - world.o
__LOG__
#-------------------------------------------------------------------------------
exit 0
