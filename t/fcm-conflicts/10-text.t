#!/bin/bash
# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-17 Met Office.
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
# Basic tests for "fcm conflicts" (text conflict following merge).
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
check_svn_version
tests 11
#-------------------------------------------------------------------------------
setup
init_repos
init_merge_branches merge1 merge2 $REPOS_URL
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-merge
export SVN_EDITOR="sed -i 1i\foo"
echo "The End" >> lib/python/info/poems.py
svn commit -m "Finish off the poem" -q
svn update -q
run_pass "$TEST_KEY" fcm merge --non-interactive $ROOT_URL/branches/dev/Share/merge1
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-merge-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
status_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<'__OUT__'
 M      .
?       lib/python/info/poems.py.merge-left.r1
?       lib/python/info/poems.py.merge-right.r5
?       lib/python/info/poems.py.working
?       unversioned_file
A  +    added_directory
A  +    added_file
A  +    module/tree_conflict_file
C       lib/python/info/poems.py
M       module/hello_constants.f90
M       module/hello_constants.inc
M       module/hello_constants_dummy.inc
M       subroutine/hello_sub_dummy.h
Summary of conflicts:
  Text conflicts: 1
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-merge-conflicts
export FCM_GRAPHIC_MERGE=fcm-dummy-diff
run_pass "$TEST_KEY" fcm conflicts <<'__IN__'
y
y
__IN__
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] lib/python/info/poems.py: in text conflict.
diff3 $PWD/lib/python/info/poems.py.working $PWD/lib/python/info/poems.py.merge-left.r1 $PWD/lib/python/info/poems.py.merge-right.r5
====3
1:1,2c
2:1,2c
  #!/usr/bin/env python
  # -*- coding: utf-8 -*-
3:0a
====3
1:6c
2:6c
  It needs a doctor for its eyes,
3:4c
  It needs a doctor FOR its eyes,
====3
1:8,9c
2:8,9c
  However, if you feel inclined
  To get one (to improve your mind,
3:6,8c
  However, if you feel INclINed
  To get one (
  to improve your mINd,
====3
1:12c
2:12c
  And when it flies into a rage
3:11c
  And when it flies INto a rage
====3
1:14c
2:14c
  I had an aunt in Yucatan
3:13c
  I had an aunt IN Yucatan
====3
1:16c
2:16c
  And kept it for a pet.
3:15c
  And kept it FOR a pet.
====3
1:19c
2:19c
  The Snake is living yet.
3:18c
  The Snake is livINg yet.
====
1:24,25c
  print "\n",  __doc__
  The End
2:24c
  print "\n",  __doc__
3:23c
  prINt "\n",  __doc__
Run "svn resolve --accept working lib/python/info/poems.py"?
Enter "y" or "n" (or just press <return> for "n") Resolved conflicted state of 'lib/python/info/poems.py'
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-merge-conflicts-status
run_pass "$TEST_KEY" svn status --config-dir=$TEST_DIR/.subversion/
status_sort "$TEST_DIR/$TEST_KEY.out" "$TEST_DIR/$TEST_KEY.sorted.out"
file_cmp "$TEST_KEY.sorted.out" "$TEST_KEY.sorted.out" <<'__OUT__'
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
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
