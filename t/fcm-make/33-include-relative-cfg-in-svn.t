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
# Tests "fcm make", include relative config in a Subversion repository
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 12
#-------------------------------------------------------------------------------
mkdir etc
cat >etc/fcm-make-build.cfg <<'__CFG__'
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
cat >fcm-make.cfg <<'__CFG__'
include = fcm-make-build.cfg
__CFG__

fcm_make_build_hello_tests \
    "$TEST_KEY_BASE-config-file-path" '.exe' -F "file://$PWD/svn-repos/etc"
#-------------------------------------------------------------------------------
cat >fcm-make.cfg <<'__CFG__'
include = fcm-make-build.cfg
__CFG__

fcm_make_build_hello_tests\
    "$TEST_KEY_BASE-config-file-path-1" '.exe' -F "file://$PWD/svn-repos/etc@1"
#-------------------------------------------------------------------------------
cat >fcm-make.cfg <<'__CFG__'
include-path=file://$PWD/svn-repos/etc
include=fcm-make-build.cfg
__CFG__

fcm_make_build_hello_tests "$TEST_KEY_BASE-include-paths" '.exe'
#-------------------------------------------------------------------------------
cat >fcm-make.cfg <<'__CFG__'
include-path=file://$PWD/svn-repos/etc@1
include=fcm-make-build.cfg
__CFG__

fcm_make_build_hello_tests "$TEST_KEY_BASE-include-path-1" '.exe'
#-------------------------------------------------------------------------------
exit 0
