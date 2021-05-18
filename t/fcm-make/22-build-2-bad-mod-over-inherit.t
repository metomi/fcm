#!/bin/bash
#-------------------------------------------------------------------------------
# Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.
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
# Tests "fcm make", inherit build correctness. metomi/fcm#110
# * 2 source files with bad syntax override.
# * Build fails on first source file.
# * Fix first source file.
# * Build should fail on second source file.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 7
set -e
mkdir -p i0 i1
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/{fcm-make.cfg,src} i0
fcm make -q -C i0
set +e
#-------------------------------------------------------------------------------
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/src-i i1/src
cat >i1/fcm-make.cfg <<'__CFG__'
use=$HERE/../i0
build.source=$HERE/src
__CFG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-i1-1"
run_fail "$TEST_KEY" fcm make -q -C i1
file_grep "$TEST_KEY.err" '\[FAIL\].*i1/src/m1.f90' "$TEST_KEY.err"
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-i1-2"
sed 's/^writ/write/' $TEST_SOURCE_DIR/$TEST_KEY_BASE/src-i/m1.f90 >i1/src/m1.f90
run_fail "$TEST_KEY" fcm make -q -C i1
file_grep "$TEST_KEY.err" '\[FAIL\].*i1/src/m2.f90' "$TEST_KEY.err"
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-i1-3"
sed 's/^writ/write/' $TEST_SOURCE_DIR/$TEST_KEY_BASE/src-i/m2.f90 >i1/src/m2.f90
run_pass "$TEST_KEY" fcm make -q -C i1 --new
run_pass "$TEST_KEY.exe" $PWD/i1/build/bin/p1.exe
file_cmp "$TEST_KEY.exe.out" "$TEST_KEY.exe.out" <<'__OUT__'
Greet from m1-s1!
Greet from m2-s2!
__OUT__
#-------------------------------------------------------------------------------
exit
