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
# Test extract conflict should continue to fail in incremental mode.
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
tests 33

mkdir -p 'foo/1' 'foo/2' 'foo/3'
cat >'foo/1/hello.f90' <<'__FORTRAN__'
program hello
write(*, '(a)') 'Hello World!'
end program hello
__FORTRAN__
cat >'foo/2/hello.f90' <<'__FORTRAN__'
program hello
write(*, '(a)') 'Hello Earth!'
end program hello
__FORTRAN__
cat >'foo/3/hello.f90' <<'__FORTRAN__'
program hello
write(*, '(a)') 'Hello Mars!'
end program hello
__FORTRAN__

cat >'fcm-make.cfg' <<'__FCM_MAKE_CFG__'
steps=extract
extract.ns=foo
extract.location[foo]=$HERE/foo/1
extract.location{diff}[foo]=$HERE/foo/2 $HERE/foo/3
__FCM_MAKE_CFG__

# 1 new + 10 incrementals
for I in {0..10}; do
    run_fail "${TEST_KEY_BASE}-${I}" fcm make
    run_pass "${TEST_KEY_BASE}-${I}.log" \
        grep -F "[FAIL] foo/hello.f90: merge results in conflict" 'fcm-make.log'
    run_pass "${TEST_KEY_BASE}-${I}.log" \
        grep -F "[FAIL] !!! source from location  2: ${PWD}/foo/3/hello.f90" \
        'fcm-make.log'
done
#-------------------------------------------------------------------------------
exit 0
