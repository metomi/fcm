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
# Basic tests for "fcm branch-info".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 12
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
fcm branch-create -t SHARE --rev-flag=NONE \
                           --non-interactive \
                           --branch-of-branch my_branch_test >/dev/null
svn switch -q $ROOT_URL/trunk
FILE_LIST=$(find . -type f | sed "/\.svn/d" | sort | head -5)
for FILE in $FILE_LIST; do 
    sed -i "s/for/FOR/g; s/fi/end if/g; s/in/IN/g;" $FILE
    sed -i "/#/d; /^ *!/d" $FILE
    sed -i "s/!/!!/g; s/q/\nq/g; s/[(]/(\n/g" $FILE
done
svn commit -q -m "add trunk commit"
svn switch -q $ROOT_URL/branches/dev/Share/branch_test
#-------------------------------------------------------------------------------
# Tests fcm branch-info
TEST_KEY=$TEST_KEY_BASE-info
run_pass "$TEST_KEY" fcm branch-info
sed -i "/ Date/d;" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
URL: $ROOT_URL/branches/dev/Share/branch_test
Repository Root: $REPOS_URL
Revision: 7
Last Changed Author: $LOGNAME
Last Changed Rev: 5
--------------------------------------------------------------------------------
Branch Create Author: $LOGNAME
Branch Create Rev: 5
--------------------------------------------------------------------------------
Branch Parent: $ROOT_URL/trunk@1
Merges Avail From Parent: 7
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm branch-info -a
TEST_KEY=$TEST_KEY_BASE-a
run_pass "$TEST_KEY" fcm branch-info -a
sed -i "/ Date/d;" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
URL: $ROOT_URL/branches/dev/Share/branch_test
Repository Root: $REPOS_URL
Revision: 7
Last Changed Author: $LOGNAME
Last Changed Rev: 5
--------------------------------------------------------------------------------
Branch Create Author: $LOGNAME
Branch Create Rev: 5
--------------------------------------------------------------------------------
Branch Parent: $ROOT_URL/trunk@1
Merges Avail From Parent: 7
--------------------------------------------------------------------------------
Searching for siblings ... 1 sibling found.
No merges with existing siblings.
--------------------------------------------------------------------------------
Searching for children ... 1 child found.
Current children:
  ------------------------------------------------------------------------------
  $ROOT_URL/branches/dev/Share/my_branch_test
  Child Create Rev: 6
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm branch-info --show-children
TEST_KEY=$TEST_KEY_BASE-show-children
run_pass "$TEST_KEY" fcm branch-info --show-children
sed -i "/ Date/d;" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
URL: $ROOT_URL/branches/dev/Share/branch_test
Repository Root: $REPOS_URL
Revision: 7
Last Changed Author: $LOGNAME
Last Changed Rev: 5
--------------------------------------------------------------------------------
Branch Create Author: $LOGNAME
Branch Create Rev: 5
--------------------------------------------------------------------------------
Branch Parent: $ROOT_URL/trunk@1
Merges Avail From Parent: 7
--------------------------------------------------------------------------------
Searching for children ... 1 child found.
Current children:
  ------------------------------------------------------------------------------
  $ROOT_URL/branches/dev/Share/my_branch_test
  Child Create Rev: 6
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm branch-info --show-siblings
TEST_KEY=$TEST_KEY_BASE-show-siblings
svn switch -q $ROOT_URL/branches/dev/Share/sibling_branch_test
svn merge -q $ROOT_URL/trunk
svn commit -q -m "Merged trunk into sibling branch"
svn switch -q $ROOT_URL/branches/dev/Share/branch_test
svn merge -q $ROOT_URL/branches/dev/Share/sibling_branch_test
svn commit -q -m "Merged sibling into test branch"
svn switch -q $ROOT_URL/branches/dev/Share/sibling_branch_test
FILE_LIST=$(find . -type f | sed "/\.svn/d" | sort | head -5)
TMPFILE=$(mktemp)
for FILE in $FILE_LIST; do 
    cut -f 1 $FILE > $TMPFILE
    mv $TMPFILE $FILE
done
svn commit -q -m "Add sibling commit"
svn switch -q $ROOT_URL/branches/dev/Share/branch_test
run_pass "$TEST_KEY" fcm branch-info --show-siblings
sed -i "/ Date/d;" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
URL: $ROOT_URL/branches/dev/Share/branch_test
Repository Root: $REPOS_URL
Revision: 9
Last Changed Author: $LOGNAME
Last Changed Rev: 9
--------------------------------------------------------------------------------
Branch Create Author: $LOGNAME
Branch Create Rev: 5
--------------------------------------------------------------------------------
Branch Parent: $ROOT_URL/trunk@1
Merges Avail From Parent: 7
Merges Avail Into Parent: 9
--------------------------------------------------------------------------------
Searching for siblings ... 1 sibling found.
No merges with existing siblings.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
teardown
#-------------------------------------------------------------------------------
