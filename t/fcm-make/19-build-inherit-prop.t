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
# Tests "fcm make", ensure that properties can be declared before or after use=
# declaration.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 2
set -e
mkdir -p i0 i1 i2
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* i0
fcm make -q -C i0
set +e
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-i1"
cat >i1/fcm-make.cfg <<'__FCM_MAKE_CFG__'
use=$HERE/../i0
build.prop{fc.defs}=WORLD='"Mars"'
__FCM_MAKE_CFG__
fcm make -q -C i1
$PWD/i1/build/bin/hello.exe >"$TEST_KEY.exe.out"
file_cmp "$TEST_KEY.exe.out" "$TEST_KEY.exe.out" <<<'Hello Mars'
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-i2"
cat >i2/fcm-make.cfg <<'__FCM_MAKE_CFG__'
build.prop{fc.defs}=WORLD='"Venus"'
use=$HERE/../i0
__FCM_MAKE_CFG__
fcm make -q -C i2
$PWD/i2/build/bin/hello.exe >"$TEST_KEY.exe.out"
file_cmp "$TEST_KEY.exe.out" "$TEST_KEY.exe.out" <<<'Hello Venus'
#-------------------------------------------------------------------------------
exit 0
