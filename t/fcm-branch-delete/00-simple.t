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
# Basic tests for "fcm branch-create".
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
init_branch branch_test $REPOS_URL
init_branch_wc my_branch_test $REPOS_URL
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests fcm branch-delete
TEST_KEY=$TEST_KEY_BASE-delete
run_pass "$TEST_KEY" fcm branch-delete --non-interactive $ROOT_URL/branches/dev/Share/branch_test
file_grep "$TEST_KEY.out" "Deleting branch $ROOT_URL/branches/dev/Share/branch_test ..." \
          "$TEST_KEY.out"
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests existence of branch
TEST_KEY=$TEST_KEY_BASE-delete-branch-exists
run_fail "$TEST_KEY" svn info \
               $ROOT_URL/branches/dev/Share/branch_test
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" </dev/null
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" <<__ERR__
$ROOT_URL/branches/dev/Share/branch_test:  (Not a valid URL)

svn: A problem occurred; see other errors for details
__ERR__
teardown
#-------------------------------------------------------------------------------
init_repos ${TEST_PROJECT:-}
REPOS_URL="file://"$(cd $TEST_DIR/test_repos && pwd)
ROOT_URL=$REPOS_URL
if [[ -n ${TEST_PROJECT:-} ]]; then
    ROOT_URL=$REPOS_URL/$TEST_PROJECT
fi
init_branch_wc branch_test $REPOS_URL
REPOS_URL="file://"$(cd $TEST_DIR/test_repos && pwd)
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests fcm brm
TEST_KEY=$TEST_KEY_BASE-brm
run_pass "$TEST_KEY" fcm brm --non-interactive $ROOT_URL/branches/dev/Share/branch_test
file_grep "$TEST_KEY.out" "Deleting branch $ROOT_URL/branches/dev/Share/branch_test ..." \
          "$TEST_KEY.out"
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm brm disappearance of branch
TEST_KEY=$TEST_KEY_BASE-brm-branch-exists
run_fail "$TEST_KEY" svn info \
               $ROOT_URL/branches/dev/Share/branch_test
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" </dev/null
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" <<__ERR__
$ROOT_URL/branches/dev/Share/branch_test:  (Not a valid URL)

svn: A problem occurred; see other errors for details
__ERR__
teardown
#-------------------------------------------------------------------------------
