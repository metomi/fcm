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
# Basic tests for "fcm make" C and C++ source.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header

function get_compiler_log() {
    sed '/^\[info\] shell(0.*) gcc\|g++/!d;
         s/^\[info\] shell(0.*) //' .fcm-make/log
}
#-------------------------------------------------------------------------------
tests 14
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
run_pass "$TEST_KEY" fcm make
find .fcm-make build -type f | sort >"$TEST_KEY.find"
file_cmp "$TEST_KEY.find" "$TEST_KEY.find" <<'__OUT__'
.fcm-make/config-as-parsed.cfg
.fcm-make/config-on-success.cfg
.fcm-make/ctx.gz
.fcm-make/log
build/bin/chello
build/bin/cxxhello
build/o/chello.o
build/o/cxxhello.o
__OUT__
run_pass "$TEST_KEY.chello" $PWD/build/bin/chello
file_cmp "$TEST_KEY.chello.out" "$TEST_KEY.chello.out" <<<'Hello C'
run_pass "$TEST_KEY.cxxhello" $PWD/build/bin/cxxhello
file_cmp "$TEST_KEY.cxxhello.out" "$TEST_KEY.cxxhello.out" <<<'Hello C++'
get_compiler_log >"$TEST_KEY.compiler.log"
file_cmp "$TEST_KEY.compiler.log" "$TEST_KEY.compiler.log" <<__LOG__
gcc -oo/chello.o -c -I./include $PWD/src/chello.c
gcc -obin/chello o/chello.o
g++ -oo/cxxhello.o -c -I./include $PWD/src/cxxhello.cxx
g++ -obin/cxxhello o/cxxhello.o
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-incr-0"
find build -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime.old"
run_pass "$TEST_KEY" fcm make
find build -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime"
file_cmp "$TEST_KEY.mtime" "$TEST_KEY.mtime.old" "$TEST_KEY.mtime"
get_compiler_log >"$TEST_KEY.compiler.log"
file_cmp "$TEST_KEY.compiler.log" "$TEST_KEY.compiler.log" </dev/null
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-incr-1"
export CCFLAGS=-O2
run_pass "$TEST_KEY" fcm make
get_compiler_log >"$TEST_KEY.compiler.log"
file_cmp "$TEST_KEY.compiler.log" "$TEST_KEY.compiler.log" <<__LOG__
gcc -oo/chello.o -c -I./include -O2 $PWD/src/chello.c
gcc -obin/chello o/chello.o
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-incr-2"
export CXXFLAGS=-O3
run_pass "$TEST_KEY" fcm make
get_compiler_log >"$TEST_KEY.compiler.log"
file_cmp "$TEST_KEY.compiler.log" "$TEST_KEY.compiler.log" <<__LOG__
g++ -oo/cxxhello.o -c -I./include -O3 $PWD/src/cxxhello.cxx
g++ -obin/cxxhello o/cxxhello.o
__LOG__
#-------------------------------------------------------------------------------
exit 0
