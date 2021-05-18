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
# Tests "fcm make", relative config in a remote host accessible via SSH
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
# Get a remote host for testing
T_HOST=
for FILE in $HOME/.metomi/fcm/t.cfg $FCM_HOME/etc/fcm/t.cfg; do
    if [[ ! -f $FILE || ! -r $FILE ]]; then
        continue
    fi
    T_HOST=$(fcm cfg $FILE | sed '/^ *host *=/!d; s/^ *host *= *//' | tail -1)
    if [[ -n $T_HOST ]]; then
        break
    fi
done
if [[ -z $T_HOST ]]; then
    skip_all 'fcm/t.cfg: "host" not defined'
fi
#-------------------------------------------------------------------------------
tests 3
#-------------------------------------------------------------------------------
mkdir etc
cat >etc/fcm-make.cfg <<'__CFG__'
steps=build
build.source=src
build.target=hello.exe
__CFG__

T_HOST_WORK_DIR=$(ssh -oBatchMode=yes $T_HOST mktemp -d)
rsync -a etc $T_HOST:$T_HOST_WORK_DIR
rm -r etc

mkdir src
cat >src/hello.f90 <<'__FORTRAN__'
program hello
write(*, '(a)') 'Hello World!'
end program hello
__FORTRAN__

#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
run_pass "$TEST_KEY-pwd" fcm make -F $T_HOST:$T_HOST_WORK_DIR/etc
file_test "$TEST_KEY.hello.exe" $PWD/build/bin/hello.exe
$PWD/build/bin/hello.exe >"$TEST_KEY.hello.exe.out"
file_cmp "$TEST_KEY.hello.exe.out" "$TEST_KEY.hello.exe.out" <<'__OUT__'
Hello World!
__OUT__
#-------------------------------------------------------------------------------
ssh -oBatchMode=yes $T_HOST rm -r $T_HOST_WORK_DIR
exit 0
