#!/bin/bash
# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-15 Met Office.
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
# ------------------------------------------------------------------------------
# Tests for "fcm commit", in a working copy with externals.
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
#-------------------------------------------------------------------------------
check_svn_version
tests 2
#-------------------------------------------------------------------------------
svnadmin create 'foo'
svnadmin create 'bar'
svn co -q "file://${PWD}/foo" 'test-work'
svn ps svn:externals "test-work/bar file://${PWD}/bar" 'test-work'
svn ci -q -m 'set external' 'test-work'
svn update 'test-work'
echo 'Whatever!' >'test-work/whatever.txt'
svn add 'test-work/whatever.txt'
export SVN_EDITOR="sed -i 1i\foo"
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}"
run_pass "${TEST_KEY}" fcm commit --svn-non-interactive 'test-work' <<<'y'
file_cmp "${TEST_KEY}.err" "${TEST_KEY}.err" <'/dev/null'
#-------------------------------------------------------------------------------
exit
