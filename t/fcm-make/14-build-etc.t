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
# Test "fcm make", build etc files, broken at 2013-11 due to:
# build.prop{class,file-she.script} = #!
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 5
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
PATH=$PWD/bin:$PATH
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
run_pass "$TEST_KEY" fcm make
find build -type f | sort >"$TEST_KEY.find"
file_cmp "$TEST_KEY.find" "$TEST_KEY.find" <<'__OUT__'
build/bin/foo
build/etc/.etc
build/etc/hello.txt
build/etc/hi/.etc
build/etc/hi/hi-earth.txt
build/etc/hi/hi-mars.txt
__OUT__
sed '
    /\[info\] install/!d;
    /\[info\] install  *targets:/d;
    s/^\[info\] install *[^ ]* M //
' .fcm-make/log >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<'__LOG__'
foo                  <- foo
hello.txt            <- hello.txt
hi/hi-earth.txt      <- hi/hi-earth.txt
hi/hi-mars.txt       <- hi/hi-mars.txt
.etc                 <- 
hi/.etc              <- hi
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-incr"
find build -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime.old"
run_pass "$TEST_KEY" fcm make
find build -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime"
file_cmp "$TEST_KEY.mtime" "$TEST_KEY.mtime.old" "$TEST_KEY.mtime"
#-------------------------------------------------------------------------------
exit 0
