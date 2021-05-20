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
# Tests "fcm make", extract, FS source path is under a hidden directory.
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
tests 5
#-------------------------------------------------------------------------------
# dot path name under source tree
mkdir -p 'bubble/.com'
cat >'bubble/.com/burst.f90' <<'__FORTRAN__'
program burst
write(*, '(a)') 'Burst!'
end program burst
__FORTRAN__
cat >'fcm-make.cfg' <<'__CFG__'
steps=extract
extract.ns = bubble
extract.location[bubble]=$HERE/bubble
__CFG__
run_pass "${TEST_KEY_BASE}-tail" fcm make --new
run_fail "${TEST_KEY_BASE}-tail-find" find 'extract' -type f
#-------------------------------------------------------------------------------
# dot path name above source tree
mkdir -p '.com/bubble'
cat >'.com/bubble/burst.f90' <<'__FORTRAN__'
program burst
write(*, '(a)') 'Burst!'
end program burst
__FORTRAN__
cat >'fcm-make.cfg' <<'__CFG__'
steps=extract
extract.ns = bubble
extract.location[bubble]=$HERE/.com/bubble
__CFG__
run_pass "${TEST_KEY_BASE}-head" fcm make --new
run_pass "${TEST_KEY_BASE}-head-find" find 'extract' -type f
file_cmp "${TEST_KEY_BASE}-head-find.out" \
    "${TEST_KEY_BASE}-head-find.out" <<'__OUT__'
extract/bubble/burst.f90
__OUT__
#-------------------------------------------------------------------------------
exit
