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
# Tests "fcm make", ensure that steps can be declared before or after use=
# declaration.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 3
set -e
mkdir -p i0 i1 i2 i3
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* i0
fcm make -q -C i0
set +e
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-i1"
cat >i1/fcm-make.cfg <<'__FCM_MAKE_CFG__'
use=$HERE/../i0
__FCM_MAKE_CFG__
fcm make -q -C i1
find i1/*/bin -type f | sort >"$TEST_KEY.ls"
file_cmp "$TEST_KEY.ls" "$TEST_KEY.ls" <<'__LIST__'
i1/build1/bin/hello.exe
i1/build2/bin/salute.exe
i1/build3/bin/greet.exe
__LIST__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-i2"
cat >i2/fcm-make.cfg <<'__FCM_MAKE_CFG__'
step.class[build1 build2]=build
steps=build1 build2
use=$HERE/../i0
__FCM_MAKE_CFG__
fcm make -q -C i2
find i2/*/bin -type f | sort >"$TEST_KEY.ls"
file_cmp "$TEST_KEY.ls" "$TEST_KEY.ls" <<'__LIST__'
i2/build1/bin/hello.exe
i2/build2/bin/salute.exe
__LIST__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-i3"
cat >i3/fcm-make.cfg <<'__FCM_MAKE_CFG__'
use=$HERE/../i0
steps=build3
__FCM_MAKE_CFG__
fcm make -q -C i3
find i3/*/bin -type f | sort >"$TEST_KEY.ls"
file_cmp "$TEST_KEY.ls" "$TEST_KEY.ls" <<'__LIST__'
i3/build3/bin/greet.exe
__LIST__
#-------------------------------------------------------------------------------
exit 0
