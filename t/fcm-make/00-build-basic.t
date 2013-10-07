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
# Basic tests for "fcm make".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 12
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
build/bin/hello.exe
build/include/world.mod
build/o/hello.o
build/o/world.o
__OUT__
file_test "$TEST_KEY.log" fcm-make.log
readlink fcm-make.log >"$TEST_KEY.log.out"
file_cmp "$TEST_KEY.log.out" "$TEST_KEY.log.out" <<<'.fcm-make/log'
file_test "$TEST_KEY-as-parsed.cfg" fcm-make-as-parsed.cfg
readlink fcm-make-as-parsed.cfg >"$TEST_KEY-as-parsed.cfg.out"
file_cmp "$TEST_KEY-as-parsed.cfg.out" "$TEST_KEY-as-parsed.cfg.out" \
    <<<'.fcm-make/config-as-parsed.cfg'
file_test "$TEST_KEY-on-success.cfg" fcm-make-on-success.cfg 
readlink fcm-make-on-success.cfg >"$TEST_KEY-on-success.cfg.out"
file_cmp "$TEST_KEY-on-success.cfg.out" "$TEST_KEY-on-success.cfg.out" \
    <<<'.fcm-make/config-on-success.cfg'
run_pass "$TEST_KEY.exe" $PWD/build/bin/hello.exe
file_cmp "$TEST_KEY.exe.out" "$TEST_KEY.exe.out" <<<'Hello Earth'
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-incr"
find build -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime.old"
run_pass "$TEST_KEY" fcm make
find build -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime"
file_cmp "$TEST_KEY.mtime" "$TEST_KEY.mtime.old" "$TEST_KEY.mtime"
#-------------------------------------------------------------------------------
exit 0
