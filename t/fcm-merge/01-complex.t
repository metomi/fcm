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
# More complex tests for "fcm merge".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
check_svn_version
tests 234
#-------------------------------------------------------------------------------
setup
init_repos
init_merge_branches merge1 merge2 $REPOS_URL
export SVN_EDITOR="sed -i 1i\foo"
cd $TEST_DIR/wc
svn switch -q $ROOT_URL/branches/dev/Share/merge1
#-------------------------------------------------------------------------------
# Test the various mergeinfo output before merging.
test_mergeinfo "$TEST_KEY_BASE-trunk-into-branch-1-pre" \
    $ROOT_URL/trunk - 9 <<__RESULTS__
begin-prop
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1                  9       
    |                  |       
  -------| |------------         trunk
     \                         
      \                        
       --| |------------         branches/dev/Share/merge1
                       |       
                       WC      
end-info
begin-eligible
r8
r9
end-eligible
begin-merged
end-merged
__RESULTS__
#-------------------------------------------------------------------------------
# Tests fcm merge of trunk-into-branch (1)
TEST_KEY=$TEST_KEY_BASE-trunk-into-branch-1-non-root
cd module
run_pass "$TEST_KEY" fcm merge --non-interactive trunk
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
$TEST_DIR/wc: working directory changed to top of working copy.
Eligible merge(s) from /${PROJECT}trunk@9: 9 8
--------------------------------------------------------------------------------
Merge: /${PROJECT}trunk@9
 c.f.: /${PROJECT}trunk@1
Merge succeeded.
--------------------------------------------------------------------------actual
--- Merging r2 through r9 into '.':
U    lib/python/info/__init__.py
--- Recording mergeinfo for merge of r2 through r9 into '.':
 U   .
--------------------------------------------------------------------------actual
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
cd ..
#-------------------------------------------------------------------------------
# Tests svn status result of fcm merge (1)
TEST_KEY=$TEST_KEY_BASE-trunk-into-branch-1-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
status_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__
 M      .
?       unversioned_file
M       lib/python/info/__init__.py
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn diff result of fcm merge (1)
TEST_KEY=$TEST_KEY_BASE-trunk-into-branch-1-diff
run_pass "$TEST_KEY" svn diff
diff_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp_filtered "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__

Index: .
===================================================================
--- .	(revision 9)
+++ .	(working copy)

Property changes on: .
___________________________________________________________________
Added: svn:mergeinfo
#IF SVN1.9/10/14 ## -0,0 +0,1 ##
   Merged /${PROJECT}trunk:r2-9
Index: lib/python/info/__init__.py
===================================================================
--- lib/python/info/__init__.py	(revision 9)
+++ lib/python/info/__init__.py	(working copy)
@@ -0,0 +1,2 @@
+trunk change
+another trunk change
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm commit of fcm merge (1)
TEST_KEY=$TEST_KEY_BASE-trunk-into-branch-1-commit
run_pass "$TEST_KEY" fcm commit <<__IN__
y
__IN__
commit_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__
[info] sed -i 1i\foo: starting commit message editor...
Change summary:
--------------------------------------------------------------------------------
[Root   : $REPOS_URL]
[Project: ${TEST_PROJECT:-}]
[Branch : branches/dev/Share/merge1]
[Sub-dir: ]
 M      .
M       lib/python/info/__init__.py
--------------------------------------------------------------------------------
Commit message is as follows:
--------------------------------------------------------------------------------
foo
Merged into /${PROJECT}branches/dev/Share/merge1: /${PROJECT}trunk@9 cf. /${PROJECT}trunk@1
--------------------------------------------------------------------------------
*** WARNING: YOU ARE COMMITTING TO A Share BRANCH.
*** Please ensure that you have the owner's permission.
Would you like to commit this change?
Enter "y" or "n" (or just press <return> for "n"): Sending        .
Sending        lib/python/info/__init__.py
Committed revision 10.
Updating '.':
At revision 10.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm log of fcm merge (1)
TEST_KEY=$TEST_KEY_BASE-trunk-into-branch-1-log
run_pass "$TEST_KEY" fcm log
sed -i "s/\(.*|.*|\).*\(|.*\)$/\1 date \2/g" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
------------------------------------------------------------------------
r10 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}branches/dev/Share/merge1: /${PROJECT}trunk@9 cf. /${PROJECT}trunk@1

------------------------------------------------------------------------
r5 | $LOGNAME | date | 1 line

Made changes for future merge of this branch
------------------------------------------------------------------------
r4 | $LOGNAME | date | 1 line

Made a branch Created /${PROJECT}branches/dev/Share/merge1 from /trunk@1.
------------------------------------------------------------------------
r1 | $LOGNAME | date | 1 line

initial trunk import
------------------------------------------------------------------------
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Test the various mergeinfo output after merging.
test_mergeinfo "$TEST_KEY_BASE-trunk-into-branch-1-post" \
    $ROOT_URL/trunk - 10 <<__RESULTS__
begin-prop
/trunk:2-9
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1         9        10      
    |         |        |       
  -------| |------------         trunk
     \         \               
      \         \              
       --| |------------         branches/dev/Share/merge1
                       |       
                       WC      
