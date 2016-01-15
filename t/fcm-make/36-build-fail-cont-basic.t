#!/bin/bash
#-------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-16 Met Office.
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
# Tests "fcm make", build, continue on failure.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header

task_lines_from_log() {
    sed '
        /\[\(info\|FAIL\)\] \(compile\+\?\|ext-iface\|install\|link\)  *\(----\|[0-9][0-9]*\.[0-9][0-9]*\) /!d
        s/  [0-9][0-9]*\.[0-9][0-9]* / ???? /
    ' fcm-make.log
}

fail_lines_from_log() {
    sed '/\[FAIL\] !/!d' fcm-make.log
}

#-------------------------------------------------------------------------------
tests 12
#-------------------------------------------------------------------------------
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
#-------------------------------------------------------------------------------
# Break hello1 and hello2
TEST_KEY="$TEST_KEY_BASE-1-2-bad"
sed -i 's/implicit none/implicit non/' src/greet_mod.f90  # introduce typo
run_fail "$TEST_KEY" fcm make --new
task_lines_from_log >"$TEST_KEY-log-tasks"
file_cmp "$TEST_KEY-log-tasks" "$TEST_KEY-log-tasks" <<'__LOG__'
[info] compile   ???? M world_mod.o          <- world_mod.f90
[FAIL] compile   ???? ! greet_mod.o          <- greet_mod.f90
[FAIL] compile   ---- ! hello2.o             <- hello2.f90
[info] compile   ???? M hello_sub.o          <- hello_sub.f90
[info] ext-iface ???? M hello_sub.interface  <- hello_sub.f90
[info] compile   ???? M hello3.o             <- hello3.f90
[info] link      ???? M hello3               <- hello3.f90
[info] compile   ???? M hello4.o             <- hello4.f90
[info] link      ???? M hello4               <- hello4.f90
__LOG__
fail_lines_from_log >"$TEST_KEY-log-fails"
file_cmp "$TEST_KEY-log-fails" "$TEST_KEY-log-fails" <<'__LOG__'
[FAIL] ! greet_mod.mod       : depends on failed target: greet_mod.o
[FAIL] ! greet_mod.o         : update task failed
[FAIL] ! hello2              : depends on failed target: hello2.o
[FAIL] ! hello2.o            : depends on failed target: greet_mod.mod
__LOG__

TEST_KEY="$TEST_KEY_BASE-1-2-fix"
sed -i 's/implicit non/implicit none/' src/greet_mod.f90  # fix typo
run_pass "$TEST_KEY" fcm make
task_lines_from_log >"$TEST_KEY-log-tasks"
file_cmp "$TEST_KEY-log-tasks" "$TEST_KEY-log-tasks" <<'__LOG__'
[info] compile   ---- U world_mod.o          <- world_mod.f90
[info] compile   ???? M greet_mod.o          <- greet_mod.f90
[info] compile   ???? M hello.o              <- hello.f90
[info] link      ???? M hello                <- hello.f90
[info] compile   ???? M hello2.o             <- hello2.f90
[info] link      ???? M hello2               <- hello2.f90
[info] compile   ---- U hello_sub.o          <- hello_sub.f90
[info] ext-iface ---- U hello_sub.interface  <- hello_sub.f90
[info] compile   ---- U hello3.o             <- hello3.f90
[info] link      ---- U hello3               <- hello3.f90
[info] compile   ---- U hello4.o             <- hello4.f90
[info] link      ---- U hello4               <- hello4.f90
__LOG__
fail_lines_from_log >"$TEST_KEY-log-fails"
file_cmp "$TEST_KEY-log-fails" "$TEST_KEY-log-fails" </dev/null
#-------------------------------------------------------------------------------
# Break hello3 and hello4
TEST_KEY="$TEST_KEY_BASE-3-4-bad"
sed -i 's/implicit none/implicit non/' src/hello_sub.f90  # introduce typo
run_fail "$TEST_KEY" fcm make --new
task_lines_from_log >"$TEST_KEY-log-tasks"
file_cmp "$TEST_KEY-log-tasks" "$TEST_KEY-log-tasks" <<'__LOG__'
[info] compile   ???? M world_mod.o          <- world_mod.f90
[info] compile   ???? M greet_mod.o          <- greet_mod.f90
[info] compile   ???? M hello.o              <- hello.f90
[info] link      ???? M hello                <- hello.f90
[info] compile   ???? M hello2.o             <- hello2.f90
[info] link      ???? M hello2               <- hello2.f90
[FAIL] compile   ???? ! hello_sub.o          <- hello_sub.f90
[info] ext-iface ???? M hello_sub.interface  <- hello_sub.f90
[info] compile   ???? M hello3.o             <- hello3.f90
[FAIL] link      ---- ! hello3               <- hello3.f90
[info] compile   ???? M hello4.o             <- hello4.f90
[FAIL] link      ---- ! hello4               <- hello4.f90
__LOG__
fail_lines_from_log >"$TEST_KEY-log-fails"
file_cmp "$TEST_KEY-log-fails" "$TEST_KEY-log-fails" <<'__LOG__'
[FAIL] ! hello3              : depends on failed target: hello_sub.o
[FAIL] ! hello4              : depends on failed target: hello_sub.o
[FAIL] ! hello_sub.o         : update task failed
__LOG__

TEST_KEY="$TEST_KEY_BASE-3-4-fix"
sed -i 's/implicit non/implicit none/' src/hello_sub.f90  # fix typo
run_pass "$TEST_KEY" fcm make
task_lines_from_log >"$TEST_KEY-log-tasks"
file_cmp "$TEST_KEY-log-tasks" "$TEST_KEY-log-tasks" <<'__LOG__'
[info] compile   ---- U world_mod.o          <- world_mod.f90
[info] compile   ---- U greet_mod.o          <- greet_mod.f90
[info] compile   ---- U hello.o              <- hello.f90
[info] link      ---- U hello                <- hello.f90
[info] compile   ---- U hello2.o             <- hello2.f90
[info] link      ---- U hello2               <- hello2.f90
[info] compile   ???? M hello_sub.o          <- hello_sub.f90
[info] ext-iface ???? U hello_sub.interface  <- hello_sub.f90
[info] compile   ---- U hello3.o             <- hello3.f90
[info] link      ???? M hello3               <- hello3.f90
[info] compile   ---- U hello4.o             <- hello4.f90
[info] link      ???? M hello4               <- hello4.f90
__LOG__
fail_lines_from_log >"$TEST_KEY-log-fails"
file_cmp "$TEST_KEY-log-fails" "$TEST_KEY-log-fails" </dev/null
#-------------------------------------------------------------------------------
exit 0
