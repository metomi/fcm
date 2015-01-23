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
# More complex tests for "fcm merge".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 234
#-------------------------------------------------------------------------------
setup
init_repos
init_merge_branches merge1 merge2 $REPOS_URL
export SVN_EDITOR="sed -i 1i\foo"
cd $TEST_DIR/wc
svn switch -q $ROOT_URL/branches/dev/Share/merge1
#-------------------------------------------------------------------------------
test_mergeinfo "$TEST_KEY_BASE-trunk-into-branch-1-pre" \
    $ROOT_URL/trunk <<__RESULTS__
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
                       9       
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
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
$TEST_DIR/wc: working directory changed to top of working copy.
Eligible merge(s) from /${PROJECT}trunk@9: 9 8
--------------------------------------------------------------------------------
Merge: /${PROJECT}trunk@9
 c.f.: /${PROJECT}trunk@1
Merge succeeded.
__OUT__
else
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
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
cd ..
#-------------------------------------------------------------------------------
# Tests svn status result of fcm merge (1)
TEST_KEY=$TEST_KEY_BASE-trunk-into-branch-1-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
sort $TEST_DIR/"$TEST_KEY.out" -o $TEST_DIR/"$TEST_KEY.out"
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
?       unversioned_file
M       lib/python/info/__init__.py
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn diff result of fcm merge (1)
TEST_KEY=$TEST_KEY_BASE-trunk-into-branch-1-diff
run_pass "$TEST_KEY" svn diff
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__

Property changes on: .
___________________________________________________________________
Added: svn:mergeinfo
   Merged /${PROJECT}trunk:r2-9

Index: lib/python/info/__init__.py
===================================================================
--- lib/python/info/__init__.py	(revision 9)
+++ lib/python/info/__init__.py	(working copy)
@@ -0,0 +1,2 @@
+trunk change
+another trunk change
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Index: lib/python/info/__init__.py
===================================================================
--- lib/python/info/__init__.py	(revision 9)
+++ lib/python/info/__init__.py	(working copy)
@@ -0,0 +1,2 @@
+trunk change
+another trunk change
Index: .
===================================================================
--- .	(revision 9)
+++ .	(working copy)

Property changes on: .
___________________________________________________________________
Added: svn:mergeinfo
   Merged /${PROJECT}trunk:r2-9
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm commit of fcm merge (1)
TEST_KEY=$TEST_KEY_BASE-trunk-into-branch-1-commit
run_pass "$TEST_KEY" fcm commit <<__IN__
y
__IN__
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
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
Transmitting file data .
Committed revision 10.
At revision 10.
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
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
Transmitting file data .
Committed revision 10.
Updating '.':
At revision 10.
__OUT__
fi
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
test_mergeinfo "$TEST_KEY_BASE-trunk-into-branch-1-post" \
    $ROOT_URL/trunk <<__RESULTS__
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
                       10      
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
BRANCH_MOD_FILE=$(find . -type f | sed "/\.svn/d" | sort | head -3| tail -1)
echo "# added this line for simple repeat testing" >>$BRANCH_MOD_FILE
svn commit -q -m "edit on branch for merge repeat test"
svn update -q
cd $TEST_DIR
rm -rf $TEST_DIR/wc
mkdir $TEST_DIR/wc
svn checkout -q $ROOT_URL/trunk $TEST_DIR/wc
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
test_mergeinfo "$TEST_KEY_BASE-branch-into-trunk-1-pre" \
    $ROOT_URL/branches/dev/Share/merge1 <<__RESULTS__
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
              9        11      
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
run_pass "$TEST_KEY" fcm merge --non-interactive branches/dev/Share/merge1
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Eligible merge(s) from /${PROJECT}branches/dev/Share/merge1@11: 11 10
--------------------------------------------------------------------------------
Merge: /${PROJECT}branches/dev/Share/merge1@11
 c.f.: /${PROJECT}trunk@9
Merge succeeded.
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Eligible merge(s) from /${PROJECT}branches/dev/Share/merge1@11: 11 10
--------------------------------------------------------------------------------
Merge: /${PROJECT}branches/dev/Share/merge1@11
 c.f.: /${PROJECT}trunk@9