end-info
begin-eligible
end-eligible
begin-merged
r8
r9
end-merged
__RESULTS__
#-------------------------------------------------------------------------------
# Tests fcm merge of branch-into-trunk (1)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-1
BRANCH_MOD_FILE="added_directory/hello_constants_dummy.inc"
echo "# added this line for simple repeat testing" >>$BRANCH_MOD_FILE
svn commit -q -m "edit on branch for merge repeat test"
svn update -q
cd $TEST_DIR
rm -rf $TEST_DIR/wc
mkdir $TEST_DIR/wc
svn checkout -q $ROOT_URL/trunk $TEST_DIR/wc
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Test the various mergeinfo output before merging.
test_mergeinfo "$TEST_KEY_BASE-branch-into-trunk-1-pre" \
    $ROOT_URL/branches/dev/Share/merge1 - 11 <<__RESULTS__
begin-prop
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1                  11      
    |                  |       
       --| |------------         branches/dev/Share/merge1
      /         /              
     /         /               
  -------| |------------         trunk
              |        |       
              9        WC      
end-info
begin-eligible
r5
r10
r11
end-eligible
begin-merged
end-merged
__RESULTS__
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-1
run_pass "$TEST_KEY" fcm merge --non-interactive branches/dev/Share/merge1
merge_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__
Eligible merge(s) from /${PROJECT}branches/dev/Share/merge1@11: 11 10
--------------------------------------------------------------------------------
Merge: /${PROJECT}branches/dev/Share/merge1@11
 c.f.: /${PROJECT}trunk@9
Merge succeeded.
--------------------------------------------------------------------------actual
--- Merging differences between repository URLs into '.':
A    added_directory
A    added_directory/hello_constants.f90
A    added_directory/hello_constants.inc
A    added_directory/hello_constants_dummy.inc
A    added_file
A    module/tree_conflict_file
U    lib/python/info/poems.py
U    module/hello_constants.f90
U    module/hello_constants.inc
U    module/hello_constants_dummy.inc
U    subroutine/hello_sub_dummy.h
--- Recording mergeinfo for merge between repository URLs into '.':
 U   .
--------------------------------------------------------------------------actual
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn status result of fcm merge (1)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-1-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
status_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__
 M      .
A  +    added_directory
A  +    added_file
A  +    module/tree_conflict_file
M       lib/python/info/poems.py
M       module/hello_constants.f90
M       module/hello_constants.inc
M       module/hello_constants_dummy.inc
M       subroutine/hello_sub_dummy.h
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn diff result of fcm merge (1)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-1-diff
run_pass "$TEST_KEY" svn diff
diff_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp_filtered "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__

Index: .
===================================================================
--- .	(revision 11)
+++ .	(working copy)

Property changes on: .
___________________________________________________________________
Added: svn:mergeinfo
#IF SVN1.9/10/14 ## -0,0 +0,1 ##
   Merged /${PROJECT}branches/dev/Share/merge1:r4-11
#IF SVN1.9/10/14 Index: added_directory/hello_constants.f90
#IF SVN1.9/10/14 ===================================================================
#IF SVN1.9/10/14 Index: added_directory/hello_constants.inc
#IF SVN1.9/10/14 ===================================================================
#IF SVN1.9/10/14 Index: added_directory/hello_constants_dummy.inc
#IF SVN1.9/10/14 ===================================================================
#IF SVN1.9/10/14 Index: added_file
#IF SVN1.9/10/14 ===================================================================
Index: lib/python/info/poems.py
===================================================================
--- lib/python/info/poems.py	(revision 11)
+++ lib/python/info/poems.py	(working copy)
@@ -1,24 +1,23 @@
-#!/usr/bin/env python
-# -*- coding: utf-8 -*-
 """The Python, by Hilaire Belloc
 
 A Python I should not advise,--
-It needs a doctor for its eyes,
+It needs a doctor FOR its eyes,
 And has the measles yearly.
-However, if you feel inclined
-To get one (to improve your mind,
+However, if you feel INclINed
+To get one (
+to improve your mINd,
 And not from fashion merely),
 Allow no music near its cage;
-And when it flies into a rage
+And when it flies INto a rage
 Chastise it, most severely.
-I had an aunt in Yucatan
+I had an aunt IN Yucatan
 Who bought a Python from a man
-And kept it for a pet.
+And kept it FOR a pet.
 She died, because she never knew
 These simple little rules and few;--
-The Snake is living yet.
+The Snake is livINg yet.
 """
 
 import this
 
-print "\n",  __doc__
+prINt "\n",  __doc__
Index: module/hello_constants.f90
===================================================================
--- module/hello_constants.f90	(revision 11)
+++ module/hello_constants.f90	(working copy)
@@ -1,5 +1,5 @@
 MODULE Hello_Constants
 
-INCLUDE 'hello_constants_dummy.inc'
+INCLUDE 'hello_constants_dummy.INc'
 
 END MODULE Hello_Constants
Index: module/hello_constants.inc
===================================================================
--- module/hello_constants.inc	(revision 11)
+++ module/hello_constants.inc	(working copy)
@@ -1 +1,2 @@
-CHARACTER (LEN=80), PARAMETER :: hello_string = 'Hello Earth!'
+CHARACTER (
+LEN=80), PARAMETER :: hello_strINg = 'Hello Earth!!'
Index: module/hello_constants_dummy.inc
===================================================================
--- module/hello_constants_dummy.inc	(revision 11)
+++ module/hello_constants_dummy.inc	(working copy)
@@ -1 +1 @@
-INCLUDE 'hello_constants.inc'
+INCLUDE 'hello_constants.INc'
#IF SVN1.9/10/14 Index: module/tree_conflict_file
#IF SVN1.9/10/14 ===================================================================
Index: subroutine/hello_sub_dummy.h
===================================================================
--- subroutine/hello_sub_dummy.h	(revision 11)
+++ subroutine/hello_sub_dummy.h	(working copy)
@@ -1 +1,2 @@
 #include "hello_sub.h"
