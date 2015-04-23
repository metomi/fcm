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
# Tests "fcm make", "build.prop{dep.o}" top namespace, complicated by a module.
# See also "09-build.dep-o.t".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 2
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
run_pass "$TEST_KEY" fcm make
sed '/^\[info\] \(source->target\|target\) /!d' .fcm-make/log >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<'__LOG__'
[info] source->target / -> (archive) lib/ libo.a
[info] source->target hello.f90 -> (link) bin/ hello.exe
[info] source->target hello.f90 -> (install) include/ hello.f90
[info] source->target hello.f90 -> (compile) o/ hello.o
[info] source->target hello_mod.f90 -> (install) include/ hello_mod.f90
[info] source->target hello_mod.f90 -> (compile+) include/ hello_mod.mod
[info] source->target hello_mod.f90 -> (compile) o/ hello_mod.o
[info] source->target hello_sub.f90 -> (install) include/ hello_sub.f90
[info] source->target hello_sub.f90 -> (ext-iface) include/ hello_sub.interface
[info] source->target hello_sub.f90 -> (compile) o/ hello_sub.o
[info] target hello.exe
[info] target  - hello.o
[info] target  - hello_mod.o
[info] target  - hello_sub.o
[info] target  -  - hello_mod.mod
[info] target  -  -  - hello_mod.o
__LOG__
#-------------------------------------------------------------------------------
exit 0
