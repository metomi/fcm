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
# Basic tests for "fcm branch-diff".
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
svn commit -q -m "make branch diff"
svn switch -q $ROOT_URL/trunk
TMPFILE=$(mktemp)
for FILE in $FILE_LIST; do
    if [[ -e $FILE ]]; then
        tac $FILE > $TMPFILE && mv $TMPFILE $FILE
    fi
done
rm -f $TMPFILE
svn commit -q -m "make trunk diff"
svn switch -q $ROOT_URL/branches/dev/Share/branch_test
#-------------------------------------------------------------------------------
# Tests fcm branch-diff
TEST_KEY=$TEST_KEY_BASE-fcm-branch-diff
run_pass "$TEST_KEY" fcm branch-diff
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Index: added_file
===================================================================
--- added_file	(.../$ROOT_URL/trunk)	(revision 0)
+++ added_file	(revision 6)
@@ -0,0 +1 @@
+INCLUDE 'hello_constants.INc'
Index: added_directory/hello_constants_dummy.inc
===================================================================
--- added_directory/hello_constants_dummy.inc	(.../$ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants_dummy.inc	(revision 6)
@@ -0,0 +1 @@
+INCLUDE 'hello_constants.INc'
Index: added_directory/hello_constants.inc
===================================================================
--- added_directory/hello_constants.inc	(.../$ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants.inc	(revision 6)
@@ -0,0 +1,2 @@
+CHARACTER (
+LEN=80), PARAMETER :: hello_strINg = 'Hello Earth!!'
Index: added_directory/hello_constants.f90
===================================================================
--- added_directory/hello_constants.f90	(.../$ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants.f90	(revision 6)
@@ -0,0 +1,5 @@
+MODULE Hello_Constants
+
+INCLUDE 'hello_constants_dummy.INc'
+
+END MODULE Hello_Constants
Index: module/hello_constants_dummy.inc
===================================================================
--- module/hello_constants_dummy.inc	(.../$ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants_dummy.inc	(working copy)
@@ -1 +0,0 @@
-INCLUDE 'hello_constants.inc'
Index: module/hello_constants.inc
===================================================================
--- module/hello_constants.inc	(.../$ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants.inc	(working copy)
@@ -1 +0,0 @@
-CHARACTER (LEN=80), PARAMETER :: hello_string = 'Hello Earth!'
Index: module/hello_constants.f90
===================================================================
--- module/hello_constants.f90	(.../$ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants.f90	(working copy)
@@ -1,5 +0,0 @@
-MODULE Hello_Constants
-
-INCLUDE 'hello_constants_dummy.inc'
-
-END MODULE Hello_Constants
Index: lib/python/info/poems.py
===================================================================
--- lib/python/info/poems.py	(.../$ROOT_URL/trunk)	(revision 1)
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
Index: module/hello_constants_dummy.inc
===================================================================
--- module/hello_constants_dummy.inc	($ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants_dummy.inc	(working copy)
@@ -1 +0,0 @@
-INCLUDE 'hello_constants.inc'
Index: module/hello_constants.inc
===================================================================
--- module/hello_constants.inc	($ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants.inc	(working copy)
@@ -1 +0,0 @@
-CHARACTER (LEN=80), PARAMETER :: hello_string = 'Hello Earth!'
Index: module/hello_constants.f90
===================================================================
--- module/hello_constants.f90	($ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants.f90	(working copy)
@@ -1,5 +0,0 @@
-MODULE Hello_Constants
-
-INCLUDE 'hello_constants_dummy.inc'
-
-END MODULE Hello_Constants
Index: lib/python/info/poems.py
===================================================================
--- lib/python/info/poems.py	($ROOT_URL/trunk)	(revision 1)
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
Index: added_directory/hello_constants.f90
===================================================================
--- added_directory/hello_constants.f90	($ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants.f90	(revision 6)
@@ -0,0 +1,5 @@
+MODULE Hello_Constants
+
+INCLUDE 'hello_constants_dummy.INc'
+
+END MODULE Hello_Constants
Index: added_directory/hello_constants.inc
===================================================================
--- added_directory/hello_constants.inc	($ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants.inc	(revision 6)
@@ -0,0 +1,2 @@
+CHARACTER (
+LEN=80), PARAMETER :: hello_strINg = 'Hello Earth!!'
Index: added_directory/hello_constants_dummy.inc
===================================================================
--- added_directory/hello_constants_dummy.inc	($ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants_dummy.inc	(revision 6)
@@ -0,0 +1 @@
+INCLUDE 'hello_constants.INc'
Index: added_file
===================================================================
--- added_file	($ROOT_URL/trunk)	(revision 0)
+++ added_file	(revision 6)
@@ -0,0 +1 @@
+INCLUDE 'hello_constants.INc'
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm bdi
TEST_KEY=$TEST_KEY_BASE-bdi
run_pass "$TEST_KEY" fcm bdi
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Index: added_file
===================================================================
--- added_file	(.../$ROOT_URL/trunk)	(revision 0)
+++ added_file	(revision 6)
@@ -0,0 +1 @@
+INCLUDE 'hello_constants.INc'
Index: added_directory/hello_constants_dummy.inc
===================================================================
--- added_directory/hello_constants_dummy.inc	(.../$ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants_dummy.inc	(revision 6)
@@ -0,0 +1 @@
+INCLUDE 'hello_constants.INc'
Index: added_directory/hello_constants.inc
===================================================================
--- added_directory/hello_constants.inc	(.../$ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants.inc	(revision 6)
@@ -0,0 +1,2 @@
+CHARACTER (
+LEN=80), PARAMETER :: hello_strINg = 'Hello Earth!!'
Index: added_directory/hello_constants.f90
===================================================================
--- added_directory/hello_constants.f90	(.../$ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants.f90	(revision 6)
@@ -0,0 +1,5 @@
+MODULE Hello_Constants
+
+INCLUDE 'hello_constants_dummy.INc'
+
+END MODULE Hello_Constants
Index: module/hello_constants_dummy.inc
===================================================================
--- module/hello_constants_dummy.inc	(.../$ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants_dummy.inc	(working copy)
@@ -1 +0,0 @@
-INCLUDE 'hello_constants.inc'
Index: module/hello_constants.inc
===================================================================
--- module/hello_constants.inc	(.../$ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants.inc	(working copy)
@@ -1 +0,0 @@
-CHARACTER (LEN=80), PARAMETER :: hello_string = 'Hello Earth!'
Index: module/hello_constants.f90
===================================================================
--- module/hello_constants.f90	(.../$ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants.f90	(working copy)
@@ -1,5 +0,0 @@
-MODULE Hello_Constants
-
-INCLUDE 'hello_constants_dummy.inc'
-
-END MODULE Hello_Constants
Index: lib/python/info/poems.py
===================================================================
--- lib/python/info/poems.py	(.../$ROOT_URL/trunk)	(revision 1)
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
Index: module/hello_constants_dummy.inc
===================================================================
--- module/hello_constants_dummy.inc	($ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants_dummy.inc	(working copy)
@@ -1 +0,0 @@
-INCLUDE 'hello_constants.inc'
Index: module/hello_constants.inc
===================================================================
--- module/hello_constants.inc	($ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants.inc	(working copy)
@@ -1 +0,0 @@
-CHARACTER (LEN=80), PARAMETER :: hello_string = 'Hello Earth!'
Index: module/hello_constants.f90
===================================================================
--- module/hello_constants.f90	($ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants.f90	(working copy)
@@ -1,5 +0,0 @@
-MODULE Hello_Constants
-
-INCLUDE 'hello_constants_dummy.inc'
-
-END MODULE Hello_Constants
Index: lib/python/info/poems.py
===================================================================
--- lib/python/info/poems.py	($ROOT_URL/trunk)	(revision 1)
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
Index: added_directory/hello_constants.f90
===================================================================
--- added_directory/hello_constants.f90	($ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants.f90	(revision 6)
@@ -0,0 +1,5 @@
+MODULE Hello_Constants
+
+INCLUDE 'hello_constants_dummy.INc'
+
+END MODULE Hello_Constants
Index: added_directory/hello_constants.inc
===================================================================
--- added_directory/hello_constants.inc	($ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants.inc	(revision 6)
@@ -0,0 +1,2 @@
+CHARACTER (
+LEN=80), PARAMETER :: hello_strINg = 'Hello Earth!!'
Index: added_directory/hello_constants_dummy.inc
===================================================================
--- added_directory/hello_constants_dummy.inc	($ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants_dummy.inc	(revision 6)
@@ -0,0 +1 @@
+INCLUDE 'hello_constants.INc'
Index: added_file
===================================================================
--- added_file	($ROOT_URL/trunk)	(revision 0)
+++ added_file	(revision 6)
@@ -0,0 +1 @@
+INCLUDE 'hello_constants.INc'
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm branch-diff --wiki
TEST_KEY=$TEST_KEY_BASE-wiki
run_pass "$TEST_KEY" fcm branch-diff --wiki
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
diff:/trunk@1///branches/dev/Share/branch_test@6
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm bdi --wiki
TEST_KEY=$TEST_KEY_BASE-bdi-wiki
run_pass "$TEST_KEY" fcm bdi --wiki
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
diff:/trunk@1///branches/dev/Share/branch_test@6
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm bdi on the trunk
svn switch -q $ROOT_URL/trunk
TEST_KEY=$TEST_KEY_BASE-bdi-trunk
run_fail "$TEST_KEY" fcm bdi
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" </dev/null
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" <<__ERR__
[FAIL] $ROOT_URL/trunk@6: not a valid URL of a standard FCM branch.

__ERR__
#-------------------------------------------------------------------------------
# Tests fcm bdi with working copy changes
svn switch -q $ROOT_URL/branches/dev/Share/branch_test
TEST_KEY=$TEST_KEY_BASE-bdi-wc-changes
echo "foo" > added_directory/foo$TEST_KEY
svn add -q added_directory/foo$TEST_KEY
echo "bar" > added_directory/bar$TEST_KEY
run_pass "$TEST_KEY" fcm bdi
if $SVN_VERSION_IS_16; then
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
Index: added_file
===================================================================
--- added_file	(.../$ROOT_URL/trunk)	(revision 0)
+++ added_file	(revision 6)
@@ -0,0 +1 @@
+INCLUDE 'hello_constants.INc'
Index: added_directory/hello_constants_dummy.inc
===================================================================
--- added_directory/hello_constants_dummy.inc	(.../$ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants_dummy.inc	(revision 6)
@@ -0,0 +1 @@
+INCLUDE 'hello_constants.INc'
Index: added_directory/foo00-simple-bdi-wc-changes
===================================================================
--- added_directory/foo00-simple-bdi-wc-changes	(.../$ROOT_URL/trunk)	(revision 0)
+++ added_directory/foo00-simple-bdi-wc-changes	(revision 0)
@@ -0,0 +1 @@
+foo
Index: added_directory/hello_constants.inc
===================================================================
--- added_directory/hello_constants.inc	(.../$ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants.inc	(revision 6)
@@ -0,0 +1,2 @@
+CHARACTER (
+LEN=80), PARAMETER :: hello_strINg = 'Hello Earth!!'
Index: added_directory/hello_constants.f90
===================================================================
--- added_directory/hello_constants.f90	(.../$ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants.f90	(revision 6)
@@ -0,0 +1,5 @@
+MODULE Hello_Constants
+
+INCLUDE 'hello_constants_dummy.INc'
+
+END MODULE Hello_Constants
Index: module/hello_constants_dummy.inc
===================================================================
--- module/hello_constants_dummy.inc	(.../$ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants_dummy.inc	(working copy)
@@ -1 +0,0 @@
-INCLUDE 'hello_constants.inc'
Index: module/hello_constants.inc
===================================================================
--- module/hello_constants.inc	(.../$ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants.inc	(working copy)
@@ -1 +0,0 @@
-CHARACTER (LEN=80), PARAMETER :: hello_string = 'Hello Earth!'
Index: module/hello_constants.f90
===================================================================
--- module/hello_constants.f90	(.../$ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants.f90	(working copy)
@@ -1,5 +0,0 @@
-MODULE Hello_Constants
-
-INCLUDE 'hello_constants_dummy.inc'
-
-END MODULE Hello_Constants
Index: lib/python/info/poems.py
===================================================================
--- lib/python/info/poems.py	(.../$ROOT_URL/trunk)	(revision 1)
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
Index: module/hello_constants_dummy.inc
===================================================================
--- module/hello_constants_dummy.inc	($ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants_dummy.inc	(working copy)
@@ -1 +0,0 @@
-INCLUDE 'hello_constants.inc'
Index: module/hello_constants.inc
===================================================================
--- module/hello_constants.inc	($ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants.inc	(working copy)
@@ -1 +0,0 @@
-CHARACTER (LEN=80), PARAMETER :: hello_string = 'Hello Earth!'
Index: module/hello_constants.f90
===================================================================
--- module/hello_constants.f90	($ROOT_URL/trunk)	(revision 1)
+++ module/hello_constants.f90	(working copy)
@@ -1,5 +0,0 @@
-MODULE Hello_Constants
-
-INCLUDE 'hello_constants_dummy.inc'
-
-END MODULE Hello_Constants
Index: lib/python/info/poems.py
===================================================================
--- lib/python/info/poems.py	($ROOT_URL/trunk)	(revision 1)
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
Index: added_directory/foo00-simple-bdi-wc-changes
===================================================================
--- added_directory/foo00-simple-bdi-wc-changes	($ROOT_URL/trunk)	(revision 0)
+++ added_directory/foo00-simple-bdi-wc-changes	(working copy)
@@ -0,0 +1 @@
+foo
Index: added_directory/hello_constants.f90
===================================================================
--- added_directory/hello_constants.f90	($ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants.f90	(revision 6)
@@ -0,0 +1,5 @@
+MODULE Hello_Constants
+
+INCLUDE 'hello_constants_dummy.INc'
+
+END MODULE Hello_Constants
Index: added_directory/hello_constants.inc
===================================================================
--- added_directory/hello_constants.inc	($ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants.inc	(revision 6)
@@ -0,0 +1,2 @@
+CHARACTER (
+LEN=80), PARAMETER :: hello_strINg = 'Hello Earth!!'
Index: added_directory/hello_constants_dummy.inc
===================================================================
--- added_directory/hello_constants_dummy.inc	($ROOT_URL/trunk)	(revision 0)
+++ added_directory/hello_constants_dummy.inc	(revision 6)
@@ -0,0 +1 @@
+INCLUDE 'hello_constants.INc'
Index: added_file
===================================================================
--- added_file	($ROOT_URL/trunk)	(revision 0)
+++ added_file	(revision 6)
@@ -0,0 +1 @@
+INCLUDE 'hello_constants.INc'
__OUT__
fi
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
teardown
#-------------------------------------------------------------------------------
