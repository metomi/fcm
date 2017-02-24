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
# #156 breaks interface generation. This test ensures that it is not broken
# again.
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
tests 2
#-------------------------------------------------------------------------------

cat >'bld.cfg' <<'__FCM_BLD_CFG__'
cfg::type bld
dest $HERE
tool::geninterface
__FCM_BLD_CFG__

mkdir 'src'
cat >'src/hello.f90' <<'__FORTRAN__'
subroutine hello(world)
character(*), intent(in) :: world
write(*, '(a)') 'Hello ' // trim(world)
end subroutine hello
__FORTRAN__

#-------------------------------------------------------------------------------
run_pass "${TEST_KEY_BASE}-cmd" fcm build -f -s 4
file_cmp "${TEST_KEY_BASE}-interface" 'inc/hello.interface' <<'__FORTRAN__'
interface
subroutine hello(world)
character(*), intent(in) :: world
end subroutine hello
end interface
__FORTRAN__

#-------------------------------------------------------------------------------
exit
