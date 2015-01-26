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
# Basic tests for "fcm merge".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 42
#-------------------------------------------------------------------------------
setup
init_repos
init_merge_branches merge1 merge2 $REPOS_URL
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Test the various mergeinfo output before merging.
test_mergeinfo "$TEST_KEY_BASE-pre" \
    $ROOT_URL/branches/dev/Share/merge1 <<__RESULTS__
begin-prop
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1                  9       
    |                  |       
       --| |------------         branches/dev/Share/merge1
      /                        
     /                         
  -------| |------------         trunk
                       |       
                       9       
end-info
begin-eligible
r5
end-eligible
begin-merged
end-merged
__RESULTS__
#-------------------------------------------------------------------------------
# Tests fcm merge --dry-run
TEST_KEY=$TEST_KEY_BASE-dry-run
export SVN_EDITOR="sed -i 1i\foo"
run_pass "$TEST_KEY" fcm merge --dry-run $ROOT_URL/branches/dev/Share/merge1
if $SVN_VERSION_IS_16; then
    START_REV=2
else
    START_REV=4
fi
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Eligible merge(s) from /${PROJECT}branches/dev/Share/merge1@9: 5
--------------------------------------------------------------------------------
Merge: /${PROJECT}branches/dev/Share/merge1@5
 c.f.: /${PROJECT}trunk@1
-------------------------------------------------------------------------dry-run
--- Merging r$START_REV through r5 into '.':
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
-------------------------------------------------------------------------dry-run
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn status result of fcm merge --dry-run
TEST_KEY=$TEST_KEY_BASE-dry-run-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
?       unversioned_file
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn diff result of fcm merge --dry-run
TEST_KEY=$TEST_KEY_BASE-dry-run-diff
run_pass "$TEST_KEY" svn diff
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm merge --non-interactive
TEST_KEY=$TEST_KEY_BASE-non-interactive
export SVN_EDITOR="sed -i 1i\foo" 
run_pass "$TEST_KEY" fcm merge --non-interactive $ROOT_URL/branches/dev/Share/merge1
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Eligible merge(s) from /${PROJECT}branches/dev/Share/merge1@9: 5
--------------------------------------------------------------------------------
Merge: /${PROJECT}branches/dev/Share/merge1@5
 c.f.: /${PROJECT}trunk@1
Merge succeeded.
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Eligible merge(s) from /${PROJECT}branches/dev/Share/merge1@9: 5
--------------------------------------------------------------------------------
Merge: /${PROJECT}branches/dev/Share/merge1@5
 c.f.: /${PROJECT}trunk@1
Merge succeeded.
--------------------------------------------------------------------------actual
--- Merging r$START_REV through r5 into '.':
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
--- Recording mergeinfo for merge of r$START_REV through r5 into '.':
 U   .
--------------------------------------------------------------------------actual
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn status result of fcm merge --non-interactive
TEST_KEY=$TEST_KEY_BASE-non-interactive-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
sort $TEST_DIR/"$TEST_KEY.out" -o $TEST_DIR/"$TEST_KEY.out"
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
?       unversioned_file
A  +    added_directory
A  +    added_directory/hello_constants.f90
A  +    added_directory/hello_constants.inc
A  +    added_directory/hello_constants_dummy.inc
A  +    added_file
A  +    module/tree_conflict_file
M       lib/python/info/poems.py
M       module/hello_constants.f90
M       module/hello_constants.inc
M       module/hello_constants_dummy.inc
M       subroutine/hello_sub_dummy.h
__OUT__
else
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
 M      .
?       unversioned_file
A  +    added_directory
A  +    added_file
A  +    module/tree_conflict_file
M       lib/python/info/poems.py
M       module/hello_constants.f90
M       module/hello_constants.inc
M       module/hello_constants_dummy.inc
M       subroutine/hello_sub_dummy.h
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests svn diff result of fcm merge --non-interactive
TEST_KEY=$TEST_KEY_BASE-non-interactive-diff
run_pass "$TEST_KEY" svn diff
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__

