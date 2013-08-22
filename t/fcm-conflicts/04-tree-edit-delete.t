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
tests 18
#-------------------------------------------------------------------------------
setup
init_repos ${TEST_PROJECT:-}
REPOS_URL="file://"$(cd $TEST_DIR/test_repos && pwd)
ROOT_URL=$REPOS_URL
if [[ -n ${TEST_PROJECT:-} ]]; then
    ROOT_URL=$REPOS_URL/$TEST_PROJECT
fi
init_branch ctrl $REPOS_URL
init_branch_wc ed_del $REPOS_URL
export SVN_EDITOR="sed -i 1i\foo"
# Set a special (null) fcm-graphic-merge diff editor.
export FCM_GRAPHIC_MERGE=fcm-dummy-diff
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests fcm conflicts: edit, delete, discard local
TEST_KEY=$TEST_KEY_BASE-discard
svn switch -q $ROOT_URL/branches/dev/Share/ctrl
echo "Local contents (1)" >>pro/hello.pro
svn commit -q -m "Modified local copy of conflict file"
svn update -q
svn switch -q $ROOT_URL/branches/dev/Share/ed_del
svn delete -q pro/hello.pro
svn commit -q -m "Deleted merge copy of conflict file"
svn update -q
svn switch -q $ROOT_URL/branches/dev/Share/ctrl
fcm merge --non-interactive $ROOT_URL/branches/dev/Share/ed_del 
run_pass "$TEST_KEY" fcm conflicts <<__IN__
n
__IN__
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] pro/hello.pro: in tree conflict.
Locally: edited.
Externally: deleted.
Answer (y) to keep the file.
Answer (n) to accept the external delete.
Keep the local version?
Enter "y" or "n" (or just press <return> for "n") D         pro/hello.pro
Resolved conflicted state of 'pro/hello.pro'
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: edit, delete, discard local (status)
TEST_KEY=$TEST_KEY_BASE-discard-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
D       pro/hello.pro
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: edit, delete, discard local (info)
TEST_KEY=$TEST_KEY_BASE-discard-info
run_pass "$TEST_KEY" svn info pro/hello.pro
sed -i "/Date:\|Updated:\|UUID:/d" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Path: pro/hello.pro
Name: hello.pro
URL: $ROOT_URL/branches/dev/Share/ctrl/pro/hello.pro
Repository Root: $REPOS_URL
Revision: 7
Node Kind: file
Schedule: delete
Last Changed Author: $LOGNAME
Last Changed Rev: 6
Checksum: cd646280a1cf8823432515abfb38713f

__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
cd $TEST_DIR
rm -rf $TEST_DIR/wc
mkdir $TEST_DIR/wc
svn checkout -q $ROOT_URL/branches/dev/Share/ctrl $TEST_DIR/wc
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests fcm conflicts: edit, delete, keep local
TEST_KEY=$TEST_KEY_BASE-keep
fcm merge --non-interactive $ROOT_URL/branches/dev/Share/ed_del 
run_pass "$TEST_KEY" fcm conflicts <<__IN__
y
__IN__
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] pro/hello.pro: in tree conflict.
Locally: edited.
Externally: deleted.
Answer (y) to keep the file.
Answer (n) to accept the external delete.
Keep the local version?
Enter "y" or "n" (or just press <return> for "n") Resolved conflicted state of 'pro/hello.pro'
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: edit, delete, keep local (status)
TEST_KEY=$TEST_KEY_BASE-keep-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: edit, delete, keep local (cat)
TEST_KEY=$TEST_KEY_BASE-keep-cat
run_pass "$TEST_KEY" cat pro/hello.pro
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
PRO HELLO
END
Local contents (1)
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
teardown
#-------------------------------------------------------------------------------
