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
# Basic tests for "fcm update".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 6
#-------------------------------------------------------------------------------
setup
init_repos
init_merge_branches merge1 merge2 $REPOS_URL
export SVN_EDITOR="sed -i 1i\foo"
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests fcm update -r PREV
svn switch -q $ROOT_URL/branches/dev/Share/merge1
TEST_KEY=$TEST_KEY_BASE-r-PREV
cd module
run_pass "$TEST_KEY" fcm update -r PREV <<__IN__
y
__IN__
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
update: status of "$TEST_DIR/wc":
?       $TEST_DIR/wc/unversioned_file
update: continue?
Enter "y" or "n" (or just press <return> for "n"): D    $TEST_DIR/wc/added_file
D    $TEST_DIR/wc/added_directory
U    $TEST_DIR/wc/subroutine/hello_sub_dummy.h
D    $TEST_DIR/wc/module/tree_conflict_file
U    $TEST_DIR/wc/module/hello_constants_dummy.inc
U    $TEST_DIR/wc/module/hello_constants.inc
U    $TEST_DIR/wc/module/hello_constants.f90
U    $TEST_DIR/wc/lib/python/info/poems.py
Updated to revision 4.
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
update: status of "$TEST_DIR/wc":
?       $TEST_DIR/wc/unversioned_file
update: continue?
Enter "y" or "n" (or just press <return> for "n"): Updating '$TEST_DIR/wc':
D    $TEST_DIR/wc/added_file
D    $TEST_DIR/wc/added_directory
U    $TEST_DIR/wc/subroutine/hello_sub_dummy.h
D    tree_conflict_file
U    hello_constants_dummy.inc
U    hello_constants.inc
U    hello_constants.f90
U    $TEST_DIR/wc/lib/python/info/poems.py
Updated to revision 4.
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm update
rm ../unversioned_file
TEST_KEY=$TEST_KEY_BASE-normal
run_pass "$TEST_KEY" fcm update <<__IN__
y
__IN__
if $SVN_VERSION_IS_16; then
    sort $TEST_DIR/"$TEST_KEY.out" -o $TEST_DIR/"$TEST_KEY.out"
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
        *            $TEST_DIR/wc/added_directory
        *            $TEST_DIR/wc/added_directory/hello_constants.f90
        *            $TEST_DIR/wc/added_directory/hello_constants.inc
        *            $TEST_DIR/wc/added_directory/hello_constants_dummy.inc
        *            $TEST_DIR/wc/added_file
        *            $TEST_DIR/wc/module/tree_conflict_file
        *        4   $TEST_DIR/wc
        *        4   $TEST_DIR/wc/lib/python/info/poems.py
        *        4   $TEST_DIR/wc/module
        *        4   $TEST_DIR/wc/module/hello_constants.f90
        *        4   $TEST_DIR/wc/module/hello_constants.inc
        *        4   $TEST_DIR/wc/module/hello_constants_dummy.inc
        *        4   $TEST_DIR/wc/subroutine/hello_sub_dummy.h
A    $TEST_DIR/wc/added_directory
A    $TEST_DIR/wc/added_directory/hello_constants.f90
A    $TEST_DIR/wc/added_directory/hello_constants.inc
A    $TEST_DIR/wc/added_directory/hello_constants_dummy.inc
A    $TEST_DIR/wc/added_file
A    $TEST_DIR/wc/module/tree_conflict_file
Enter "y" or "n" (or just press <return> for "n"): U    $TEST_DIR/wc/subroutine/hello_sub_dummy.h
U    $TEST_DIR/wc/lib/python/info/poems.py
U    $TEST_DIR/wc/module/hello_constants.f90
U    $TEST_DIR/wc/module/hello_constants.inc
U    $TEST_DIR/wc/module/hello_constants_dummy.inc
Updated to revision 9.
update: continue?
update: status of "$TEST_DIR/wc":
__OUT__
else
    # The output is now not deterministic for svn update!!
    sort $TEST_DIR/"$TEST_KEY.out" -o $TEST_DIR/"$TEST_KEY.out"
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
        *            $TEST_DIR/wc/added_directory
        *            $TEST_DIR/wc/added_directory/hello_constants.f90
        *            $TEST_DIR/wc/added_directory/hello_constants.inc
        *            $TEST_DIR/wc/added_directory/hello_constants_dummy.inc
        *            $TEST_DIR/wc/added_file
        *            $TEST_DIR/wc/module/tree_conflict_file
        *        4   $TEST_DIR/wc
        *        4   $TEST_DIR/wc/lib/python/info/poems.py
        *        4   $TEST_DIR/wc/module
        *        4   $TEST_DIR/wc/module/hello_constants.f90
        *        4   $TEST_DIR/wc/module/hello_constants.inc
        *        4   $TEST_DIR/wc/module/hello_constants_dummy.inc
        *        4   $TEST_DIR/wc/subroutine/hello_sub_dummy.h
A    $TEST_DIR/wc/added_directory
A    $TEST_DIR/wc/added_directory/hello_constants.f90
A    $TEST_DIR/wc/added_directory/hello_constants.inc
A    $TEST_DIR/wc/added_directory/hello_constants_dummy.inc
A    $TEST_DIR/wc/added_file
A    tree_conflict_file
Enter "y" or "n" (or just press <return> for "n"): Updating '$TEST_DIR/wc':
U    $TEST_DIR/wc/lib/python/info/poems.py
U    $TEST_DIR/wc/subroutine/hello_sub_dummy.h
U    hello_constants.f90
U    hello_constants.inc
U    hello_constants_dummy.inc
Updated to revision 9.
update: continue?
update: status of "$TEST_DIR/wc":
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
teardown
#-------------------------------------------------------------------------------
