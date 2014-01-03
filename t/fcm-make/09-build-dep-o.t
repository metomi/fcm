#!/bin/bash
#-------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-14 Met Office.
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
# Tests for "fcm make", "build.prop{dep.o}" top namespace.
# (Cyclic dependency bug in 2013-09.)
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 2
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
run_pass "$TEST_KEY" fcm make
sed '/\[info\] target /!d' .fcm-make/log >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<'__LOG__'
[info] target hi.exe
[info] target  - greet.o
[info] target  -  - greet_fmt_mod.mod
[info] target  -  -  - greet_fmt_mod.o
[info] target  - world.o
[info] target  - greet_fmt_mod.o
[info] target  - hi.o
[info] target hello.exe
[info] target  - greet.o (n-deps=1)
[info] target  - world.o
[info] target  - greet_fmt_mod.o
[info] target  - hello.o
__LOG__
#-------------------------------------------------------------------------------
exit 0
