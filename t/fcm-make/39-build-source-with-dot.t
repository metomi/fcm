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
# Tests "fcm make", build, source path is under a hidden directory.
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
tests 5
#-------------------------------------------------------------------------------
mkdir -p 'src/.singularity'
cat >'src/.singularity/hello.f90' <<'__FORTRAN__'
program hello
write(*, '(a)') 'No information!'
end program hello
__FORTRAN__
#-------------------------------------------------------------------------------
cat >'fcm-make.cfg' <<'__CFG__'
steps=build
build.source=$HERE/src
build.prop{file-ext.bin}=.bin
build.target=hello.bin
__CFG__
run_fail "${TEST_KEY_BASE}-tail" fcm make --new
run_fail "${TEST_KEY_BASE}-tail.bin" './build/bin/hello.bin'

cat >'fcm-make.cfg' <<'__CFG__'
steps=build
build.source=$HERE/src/.singularity
build.prop{file-ext.bin}=.bin
build.target=hello.bin
__CFG__
run_pass "${TEST_KEY_BASE}-head" fcm make --new
run_pass "${TEST_KEY_BASE}-head.bin" './build/bin/hello.bin'
file_cmp "${TEST_KEY_BASE}-head.bin.out" \
    "${TEST_KEY_BASE}-head.bin.out" <<'__OUT__'
No information!
__OUT__
#-------------------------------------------------------------------------------
exit
