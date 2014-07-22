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
# Tests "fcm make", include relative config
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header

run_tests() {
    local TEST_KEY=$1
    local HELLO_EXT=${2:-}
    rm -fr \
        .fcm-make \
        build \
        fcm-make-as-parsed.cfg \
        fcm-make-on-success.cfg \
        fcm-make.log
    run_pass "$TEST_KEY" fcm make
    cat "$TEST_KEY.err" >&2
    file_test "$TEST_KEY.hello$HELLO_EXT" $PWD/build/bin/hello$HELLO_EXT
    $PWD/build/bin/hello$HELLO_EXT >"$TEST_KEY.hello$HELLO_EXT.out"
    file_cmp "$TEST_KEY.hello$HELLO_EXT.out" \
        "$TEST_KEY.hello$HELLO_EXT.out" <<'__OUT__'
Hello World!
__OUT__
}
#-------------------------------------------------------------------------------
tests 6
#-------------------------------------------------------------------------------
mkdir cfg1 cfg2
cat >cfg1/fcm-make-head.cfg <<'__CFG__'
steps=build
build.source=src
__CFG__
cat >cfg1/fcm-make-tail.cfg <<'__CFG__'
build.target=hello.exe
__CFG__
cat >cfg2/fcm-make-tail.cfg <<'__CFG__'
build.target=hello
build.prop{file-ext.bin}=
__CFG__

mkdir src
cat >src/hello.f90 <<'__FORTRAN__'
program hello
write(*, '(a)') 'Hello World!'
end program hello
__FORTRAN__

#-------------------------------------------------------------------------------
cat >fcm-make.cfg <<'__CFG__'
include-path = $HERE/cfg1 $HERE/cfg2
include = fcm-make-head.cfg fcm-make-tail.cfg
__CFG__

run_tests "$TEST_KEY_BASE-1" .exe
#-------------------------------------------------------------------------------
cat >fcm-make.cfg <<'__CFG__'
include-path = $HERE/cfg2
include-path{+} = $HERE/cfg1
include = fcm-make-head.cfg fcm-make-tail.cfg
__CFG__

run_tests "$TEST_KEY_BASE-2"
#-------------------------------------------------------------------------------
exit 0
