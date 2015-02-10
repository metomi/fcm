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
# Basic tests for "fcm conflicts" (tree conflict mode).
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 24
#-------------------------------------------------------------------------------
setup
init_repos
init_branch ctrl $REPOS_URL
init_branch_wc ed_ren $REPOS_URL
export SVN_EDITOR="sed -i 1i\foo"
# Set a special (null) fcm-graphic-merge diff editor.
export FCM_GRAPHIC_MERGE=fcm-dummy-diff
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests fcm conflicts: edit, rename, discard local
TEST_KEY=$TEST_KEY_BASE-discard
svn switch -q $ROOT_URL/branches/dev/Share/ctrl
echo "Local contents (1)" >>pro/hello.pro
svn commit -q -m "Modified local copy of conflict file"
svn update -q
svn switch -q $ROOT_URL/branches/dev/Share/ed_ren
echo "Merge contents (1)" >>pro/hello.pro
svn rename -q pro/hello.pro pro/hello.pro.renamed
svn commit -q -m "Modified and renamed merge copy of conflict file"
svn update -q
echo "Merge contents (2)" >>pro/hello.pro.renamed
svn commit -q -m "Modified the merge copy of renamed conflict file"
svn update -q
svn switch -q $ROOT_URL/branches/dev/Share/ctrl
fcm merge --non-interactive $ROOT_URL/branches/dev/Share/ed_ren >/dev/null
run_pass "$TEST_KEY" fcm conflicts <<__IN__
n
__IN__
sed -i "/^Resolved conflicted state of 'pro\/hello.pro'$/d" $TEST_DIR/"$TEST_KEY.out"
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] pro/hello.pro: in tree conflict.
Locally: edited.
Externally: renamed to pro/hello.pro.renamed.
Answer (y) to keep the file.
Answer (n) to accept the external rename.
You can then merge in changes.
Keep the local version?
Enter "y" or "n" (or just press <return> for "n") diff3 pro/hello.pro.renamed.working pro/hello.pro.renamed.merge-left.r1 pro/hello.pro.renamed.merge-right.r8
====
1:3c
  Local contents (1)
2:2a
3:3,4c
  Merge contents (1)
  Merge contents (2)
D         pro/hello.pro
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: edit, rename, discard local (status)
TEST_KEY=$TEST_KEY_BASE-discard-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
D       pro/hello.pro
A  +    pro/hello.pro.renamed
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: edit, rename, discard local (info)
TEST_KEY=$TEST_KEY_BASE-discard-info
run_pass "$TEST_KEY" svn info pro/hello.pro.renamed
sed -i "/Date:\|Updated:\|UUID:\|Checksum\|Relative URL:\|Working Copy Root Path:/d" $TEST_DIR/"$TEST_KEY.out"
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Path: pro/hello.pro.renamed
Name: hello.pro.renamed
URL: $ROOT_URL/branches/dev/Share/ctrl/pro/hello.pro.renamed
Repository Root: $REPOS_URL
Revision: 8
Node Kind: file
Schedule: add
Copied From URL: $ROOT_URL/branches/dev/Share/ed_ren/pro/hello.pro.renamed
Copied From Rev: 8
Last Changed Author: $LOGNAME
Last Changed Rev: 8

__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: delete, rename, discard local (cat)
TEST_KEY=$TEST_KEY_BASE-discard-cat
run_pass "$TEST_KEY" cat pro/hello.pro.renamed
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
PRO HELLO
END
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
# Tests fcm conflicts: edit, rename, keep local
TEST_KEY=$TEST_KEY_BASE-keep
fcm merge --non-interactive $ROOT_URL/branches/dev/Share/ed_ren >/dev/null
run_pass "$TEST_KEY" fcm conflicts <<__IN__
y
__IN__
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] pro/hello.pro: in tree conflict.
Locally: edited.
Externally: renamed to pro/hello.pro.renamed.
Answer (y) to keep the file.
Answer (n) to accept the external rename.
You can then merge in changes.
Keep the local version?
Enter "y" or "n" (or just press <return> for "n") diff3 pro/hello.pro.working pro/hello.pro.merge-left.r1 pro/hello.pro.merge-right.r8
====
1:3c
  Local contents (1)
2:2a
3:3,4c
  Merge contents (1)
  Merge contents (2)
Reverted 'pro/hello.pro.renamed'
Resolved conflicted state of 'pro/hello.pro'
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: edit, rename, keep local (status)
TEST_KEY=$TEST_KEY_BASE-keep-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: edit, rename, keep local (info)
TEST_KEY=$TEST_KEY_BASE-keep-info
run_pass "$TEST_KEY" svn info pro/hello.pro
sed -i "/Date:\|Updated:\|UUID:\|Checksum\|Relative URL:\|Working Copy Root Path:/d" $TEST_DIR/"$TEST_KEY.out"
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Path: pro/hello.pro
Name: hello.pro
URL: $ROOT_URL/branches/dev/Share/ctrl/pro/hello.pro
Repository Root: $REPOS_URL
Revision: 8
Node Kind: file
Schedule: normal
Last Changed Author: $LOGNAME
Last Changed Rev: 6

__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: delete, rename, keep local (cat)
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