Merge succeeded.
--------------------------------------------------------------------------actual
--- Merging differences between repository URLs into '.':
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
U    lib/python/info/poems.py
--- Recording mergeinfo for merge between repository URLs into '.':
 U   .
--------------------------------------------------------------------------actual
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn status result of fcm merge (1)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-1-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
M       subroutine/hello_sub_dummy.h
A  +    added_file
A  +    module/tree_conflict_file
M       module/hello_constants_dummy.inc
M       module/hello_constants.inc
M       module/hello_constants.f90
A  +    added_directory
A  +    added_directory/hello_constants_dummy.inc
A  +    added_directory/hello_constants.inc
A  +    added_directory/hello_constants.f90
M       lib/python/info/poems.py
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
A  +    added_directory
A  +    added_file
M       lib/python/info/poems.py
M       module/hello_constants.f90
M       module/hello_constants.inc
M       module/hello_constants_dummy.inc
A  +    module/tree_conflict_file
M       subroutine/hello_sub_dummy.h
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn diff result of fcm merge (1)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-1-diff
run_pass "$TEST_KEY" svn diff
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__

Property changes on: .
___________________________________________________________________
Added: svn:mergeinfo
   Merged /${PROJECT}branches/dev/Share/merge1:r2-11

Index: subroutine/hello_sub_dummy.h
===================================================================
--- subroutine/hello_sub_dummy.h	(revision 11)
+++ subroutine/hello_sub_dummy.h	(working copy)
@@ -1 +1,2 @@
 #include "hello_sub.h"
+Modified a line
Index: module/hello_constants_dummy.inc
===================================================================
--- module/hello_constants_dummy.inc	(revision 11)
+++ module/hello_constants_dummy.inc	(working copy)
@@ -1 +1 @@
-INCLUDE 'hello_constants.inc'
+INCLUDE 'hello_constants.INc'
Index: module/hello_constants.inc
===================================================================
--- module/hello_constants.inc	(revision 11)
+++ module/hello_constants.inc	(working copy)
@@ -1 +1,2 @@
-CHARACTER (LEN=80), PARAMETER :: hello_string = 'Hello Earth!'
+CHARACTER (
+LEN=80), PARAMETER :: hello_strINg = 'Hello Earth!!'
Index: module/hello_constants.f90
===================================================================
--- module/hello_constants.f90	(revision 11)
+++ module/hello_constants.f90	(working copy)
@@ -1,5 +1,5 @@
 MODULE Hello_Constants
 
-INCLUDE 'hello_constants_dummy.inc'
+INCLUDE 'hello_constants_dummy.INc'
 
 END MODULE Hello_Constants
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
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
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
Index: subroutine/hello_sub_dummy.h
===================================================================
--- subroutine/hello_sub_dummy.h	(revision 11)
+++ subroutine/hello_sub_dummy.h	(working copy)
@@ -1 +1,2 @@
 #include "hello_sub.h"
+Modified a line
Index: .
===================================================================
--- .	(revision 11)
+++ .	(working copy)

Property changes on: .
___________________________________________________________________
Added: svn:mergeinfo
   Merged /${PROJECT}branches/dev/Share/merge1:r4-11
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm commit of fcm merge (1)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-1-commit
run_pass "$TEST_KEY" fcm commit <<__IN__
y
__IN__
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] sed -i 1i\foo: starting commit message editor...
Change summary:
--------------------------------------------------------------------------------
[Root   : $REPOS_URL]
[Project: ${TEST_PROJECT:-}]
[Branch : trunk]
[Sub-dir: ]

 M      .
