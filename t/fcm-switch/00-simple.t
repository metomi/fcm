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
# Basic tests for "fcm switch".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 12
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
run_pass "$TEST_KEY" fcm switch trunk <<<'y'
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
switch: status of "$TEST_DIR/wc":
?       unversioned_file
switch: continue?
Enter "y" or "n" (or just press <return> for "n"): D    added_file
D    added_directory
U    subroutine/hello_sub_dummy.h
D    module/tree_conflict_file
U    module/hello_constants_dummy.inc
U    module/hello_constants.inc
U    module/hello_constants.f90
U    lib/python/info/__init__.py
U    lib/python/info/poems.py
Updated to revision 9.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm switch merge1 branch
rm unversioned_file
TEST_KEY=$TEST_KEY_BASE-branch-1
run_pass "$TEST_KEY" fcm switch branches/dev/Share/merge1 <<<'y'
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
U    subroutine/hello_sub_dummy.h
A    added_file
A    added_directory
A    added_directory/hello_constants_dummy.inc
A    added_directory/hello_constants.inc
A    added_directory/hello_constants.f90
A    module/tree_conflict_file
U    module/hello_constants_dummy.inc
U    module/hello_constants.inc
U    module/hello_constants.f90
U    lib/python/info/__init__.py
U    lib/python/info/poems.py
Updated to revision 9.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm switch merge2 branch
TEST_KEY=$TEST_KEY_BASE-branch-2
run_pass "$TEST_KEY" fcm switch --non-interactive dev/Share/merge2
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
D    added_file
D    added_directory
 U   subroutine/hello_sub.h
U    subroutine/hello_sub_dummy.h
D    module/tree_conflict_file
U    module/hello_constants_dummy.inc
U    module/hello_constants.inc
U    module/hello_constants.f90
U    lib/python/info/poems.py
A    renamed_added_file
Updated to revision 9.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm switch trunk, without .svn/entries
TEST_KEY=$TEST_KEY_BASE-trunk-2
if $SVN_VERSION_IS_16; then
    skip 3 "$TEST_KEY won't work under Subversion 1.6"
else
    rm -f .svn/entries
    run_pass "$TEST_KEY" fcm switch trunk <<<'y'
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<'__OUT__'
D    renamed_added_file
 U   subroutine/hello_sub.h
U    lib/python/info/__init__.py
Updated to revision 9.
__OUT__
    file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
fi
#-------------------------------------------------------------------------------
teardown
exit