+Modified a line
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm commit of fcm merge (1)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-1-commit
run_pass "$TEST_KEY" fcm commit <<__IN__
y
__IN__
commit_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__
[info] sed -i 1i\foo: starting commit message editor...
Change summary:
--------------------------------------------------------------------------------
[Root   : $REPOS_URL]
[Project: ${TEST_PROJECT:-}]
[Branch : trunk]
[Sub-dir: ]
 M      .
A  +    added_directory
A  +    added_file
A  +    module/tree_conflict_file
M       lib/python/info/poems.py
M       module/hello_constants.f90
M       module/hello_constants.inc
M       module/hello_constants_dummy.inc
M       subroutine/hello_sub_dummy.h
--------------------------------------------------------------------------------
Commit message is as follows:
--------------------------------------------------------------------------------
foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@11 cf. /${PROJECT}trunk@9
--------------------------------------------------------------------------------
*** WARNING: YOU ARE COMMITTING TO THE TRUNK.
*** Please ensure that your change conforms to your project's working practices.
Would you like to commit this change?
Enter "y" or "n" (or just press <return> for "n"): Sending        .
Adding         added_directory
Adding         added_file
Adding         module/tree_conflict_file
Sending        lib/python/info/poems.py
Sending        module/hello_constants.f90
Sending        module/hello_constants.inc
Sending        module/hello_constants_dummy.inc
Sending        subroutine/hello_sub_dummy.h
Committed revision 12.
Updating '.':
At revision 12.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm log of fcm merge branch-into-trunk (1)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-1-log
run_pass "$TEST_KEY" fcm log
sed -i "s/\(.*|.*|\).*\(|.*\)$/\1 date \2/g" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
------------------------------------------------------------------------
r12 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@11 cf. /${PROJECT}trunk@9

------------------------------------------------------------------------
r9 | $LOGNAME | date | 1 line

Made another trunk change
------------------------------------------------------------------------
r8 | $LOGNAME | date | 1 line

Made trunk change
------------------------------------------------------------------------
r1 | $LOGNAME | date | 1 line

initial trunk import
------------------------------------------------------------------------
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Test the various mergeinfo output after merging.
test_mergeinfo "$TEST_KEY_BASE-branch-into-trunk-1-post" \
    $ROOT_URL/branches/dev/Share/merge1 - 12 <<__RESULTS__
begin-prop
/branches/dev/Share/merge1:4-11
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1         11       12      
    |         |        |       
       --| |------------         branches/dev/Share/merge1
      /        \               
     /          \              
  -------| |------------         trunk
                       |       
                       WC      
end-info
begin-eligible
end-eligible
begin-merged
r4
r5
r10
r11
end-merged
__RESULTS__
#-------------------------------------------------------------------------------
# Tests fcm merge of branch-into-trunk (2)
svn switch -q $ROOT_URL/branches/dev/Share/merge1
MOD_FILE="added_file"
echo "call_extra_feature()" >>$MOD_FILE
svn commit -q -m "Made branch change to add extra feature"
svn update -q
# Create a new branch to up the revision number, as a test.
init_branch merge3 $REPOS_URL
# Checkout the trunk.
svn switch -q $ROOT_URL/trunk
#-------------------------------------------------------------------------------
# Test the various mergeinfo output before merging.
test_mergeinfo "$TEST_KEY_BASE-branch-into-trunk-2-pre" \
    $ROOT_URL/branches/dev/Share/merge1 - 14 <<__RESULTS__
begin-prop
/branches/dev/Share/merge1:4-11
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1         11       14      
    |         |        |       
       --| |------------         branches/dev/Share/merge1
      /        \               
     /          \              
  -------| |------------         trunk
                       |       
                       WC      
end-info
begin-eligible
r13
end-eligible
begin-merged
r4
r5
r10
r11
end-merged
__RESULTS__
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-2
run_pass "$TEST_KEY" fcm merge --non-interactive branches/dev/Share/merge1
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Eligible merge(s) from /${PROJECT}branches/dev/Share/merge1@14: 13
--------------------------------------------------------------------------------
Merge: /${PROJECT}branches/dev/Share/merge1@13
 c.f.: /${PROJECT}branches/dev/Share/merge1@11
Merge succeeded.
--------------------------------------------------------------------------actual
--- Merging r12 through r13 into '.':
U    added_file
--- Recording mergeinfo for merge of r12 through r13 into '.':
 U   .
--------------------------------------------------------------------------actual
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn status result of fcm merge branch-into-trunk (2)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-2-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
M       added_file
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn diff result of fcm merge branch-into-trunk (2)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-2-diff
run_pass "$TEST_KEY" svn diff
diff_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp_filtered "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__

Index: .
===================================================================
--- .	(revision 14)
+++ .	(working copy)

Property changes on: .
___________________________________________________________________
Modified: svn:mergeinfo
#IF SVN1.9/10/14 ## -0,0 +0,1 ##
   Merged /${PROJECT}branches/dev/Share/merge1:r12-13
Index: added_file
===================================================================
--- added_file	(revision 14)
+++ added_file	(working copy)
@@ -1 +1,2 @@
 INCLUDE 'hello_constants.INc'
+call_extra_feature()
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm commit of fcm merge branch-into-trunk (2)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-2-commit
run_pass "$TEST_KEY" fcm commit <<__IN__
y
__IN__
sed -i "/^Updating '.':$/d" "$TEST_DIR/$TEST_KEY.out"
commit_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__
[info] sed -i 1i\foo: starting commit message editor...
Change summary:
--------------------------------------------------------------------------------
[Root   : $REPOS_URL]
[Project: ${TEST_PROJECT:-}]
[Branch : trunk]
[Sub-dir: ]
 M      .
