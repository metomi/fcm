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
# Tests for "fcm make --archive"
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"

file_cmp_sorted() {
    sort - >"${1}.expected"
    file_cmp "$1" "${2}" "${1}.expected"
}

tests 11
#-------------------------------------------------------------------------------
# Create a repository to extract
svnadmin create 'repos'
T_REPOS="file://${PWD}/repos"
mkdir 't'
cat >'t/hello.f90' <<'__FORTRAN__'
program hello
use world_mod, only: world
write(*, '(a,1x,a)') 'Hello', world
end program hello
__FORTRAN__
cat >'t/world_mod.f90' <<'__FORTRAN__'
module world_mod
character(*), parameter :: world = 'Earth'
end module world_mod
__FORTRAN__
svn import --no-auth-cache -q -m'Test' t "${T_REPOS}/hello/trunk"
rm -r 't'

# Create a fcm-make.cfg to do some extract and build
cat >'fcm-make.cfg' <<__CFG__
steps = extract build
extract.ns = hello
extract.location{primary}[hello] = ${T_REPOS}/hello
build.target{task} = link
build.prop{file-ext.bin} =
__CFG__
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-on-new"
run_pass "${TEST_KEY}" fcm make -a
find '.fcm-make/cache' 'build' -type f | sort >"${TEST_KEY}.find"
file_cmp_sorted "${TEST_KEY}.find" "${TEST_KEY}.find" <<'__FIND__'
.fcm-make/cache/extract.tar.gz
build/bin/hello
build/include.tar.gz
build/o.tar.gz
__FIND__

touch 'new'
sleep 1

TEST_KEY="${TEST_KEY_BASE}-on-incr"
run_pass "${TEST_KEY}" fcm make -a
find '.fcm-make/cache' 'build' -type f -newer 'new' \
    | sort >"${TEST_KEY}.find.new"
file_cmp_sorted "${TEST_KEY}.find.new" "${TEST_KEY}.find.new" <<'__FIND__'
.fcm-make/cache/extract.tar.gz
build/include.tar.gz
build/o.tar.gz
__FIND__
find '.fcm-make/cache' 'build' -type f '!' -newer 'new' \
    | sort >"${TEST_KEY}.find.old"
file_cmp_sorted "${TEST_KEY}.find.old" "${TEST_KEY}.find.old" <<'__FIND__'
build/bin/hello
__FIND__

TEST_KEY="${TEST_KEY_BASE}-on-incr-build-o"
run_pass "${TEST_KEY}" \
    fcm make -a 'build.prop{archive-ok-target-category}=o'
find '.fcm-make/cache' 'build' -type f -newer 'new' \
    | sort >"${TEST_KEY}.find.new"
file_cmp_sorted "${TEST_KEY}.find.new" "${TEST_KEY}.find.new" <<'__FIND__'
.fcm-make/cache/extract.tar.gz
build/o.tar.gz
__FIND__
find '.fcm-make/cache' 'build' -type f '!' -newer 'new' \
    | sort >"${TEST_KEY}.find.old"
file_cmp_sorted "${TEST_KEY}.find.old" "${TEST_KEY}.find.old" <<'__FIND__'
build/bin/hello
build/include/world_mod.mod
__FIND__

run_pass "${TEST_KEY_BASE}-off" fcm make
find '.fcm-make/cache' 'build' -type f -newer 'new' \
    | sort >"${TEST_KEY}.find.new"
file_cmp_sorted "${TEST_KEY}.find.new" "${TEST_KEY}.find.new" <'/dev/null'
find '.fcm-make/cache' 'build' -type f '!' -newer 'new' \
    | sort >"${TEST_KEY}.find.old"
file_cmp_sorted "${TEST_KEY}.find.old" "${TEST_KEY}.find.old" <<'__FIND__'
.fcm-make/cache/extract/hello/0/hello.f90
.fcm-make/cache/extract/hello/0/world_mod.f90
build/bin/hello
build/include/world_mod.mod
build/o/hello.o
build/o/world_mod.o
__FIND__
#-------------------------------------------------------------------------------
exit 0