M       subroutine/hello_sub_dummy.h
A  +    added_file
A  +    module/tree_conflict_file
M       module/hello_constants_dummy.inc
M       module/hello_constants.inc
M       module/hello_constants.f90
A  +    added_directory
A  +    added_directory/hello_constants_dummy.inc
A  +    added_directory/hello_constants.inc
A  +    added_directory/hello_constants.f90
M       lib/python/info/poems.py
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
Adding         added_directory/hello_constants.f90
Adding         added_directory/hello_constants.inc
Adding         added_directory/hello_constants_dummy.inc
Adding         added_file
Sending        lib/python/info/poems.py
Sending        module/hello_constants.f90
Sending        module/hello_constants.inc
Sending        module/hello_constants_dummy.inc
Adding         module/tree_conflict_file
Sending        subroutine/hello_sub_dummy.h
Transmitting file data .....
Committed revision 12.
At revision 12.
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
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
M       lib/python/info/poems.py
M       module/hello_constants.f90
M       module/hello_constants.inc
M       module/hello_constants_dummy.inc
A  +    module/tree_conflict_file
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
Sending        lib/python/info/poems.py
Sending        module/hello_constants.f90
Sending        module/hello_constants.inc
Sending        module/hello_constants_dummy.inc
Adding         module/tree_conflict_file
Sending        subroutine/hello_sub_dummy.h
Transmitting file data .....
Committed revision 12.
Updating '.':
At revision 12.
__OUT__
fi
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
test_mergeinfo "$TEST_KEY_BASE-branch-into-trunk-1-post" \
    $ROOT_URL/branches/dev/Share/merge1 <<__RESULTS__
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
                       12      
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
MOD_FILE=$(find . -type f | sed "/\.svn/d" | sort | head -4 | tail -1)
echo "call_extra_feature()" >>$MOD_FILE
svn commit -q -m "Made branch change to add extra feature"
svn update -q
svn switch -q $ROOT_URL/trunk
#-------------------------------------------------------------------------------
test_mergeinfo "$TEST_KEY_BASE-branch-into-trunk-2-pre" \
    $ROOT_URL/branches/dev/Share/merge1 <<__RESULTS__
begin-prop
/branches/dev/Share/merge1:4-11
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1         11       13      
    |         |        |       
       --| |------------         branches/dev/Share/merge1
      /        \               
     /          \              
  -------| |------------         trunk
                       |       
                       13      
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
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Eligible merge(s) from /${PROJECT}branches/dev/Share/merge1@13: 13
--------------------------------------------------------------------------------
Merge: /${PROJECT}branches/dev/Share/merge1@13
 c.f.: /${PROJECT}branches/dev/Share/merge1@11
Merge succeeded.
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Eligible merge(s) from /${PROJECT}branches/dev/Share/merge1@13: 13
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
fi
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
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__

Property changes on: .
___________________________________________________________________
Modified: svn:mergeinfo
   Merged /${PROJECT}branches/dev/Share/merge1:r12-13

Index: added_file
===================================================================
--- added_file	(revision 13)
+++ added_file	(working copy)
@@ -1 +1,2 @@
 INCLUDE 'hello_constants.INc'
+call_extra_feature()
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Index: added_file
===================================================================
--- added_file	(revision 13)
+++ added_file	(working copy)
@@ -1 +1,2 @@
 INCLUDE 'hello_constants.INc'
+call_extra_feature()
Index: .
===================================================================
--- .	(revision 13)
+++ .	(working copy)

Property changes on: .
___________________________________________________________________
Modified: svn:mergeinfo
   Merged /${PROJECT}branches/dev/Share/merge1:r12-13
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm commit of fcm merge branch-into-trunk (2)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-2-commit
run_pass "$TEST_KEY" fcm commit <<__IN__
y
__IN__
sed -i "/^Updating '.':$/d" $TEST_DIR/"$TEST_KEY.out"
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
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
Transmitting file data .
Committed revision 14.
At revision 14.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm log of fcm merge branch-into-trunk (2)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-2-log
run_pass "$TEST_KEY" fcm log
sed -i "s/\(.*|.*|\).*\(|.*\)$/\1 date \2/g" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
------------------------------------------------------------------------
r14 | $LOGNAME | date | 3 lines

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
test_mergeinfo "$TEST_KEY_BASE-branch-into-trunk-2-post" \
    $ROOT_URL/branches/dev/Share/merge1 <<__RESULTS__
begin-prop
/branches/dev/Share/merge1:4-13
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1         13       14      
    |         |        |       
       --| |------------         branches/dev/Share/merge1
      /        \               
     /          \              
  -------| |------------         trunk
                       |       
                       14      
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
test_mergeinfo "$TEST_KEY_BASE-trunk-into-branch-2-pre" \
    $ROOT_URL/trunk <<__RESULTS__