M       added_file
--------------------------------------------------------------------------------
Commit message is as follows:
--------------------------------------------------------------------------------
foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@13 cf. /${PROJECT}branches/dev/Share/merge1@11
--------------------------------------------------------------------------------
*** WARNING: YOU ARE COMMITTING TO THE TRUNK.
*** Please ensure that your change conforms to your project's working practices.
Would you like to commit this change?
Enter "y" or "n" (or just press <return> for "n"): Sending        .
Sending        added_file
Committed revision 15.
At revision 15.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm log of fcm merge branch-into-trunk (2)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-2-log
run_pass "$TEST_KEY" fcm log
sed -i "s/\(.*|.*|\).*\(|.*\)$/\1 date \2/g" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
------------------------------------------------------------------------
r15 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@13 cf. /${PROJECT}branches/dev/Share/merge1@11

------------------------------------------------------------------------
r12 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@11 cf. /${PROJECT}trunk@9

------------------------------------------------------------------------
r9 | $LOGNAME | date | 1 line

Made another trunk change
------------------------------------------------------------------------
r8 | $LOGNAME | date | 1 line

Made trunk change
------------------------------------------------------------------------
r1 | $LOGNAME | date | 1 line

initial trunk import
------------------------------------------------------------------------
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Test the various mergeinfo output after merging.
test_mergeinfo "$TEST_KEY_BASE-branch-into-trunk-2-post" \
    $ROOT_URL/branches/dev/Share/merge1 - 15 <<__RESULTS__
begin-prop
/branches/dev/Share/merge1:4-13
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1         13       15      
    |         |        |       
       --| |------------         branches/dev/Share/merge1
      /        \               
     /          \              
  -------| |------------         trunk
                       |       
                       WC      
end-info
begin-eligible
end-eligible
begin-merged
r4
r5
r10
r11
r13
end-merged
__RESULTS__
#-------------------------------------------------------------------------------
# Tests fcm merge of trunk-into-branch (2)
echo "# trunk modification" >>$MOD_FILE
svn commit -q -m "Made trunk change - a simple edit of $MOD_FILE"
svn update -q
svn switch -q $ROOT_URL/branches/dev/Share/merge1

echo "# added another line for simple repeat testing" >>$BRANCH_MOD_FILE
svn commit -q -m "Made branch change for merge repeat test"
svn update -q
#------------------------------------------------------------------------------
# Test the various mergeinfo output before merging.
test_mergeinfo "$TEST_KEY_BASE-trunk-into-branch-2-pre" \
    $ROOT_URL/trunk - 17 <<__RESULTS__
begin-prop
/trunk:2-9
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1                  17      
    |                  |       
  -------| |------------         trunk
     \          /              
      \        /               
       --| |------------         branches/dev/Share/merge1
              |        |       
              13       WC      
end-info
begin-eligible
r12
r15
r16
end-eligible
begin-merged
r8
r9
end-merged
__RESULTS__
#------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-trunk-into-branch-2
run_pass "$TEST_KEY" fcm merge --non-interactive trunk
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Eligible merge(s) from /${PROJECT}trunk@17: 16 15
--------------------------------------------------------------------------------
Merge: /${PROJECT}trunk@16
 c.f.: /${PROJECT}branches/dev/Share/merge1@13
Merge succeeded.
--------------------------------------------------------------------------actual
--- Merging differences between repository URLs into '.':
U    added_file
--- Recording mergeinfo for merge between repository URLs into '.':
 U   .
--------------------------------------------------------------------------actual
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn status result of fcm merge trunk-into-branch (2)
TEST_KEY=$TEST_KEY_BASE-trunk-into-branch-2-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
M       added_file
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn diff result of fcm merge trunk-into-branch (2)
TEST_KEY=$TEST_KEY_BASE-trunk-into-branch-2-diff
run_pass "$TEST_KEY" svn diff
diff_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp_filtered "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__

Index: .
===================================================================
--- .	(revision 17)
+++ .	(working copy)

Property changes on: .
___________________________________________________________________
Modified: svn:mergeinfo
#IF SVN1.9/10/14 ## -0,0 +0,1 ##
   Merged /${PROJECT}trunk:r10-16
Index: added_file
===================================================================
--- added_file	(revision 17)
+++ added_file	(working copy)
@@ -1,2 +1,3 @@
 INCLUDE 'hello_constants.INc'
 call_extra_feature()
+# trunk modification
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm commit of fcm merge trunk-into-branch (2)
TEST_KEY=$TEST_KEY_BASE-trunk-into-branch-2-commit
run_pass "$TEST_KEY" fcm commit <<__IN__
y
__IN__
sed -i "/^Updating '.':$/d" "$TEST_DIR/$TEST_KEY.out"
commit_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__
[info] sed -i 1i\foo: starting commit message editor...
Change summary:
--------------------------------------------------------------------------------
[Root   : $REPOS_URL]
[Project: ${TEST_PROJECT:-}]
[Branch : branches/dev/Share/merge1]
[Sub-dir: ]
 M      .
