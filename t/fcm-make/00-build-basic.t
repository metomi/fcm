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
# Basic tests for "fcm make".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 18
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
run_pass "$TEST_KEY" fcm make
find .fcm-make build -type f | sed 's/^\(\.fcm-make\/log\).*$/\1/' \
    | sort >"$TEST_KEY.find"
sort >"${TEST_KEY}.find.expected" <<'__OUT__'
.fcm-make/config-as-parsed.cfg
.fcm-make/config-on-success.cfg
.fcm-make/ctx.gz
.fcm-make/log
build/bin/hello.exe
build/include/world.mod
build/o/hello.o
build/o/world.o
__OUT__
file_cmp "$TEST_KEY.find" "$TEST_KEY.find" "${TEST_KEY}.find.expected"
file_test "$TEST_KEY.log" fcm-make.log
file_test "$TEST_KEY.fcm-make-as-parsed.cfg" fcm-make-as-parsed.cfg
file_test "$TEST_KEY.fcm-make-on-success.cfg" fcm-make-on-success.cfg
readlink fcm-make.log >"$TEST_KEY.log.readlink"
file_cmp "$TEST_KEY.log.readlink" "$TEST_KEY.log.readlink" <<<'.fcm-make/log'
sed '/^\[info\] \(source->target\|target\|required-target\) /!d' \
    .fcm-make/log >"$TEST_KEY.log.sed"
file_cmp "$TEST_KEY.log.sed" "$TEST_KEY.log.sed" <<'__LOG__'
[info] source->target / -> (archive) lib/ libo.a
[info] source->target hello.f90 -> (link) bin/ hello.exe
[info] source->target hello.f90 -> (install) include/ hello.f90
[info] source->target hello.f90 -> (compile) o/ hello.o
[info] source->target world.f90 -> (install) include/ world.f90
[info] source->target world.f90 -> (compile+) include/ world.mod
[info] source->target world.f90 -> (compile) o/ world.o
[info] target hello.exe
[info] target  - hello.o
[info] target  -  - world.mod
[info] target  -  -  - world.o
[info] target  - world.o
__LOG__
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
TEST_KEY="$TEST_KEY_BASE-incr-fail"
echo 'build.target=foo' >>fcm-make.cfg
run_fail "$TEST_KEY" fcm make
run_fail "$TEST_KEY.config-on-success" test -e .fcm-make/config-on-success
run_fail "$TEST_KEY.fcm-make-on-success.cfg" test -e fcm-make-on-success.cfg
#-------------------------------------------------------------------------------
exit 0
