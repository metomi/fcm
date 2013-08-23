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
# Basic tests for "fcm conflicts" (tree conflict mode).
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 24
#-------------------------------------------------------------------------------
setup
init_repos ${TEST_PROJECT:-}
REPOS_URL="file://"$(cd $TEST_DIR/test_repos && pwd)
ROOT_URL=$REPOS_URL
if [[ -n ${TEST_PROJECT:-} ]]; then
    ROOT_URL=$REPOS_URL/$TEST_PROJECT
fi
init_branch ctrl $REPOS_URL
init_branch_wc add_add $REPOS_URL
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests fcm conflicts: add, add, discard local   
TEST_KEY=$TEST_KEY_BASE-discard
svn switch -q $ROOT_URL/branches/dev/Share/ctrl
echo "Local contents (1)" > new_file
svn add -q new_file
svn commit -q -m "Added duplicate-name copy of conflict file"
svn update -q
svn switch -q $ROOT_URL/branches/dev/Share/add_add
echo "Merge contents (1)" >new_file
echo "Merge contents (2)" >>new_file
svn add -q new_file
svn commit -q -m "Added duplicated-name copy of conflict file"
svn update -q
svn switch -q $ROOT_URL/branches/dev/Share/ctrl
fcm merge --non-interactive $ROOT_URL/branches/dev/Share/add_add
run_pass "$TEST_KEY" fcm conflicts <<__IN__
n
__IN__
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] new_file: in tree conflict.
Locally: added.
Externally: added.
Answer (y) to keep the local file filename.
Answer (n) to keep the external file filename.
Keep the local version?
Enter "y" or "n" (or just press <return> for "n") Resolved conflicted state of 'new_file'
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: add, add, discard local (status)
TEST_KEY=$TEST_KEY_BASE-discard-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
M       new_file
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: add, add, discard local (info)
TEST_KEY=$TEST_KEY_BASE-discard-info
run_pass "$TEST_KEY" svn info new_file
sed -i "/Date:\|Updated:\|UUID:/d" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Path: new_file
Name: new_file
URL: $ROOT_URL/branches/dev/Share/ctrl/new_file
Repository Root: $REPOS_URL
Revision: 7
Node Kind: file
Schedule: normal
Last Changed Author: $LOGNAME
Last Changed Rev: 6
Checksum: 1e03a88ca73f388081168bc228c4de7d

__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: add, add, discard local (cat)
TEST_KEY=$TEST_KEY_BASE-discard-cat
run_pass "$TEST_KEY" cat new_file
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Merge contents (1)
Merge contents (2)
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
cd $TEST_DIR
rm -rf $TEST_DIR/wc
mkdir $TEST_DIR/wc
svn checkout -q $ROOT_URL/branches/dev/Share/ctrl $TEST_DIR/wc
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests fcm conflicts: add, add, keep local
TEST_KEY=$TEST_KEY_BASE-keep
fcm merge --non-interactive $ROOT_URL/branches/dev/Share/add_add
run_pass "$TEST_KEY" fcm conflicts <<__IN__
y
__IN__
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] new_file: in tree conflict.
Locally: added.
Externally: added.
Answer (y) to keep the local file filename.
Answer (n) to keep the external file filename.
Keep the local version?
Enter "y" or "n" (or just press <return> for "n") Resolved conflicted state of 'new_file'
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: add, add, keep local (status)
TEST_KEY=$TEST_KEY_BASE-keep-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: add, add, keep local (info)
TEST_KEY=$TEST_KEY_BASE-keep-info
run_pass "$TEST_KEY" svn info new_file
sed -i "/Date:\|Updated:\|UUID:/d" "$TEST_DIR/$TEST_KEY.out"
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Path: new_file
Name: new_file
URL: $ROOT_URL/branches/dev/Share/ctrl/new_file
Repository Root: $REPOS_URL
Revision: 7
Node Kind: file
Schedule: normal
Last Changed Author: $LOGNAME
Last Changed Rev: 6
Checksum: 1e03a88ca73f388081168bc228c4de7d

__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: add, add, keep local (cat)
TEST_KEY=$TEST_KEY_BASE-keep-cat
run_pass "$TEST_KEY" cat new_file
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Local contents (1)
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
teardown
#-------------------------------------------------------------------------------
