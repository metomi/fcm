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
# Tests "fcm make", destination moved.
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"

tests 9

mkdir -p 'src/hello'
cat >'src/hello/hello.f90' <<'__FORTRAN__'
program hello
use greet_mod, only: greet
use world_mod, only: world
write(*, '(a,1x,a)') greet, world
end program hello
__FORTRAN__
cat >'src/hello/world_mod.f90' <<'__FORTRAN__'
module world_mod
character(*), parameter :: world = 'Earth'
end module world_mod
__FORTRAN__
cat >'src/hello/greet_mod.f90' <<'__FORTRAN__'
module greet_mod
character(*), parameter :: greet = 'Hello'
end module greet_mod
__FORTRAN__

svnadmin create 'hello.svn'
URL="file://${PWD}/hello.svn/hello"
svn import --no-auth-cache -m'initial import' 'src' "${URL}/trunk/src"

mkdir -p 'loc1'
cat >'loc1/fcm-make.cfg' <<__CFG__
steps=extract build
extract.ns=hello
extract.location{primary}[hello]=${URL}
build.target{task}=link
build.prop{file-ext.bin}=
__CFG__
#-------------------------------------------------------------------------------
run_pass "${TEST_KEY_BASE}-1" fcm make -C "${PWD}/loc1"
mv "${PWD}/loc1" "${PWD}/loc2"
#-------------------------------------------------------------------------------
# Inherit
mkdir -p 'loc3'
cat >'loc3/fcm-make.cfg' <<__CFG__
use=${PWD}/loc2
__CFG__
run_pass "${TEST_KEY_BASE}-3" fcm make -C "${PWD}/loc3"
LOG="${PWD}/loc3/fcm-make.log"
file_grep "${TEST_KEY_BASE}-3-log-1" \
    '\[info\]   dest:    3 \[U unchanged\]' "${LOG}"
file_grep "${TEST_KEY_BASE}-3-log-2" \
    '\[info\] sources: total=3, analysed=0' "${LOG}"
file_grep "${TEST_KEY_BASE}-3-log-3" \
    '\[info\] TOTAL     targets: modified=0, unchanged=6, failed=0' "${LOG}"
#-------------------------------------------------------------------------------
# Incremental
run_pass "${TEST_KEY_BASE}-2" fcm make -C "${PWD}/loc2"
LOG="${PWD}/loc2/fcm-make.log"
file_grep "${TEST_KEY_BASE}-2-log-1" \
    '\[info\]   dest:    3 \[U unchanged\]' "${LOG}"
file_grep "${TEST_KEY_BASE}-2-log-2" \
    '\[info\] sources: total=3, analysed=0' "${LOG}"
file_grep "${TEST_KEY_BASE}-2-log-3" \
    '\[info\] TOTAL     targets: modified=0, unchanged=6, failed=0' "${LOG}"
#-------------------------------------------------------------------------------
exit
