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
# Test "fcm make", build.prop{*}[target].
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 5
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
PATH=$PWD/bin:$PATH
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
run_pass "$TEST_KEY" fcm make
find .fcm-make build -type f | sort >"$TEST_KEY.find"
file_cmp "$TEST_KEY.find" "$TEST_KEY.find" <<'__OUT__'
.fcm-make/config-as-parsed.cfg
.fcm-make/config-on-success.cfg
.fcm-make/ctx.gz
.fcm-make/log
build/bin/hello.exe
build/include/world.mod
build/o/hello.o
build/o/world.o
__OUT__
sed '
    /\[info\] shell(0.*) \(gfortran\|my-fc\)/!d;
    /hello\.exe/d;
    s/^\[info\] shell(0.*) //
' .fcm-make/log >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
my-fc -oo/world.o -c -I./include $PWD/src/world.f90
gfortran -oo/hello.o -c -I./include $PWD/src/hello.f90
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-incr"
find build -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime.old"
run_pass "$TEST_KEY" fcm make
find build -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime"
file_cmp "$TEST_KEY.mtime" "$TEST_KEY.mtime.old" "$TEST_KEY.mtime"
#-------------------------------------------------------------------------------
exit 0