M       added_file
--------------------------------------------------------------------------------
Commit message is as follows:
--------------------------------------------------------------------------------
foo
Merged into /${PROJECT}branches/dev/Share/merge1: /${PROJECT}trunk@16 cf. /${PROJECT}branches/dev/Share/merge1@13
--------------------------------------------------------------------------------
*** WARNING: YOU ARE COMMITTING TO A Share BRANCH.
*** Please ensure that you have the owner's permission.
Would you like to commit this change?
Enter "y" or "n" (or just press <return> for "n"): Sending        .
Sending        added_file
Committed revision 18.
At revision 18.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm log of fcm merge trunk-into-branch (2)
TEST_KEY=$TEST_KEY_BASE-trunk-into-branch-2-log
run_pass "$TEST_KEY" fcm log
sed -i "s/\(.*|.*|\).*\(|.*\)$/\1 date \2/g" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
------------------------------------------------------------------------
r18 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}branches/dev/Share/merge1: /${PROJECT}trunk@16 cf. /${PROJECT}branches/dev/Share/merge1@13

------------------------------------------------------------------------
r17 | $LOGNAME | date | 1 line

Made branch change for merge repeat test
------------------------------------------------------------------------
r13 | $LOGNAME | date | 1 line

Made branch change to add extra feature
------------------------------------------------------------------------
r11 | $LOGNAME | date | 1 line

edit on branch for merge repeat test
------------------------------------------------------------------------
r10 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}branches/dev/Share/merge1: /${PROJECT}trunk@9 cf. /${PROJECT}trunk@1

------------------------------------------------------------------------
r5 | $LOGNAME | date | 1 line

Made changes for future merge of this branch
------------------------------------------------------------------------
r4 | $LOGNAME | date | 1 line

Made a branch Created /${PROJECT}branches/dev/Share/merge1 from /trunk@1.
------------------------------------------------------------------------
r1 | $LOGNAME | date | 1 line

initial trunk import
------------------------------------------------------------------------
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Test the various mergeinfo output after merging.
test_mergeinfo "$TEST_KEY_BASE-trunk-into-branch-2-post" \
    $ROOT_URL/trunk - 18 <<__RESULTS__
begin-prop
/trunk:2-16
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1         16       18      
    |         |        |       
  -------| |------------         trunk
     \         \               
      \         \              
       --| |------------         branches/dev/Share/merge1
                       |       
                       WC      
end-info
begin-eligible
end-eligible
begin-merged
r8
r9
r12
r15
r16
end-merged
__RESULTS__
#-------------------------------------------------------------------------------
# Tests fcm merge of branch-into-trunk (3)
svn delete -q $BRANCH_MOD_FILE
svn copy -q $MOD_FILE $MOD_FILE.add
svn commit -q -m "Made branch change - deleted $BRANCH_MOD_FILE, copied $MOD_FILE"
svn update -q
svn switch -q $ROOT_URL/trunk
#-------------------------------------------------------------------------------
# Test the various mergeinfo output before merging.
test_mergeinfo "$TEST_KEY_BASE-branch-into-trunk-3-pre" \
    $ROOT_URL/branches/dev/Share/merge1 - 19 <<__RESULTS__
begin-prop
/branches/dev/Share/merge1:4-13
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1                  19      
    |                  |       
       --| |------------         branches/dev/Share/merge1
      /         /              
     /         /               
  -------| |------------         trunk
              |        |       
              16       WC      
end-info
begin-eligible
r17
r18
r19
end-eligible
begin-merged
r4
r5
r10
r11
r13
end-merged
__RESULTS__
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-3
run_pass "$TEST_KEY" fcm merge --non-interactive branches/dev/Share/merge1
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Eligible merge(s) from /${PROJECT}branches/dev/Share/merge1@19: 19 18
--------------------------------------------------------------------------------
Merge: /${PROJECT}branches/dev/Share/merge1@19
 c.f.: /${PROJECT}trunk@16
Merge succeeded.
--------------------------------------------------------------------------actual
--- Merging differences between repository URLs into '.':
D    added_directory/hello_constants_dummy.inc
A    added_file.add
--- Recording mergeinfo for merge between repository URLs into '.':
 U   .
--------------------------------------------------------------------------actual
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn status result of fcm merge branch-into-trunk (3)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-3-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
D       added_directory/hello_constants_dummy.inc
A  +    added_file.add
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn diff result of fcm merge branch-into-trunk (3)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-3-diff
run_pass "$TEST_KEY" svn diff
diff_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp_filtered "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__

Index: .
===================================================================
--- .	(revision 19)
+++ .	(working copy)

Property changes on: .
___________________________________________________________________
Modified: svn:mergeinfo
#IF SVN1.9/10/14 ## -0,0 +0,1 ##
   Merged /${PROJECT}branches/dev/Share/merge1:r14-19
Index: added_directory/hello_constants_dummy.inc
===================================================================
--- added_directory/hello_constants_dummy.inc	(revision 19)
+++ added_directory/hello_constants_dummy.inc	(working copy)
@@ -1,2 +0,0 @@
-INCLUDE 'hello_constants.INc'
-# added this line for simple repeat testing
#IF SVN1.9/10/14 Index: added_file.add
#IF SVN1.9/10/14 ===================================================================
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm commit of fcm merge branch-into-trunk (3)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-3-commit
run_pass "$TEST_KEY" fcm commit <<__IN__
y
__IN__
sed -i "/^Updating '.':$/d" $TEST_DIR/"$TEST_KEY.out"
commit_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__
[info] sed -i 1i\foo: starting commit message editor...
Change summary:
--------------------------------------------------------------------------------
[Root   : $REPOS_URL]
[Project: ${TEST_PROJECT:-}]
[Branch : trunk]
[Sub-dir: ]
 M      .
