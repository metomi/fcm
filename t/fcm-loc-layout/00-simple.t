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
tests 24
#-------------------------------------------------------------------------------
setup
unset TEST_PROJECT
init_repos
init_merge_branches merge1 merge2 $REPOS_URL
export SVN_EDITOR="sed -i 1i\foo"
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests fcm loc-layout, no project, default setup
TEST_KEY=$TEST_KEY_BASE-no-project-default
run_pass "$TEST_KEY" fcm loc-layout
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
target: .
url: $ROOT_URL/trunk@9
root: $REPOS_URL
path: /trunk
peg_rev: 9
project: 
branch: trunk
branch_category: trunk
sub_tree: 
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm loc-layout, no project, default setup, cd to subdirectory
TEST_KEY=$TEST_KEY_BASE-no-project-subtree
cd module
run_pass "$TEST_KEY" fcm loc-layout
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
target: .
url: $ROOT_URL/trunk/module@9
root: $REPOS_URL
path: /trunk/module
peg_rev: 9
project: 
branch: trunk
branch_category: trunk
sub_tree: module
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
cd ..
#-------------------------------------------------------------------------------
# Tests fcm loc-layout, no project, default setup, target subdirectory
TEST_KEY=$TEST_KEY_BASE-no-project-target-subtree
run_pass "$TEST_KEY" fcm loc-layout module
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
target: module
url: $ROOT_URL/trunk/module@9
root: $REPOS_URL
path: /trunk/module
peg_rev: 9
project: 
branch: trunk
branch_category: trunk
sub_tree: module
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm loc-layout, no project, default setup, target subdirectory
TEST_KEY=$TEST_KEY_BASE-no-project-target-repos
run_pass "$TEST_KEY" fcm loc-layout $REPOS_URL
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
target: $REPOS_URL
url: $ROOT_URL@9
root: $REPOS_URL
path: 
peg_rev: 9
project: 
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
teardown
#-------------------------------------------------------------------------------
setup
init_repos_layout_roses
svn checkout -q $ROOT_URL/a/a/0/0/0/trunk $TEST_DIR/wc
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests fcm loc-layout, 'roses' 5-level project
TEST_KEY=$TEST_KEY_BASE-roses-default
run_pass "$TEST_KEY" fcm loc-layout
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
target: .
url: $ROOT_URL/a/a/0/0/0/trunk@3
root: $REPOS_URL
path: /a/a/0/0/0/trunk
peg_rev: 3
project: a/a/0/0/0
branch: trunk
branch_category: trunk
sub_tree: 
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm loc-layout, 'roses' 5-level project
TEST_KEY=$TEST_KEY_BASE-roses-subtree
cd module
run_pass "$TEST_KEY" fcm loc-layout
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
target: .
url: $ROOT_URL/a/a/0/0/0/trunk/module@3
root: $REPOS_URL
path: /a/a/0/0/0/trunk/module
peg_rev: 3
project: a/a/0/0/0
branch: trunk
branch_category: trunk
sub_tree: module
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
cd ..
#-------------------------------------------------------------------------------
# Tests fcm loc-layout, 'roses' 5-level project
TEST_KEY=$TEST_KEY_BASE-roses-target-subtree
run_pass "$TEST_KEY" fcm loc-layout module
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
target: module
url: $ROOT_URL/a/a/0/0/0/trunk/module@3
root: $REPOS_URL
path: /a/a/0/0/0/trunk/module
peg_rev: 3
project: a/a/0/0/0
branch: trunk
branch_category: trunk
sub_tree: module
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm loc-layout, no project, default setup, target subdirectory
TEST_KEY=$TEST_KEY_BASE-roses-target-repos
run_pass "$TEST_KEY" fcm loc-layout $REPOS_URL
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
target: $REPOS_URL
url: $ROOT_URL@3
root: $REPOS_URL
path: 
peg_rev: 3
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
teardown
