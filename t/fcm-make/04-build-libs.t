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
# Tests for "fcm make", "build.prop{fc.lib-paths}" and "build.prop{fc.libs}".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header

function get_linker_log() {
    sed '/^\[info\] shell(0.*) gfortran/!d;
         s/^\[info\] shell(0.*) //' .fcm-make/log
}
#-------------------------------------------------------------------------------
tests 11
set -e
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
gfortran -c src-lib/*
mkdir -p greet/lib
ar rs greet/lib/libgreet.a greet.o 2>/dev/null
ar rs greet/lib/libearth.a earth.o 2>/dev/null
ar rs greet/lib/libmoon.a moon.o 2>/dev/null
rm *.o
set +e
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-control"
run_fail "$TEST_KEY" fcm make
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
FCM_TEST_FC_LIBS='greet earth' run_pass "$TEST_KEY" fcm make
$PWD/build/bin/hello.exe >"$TEST_KEY.command.out"
file_cmp "$TEST_KEY.command.out" "$TEST_KEY.command.out" <<<'Hello Earth'
get_linker_log >"$TEST_KEY.gfortran.log"
file_cmp "$TEST_KEY.gfortran.log" "$TEST_KEY.gfortran.log" <<__LOG__
gfortran -obin/hello.exe o/hello.o -L$PWD/greet/lib -lgreet -learth
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-incr0"
find build -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime.old"
FCM_TEST_FC_LIBS='greet earth' run_pass "$TEST_KEY" fcm make
find build -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime"
file_cmp "$TEST_KEY.mtime" "$TEST_KEY.mtime.old" "$TEST_KEY.mtime"
$PWD/build/bin/hello.exe >"$TEST_KEY.command.out"
file_cmp "$TEST_KEY.command.out" "$TEST_KEY.command.out" <<<'Hello Earth'
get_linker_log >"$TEST_KEY.gfortran.log"
file_cmp "$TEST_KEY.gfortran.log" "$TEST_KEY.gfortran.log" </dev/null
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-incr1"
FCM_TEST_FC_LIBS='greet moon' run_pass "$TEST_KEY" fcm make
$PWD/build/bin/hello.exe >"$TEST_KEY.command.out"
file_cmp "$TEST_KEY.command.out" "$TEST_KEY.command.out" <<<'Hello Moon'
get_linker_log >"$TEST_KEY.gfortran.log"
file_cmp "$TEST_KEY.gfortran.log" "$TEST_KEY.gfortran.log" <<__LOG__
gfortran -obin/hello.exe o/hello.o -L$PWD/greet/lib -lgreet -lmoon
__LOG__
#-------------------------------------------------------------------------------
exit 0
