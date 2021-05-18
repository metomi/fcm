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
# Tests "fcm make", build detects dependencies in OMP sentinels.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 16
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
yes 6.0 | head -n 100 >"$TEST_KEY_BASE.exe.on.out"
yes 1.0 | head -n 100 >"$TEST_KEY_BASE.exe.off.out"
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-on # fc.flag-omp on in new mode
run_pass "$TEST_KEY" fcm make
grep ' !\$' fcm-make.log | sort >"$TEST_KEY.log.deps"
sort >"${TEST_KEY}.log.deps.expected" <<'__LOG__'
[info]              -> (  include) !$i1.f90
[info]              -> (  include) !$i2.f90
[info]              -> ( f.module) !$m1
[info]              -> ( f.module) !$m2
__LOG__
file_cmp "${TEST_KEY}.log.deps" \
    "${TEST_KEY}.log.deps" "${TEST_KEY}.log.deps.expected"
run_pass "$TEST_KEY.exe" $PWD/build/bin/p1.exe
file_cmp "$TEST_KEY.exe.out" "$TEST_KEY_BASE.exe.on.out" "$TEST_KEY.exe.out"
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-on-off # fc.flag-omp on->off in incremental mode
echo 'build.prop{fc.flag-omp}=' >>fcm-make.cfg
run_pass "$TEST_KEY" fcm make
run_pass "$TEST_KEY.exe" $PWD/build/bin/p1.exe
file_cmp "$TEST_KEY.exe.out" "$TEST_KEY_BASE.exe.off.out" "$TEST_KEY.exe.out"
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-on-off-on # fc.flag-omp on->off->on in incremental mode
echo 'build.prop{fc.flag-omp}=-fopenmp' >>fcm-make.cfg
run_pass "$TEST_KEY" fcm make
run_pass "$TEST_KEY.exe" $PWD/build/bin/p1.exe
file_cmp "$TEST_KEY.exe.out" "$TEST_KEY_BASE.exe.on.out" "$TEST_KEY.exe.out"
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-off # fc.flag-omp off in new mode
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/fcm-make.cfg .
echo 'build.prop{fc.flag-omp}=' >>fcm-make.cfg
run_pass "$TEST_KEY" fcm make --new
run_pass "$TEST_KEY.exe" $PWD/build/bin/p1.exe
file_cmp "$TEST_KEY.exe.out" "$TEST_KEY_BASE.exe.off.out" "$TEST_KEY.exe.out"
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-off-on # fc.flag-omp off->on in incremental mode
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/fcm-make.cfg .
run_pass "$TEST_KEY" fcm make
run_pass "$TEST_KEY.exe" $PWD/build/bin/p1.exe
file_cmp "$TEST_KEY.exe.out" "$TEST_KEY_BASE.exe.on.out" "$TEST_KEY.exe.out"
#-------------------------------------------------------------------------------
exit
