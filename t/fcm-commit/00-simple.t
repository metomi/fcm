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
tests 3
#-------------------------------------------------------------------------------
setup
init_repos ${TEST_PROJECT:-}
REPOS_URL="file://"$(cd $TEST_DIR/test_repos && pwd)
ROOT_URL=$REPOS_URL
if [[ -n ${TEST_PROJECT:-} ]]; then
    ROOT_URL=$REPOS_URL/$TEST_PROJECT
fi
init_branch sibling_branch_test $REPOS_URL
init_branch_wc branch_test $REPOS_URL
cd $TEST_DIR/wc
FILE_LIST=$(find . -type f | sed "/\.svn/d" | sort | head -5)
for FILE in $FILE_LIST; do 
    sed -i "s/for/FOR/g; s/fi/end if/g; s/in/IN/g;" $FILE
    sed -i "/#/d; /^ *!/d" $FILE
    sed -i "s/!/!!/g; s/q/\nq/g; s/[(]/(\n/g" $FILE
done
FILE_DIR=$(dirname $FILE)
svn copy -q $FILE added_file
svn copy -q $FILE_DIR added_directory
svn delete --force -q $FILE_DIR
#-------------------------------------------------------------------------------
# Tests fcm commit
TEST_KEY=$TEST_KEY_BASE
export SVN_EDITOR="sed -i 1i\foo" 
run_pass "$TEST_KEY" fcm commit --svn-non-interactive <<__IN__
y
__IN__
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] sed -i 1i\foo: starting commit message editor...
Change summary:
--------------------------------------------------------------------------------
[Root   : $REPOS_URL]
[Project: ${TEST_PROJECT:-}]
[Branch : branches/dev/Share/branch_test]
[Sub-dir: ]

A  +    added_file
D       module
D       module/hello_constants_dummy.inc
D       module/hello_constants.inc
D       module/hello_constants.f90
A  +    added_directory
M  +    added_directory/hello_constants_dummy.inc
M  +    added_directory/hello_constants.inc
M  +    added_directory/hello_constants.f90
M       lib/python/info/poems.py
--------------------------------------------------------------------------------
Commit message is as follows:
--------------------------------------------------------------------------------
foo
--------------------------------------------------------------------------------

*** WARNING: YOU ARE COMMITTING TO A Share BRANCH.
*** Please ensure that you have the owner's permission.

Would you like to commit this change?
Enter "y" or "n" (or just press <return> for "n"): Adding         added_directory
Sending        added_directory/hello_constants.f90
Sending        added_directory/hello_constants.inc
Sending        added_directory/hello_constants_dummy.inc
Adding         added_file
Sending        lib/python/info/poems.py
Deleting       module
Transmitting file data .....
Committed revision 6.
At revision 6.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
teardown
#-------------------------------------------------------------------------------