Property changes on: .
___________________________________________________________________
Added: svn:mergeinfo
   Merged /${PROJECT}branches/dev/Share/merge1:r4-5

Index: subroutine/hello_sub_dummy.h
===================================================================
--- subroutine/hello_sub_dummy.h	(revision 9)
+++ subroutine/hello_sub_dummy.h	(working copy)
@@ -1 +1,2 @@
 #include "hello_sub.h"
+Modified a line
Index: module/hello_constants_dummy.inc
===================================================================
--- module/hello_constants_dummy.inc	(revision 9)
+++ module/hello_constants_dummy.inc	(working copy)
@@ -1 +1 @@
-INCLUDE 'hello_constants.inc'
+INCLUDE 'hello_constants.INc'
Index: module/hello_constants.inc
===================================================================
--- module/hello_constants.inc	(revision 9)
+++ module/hello_constants.inc	(working copy)
@@ -1 +1,2 @@
-CHARACTER (LEN=80), PARAMETER :: hello_string = 'Hello Earth!'
+CHARACTER (
+LEN=80), PARAMETER :: hello_strINg = 'Hello Earth!!'
Index: module/hello_constants.f90
===================================================================
--- module/hello_constants.f90	(revision 9)
+++ module/hello_constants.f90	(working copy)
@@ -1,5 +1,5 @@
 MODULE Hello_Constants
 
-INCLUDE 'hello_constants_dummy.inc'
+INCLUDE 'hello_constants_dummy.INc'
 
 END MODULE Hello_Constants
Index: lib/python/info/poems.py
===================================================================
--- lib/python/info/poems.py	(revision 9)
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
--- lib/python/info/poems.py	(revision 9)
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
--- module/hello_constants.f90	(revision 9)
+++ module/hello_constants.f90	(working copy)
@@ -1,5 +1,5 @@
 MODULE Hello_Constants
 
-INCLUDE 'hello_constants_dummy.inc'
+INCLUDE 'hello_constants_dummy.INc'
 
 END MODULE Hello_Constants
Index: module/hello_constants.inc
===================================================================
--- module/hello_constants.inc	(revision 9)
+++ module/hello_constants.inc	(working copy)
@@ -1 +1,2 @@
-CHARACTER (LEN=80), PARAMETER :: hello_string = 'Hello Earth!'
+CHARACTER (
+LEN=80), PARAMETER :: hello_strINg = 'Hello Earth!!'
Index: module/hello_constants_dummy.inc
===================================================================
--- module/hello_constants_dummy.inc	(revision 9)
+++ module/hello_constants_dummy.inc	(working copy)
@@ -1 +1 @@
-INCLUDE 'hello_constants.inc'
+INCLUDE 'hello_constants.INc'
Index: subroutine/hello_sub_dummy.h
===================================================================
--- subroutine/hello_sub_dummy.h	(revision 9)
+++ subroutine/hello_sub_dummy.h	(working copy)
@@ -1 +1,2 @@
 #include "hello_sub.h"
+Modified a line
Index: .
===================================================================
--- .	(revision 9)
+++ .	(working copy)

Property changes on: .
___________________________________________________________________
Added: svn:mergeinfo
   Merged /${PROJECT}branches/dev/Share/merge1:r4-5
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Test the various mergeinfo output after merging.
test_mergeinfo "$TEST_KEY_BASE-post" \
    $ROOT_URL/branches/dev/Share/merge1 - <<__RESULTS__
begin-prop
/branches/dev/Share/merge1:4-5
end-prop
begin-info
    youngest common ancestor
    |         last full merge
    |         |        tip of branch
    |         |        |         repository path

    1                  9       
    |                  |       
       --| |------------         branches/dev/Share/merge1
      /                        
     /                         
  -------| |------------         trunk
                       |       
                       9       
end-info
begin-eligible
end-eligible
begin-merged
r4
r5
end-merged
__RESULTS__
#-------------------------------------------------------------------------------
teardown
#-------------------------------------------------------------------------------
