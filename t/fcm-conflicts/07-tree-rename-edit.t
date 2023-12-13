#!/bin/bash
# ------------------------------------------------------------------------------
# Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.
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
check_svn_version
tests 18
#-------------------------------------------------------------------------------
setup
init_repos
init_branch ctrl $REPOS_URL
init_branch_wc ren_ed $REPOS_URL
# Set a special (null) fcm-graphic-merge diff editor.
export FCM_GRAPHIC_MERGE=fcm-dummy-diff
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests fcm conflicts: rename, edit, discard local
TEST_KEY=$TEST_KEY_BASE-discard
svn switch -q $ROOT_URL/branches/dev/Share/ctrl
svn rename -q pro/hello.pro pro/hello.pro.renamed
svn commit -q -m "Renamed conflict file (local)"
svn update -q
echo "Local contents (1)" >>pro/hello.pro.renamed
svn commit -q -m "Modified conflict file (local)"
svn update -q
svn switch -q $ROOT_URL/branches/dev/Share/ren_ed
echo "Merge contents (1)" >>pro/hello.pro
svn commit -q -m "Modified conflict file  (merge)"
svn update -q
svn switch -q $ROOT_URL/branches/dev/Share/ctrl
fcm merge --non-interactive $ROOT_URL/branches/dev/Share/ren_ed >/dev/null
if [[ $SVN_MINOR_VERSION == "1.14" ]]; then
  run_pass "$TEST_KEY" fcm conflicts <<__IN__
y
__IN__
else
  run_pass "$TEST_KEY" fcm conflicts <<__IN__
n
__IN__
fi
file_cmp_filtered "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
#IF SVN1.8/9/10 [info] pro/hello.pro: in tree conflict.
#IF SVN1.14 [info] pro/hello.pro.renamed: in text conflict.
#IF SVN1.8/9/10 Locally: renamed to pro/hello.pro.renamed.
#IF SVN1.8/9/10 Externally: edited.
#IF SVN1.8/9/10 Answer (y) to accept the local rename.
#IF SVN1.8/9/10 Answer (n) to keep the file.
#IF SVN1.8/9/10 You can then merge in changes.
#IF SVN1.8/9/10 Keep the local version?
#IF SVN1.8/9/10 Enter "y" or "n" (or just press <return> for "n") diff3 pro/hello.pro.renamed.working pro/hello.pro.renamed.merge-left.r1 pro/hello.pro.renamed.merge-right.r8
#IF SVN1.14 diff3 $PWD/pro/hello.pro.renamed.3.tmp $PWD/pro/hello.pro.renamed.tmp $PWD/pro/hello.pro.renamed.2.tmp
====
1:3c
  Local contents (1)
2:2a
3:3c
  Merge contents (1)
#IF SVN1.8/9/10 A         pro/hello.pro
#IF SVN1.8/9/10 D         pro/hello.pro.renamed
#IF SVN1.8/9 Resolved conflicted state of 'pro/hello.pro'
#IF SVN1.10 Tree conflict at 'pro/hello.pro' marked as resolved.
#IF SVN1.14 Run "svn resolve --accept working pro/hello.pro.renamed"?
#IF SVN1.14 Enter "y" or "n" (or just press <return> for "n") Merge conflicts in 'pro/hello.pro.renamed' marked as resolved.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: rename, edit, discard local (status)
TEST_KEY=$TEST_KEY_BASE-discard-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
file_cmp_filtered "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
#IF SVN1.8/9/10 A  +    pro/hello.pro
#IF SVN1.8/9/10         > moved from pro/hello.pro.renamed
#IF SVN1.8/9/10 D       pro/hello.pro.renamed
#IF SVN1.8/9/10         > moved to pro/hello.pro
#IF SVN1.14 M       pro/hello.pro.renamed
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: rename, edit, discard local (cat)
TEST_KEY=$TEST_KEY_BASE-discard-cat
if [[ $SVN_MINOR_VERSION == "1.14" ]]; then
  run_pass "$TEST_KEY" cat pro/hello.pro.renamed
else
  run_pass "$TEST_KEY" cat pro/hello.pro
fi
file_cmp_filtered "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
PRO HELLO
END
#IF SVN1.14 <<<<<<< .working
Local contents (1)
#IF SVN1.14 ||||||| .old
#IF SVN1.14 =======
#IF SVN1.14 Merge contents (1)
#IF SVN1.14 >>>>>>> .new
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
cd $TEST_DIR
rm -rf $TEST_DIR/wc
mkdir $TEST_DIR/wc
svn checkout -q $ROOT_URL/branches/dev/Share/ctrl $TEST_DIR/wc
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests fcm conflicts: rename, edit, keep local
TEST_KEY=$TEST_KEY_BASE-keep
fcm merge --non-interactive $ROOT_URL/branches/dev/Share/ren_ed >/dev/null
run_pass "$TEST_KEY" fcm conflicts <<__IN__
y
__IN__
file_cmp_filtered "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
#IF SVN1.8/9/10 [info] pro/hello.pro: in tree conflict.
#IF SVN1.14 [info] pro/hello.pro.renamed: in text conflict.
#IF SVN1.8/9/10 Locally: renamed to pro/hello.pro.renamed.
#IF SVN1.8/9/10 Externally: edited.
#IF SVN1.8/9/10 Answer (y) to accept the local rename.
#IF SVN1.8/9/10 Answer (n) to keep the file.
#IF SVN1.8/9/10 You can then merge in changes.
#IF SVN1.8/9/10 Keep the local version?
#IF SVN1.8/9/10 Enter "y" or "n" (or just press <return> for "n") diff3 pro/hello.pro.renamed.working pro/hello.pro.renamed.merge-left.r1 pro/hello.pro.renamed.merge-right.r8
#IF SVN1.14 diff3 $PWD/pro/hello.pro.renamed.3.tmp $PWD/pro/hello.pro.renamed.tmp $PWD/pro/hello.pro.renamed.2.tmp
====
1:3c
  Local contents (1)
2:2a
3:3c
  Merge contents (1)
#IF SVN1.8/9 Resolved conflicted state of 'pro/hello.pro'
#IF SVN1.10 Tree conflict at 'pro/hello.pro' marked as resolved.
#IF SVN1.14 Run "svn resolve --accept working pro/hello.pro.renamed"?
#IF SVN1.14 Enter "y" or "n" (or just press <return> for "n") Merge conflicts in 'pro/hello.pro.renamed' marked as resolved.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: rename, edit, keep local (status)
TEST_KEY=$TEST_KEY_BASE-keep-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
file_cmp_filtered "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
#IF SVN1.14 M       pro/hello.pro.renamed
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm conflicts: rename, edit, keep local (cat)
TEST_KEY=$TEST_KEY_BASE-keep-cat
run_pass "$TEST_KEY" cat pro/hello.pro.renamed
file_cmp_filtered "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
PRO HELLO
END
#IF SVN1.14 <<<<<<< .working
Local contents (1)
#IF SVN1.14 ||||||| .old
#IF SVN1.14 =======
#IF SVN1.14 Merge contents (1)
#IF SVN1.14 >>>>>>> .new
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
teardown