begin-prop
/trunk:2-9
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1                  16      
    |                  |       
  -------| |------------         trunk
     \          /              
      \        /               
       --| |------------         branches/dev/Share/merge1
              |        |       
              13       16      
end-info
begin-eligible
r12
r14
r15
end-eligible
begin-merged
r8
r9
end-merged
__RESULTS__
#------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-trunk-into-branch-2
run_pass "$TEST_KEY" fcm merge --non-interactive trunk
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Eligible merge(s) from /${PROJECT}trunk@16: 15 14
--------------------------------------------------------------------------------
Merge: /${PROJECT}trunk@15
 c.f.: /${PROJECT}branches/dev/Share/merge1@13
Merge succeeded.
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Eligible merge(s) from /${PROJECT}trunk@16: 15 14
--------------------------------------------------------------------------------
Merge: /${PROJECT}trunk@15
 c.f.: /${PROJECT}branches/dev/Share/merge1@13
Merge succeeded.
--------------------------------------------------------------------------actual
--- Merging differences between repository URLs into '.':
U    added_file
--- Recording mergeinfo for merge between repository URLs into '.':
 U   .
--------------------------------------------------------------------------actual
__OUT__
fi
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
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__

Property changes on: .
___________________________________________________________________
Modified: svn:mergeinfo
   Merged /${PROJECT}trunk:r10-15
   Merged /${PROJECT}branches/dev/Share/merge1:r2-3

Index: added_file
===================================================================
--- added_file	(revision 16)
+++ added_file	(working copy)
@@ -1,2 +1,3 @@
 INCLUDE 'hello_constants.INc'
 call_extra_feature()
+# trunk modification
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Index: added_file
===================================================================
--- added_file	(revision 16)
+++ added_file	(working copy)
@@ -1,2 +1,3 @@
 INCLUDE 'hello_constants.INc'
 call_extra_feature()
+# trunk modification
Index: .
===================================================================
--- .	(revision 16)
+++ .	(working copy)

Property changes on: .
___________________________________________________________________
Modified: svn:mergeinfo
   Merged /${PROJECT}trunk:r10-15
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm commit of fcm merge trunk-into-branch (2)
TEST_KEY=$TEST_KEY_BASE-trunk-into-branch-2-commit
run_pass "$TEST_KEY" fcm commit <<__IN__
y
__IN__
sed -i "/^Updating '.':$/d" $TEST_DIR/"$TEST_KEY.out"
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
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
Merged into /${PROJECT}branches/dev/Share/merge1: /${PROJECT}trunk@15 cf. /${PROJECT}branches/dev/Share/merge1@13
--------------------------------------------------------------------------------

*** WARNING: YOU ARE COMMITTING TO A Share BRANCH.
*** Please ensure that you have the owner's permission.

Would you like to commit this change?
Enter "y" or "n" (or just press <return> for "n"): Sending        .
Sending        added_file
Transmitting file data .
Committed revision 17.
At revision 17.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm log of fcm merge trunk-into-branch (2)
TEST_KEY=$TEST_KEY_BASE-trunk-into-branch-2-log
run_pass "$TEST_KEY" fcm log
sed -i "s/\(.*|.*|\).*\(|.*\)$/\1 date \2/g" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
------------------------------------------------------------------------
r17 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}branches/dev/Share/merge1: /${PROJECT}trunk@15 cf. /${PROJECT}branches/dev/Share/merge1@13

------------------------------------------------------------------------
r16 | $LOGNAME | date | 1 line

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
test_mergeinfo "$TEST_KEY_BASE-trunk-into-branch-2-post" \
    $ROOT_URL/trunk <<__RESULTS__
begin-prop
/trunk:2-15
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1         15       17      
    |         |        |       
  -------| |------------         trunk
     \         \               
      \         \              
       --| |------------         branches/dev/Share/merge1
                       |       
                       17      
end-info
begin-eligible
end-eligible
begin-merged
r8
r9
r12
r14
r15
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
test_mergeinfo "$TEST_KEY_BASE-branch-into-trunk-3-pre" \
    $ROOT_URL/branches/dev/Share/merge1 <<__RESULTS__
