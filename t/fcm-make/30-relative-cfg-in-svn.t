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
# Tests "fcm make", relative config in a Subversion repository
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header

run_tests() {
    local TEST_KEY=$1
    local AT_REV=${2:-}
    rm -fr \
        .fcm-make \
        build \
        fcm-make-as-parsed.cfg \
        fcm-make-on-success.cfg \
        fcm-make.log
    run_pass "$TEST_KEY" \
        fcm make -F file://$PWD/svn-repos$AT_REV -f etc/fcm-make.cfg
    file_test "$TEST_KEY.hello.exe" $PWD/build/bin/hello.exe
    $PWD/build/bin/hello.exe >"$TEST_KEY.hello.exe.out"
    file_cmp "$TEST_KEY.hello.exe.out" "$TEST_KEY.hello.exe.out" <<'__OUT__'
Hello World!
__OUT__
}
#-------------------------------------------------------------------------------
tests 9
#-------------------------------------------------------------------------------
mkdir etc
cat >etc/fcm-make.cfg <<'__CFG__'
steps=build
build.source=src
build.target=hello.exe
__CFG__

mkdir src
cat >src/hello.f90 <<'__FORTRAN__'
program hello
write(*, '(a)') 'Hello World!'
end program hello
__FORTRAN__

svnadmin create svn-repos
svn import -m 'test stuff' etc file://$PWD/svn-repos/etc
rm -fr etc

#-------------------------------------------------------------------------------
run_tests "$TEST_KEY_BASE"
run_tests "$TEST_KEY_BASE-1" '@1'
run_tests "$TEST_KEY_BASE-HEAD" '@HEAD'
#-------------------------------------------------------------------------------
exit 0
