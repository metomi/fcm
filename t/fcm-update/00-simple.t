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
# Tests fcm update -r PREV
svn switch -q $ROOT_URL/branches/dev/Share/merge1
TEST_KEY=$TEST_KEY_BASE-r-PREV
run_pass "$TEST_KEY" fcm update -r PREV <<__IN__
y
__IN__
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
update: status of ".":
?       unversioned_file
update: continue?
Enter "y" or "n" (or just press <return> for "n"): D    added_file
D    added_directory
U    subroutine/hello_sub_dummy.h
D    module/tree_conflict_file
U    module/hello_constants_dummy.inc
U    module/hello_constants.inc
U    module/hello_constants.f90
U    lib/python/info/poems.py
Updated to revision 4.
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
update: status of ".":
?       unversioned_file
update: continue?
Enter "y" or "n" (or just press <return> for "n"): Updating '.':
D    added_file
D    added_directory
U    subroutine/hello_sub_dummy.h
D    module/tree_conflict_file
U    module/hello_constants_dummy.inc
U    module/hello_constants.inc
U    module/hello_constants.f90
U    lib/python/info/poems.py
Updated to revision 4.
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm update
rm unversioned_file
TEST_KEY=$TEST_KEY_BASE-normal
run_pass "$TEST_KEY" fcm update <<__IN__
y
__IN__
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
update: status of ".":
        *        4   subroutine/hello_sub_dummy.h
        *            added_directory/hello_constants.f90
        *            added_directory/hello_constants_dummy.inc
        *            added_directory/hello_constants.inc
        *            added_directory
        *        4   module/hello_constants.f90
        *            module/tree_conflict_file
        *        4   module/hello_constants_dummy.inc
        *        4   module/hello_constants.inc
        *        4   module
        *        4   lib/python/info/poems.py
        *            added_file
        *        4   .
update: continue?
Enter "y" or "n" (or just press <return> for "n"): U    subroutine/hello_sub_dummy.h
A    added_file
A    added_directory
A    added_directory/hello_constants_dummy.inc
A    added_directory/hello_constants.inc
A    added_directory/hello_constants.f90
A    module/tree_conflict_file
U    module/hello_constants_dummy.inc
U    module/hello_constants.inc
U    module/hello_constants.f90
U    lib/python/info/poems.py
Updated to revision 9.
__OUT__
else
    # The output is now not deterministic for svn update!!
    sort $TEST_DIR/"$TEST_KEY.out" -o $TEST_DIR/"$TEST_KEY.out"
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
        *            added_directory
        *            added_directory/hello_constants.f90
        *            added_directory/hello_constants.inc
        *            added_directory/hello_constants_dummy.inc
        *            added_file
        *            module/tree_conflict_file
        *        4   .
        *        4   lib/python/info/poems.py
        *        4   module
        *        4   module/hello_constants.f90
        *        4   module/hello_constants.inc
        *        4   module/hello_constants_dummy.inc
        *        4   subroutine/hello_sub_dummy.h
A    added_directory
A    added_directory/hello_constants.f90
A    added_directory/hello_constants.inc
A    added_directory/hello_constants_dummy.inc
A    added_file
A    module/tree_conflict_file
Enter "y" or "n" (or just press <return> for "n"): Updating '.':
U    lib/python/info/poems.py
U    module/hello_constants.f90
U    module/hello_constants.inc
U    module/hello_constants_dummy.inc
U    subroutine/hello_sub_dummy.h
Updated to revision 9.
update: continue?
update: status of ".":
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