begin-prop
/branches/dev/Share/merge1:4-13
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1                  18      
    |                  |       
       --| |------------         branches/dev/Share/merge1
      /         /              
     /         /               
  -------| |------------         trunk
              |        |       
              15       18      
end-info
begin-eligible
r16
r17
r18
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
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Eligible merge(s) from /${PROJECT}branches/dev/Share/merge1@18: 18 17
--------------------------------------------------------------------------------
Merge: /${PROJECT}branches/dev/Share/merge1@18
 c.f.: /${PROJECT}trunk@15
Merge succeeded.
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Eligible merge(s) from /${PROJECT}branches/dev/Share/merge1@18: 18 17
--------------------------------------------------------------------------------
Merge: /${PROJECT}branches/dev/Share/merge1@18
 c.f.: /${PROJECT}trunk@15
Merge succeeded.
--------------------------------------------------------------------------actual
--- Merging differences between repository URLs into '.':
D    added_directory/hello_constants_dummy.inc
A    added_file.add
--- Recording mergeinfo for merge between repository URLs into '.':
 U   .
--------------------------------------------------------------------------actual
__OUT__
fi
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
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__

Property changes on: .
___________________________________________________________________
Modified: svn:mergeinfo
   Merged /${PROJECT}branches/dev/Share/merge1:r14-18

Index: added_directory/hello_constants_dummy.inc
===================================================================
--- added_directory/hello_constants_dummy.inc	(revision 18)
+++ added_directory/hello_constants_dummy.inc	(working copy)
@@ -1,2 +0,0 @@
-INCLUDE 'hello_constants.INc'
-# added this line for simple repeat testing
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Index: added_directory/hello_constants_dummy.inc
===================================================================
--- added_directory/hello_constants_dummy.inc	(revision 18)
+++ added_directory/hello_constants_dummy.inc	(working copy)
@@ -1,2 +0,0 @@
-INCLUDE 'hello_constants.INc'
-# added this line for simple repeat testing
Index: .
===================================================================
--- .	(revision 18)
+++ .	(working copy)

Property changes on: .
___________________________________________________________________
Modified: svn:mergeinfo
   Merged /${PROJECT}branches/dev/Share/merge1:r14-18
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm commit of fcm merge branch-into-trunk (3)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-3-commit
run_pass "$TEST_KEY" fcm commit <<__IN__
y
__IN__
sed -i "/^Updating '.':$/d" $TEST_DIR/"$TEST_KEY.out"
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] sed -i 1i\foo: starting commit message editor...
Change summary:
--------------------------------------------------------------------------------
[Root   : $REPOS_URL]
[Project: ${TEST_PROJECT:-}]
[Branch : trunk]
[Sub-dir: ]

 M      .
D       added_directory/hello_constants_dummy.inc
A  +    added_file.add
--------------------------------------------------------------------------------
Commit message is as follows:
--------------------------------------------------------------------------------
foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@18 cf. /${PROJECT}trunk@15
--------------------------------------------------------------------------------

*** WARNING: YOU ARE COMMITTING TO THE TRUNK.
*** Please ensure that your change conforms to your project's working practices.

Would you like to commit this change?
Enter "y" or "n" (or just press <return> for "n"): Sending        .
Deleting       added_directory/hello_constants_dummy.inc
Adding         added_file.add

Committed revision 19.
At revision 19.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm log of fcm merge branch-into-trunk (3)
TEST_KEY=$TEST_KEY_BASE-branch-into-trunk-3-log
run_pass "$TEST_KEY" fcm log $ROOT_URL
sed -i "s/\(.*|.*|\).*\(|.*\)$/\1 date \2/g" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
------------------------------------------------------------------------
r19 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@18 cf. /${PROJECT}trunk@15

------------------------------------------------------------------------
r18 | $LOGNAME | date | 1 line

Made branch change - deleted ./added_directory/hello_constants_dummy.inc, copied ./added_file
------------------------------------------------------------------------
r17 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}branches/dev/Share/merge1: /${PROJECT}trunk@15 cf. /${PROJECT}branches/dev/Share/merge1@13

------------------------------------------------------------------------
r16 | $LOGNAME | date | 1 line

