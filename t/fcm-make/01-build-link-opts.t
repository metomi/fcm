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
# Tests some linker options for "fcm make".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 11
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
PATH=$PWD/bin:$PATH
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-keep-lib-o-incr"
fcm make -q
echo 'build.prop{keep-lib-o} = true' >>fcm-make.cfg
find build -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime.old"
run_pass "$TEST_KEY" fcm make
find build -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime"
if cmp -s "$TEST_KEY.mtime.old" "$TEST_KEY.mtime"; then
    fail "$TEST_KEY.mtime"
else
    pass "$TEST_KEY.mtime"
fi
file_grep "$TEST_KEY.mtime.grep" 'lib/libhello[.]a' "$TEST_KEY.mtime"
sed -i '/hello[.]exe/d' "$TEST_KEY.mtime.old"
sed -i '/libhello[.]a/d; /hello[.]exe/d' "$TEST_KEY.mtime"
file_cmp "$TEST_KEY.mtime.old" "$TEST_KEY.mtime.old" "$TEST_KEY.mtime"
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-keep-lib-o-new"
# echo 'build.prop{keep-lib-o} = true' >>fcm-make.cfg # already done above
run_pass "$TEST_KEY" fcm make --new
find build -type f | sort >"$TEST_KEY.find"
file_cmp "$TEST_KEY.find" "$TEST_KEY.find" <<'__OUT__'
build/bin/hello.exe
build/include/world.mod
build/lib/libhello.a
build/o/hello.o
build/o/world.o
__OUT__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-ld-incr"
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/fcm-make.cfg .
fcm make -q --new
find build -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime.old"
echo 'build.prop{ld} = my-ld' >>fcm-make.cfg
run_pass "$TEST_KEY" fcm make
find build -type f -exec stat -c'%Y %n' {} \; | sort >"$TEST_KEY.mtime"
file_grep "$TEST_KEY.mtime.grep" 'build/my-ld[.]out' "$TEST_KEY.mtime"
sed -i '/hello[.]exe/d' "$TEST_KEY.mtime.old"
sed -i '/hello[.]exe/d; /my-ld[.]out/d' "$TEST_KEY.mtime"
file_cmp "$TEST_KEY.mtime.old" "$TEST_KEY.mtime.old" "$TEST_KEY.mtime"
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-ld-new"
# echo 'build.prop{ld} = my-ld' >>fcm-make.cfg # already done above
run_pass "$TEST_KEY" fcm make --new
find build -type f | sort >"$TEST_KEY.find"
file_cmp "$TEST_KEY.find" "$TEST_KEY.find" <<'__OUT__'
build/bin/hello.exe
build/include/world.mod
build/my-ld.out
build/o/hello.o
build/o/world.o
__OUT__
#-------------------------------------------------------------------------------
exit 0
