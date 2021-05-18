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
# Tests for "fcm make", *.prop{class,*}.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 6
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
PATH=$PWD/bin:$PATH
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
run_pass "$TEST_KEY" fcm make
find build* -type f | sort >"$TEST_KEY.find"
sort >"${TEST_KEY}.find.expected" <<'__FIND__'
build/bin/hello.bin
build/o/hello.o
build_house/bin/hello_house
build_house/o/hello_house.o
build_office/bin/hello_office
build_office/o/hello_office.o
build_road/bin/hello_road
build_road/o/hello_road.o
__FIND__
file_cmp "$TEST_KEY.find" "$TEST_KEY.find" "${TEST_KEY}.find.expected"
sed '/^\[info\] shell(0.*) \(my-fc\|gfortran\)/!d; s/^\[info\] shell(0.*) //' \
    .fcm-make/log >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
my-fc -oo/hello.o -c -I./include $PWD/src/hello.f90
my-fc -obin/hello.bin o/hello.o
my-fc -oo/hello_house.o -c -I./include $PWD/src/hello_house.f90
my-fc -obin/hello_house o/hello_house.o
my-fc -oo/hello_office.o -c -I./include $PWD/src/hello_office.f90
my-fc -obin/hello_office o/hello_office.o
gfortran -oo/hello_road.o -c -I./include $PWD/src/hello_road.f90
gfortran -obin/hello_road o/hello_road.o
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-incr"
find build* -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime.old"
run_pass "$TEST_KEY" fcm make
find build* -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime"
file_cmp "$TEST_KEY.mtime" "$TEST_KEY.mtime.old" "$TEST_KEY.mtime"
sed '/^\[info\] \(compile\|link\)   targets:/!d; s/total-time=.*$//' \
    .fcm-make/log >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<'__LOG__'
[info] compile   targets: modified=0, unchanged=1, failed=0, 
[info] compile   targets: modified=0, unchanged=1, failed=0, 
[info] compile   targets: modified=0, unchanged=1, failed=0, 
[info] compile   targets: modified=0, unchanged=1, failed=0, 
__LOG__
#-------------------------------------------------------------------------------
exit 0