Made branch change for merge repeat test
------------------------------------------------------------------------
r15 | $LOGNAME | date | 1 line

Made trunk change - a simple edit of ./added_file
------------------------------------------------------------------------
r14 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@13 cf. /${PROJECT}branches/dev/Share/merge1@11

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
test_mergeinfo "$TEST_KEY_BASE-branch-into-trunk-3-post" \
    $ROOT_URL/branches/dev/Share/merge1 <<__RESULTS__
begin-prop
/branches/dev/Share/merge1:4-18
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1         18       19      
    |         |        |       
       --| |------------         branches/dev/Share/merge1
      /        \               
     /          \              
  -------| |------------         trunk
                       |       
                       19      
end-info
begin-eligible
end-eligible
begin-merged
r4
r5
r10
r11
r13
r16
r17
r18
end-merged
__RESULTS__
#-------------------------------------------------------------------------------
# Tests fcm merge of branch-into-branch (1)
cd $TEST_DIR
rm -rf $TEST_DIR/wc
mkdir $TEST_DIR/wc
svn checkout -q $ROOT_URL/branches/dev/Share/merge2 $TEST_DIR/wc
cd $TEST_DIR/wc
BRANCH_2_MOD_FILE=$(find . -type f | sed "/\.svn/d" | sort | head -3| tail -1)
echo "Second branch change" >>$BRANCH_2_MOD_FILE
svn commit -q -m "Made branch change - added to $BRANCH_2_MOD_FILE"
svn update -q
#------------------------------------------------------------------------------
test_mergeinfo "$TEST_KEY_BASE-branch-into-branch-1-pre" \
    $ROOT_URL/branches/dev/Share/merge1 <<__RESULTS__
begin-prop
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1                  20      
    |                  |       
       --| |------------         branches/dev/Share/merge1
  ... /                        
      \                        
       --| |------------         branches/dev/Share/merge2
                       |       
                       20      
end-info
begin-eligible
r5
r10
r11
r13
r16
r17
r18
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
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Eligible merge(s) from /${PROJECT}branches/dev/Share/merge1@20: 18 17 16 13 11 10 5
Enter a revision (or just press <return> for "18"): --------------------------------------------------------------------------------
Merge: /${PROJECT}branches/dev/Share/merge1@13
 c.f.: /${PROJECT}trunk@1
-------------------------------------------------------------------------dry-run
--- Merging r2 through r13 into '.':
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
 U   .
-------------------------------------------------------------------------dry-run
Would you like to go ahead with the merge?
Enter "y" or "n" (or just press <return> for "n"): Merge succeeded.
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Eligible merge(s) from /${PROJECT}branches/dev/Share/merge1@20: 18 17 16 13 11 10 5
Enter a revision (or just press <return> for "18"): --------------------------------------------------------------------------------
Merge: /${PROJECT}branches/dev/Share/merge1@13
 c.f.: /${PROJECT}trunk@1
-------------------------------------------------------------------------dry-run
--- Merging r4 through r13 into '.':
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
 U   .
-------------------------------------------------------------------------dry-run
Would you like to go ahead with the merge?
Enter "y" or "n" (or just press <return> for "n"): Merge succeeded.
--------------------------------------------------------------------------actual
--- Merging r4 through r13 into '.':
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
 U   .
--- Recording mergeinfo for merge of r4 through r13 into '.':
 G   .
--------------------------------------------------------------------------actual
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn status result of fcm merge branch-into-branch (1)
TEST_KEY=$TEST_KEY_BASE-branch-into-branch-1-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
M       subroutine/hello_sub_dummy.h
A  +    added_file
A  +    module/tree_conflict_file
M       module/hello_constants_dummy.inc
M       module/hello_constants.inc
M       module/hello_constants.f90
A  +    added_directory
A  +    added_directory/hello_constants_dummy.inc
A  +    added_directory/hello_constants.inc
A  +    added_directory/hello_constants.f90
M       lib/python/info/__init__.py
M       lib/python/info/poems.py
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
A  +    added_directory
A  +    added_file
M       lib/python/info/__init__.py
M       lib/python/info/poems.py
M       module/hello_constants.f90
M       module/hello_constants.inc
M       module/hello_constants_dummy.inc
A  +    module/tree_conflict_file
M       subroutine/hello_sub_dummy.h
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn diff result of fcm merge branch-into-branch (1)
TEST_KEY=$TEST_KEY_BASE-branch-into-branch-1-diff
run_pass "$TEST_KEY" svn diff
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__

