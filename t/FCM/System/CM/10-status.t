#!/bin/bash
# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-2013 Met Office.
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
# Basic tests for "fcm commit".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 4
#-------------------------------------------------------------------------------
setup
init_repos ${TEST_PROJECT:-}
REPOS_URL="file://"$(cd $TEST_DIR/test_repos && pwd)
ROOT_URL=$REPOS_URL
if [[ -n ${TEST_PROJECT:-} ]]; then
    ROOT_URL=$REPOS_URL/$TEST_PROJECT
fi
init_merge_branches merge1 merge2 $REPOS_URL
export SVN_EDITOR="sed -i 1i\foo"
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests the setup for fcm status testing
svn switch -q $ROOT_URL/trunk
touch added_file
touch module/tree_conflict_file
svn add module/tree_conflict_file
rm subroutine/hello_sub.h
svn delete lib/python/info/poems.py
svn delete module/hello_constants.inc
TEST_KEY=$TEST_KEY_BASE-setup
run_pass "$TEST_KEY" fcm merge --non-interactive branches/dev/Share/merge1
#-------------------------------------------------------------------------------
# Tests fcm status result of fcm merge (1)
TEST_KEY=$TEST_KEY_BASE-status
run_pass "$TEST_KEY" fcm status
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
?       unversioned_file
?       added_file
?       #commit_message#
!       subroutine/hello_sub.h
M       subroutine/hello_sub_dummy.h
A     C module/tree_conflict_file
      >   local add, incoming add upon merge
M       module/hello_constants_dummy.inc
D     C module/hello_constants.inc
      >   local missing, incoming edit upon merge
M       module/hello_constants.f90
A  +    added_directory
A  +    added_directory/hello_constants_dummy.inc
A  +    added_directory/hello_constants.inc
A  +    added_directory/hello_constants.f90
D     C lib/python/info/poems.py
      >   local missing, incoming edit upon merge
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
