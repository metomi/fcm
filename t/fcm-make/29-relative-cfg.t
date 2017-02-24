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
# Tests "fcm make", config as relative paths
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header

clean() {
    rm -fr \
        .fcm-make \
        build \
        fcm-make-as-parsed.cfg \
        fcm-make-on-success.cfg \
        fcm-make.log
}
#-------------------------------------------------------------------------------
tests 11
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"

mkdir etc
cat >etc/fcm-make.cfg <<'__CFG__'
steps=build
build.source=$HERE/../src
build.target=hello.exe
__CFG__

mkdir src
cat >src/hello.f90 <<'__FORTRAN__'
program hello
write(*, '(a)') 'Hello World!'
end program hello
__FORTRAN__

#-------------------------------------------------------------------------------
clean
run_fail "$TEST_KEY-control" fcm make
file_cmp "$TEST_KEY-control.err" "$TEST_KEY-control.err" <<'__ERROR__'
[FAIL] no configuration specified or found

__ERROR__
#-------------------------------------------------------------------------------
clean
run_pass "$TEST_KEY-pwd" fcm make -f etc/fcm-make.cfg
file_test "$TEST_KEY.hello.exe" $PWD/build/bin/hello.exe
$PWD/build/bin/hello.exe >"$TEST_KEY.hello.exe.out"
file_cmp "$TEST_KEY.hello.exe.out" "$TEST_KEY.hello.exe.out" <<'__OUT__'
Hello World!
__OUT__
#-------------------------------------------------------------------------------
clean
run_pass "$TEST_KEY-path" fcm make -F $PWD/etc
file_test "$TEST_KEY.hello.exe" $PWD/build/bin/hello.exe
$PWD/build/bin/hello.exe >"$TEST_KEY.hello.exe.out"
file_cmp "$TEST_KEY.hello.exe.out" "$TEST_KEY.hello.exe.out" <<'__OUT__'
Hello World!
__OUT__
#-------------------------------------------------------------------------------
clean
cd src
run_pass "$TEST_KEY-path" fcm make -C .. -f etc/fcm-make.cfg
file_test "$TEST_KEY.hello.exe" ../build/bin/hello.exe
../build/bin/hello.exe >"$TEST_KEY.hello.exe.out"
file_cmp "$TEST_KEY.hello.exe.out" "$TEST_KEY.hello.exe.out" <<'__OUT__'
Hello World!
__OUT__
cd ..
#-------------------------------------------------------------------------------
exit 0
