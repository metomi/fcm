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
# Bad-behaviour tests for "fcm commit".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 3
#-------------------------------------------------------------------------------
setup
init_repos
init_branch sibling_branch_test $REPOS_URL
init_branch_wc branch_test $REPOS_URL
cd $TEST_DIR/wc
svn copy -q pro/hello.pro copied_file
svn copy -q module copied_directory
svn delete -q --force lib
rm -rf program/hello.F90
#-------------------------------------------------------------------------------
# Tests fcm commit
TEST_KEY=$TEST_KEY_BASE
export SVN_EDITOR="sed -i 1i\foo" 
run_fail "$TEST_KEY" fcm commit --svn-non-interactive
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" </dev/null
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" <<__ERR__
[ERROR] File(s) missing:
!                5   program/hello.F90
[FAIL] FCM1::Cm::Abort: abort

__ERR__
teardown
#-------------------------------------------------------------------------------