A  +    added_file.add
D       added_directory/hello_constants_dummy.inc
--------------------------------------------------------------------------------
Commit message is as follows:
--------------------------------------------------------------------------------
foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@19 cf. /${PROJECT}trunk@16
--------------------------------------------------------------------------------
*** WARNING: YOU ARE COMMITTING TO THE TRUNK.
*** Please ensure that your change conforms to your project's working practices.
Would you like to commit this change?
Enter "y" or "n" (or just press <return> for "n"): Sending        .
Adding         added_file.add
Deleting       added_directory/hello_constants_dummy.inc
Committed revision 20.
At revision 20.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm log of fcm merge branch-into-trunk (3)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-3-log
run_pass "$TEST_KEY" fcm log $ROOT_URL
sed -i "s/\(.*|.*|\).*\(|.*\)$/\1 date \2/g" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
------------------------------------------------------------------------
r20 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@19 cf. /${PROJECT}trunk@16

------------------------------------------------------------------------
r19 | $LOGNAME | date | 1 line

Made branch change - deleted added_directory/hello_constants_dummy.inc, copied added_file
------------------------------------------------------------------------
r18 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}branches/dev/Share/merge1: /${PROJECT}trunk@16 cf. /${PROJECT}branches/dev/Share/merge1@13

------------------------------------------------------------------------
r17 | $LOGNAME | date | 1 line

Made branch change for merge repeat test
------------------------------------------------------------------------
r16 | $LOGNAME | date | 1 line

Made trunk change - a simple edit of added_file
------------------------------------------------------------------------
r15 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@13 cf. /${PROJECT}branches/dev/Share/merge1@11

------------------------------------------------------------------------
r14 | $LOGNAME | date | 1 line

Made a branch Created /branches/dev/Share/merge3 from /trunk@1.
------------------------------------------------------------------------
r13 | $LOGNAME | date | 1 line

Made branch change to add extra feature
------------------------------------------------------------------------
r12 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@11 cf. /${PROJECT}trunk@9

------------------------------------------------------------------------
r11 | $LOGNAME | date | 1 line

edit on branch for merge repeat test
------------------------------------------------------------------------
r10 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}branches/dev/Share/merge1: /${PROJECT}trunk@9 cf. /${PROJECT}trunk@1

------------------------------------------------------------------------
r9 | $LOGNAME | date | 1 line

Made another trunk change
------------------------------------------------------------------------
r8 | $LOGNAME | date | 1 line

Made trunk change
------------------------------------------------------------------------
r7 | $LOGNAME | date | 1 line

Made changes for future merge
------------------------------------------------------------------------
r6 | $LOGNAME | date | 1 line

Made a branch Created /${PROJECT}branches/dev/Share/merge2 from /trunk@1.
------------------------------------------------------------------------
r5 | $LOGNAME | date | 1 line

Made changes for future merge of this branch
------------------------------------------------------------------------
r4 | $LOGNAME | date | 1 line

Made a branch Created /${PROJECT}branches/dev/Share/merge1 from /trunk@1.
------------------------------------------------------------------------
r3 | $LOGNAME | date | 1 line

 
------------------------------------------------------------------------
r2 | $LOGNAME | date | 1 line

make tags
------------------------------------------------------------------------
r1 | $LOGNAME | date | 1 line

initial trunk import
------------------------------------------------------------------------
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Test the various mergeinfo output after merging.
test_mergeinfo "$TEST_KEY_BASE-branch-into-trunk-3-post" \
    $ROOT_URL/branches/dev/Share/merge1 - 20 <<__RESULTS__
begin-prop
/branches/dev/Share/merge1:4-19
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1         19       20      
    |         |        |       
       --| |------------         branches/dev/Share/merge1
      /        \               
     /          \              
  -------| |------------         trunk
                       |       
                       WC      
end-info
begin-eligible
end-eligible
begin-merged
r4
r5
r10
r11
r13
r17
r18
r19
end-merged
__RESULTS__
#-------------------------------------------------------------------------------
# Tests fcm merge of branch-into-branch (1)
cd $TEST_DIR
rm -rf $TEST_DIR/wc
mkdir $TEST_DIR/wc
svn checkout -q $ROOT_URL/branches/dev/Share/merge2 $TEST_DIR/wc
cd $TEST_DIR/wc
BRANCH_2_MOD_FILE="module/hello_constants.f90"
echo "Second branch change" >>$BRANCH_2_MOD_FILE
svn commit -q -m "Made branch change - added to $BRANCH_2_MOD_FILE"
svn update -q
#------------------------------------------------------------------------------
# Test the various mergeinfo output before merging.
test_mergeinfo "$TEST_KEY_BASE-branch-into-branch-1-pre" \
    $ROOT_URL/branches/dev/Share/merge1 - 21 <<__RESULTS__
begin-prop
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1                  21      
    |                  |       
       --| |------------         branches/dev/Share/merge1
  ... /                        
      \                        
       --| |------------         branches/dev/Share/merge2
                       |       
                       WC      
end-info
begin-eligible
r5
r10
r11
r13
r17
r18
r19
end-eligible
begin-merged
end-merged
__RESULTS__
#------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-branch-into-branch-1
run_pass "$TEST_KEY" fcm merge $ROOT_URL/branches/dev/Share/merge1 <<__IN__
13
y
__IN__
merge_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__
Eligible merge(s) from /${PROJECT}branches/dev/Share/merge1@21: 19 18 17 13 11 10 5
Enter a revision (or just press <return> for "19"): --------------------------------------------------------------------------------
Merge: /${PROJECT}branches/dev/Share/merge1@13
 c.f.: /${PROJECT}trunk@1
-------------------------------------------------------------------------dry-run
--- Merging r4 through r13 into '.':
 U   .
