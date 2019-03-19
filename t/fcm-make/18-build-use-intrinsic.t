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
# Tests "fcm make", build, Fortran source file, "use, intrinsic" statement.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 7
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
run_pass "$TEST_KEY" fcm make
sed '/^\[info\] target /!d' .fcm-make/log >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<'__LOG__'
[info] target greet.exe
[info] target  - greet.o
[info] target  -  - hello.interface
[info] target  -  - hi.interface
[info] target  - hello.o
[info] target  - hi.o
__LOG__
file_cmp "$TEST_KEY.hello.interface" "build/include/hello.interface" \
    <<'__INTERFACE__'
interface
subroutine hello()
end subroutine hello
end interface
__INTERFACE__
file_cmp "$TEST_KEY.hi.interface" "build/include/hi.interface" \
    <<'__INTERFACE__'
interface
subroutine hi()
use, intrinsic :: iso_fortran_env
end subroutine hi
end interface
__INTERFACE__
run_pass "$TEST_KEY.exe" ./build/bin/greet.exe
file_cmp "$TEST_KEY.exe.out" "$TEST_KEY.exe.out" <<'__OUT__'
Hello
Hi
__OUT__
file_cmp "$TEST_KEY.exe.err" "$TEST_KEY.exe.err" </dev/null
#-------------------------------------------------------------------------------
exit 0
