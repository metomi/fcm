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
# Tests "fcm make", relative config in a Subversion repository
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
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
fcm_make_build_hello_tests "$TEST_KEY_BASE" \
    '.exe' -F "file://$PWD/svn-repos" -f 'etc/fcm-make.cfg'
fcm_make_build_hello_tests "$TEST_KEY_BASE-1" \
    '.exe' -F "file://$PWD/svn-repos@1" -f 'etc/fcm-make.cfg'
fcm_make_build_hello_tests "$TEST_KEY_BASE-HEAD" \
    '.exe' -F "file://$PWD/svn-repos@HEAD" -f 'etc/fcm-make.cfg'
#-------------------------------------------------------------------------------
exit 0