A    added_directory
A    added_directory/hello_constants.f90
A    added_directory/hello_constants.inc
A    added_directory/hello_constants_dummy.inc
A    added_file
A    module/tree_conflict_file
U    lib/python/info/__init__.py
U    lib/python/info/poems.py
U    module/hello_constants.f90
U    module/hello_constants.inc
U    module/hello_constants_dummy.inc
U    subroutine/hello_sub_dummy.h
-------------------------------------------------------------------------dry-run
Would you like to go ahead with the merge?
Enter "y" or "n" (or just press <return> for "n"): 
Merge succeeded.
--------------------------------------------------------------------------actual
--- Merging r4 through r13 into '.':
 U   .
A    added_directory
A    added_directory/hello_constants.f90
A    added_directory/hello_constants.inc
A    added_directory/hello_constants_dummy.inc
A    added_file
A    module/tree_conflict_file
U    lib/python/info/__init__.py
U    lib/python/info/poems.py
U    module/hello_constants.f90
U    module/hello_constants.inc
U    module/hello_constants_dummy.inc
U    subroutine/hello_sub_dummy.h
--- Recording mergeinfo for merge of r4 through r13 into '.':
 G   .
--------------------------------------------------------------------------actual
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn status result of fcm merge branch-into-branch (1)
TEST_KEY=$TEST_KEY_BASE-branch-into-branch-1-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
status_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__
 M      .
A  +    added_directory
A  +    added_file
A  +    module/tree_conflict_file
M       lib/python/info/__init__.py
M       lib/python/info/poems.py
M       module/hello_constants.f90
M       module/hello_constants.inc
M       module/hello_constants_dummy.inc
M       subroutine/hello_sub_dummy.h
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn diff result of fcm merge branch-into-branch (1)
TEST_KEY=$TEST_KEY_BASE-branch-into-branch-1-diff
run_pass "$TEST_KEY" svn diff
diff_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp_filtered "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__

Index: .
===================================================================
--- .	(revision 21)
+++ .	(working copy)

Property changes on: .
___________________________________________________________________
Added: svn:mergeinfo
#IF SVN1.9/10/14 ## -0,0 +0,2 ##
   Merged /${PROJECT}trunk:r2-9
   Merged /${PROJECT}branches/dev/Share/merge1:r4-13
#IF SVN1.9/10/14 Index: added_directory/hello_constants.f90
#IF SVN1.9/10/14 ===================================================================
#IF SVN1.9/10/14 Index: added_directory/hello_constants.inc
#IF SVN1.9/10/14 ===================================================================
#IF SVN1.9/10/14 Index: added_directory/hello_constants_dummy.inc
#IF SVN1.9/10/14 ===================================================================
#IF SVN1.9/10/14 Index: added_file
#IF SVN1.9/10/14 ===================================================================
Index: lib/python/info/__init__.py
===================================================================
--- lib/python/info/__init__.py	(revision 21)
+++ lib/python/info/__init__.py	(working copy)
@@ -0,0 +1,2 @@
+trunk change
+another trunk change
Index: lib/python/info/poems.py
===================================================================
--- lib/python/info/poems.py	(revision 21)
+++ lib/python/info/poems.py	(working copy)
@@ -1,24 +1,23 @@
-#!/usr/bin/env python
-# -*- coding: utf-8 -*-
 """The Python, by Hilaire Belloc
 
 A Python I should not advise,--
-It needs a doctor for its eyes,
+It needs a doctor FOR its eyes,
 And has the measles yearly.
-However, if you feel inclined
-To get one (to improve your mind,
+However, if you feel INclINed
+To get one (
+to improve your mINd,
 And not from fashion merely),
 Allow no music near its cage;
-And when it flies into a rage
+And when it flies INto a rage
 Chastise it, most severely.
-I had an aunt in Yucatan
+I had an aunt IN Yucatan
 Who bought a Python from a man
-And kept it for a pet.
+And kept it FOR a pet.
 She died, because she never knew
 These simple little rules and few;--
-The Snake is living yet.
+The Snake is livINg yet.
 """
 
 import this
 
-print "\n",  __doc__
+prINt "\n",  __doc__
Index: module/hello_constants.f90
===================================================================
--- module/hello_constants.f90	(revision 21)
+++ module/hello_constants.f90	(working copy)
@@ -1,6 +1,6 @@
 MODULE Hello_Constants
 
-INCLUDE 'hello_constants_dummy.inc'
+INCLUDE 'hello_constants_dummy.INc'
 
 END MODULE Hello_Constants
 Second branch change
Index: module/hello_constants.inc
===================================================================
--- module/hello_constants.inc	(revision 21)
+++ module/hello_constants.inc	(working copy)
@@ -1 +1,2 @@
-CHARACTER (LEN=80), PARAMETER :: hello_string = 'Hello Earth!'
+CHARACTER (
+LEN=80), PARAMETER :: hello_strINg = 'Hello Earth!!'
Index: module/hello_constants_dummy.inc
===================================================================
--- module/hello_constants_dummy.inc	(revision 21)
+++ module/hello_constants_dummy.inc	(working copy)
@@ -1 +1 @@
-INCLUDE 'hello_constants.inc'
+INCLUDE 'hello_constants.INc'
#IF SVN1.9/10/14 Index: module/tree_conflict_file
#IF SVN1.9/10/14 ===================================================================
Index: subroutine/hello_sub_dummy.h
===================================================================
--- subroutine/hello_sub_dummy.h	(revision 21)
+++ subroutine/hello_sub_dummy.h	(working copy)
@@ -1 +1,2 @@
 #include "hello_sub.h"