Property changes on: .
___________________________________________________________________
Added: svn:mergeinfo
   Merged /${PROJECT}trunk:r2-9
   Merged /${PROJECT}branches/dev/Share/merge1:r4-13

Index: subroutine/hello_sub_dummy.h
===================================================================
--- subroutine/hello_sub_dummy.h	(revision 20)
+++ subroutine/hello_sub_dummy.h	(working copy)
@@ -1 +1,2 @@
 #include "hello_sub.h"
+Modified a line
Index: module/hello_constants_dummy.inc
===================================================================
--- module/hello_constants_dummy.inc	(revision 20)
+++ module/hello_constants_dummy.inc	(working copy)
@@ -1 +1 @@
-INCLUDE 'hello_constants.inc'
+INCLUDE 'hello_constants.INc'
Index: module/hello_constants.inc
===================================================================
--- module/hello_constants.inc	(revision 20)
+++ module/hello_constants.inc	(working copy)
@@ -1 +1,2 @@
-CHARACTER (LEN=80), PARAMETER :: hello_string = 'Hello Earth!'
+CHARACTER (
+LEN=80), PARAMETER :: hello_strINg = 'Hello Earth!!'
Index: module/hello_constants.f90
===================================================================
--- module/hello_constants.f90	(revision 20)
+++ module/hello_constants.f90	(working copy)
@@ -1,6 +1,6 @@
 MODULE Hello_Constants
 
-INCLUDE 'hello_constants_dummy.inc'
+INCLUDE 'hello_constants_dummy.INc'
 
 END MODULE Hello_Constants
 Second branch change
Index: lib/python/info/__init__.py
===================================================================
--- lib/python/info/__init__.py	(revision 20)
+++ lib/python/info/__init__.py	(working copy)
@@ -0,0 +1,2 @@
+trunk change
+another trunk change
Index: lib/python/info/poems.py
===================================================================
--- lib/python/info/poems.py	(revision 20)
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
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Index: lib/python/info/__init__.py
===================================================================
--- lib/python/info/__init__.py	(revision 20)
+++ lib/python/info/__init__.py	(working copy)
@@ -0,0 +1,2 @@
+trunk change
+another trunk change
Index: lib/python/info/poems.py
===================================================================
--- lib/python/info/poems.py	(revision 20)
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
--- module/hello_constants.f90	(revision 20)
+++ module/hello_constants.f90	(working copy)
@@ -1,6 +1,6 @@
 MODULE Hello_Constants
 
-INCLUDE 'hello_constants_dummy.inc'
+INCLUDE 'hello_constants_dummy.INc'
 
 END MODULE Hello_Constants
 Second branch change
Index: module/hello_constants.inc
===================================================================
--- module/hello_constants.inc	(revision 20)
+++ module/hello_constants.inc	(working copy)
@@ -1 +1,2 @@
-CHARACTER (LEN=80), PARAMETER :: hello_string = 'Hello Earth!'
+CHARACTER (
+LEN=80), PARAMETER :: hello_strINg = 'Hello Earth!!'
Index: module/hello_constants_dummy.inc
===================================================================
--- module/hello_constants_dummy.inc	(revision 20)
+++ module/hello_constants_dummy.inc	(working copy)
@@ -1 +1 @@
-INCLUDE 'hello_constants.inc'
+INCLUDE 'hello_constants.INc'
Index: subroutine/hello_sub_dummy.h
===================================================================
--- subroutine/hello_sub_dummy.h	(revision 20)
+++ subroutine/hello_sub_dummy.h	(working copy)
@@ -1 +1,2 @@
 #include "hello_sub.h"
+Modified a line
Index: .
===================================================================
--- .	(revision 20)
+++ .	(working copy)

