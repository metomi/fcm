#!/bin/bash
# ------------------------------------------------------------------------------
# Copyright (C) British Crown (Met Office) & Contributors.
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
# Basic tests for "fcm status".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
check_svn_version
tests 4
#-------------------------------------------------------------------------------
setup
init_repos
init_merge_branches merge1 merge2 $REPOS_URL
export SVN_EDITOR="sed -i 1i\foo"
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests the setup for fcm status testing
svn switch -q $ROOT_URL/trunk
touch added_file
svn add -q added_file
svn commit -q -m "trunk modifications"
svn update -q
TEST_KEY=$TEST_KEY_BASE-setup
run_pass "$TEST_KEY" fcm merge --non-interactive branches/dev/Share/merge1
rm subroutine/hello_sub.h
svn delete -q --force lib/python/info/poems.py
#-------------------------------------------------------------------------------
# Tests fcm status result of fcm merge (1)
TEST_KEY=$TEST_KEY_BASE-status
run_pass "$TEST_KEY" fcm status --config-dir=$TEST_DIR/.subversion
status_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
A  +    added_directory
      C added_file
      >   local file obstruction, incoming file add upon merge
D       lib/python/info/poems.py
M       module/hello_constants.f90
M       module/hello_constants.inc
M       module/hello_constants_dummy.inc
A  +    module/tree_conflict_file
!       subroutine/hello_sub.h
M       subroutine/hello_sub_dummy.h
?       unversioned_file
Summary of conflicts:
  Tree conflicts: 1
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
