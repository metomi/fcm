#!/bin/bash
#-------------------------------------------------------------------------------
# Copyright (C) 2006-2019 British Crown (Met Office) & Contributors.
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
# Tests "fcm make", context name.
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

tests 17

mkdir -p 'src/a' 'src/b'
cat >'src/a/a.f90' <<'__FORTRAN__'
program a
write(*, '(a)') 'I am program A.'
end program a
__FORTRAN__
cat >'src/b/b.f90' <<'__FORTRAN__'
program b
write(*, '(a)') 'I am program B.'
end program b
__FORTRAN__

cat >'fcm-make.cfg' <<'__CFG__'
steps=extract
extract.ns = a
extract.location[a]=$HERE/src/a
__CFG__

cat >'fcm-make2.cfg' <<'__CFG__'
name=2
steps=build
build.source=extract src/b
build.target{task}=link
__CFG__
#-------------------------------------------------------------------------------
run_pass "${TEST_KEY_BASE}-1" fcm make
find_fcm_make_files >"${TEST_KEY_BASE}-1.find.new"
file_cmp_sorted \
    "${TEST_KEY_BASE}-1.find.new" "${TEST_KEY_BASE}-1.find.new" <<'__FIND__'
./.fcm-make/config-as-parsed.cfg
./.fcm-make/config-on-success.cfg
./.fcm-make/ctx.gz
./extract/a/a.f90
__FIND__

touch 'marker'
sleep 1
run_pass "${TEST_KEY_BASE}-2" fcm make --name=2
find_fcm_make_files '!' -newer 'marker' >"${TEST_KEY_BASE}-2.find.old"
file_cmp "${TEST_KEY_BASE}-2.find.old" \
    "${TEST_KEY_BASE}-2.find.old" "${TEST_KEY_BASE}-1.find.new"
find_fcm_make_files -newer 'marker' >"${TEST_KEY_BASE}-2.find.new"
file_cmp_sorted \
    "${TEST_KEY_BASE}-2.find.new" "${TEST_KEY_BASE}-2.find.new" <<'__FIND__'
./.fcm-make2/config-as-parsed.cfg
./.fcm-make2/config-on-success.cfg
./.fcm-make2/ctx.gz
./build/bin/a.exe
./build/bin/b.exe
./build/o/a.o
./build/o/b.o
__FIND__

touch 'marker'
sleep 1
run_pass "${TEST_KEY_BASE}-1-incr" fcm make
find_fcm_make_files '!' -newer 'marker' >"${TEST_KEY_BASE}-1-incr.find.old"
file_cmp_sorted "${TEST_KEY_BASE}-1-incr.find.old" \
    "${TEST_KEY_BASE}-1-incr.find.old" <<'__FIND__'
./.fcm-make2/config-as-parsed.cfg
./.fcm-make2/config-on-success.cfg
./.fcm-make2/ctx.gz
./build/bin/a.exe
./build/bin/b.exe
./build/o/a.o
./build/o/b.o
./extract/a/a.f90
__FIND__
find_fcm_make_files -newer 'marker' >"${TEST_KEY_BASE}-1-incr.find.new"
file_cmp_sorted "${TEST_KEY_BASE}-1-incr.find.new" \
    "${TEST_KEY_BASE}-1-incr.find.new" <<'__FIND__'
./.fcm-make/config-as-parsed.cfg
./.fcm-make/config-on-success.cfg
./.fcm-make/ctx.gz
__FIND__

touch 'marker'
sleep 1
run_pass "${TEST_KEY_BASE}-2-incr" fcm make --name=2
find_fcm_make_files '!' -newer 'marker' >"${TEST_KEY_BASE}-2-incr.find.old"
file_cmp_sorted "${TEST_KEY_BASE}-2-incr.find.old" \
    "${TEST_KEY_BASE}-2-incr.find.old" <<'__FIND__'
./.fcm-make/config-as-parsed.cfg
./.fcm-make/config-on-success.cfg
./.fcm-make/ctx.gz
./build/bin/a.exe
./build/bin/b.exe
./build/o/a.o
./build/o/b.o
./extract/a/a.f90
__FIND__
find_fcm_make_files -newer 'marker' >"${TEST_KEY_BASE}-2-incr.find.new"
file_cmp_sorted "${TEST_KEY_BASE}-2-incr.find.new" \
    "${TEST_KEY_BASE}-2-incr.find.new" <<'__FIND__'
./.fcm-make2/config-as-parsed.cfg
./.fcm-make2/config-on-success.cfg
./.fcm-make2/ctx.gz
__FIND__

touch 'marker'
sleep 1
run_pass "${TEST_KEY_BASE}-1-new" fcm make --new
find_fcm_make_files '!' -newer 'marker' >"${TEST_KEY_BASE}-1-new.find.old"
file_cmp_sorted "${TEST_KEY_BASE}-1-new.find.old" \
    "${TEST_KEY_BASE}-1-new.find.old" <<'__FIND__'
./.fcm-make2/config-as-parsed.cfg
./.fcm-make2/config-on-success.cfg
./.fcm-make2/ctx.gz
./build/bin/a.exe
./build/bin/b.exe
./build/o/a.o
./build/o/b.o
__FIND__
find_fcm_make_files -newer 'marker' >"${TEST_KEY_BASE}-1-new.find.new"
file_cmp_sorted "${TEST_KEY_BASE}-1-new.find.new" \
    "${TEST_KEY_BASE}-1-new.find.new" <<'__FIND__'
./.fcm-make/config-as-parsed.cfg
./.fcm-make/config-on-success.cfg
./.fcm-make/ctx.gz
./extract/a/a.f90
__FIND__

touch 'marker'
sleep 1
run_pass "${TEST_KEY_BASE}-2-new" fcm make --name=2 --new
find_fcm_make_files '!' -newer 'marker' >"${TEST_KEY_BASE}-2-new.find.old"
file_cmp_sorted "${TEST_KEY_BASE}-2-new.find.old" \
    "${TEST_KEY_BASE}-2-new.find.old" <<'__FIND__'
./.fcm-make/config-as-parsed.cfg
./.fcm-make/config-on-success.cfg
./.fcm-make/ctx.gz
./extract/a/a.f90
__FIND__
find_fcm_make_files -newer 'marker' >"${TEST_KEY_BASE}-2-new.find.new"
file_cmp_sorted "${TEST_KEY_BASE}-2-new.find.new" \
    "${TEST_KEY_BASE}-2-new.find.new" <<'__FIND__'
./.fcm-make2/config-as-parsed.cfg
./.fcm-make2/config-on-success.cfg
./.fcm-make2/ctx.gz
./build/bin/a.exe
./build/bin/b.exe
./build/o/a.o
./build/o/b.o
__FIND__
#-------------------------------------------------------------------------------
exit
