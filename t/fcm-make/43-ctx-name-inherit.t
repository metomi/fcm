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
# Tests "fcm make", inherit, with context name.
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"

file_cmp_sorted() {
    sort - >"${1}.expected"
    file_cmp "$1" "${2}" "${1}.expected"
}

find_fcm_make_files() {
    find . "$@" -type f \
        '(' -path '*/build/*' -o \
            -path '*/extract/*' -o \
            -path '*/.fcm-make*/c*' ')' \
        | sort
}

tests 5

#-------------------------------------------------------------------------------
mkdir -p 'hello/src'
cat >'hello/fcm-make-friend.cfg' <<'__CFG__'
name=-friend
steps=build
build.source=$HERE/src
build.target{task}=link
__CFG__
cat >'hello/src/friend.f90' <<'__FORTRAN__'
module friend
character(*), parameter :: name = 'friend'
end module friend
__FORTRAN__
cat >'hello/src/hello.f90' <<'__FORTRAN__'
program hello
use friend, only: name
write(*, '(a,1x,a)') 'Hello', name
end program hello
__FORTRAN__

run_pass "${TEST_KEY_BASE}-hello" fcm make -C "${PWD}/hello" -n '-friend'
#-------------------------------------------------------------------------------
mkdir -p 'greet/src'
cat >'greet/fcm-make-friend.cfg' <<'__CFG__'
use=$HERE/../hello
name=-friend
steps=build
build.source=$HERE/src
build.target{task}=link
__CFG__
cat >'greet/src/greet.f90' <<'__FORTRAN__'
program greet
use friend, only: name
write(*, '(a,1x,a)') 'Greet', name
end program greet
__FORTRAN__

run_pass "${TEST_KEY_BASE}-greet" fcm make -C "${PWD}/greet" -n '-friend'
(cd 'greet' && find_fcm_make_files) >"${TEST_KEY_BASE}-greet.find"
file_cmp_sorted \
    "${TEST_KEY_BASE}-greet.find" "${TEST_KEY_BASE}-greet.find" <<'__FIND__'
./.fcm-make-friend/config-as-parsed.cfg
./.fcm-make-friend/config-on-success.cfg
./.fcm-make-friend/ctx.gz
./build/bin/greet.exe
./build/bin/hello.exe
./build/o/greet.o
__FIND__
#-------------------------------------------------------------------------------
mkdir -p 'snub/src'
cat >'snub/fcm-make-no-friend.cfg' <<'__CFG__'
use=$HERE/../hello
name=-no-friend
steps=build
build.source=$HERE/src
build.target{task}=link
__CFG__
run_fail "${TEST_KEY_BASE}-snub" fcm make -C "${PWD}/snub" -n '-no-friend'
sed -i '3q' "${TEST_KEY_BASE}-snub.err"  # 3 lines only
file_cmp "${TEST_KEY_BASE}-snub.err" "${TEST_KEY_BASE}-snub.err" <<__ERR__
[FAIL] use = ${PWD}/hello: incorrect value in declaration
[FAIL] config-file=${PWD}/snub/fcm-make-no-friend.cfg:1
[FAIL] ${PWD}/hello/.fcm-make/ctx.gz: cannot retrieve cache
__ERR__
#-------------------------------------------------------------------------------
exit