+Modified a line
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm commit of fcm merge branch-into-branch (1)
TEST_KEY=$TEST_KEY_BASE-branch-into-branch-1-commit
run_pass "$TEST_KEY" fcm commit <<__IN__
y
__IN__
commit_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<__OUT__
[info] sed -i 1i\foo: starting commit message editor...
Change summary:
--------------------------------------------------------------------------------
[Root   : $REPOS_URL]
[Project: ${TEST_PROJECT:-}]
[Branch : branches/dev/Share/merge2]
[Sub-dir: ]
 M      .
A  +    added_directory
A  +    added_file
A  +    module/tree_conflict_file
M       lib/python/info/__init__.py
M       lib/python/info/poems.py
M       module/hello_constants.f90
M       module/hello_constants.inc
M       module/hello_constants_dummy.inc
M       subroutine/hello_sub_dummy.h
--------------------------------------------------------------------------------
Commit message is as follows:
--------------------------------------------------------------------------------
foo
Merged into /${PROJECT}branches/dev/Share/merge2: /${PROJECT}branches/dev/Share/merge1@13 cf. /${PROJECT}trunk@1
--------------------------------------------------------------------------------
*** WARNING: YOU ARE COMMITTING TO A Share BRANCH.
*** Please ensure that you have the owner's permission.
Would you like to commit this change?
Enter "y" or "n" (or just press <return> for "n"): Sending        .
Adding         added_directory
Adding         added_file
Adding         module/tree_conflict_file
Sending        lib/python/info/__init__.py
Sending        lib/python/info/poems.py
Sending        module/hello_constants.f90
Sending        module/hello_constants.inc
Sending        module/hello_constants_dummy.inc
Sending        subroutine/hello_sub_dummy.h
Committed revision 22.
Updating '.':
At revision 22.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm log of fcm merge branch-into-branch (1)
TEST_KEY=$TEST_KEY_BASE-branch-into-branch-1-log
run_pass "$TEST_KEY" fcm log $REPOS_URL
sed -i "s/\(.*|.*|\).*\(|.*\)$/\1 date \2/g" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
------------------------------------------------------------------------
r22 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}branches/dev/Share/merge2: /${PROJECT}branches/dev/Share/merge1@13 cf. /${PROJECT}trunk@1

------------------------------------------------------------------------
r21 | $LOGNAME | date | 1 line

Made branch change - added to module/hello_constants.f90
------------------------------------------------------------------------
r20 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@19 cf. /${PROJECT}trunk@16

------------------------------------------------------------------------
r19 | $LOGNAME | date | 1 line

Made branch change - deleted added_directory/hello_constants_dummy.inc, copied added_file
------------------------------------------------------------------------
r18 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}branches/dev/Share/merge1: /${PROJECT}trunk@16 cf. /${PROJECT}branches/dev/Share/merge1@13

------------------------------------------------------------------------
r17 | $LOGNAME | date | 1 line

Made branch change for merge repeat test
------------------------------------------------------------------------
r16 | $LOGNAME | date | 1 line

Made trunk change - a simple edit of added_file
------------------------------------------------------------------------
r15 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@13 cf. /${PROJECT}branches/dev/Share/merge1@11

------------------------------------------------------------------------
r14 | $LOGNAME | date | 1 line

Made a branch Created /branches/dev/Share/merge3 from /trunk@1.
------------------------------------------------------------------------
r13 | $LOGNAME | date | 1 line

Made branch change to add extra feature
------------------------------------------------------------------------
r12 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@11 cf. /${PROJECT}trunk@9

------------------------------------------------------------------------
r11 | $LOGNAME | date | 1 line

edit on branch for merge repeat test
------------------------------------------------------------------------
r10 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}branches/dev/Share/merge1: /${PROJECT}trunk@9 cf. /${PROJECT}trunk@1

------------------------------------------------------------------------
r9 | $LOGNAME | date | 1 line

Made another trunk change
------------------------------------------------------------------------
r8 | $LOGNAME | date | 1 line

Made trunk change
------------------------------------------------------------------------
r7 | $LOGNAME | date | 1 line

Made changes for future merge
------------------------------------------------------------------------
r6 | $LOGNAME | date | 1 line

Made a branch Created /${PROJECT}branches/dev/Share/merge2 from /trunk@1.
------------------------------------------------------------------------
r5 | $LOGNAME | date | 1 line

Made changes for future merge of this branch
------------------------------------------------------------------------
r4 | $LOGNAME | date | 1 line

Made a branch Created /${PROJECT}branches/dev/Share/merge1 from /trunk@1.
------------------------------------------------------------------------
r3 | $LOGNAME | date | 1 line

 
------------------------------------------------------------------------
r2 | $LOGNAME | date | 1 line

make tags
------------------------------------------------------------------------
r1 | $LOGNAME | date | 1 line

initial trunk import
------------------------------------------------------------------------
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#------------------------------------------------------------------------------
# Test the various mergeinfo output after merging.
test_mergeinfo "$TEST_KEY_BASE-branch-into-branch-1-post" \
    $ROOT_URL/branches/dev/Share/merge1 - 22 <<__RESULTS__
begin-prop
/branches/dev/Share/merge1:4-13
/trunk:2-9
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1         13       22      
    |         |        |       
       --| |------------         branches/dev/Share/merge1
  ... /        \               
      \         \              
       --| |------------         branches/dev/Share/merge2
                       |       
                       WC      
end-info
begin-eligible
r17
r18
r19
end-eligible
begin-merged
r4
r5
r10
r11
r13
end-merged
__RESULTS__

#-------------------------------------------------------------------------------
teardown
#-------------------------------------------------------------------------------
