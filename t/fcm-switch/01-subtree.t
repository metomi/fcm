#!/bin/bash
# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-14 Met Office.
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
# Basic tests for "fcm switch".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 9
#-------------------------------------------------------------------------------
setup
init_repos
init_merge_branches merge1 merge2 $REPOS_URL
export SVN_EDITOR="sed -i 1i\foo"
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests fcm switch trunk
svn switch -q $ROOT_URL/branches/dev/Share/merge1
TEST_KEY=$TEST_KEY_BASE-trunk
cd module
run_pass "$TEST_KEY" fcm switch trunk <<__IN__
y
__IN__
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
switch: status of "$TEST_DIR/wc":
?       $TEST_DIR/wc/unversioned_file
switch: continue?
Enter "y" or "n" (or just press <return> for "n"): D    $TEST_DIR/wc/added_file
D    $TEST_DIR/wc/added_directory
U    $TEST_DIR/wc/subroutine/hello_sub_dummy.h
D    $TEST_DIR/wc/module/tree_conflict_file
U    $TEST_DIR/wc/module/hello_constants_dummy.inc
U    $TEST_DIR/wc/module/hello_constants.inc
U    $TEST_DIR/wc/module/hello_constants.f90
U    $TEST_DIR/wc/lib/python/info/__init__.py
U    $TEST_DIR/wc/lib/python/info/poems.py
Updated to revision 9.
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
switch: status of "$TEST_DIR/wc":
?       $TEST_DIR/wc/unversioned_file
switch: continue?
Enter "y" or "n" (or just press <return> for "n"): D    $TEST_DIR/wc/added_file
D    $TEST_DIR/wc/added_directory
U    $TEST_DIR/wc/subroutine/hello_sub_dummy.h
D    tree_conflict_file
U    hello_constants_dummy.inc
U    hello_constants.inc
U    hello_constants.f90
U    $TEST_DIR/wc/lib/python/info/__init__.py
U    $TEST_DIR/wc/lib/python/info/poems.py
Updated to revision 9.
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm switch merge1 branch
rm ../unversioned_file
TEST_KEY=$TEST_KEY_BASE-branch-1
run_pass "$TEST_KEY" fcm switch branches/dev/Share/merge1 <<__IN__
y
__IN__
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
U    $TEST_DIR/wc/subroutine/hello_sub_dummy.h
A    $TEST_DIR/wc/added_file
A    $TEST_DIR/wc/added_directory
A    $TEST_DIR/wc/added_directory/hello_constants_dummy.inc
A    $TEST_DIR/wc/added_directory/hello_constants.inc
A    $TEST_DIR/wc/added_directory/hello_constants.f90
A    $TEST_DIR/wc/module/tree_conflict_file
U    $TEST_DIR/wc/module/hello_constants_dummy.inc
U    $TEST_DIR/wc/module/hello_constants.inc
U    $TEST_DIR/wc/module/hello_constants.f90
U    $TEST_DIR/wc/lib/python/info/__init__.py
U    $TEST_DIR/wc/lib/python/info/poems.py
Updated to revision 9.
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
U    $TEST_DIR/wc/subroutine/hello_sub_dummy.h
A    $TEST_DIR/wc/added_file
A    $TEST_DIR/wc/added_directory
A    $TEST_DIR/wc/added_directory/hello_constants_dummy.inc
A    $TEST_DIR/wc/added_directory/hello_constants.inc
A    $TEST_DIR/wc/added_directory/hello_constants.f90
A    tree_conflict_file
U    hello_constants_dummy.inc
U    hello_constants.inc
U    hello_constants.f90
U    $TEST_DIR/wc/lib/python/info/__init__.py
U    $TEST_DIR/wc/lib/python/info/poems.py
Updated to revision 9.
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm switch merge2 branch
TEST_KEY=$TEST_KEY_BASE-branch-2
run_pass "$TEST_KEY" fcm switch --non-interactive dev/Share/merge2
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
D    $TEST_DIR/wc/added_file
D    $TEST_DIR/wc/added_directory
 U   $TEST_DIR/wc/subroutine/hello_sub.h
U    $TEST_DIR/wc/subroutine/hello_sub_dummy.h
D    $TEST_DIR/wc/module/tree_conflict_file
U    $TEST_DIR/wc/module/hello_constants_dummy.inc
U    $TEST_DIR/wc/module/hello_constants.inc
U    $TEST_DIR/wc/module/hello_constants.f90
U    $TEST_DIR/wc/lib/python/info/poems.py
A    $TEST_DIR/wc/renamed_added_file
Updated to revision 9.
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
D    $TEST_DIR/wc/added_file
D    $TEST_DIR/wc/added_directory
 U   $TEST_DIR/wc/subroutine/hello_sub.h
U    $TEST_DIR/wc/subroutine/hello_sub_dummy.h
D    tree_conflict_file
U    hello_constants_dummy.inc
U    hello_constants.inc
U    hello_constants.f90
U    $TEST_DIR/wc/lib/python/info/poems.py
A    $TEST_DIR/wc/renamed_added_file
Updated to revision 9.
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
teardown
#-------------------------------------------------------------------------------