Property changes on: .
___________________________________________________________________
Added: svn:mergeinfo
   Merged /${PROJECT}trunk:r2-9
   Merged /${PROJECT}branches/dev/Share/merge1:r4-13
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm commit of fcm merge branch-into-branch (1)
TEST_KEY=$TEST_KEY_BASE-branch-into-branch-1-commit
run_pass "$TEST_KEY" fcm commit <<__IN__
y
__IN__
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] sed -i 1i\foo: starting commit message editor...
Change summary:
--------------------------------------------------------------------------------
[Root   : $REPOS_URL]
[Project: ${TEST_PROJECT:-}]
[Branch : branches/dev/Share/merge2]
[Sub-dir: ]

 M      .
M       subroutine/hello_sub_dummy.h
A  +    added_file
A  +    module/tree_conflict_file
M       module/hello_constants_dummy.inc
M       module/hello_constants.inc
M       module/hello_constants.f90
A  +    added_directory
A  +    added_directory/hello_constants_dummy.inc
A  +    added_directory/hello_constants.inc
A  +    added_directory/hello_constants.f90
M       lib/python/info/__init__.py
M       lib/python/info/poems.py
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
Adding         added_directory/hello_constants.f90
Adding         added_directory/hello_constants.inc
Adding         added_directory/hello_constants_dummy.inc
Adding         added_file
Sending        lib/python/info/__init__.py
Sending        lib/python/info/poems.py
Sending        module/hello_constants.f90
Sending        module/hello_constants.inc
Sending        module/hello_constants_dummy.inc
Adding         module/tree_conflict_file
Sending        subroutine/hello_sub_dummy.h
Transmitting file data ......
Committed revision 21.
At revision 21.
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
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
M       lib/python/info/__init__.py
M       lib/python/info/poems.py
M       module/hello_constants.f90
M       module/hello_constants.inc
M       module/hello_constants_dummy.inc
A  +    module/tree_conflict_file
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
Sending        lib/python/info/__init__.py
Sending        lib/python/info/poems.py
Sending        module/hello_constants.f90
Sending        module/hello_constants.inc
Sending        module/hello_constants_dummy.inc
Adding         module/tree_conflict_file
Sending        subroutine/hello_sub_dummy.h
Transmitting file data ......
Committed revision 21.
Updating '.':
At revision 21.
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm log of fcm merge branch-into-branch (1)
TEST_KEY=$TEST_KEY_BASE-branch-into-branch-1-log
run_pass "$TEST_KEY" fcm log $REPOS_URL
sed -i "s/\(.*|.*|\).*\(|.*\)$/\1 date \2/g" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
------------------------------------------------------------------------
r21 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}branches/dev/Share/merge2: /${PROJECT}branches/dev/Share/merge1@13 cf. /${PROJECT}trunk@1

------------------------------------------------------------------------
r20 | $LOGNAME | date | 1 line

Made branch change - added to ./module/hello_constants.f90
------------------------------------------------------------------------
r19 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@18 cf. /${PROJECT}trunk@15

------------------------------------------------------------------------
r18 | $LOGNAME | date | 1 line

Made branch change - deleted ./added_directory/hello_constants_dummy.inc, copied ./added_file
------------------------------------------------------------------------
r17 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}branches/dev/Share/merge1: /${PROJECT}trunk@15 cf. /${PROJECT}branches/dev/Share/merge1@13

------------------------------------------------------------------------
r16 | $LOGNAME | date | 1 line

Made branch change for merge repeat test
------------------------------------------------------------------------
r15 | $LOGNAME | date | 1 line

Made trunk change - a simple edit of ./added_file
------------------------------------------------------------------------
r14 | $LOGNAME | date | 3 lines

foo
Merged into /${PROJECT}trunk: /${PROJECT}branches/dev/Share/merge1@13 cf. /${PROJECT}branches/dev/Share/merge1@11

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
test_mergeinfo "$TEST_KEY_BASE-branch-into-branch-1-post" \
    $ROOT_URL/branches/dev/Share/merge1 <<__RESULTS__
begin-prop
/branches/dev/Share/merge1:4-13
/trunk:2-9
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1         13       21      
    |         |        |       
       --| |------------         branches/dev/Share/merge1
  ... /        \               
      \         \              
       --| |------------         branches/dev/Share/merge2
                       |       
                       21      
end-info
begin-eligible
r16
r17
r18
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
