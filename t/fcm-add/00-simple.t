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
# Basic tests for "fcm add".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
if [[ $? -ne 0 ]]; then
    exit 1
fi
#-------------------------------------------------------------------------------
tests 27
#-------------------------------------------------------------------------------
setup
init_repos ${TEST_PROJECT:-}
REPOS_URL="file://"$(cd $TEST_DIR/test_repos && pwd)
ROOT_URL=$REPOS_URL
if [[ -n ${TEST_PROJECT:-} ]]; then
    ROOT_URL=$REPOS_URL/$TEST_PROJECT
fi
init_branch_wc add $REPOS_URL
mkdir $TEST_DIR/wc/added_directory1
svn add -q $TEST_DIR/wc/added_directory1
touch $TEST_DIR/wc/added_directory1/added_file1
mkdir $TEST_DIR/wc/added_directory2
touch $TEST_DIR/wc/added_directory2/added_file2
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests fcm add unversioned file
TEST_KEY=$TEST_KEY_BASE-fcm-add-file
run_pass "$TEST_KEY" fcm add added_directory1/added_file1
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<'__OUT__'
A         added_directory1/added_file1
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm add unversioned directory
TEST_KEY=$TEST_KEY_BASE-fcm-add-dir
run_pass "$TEST_KEY" fcm add added_directory2
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<'__OUT__'
A         added_directory2
A         added_directory2/added_file2
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm add invalid path
TEST_KEY=$TEST_KEY_BASE-fcm-add-err-file
run_pass "$TEST_KEY" fcm add made_up_file
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" </dev/null
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" <<'__ERR__'
svn: warning: 'made_up_file' not found
__ERR__
cd $TEST_DIR
teardown
#-------------------------------------------------------------------------------
init_repos ${TEST_PROJECT:-}
REPOS_URL="file://"$(cd $TEST_DIR/test_repos && pwd)
ROOT_URL=$REPOS_URL
if [[ -n ${TEST_PROJECT:-} ]]; then
    ROOT_URL=$REPOS_URL/$TEST_PROJECT
fi
init_branch_wc add_c $REPOS_URL
touch $TEST_DIR/wc/unversioned_file
mkdir $TEST_DIR/wc/unversioned_directory
touch $TEST_DIR/wc/unversioned_directory/unversioned_file_2
mkdir $TEST_DIR/wc/versioned_directory
svn add -q $TEST_DIR/wc/versioned_directory
touch $TEST_DIR/wc/versioned_directory/unversioned_file_3
cd $TEST_DIR/wc
#-------------------------------------------------------------------------------
# Tests fcm add -c unversioned file
TEST_KEY=$TEST_KEY_BASE-fcm-add-c-file
run_pass "$TEST_KEY" fcm add -c unversioned_file <<'__EOF__'
y
__EOF__
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<'__OUT__'
?       unversioned_file
Would you like to run "svn add unversioned_file"?
Enter "y", "n" or "a" (or just press <return> for "n"): A         unversioned_file
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm add -c unversioned directory
TEST_KEY=$TEST_KEY_BASE-fcm-add-c-dir
run_pass "$TEST_KEY" fcm add -c unversioned_directory <<'__EOF__'
y
__EOF__
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<'__OUT__'
?       unversioned_directory
Would you like to run "svn add unversioned_directory"?
Enter "y", "n" or "a" (or just press <return> for "n"): A         unversioned_directory
A         unversioned_directory/unversioned_file_2
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm add -c versioned directory
TEST_KEY=$TEST_KEY_BASE-fcm-add-c-versioned-dir
run_pass "$TEST_KEY" fcm add -c versioned_directory <<'__EOF__'
y
y
__EOF__
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<'__OUT__'
?       versioned_directory/unversioned_file_3
Would you like to run "svn add versioned_directory/unversioned_file_3"?
Enter "y", "n" or "a" (or just press <return> for "n"): A         versioned_directory/unversioned_file_3
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm status after above tests
TEST_KEY=$TEST_KEY_BASE-fcm-add-c-status
run_pass "$TEST_KEY" fcm st
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<'__OUT__'
A       unversioned_file
A       versioned_directory
A       versioned_directory/unversioned_file_3
A       unversioned_directory
A       unversioned_directory/unversioned_file_2
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm add -c with no arguments
TEST_KEY=$TEST_KEY_BASE-fcm-add-c-no-args
fcm revert -R $TEST_DIR/wc/
run_pass "$TEST_KEY" fcm add -c <<'__EOF__'
y
y
n
__EOF__
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<'__OUT__'
?       unversioned_file
?       versioned_directory
?       unversioned_directory
Would you like to run "svn add unversioned_file"?
Enter "y", "n" or "a" (or just press <return> for "n"): Would you like to run "svn add versioned_directory"?
Enter "y", "n" or "a" (or just press <return> for "n"): Would you like to run "svn add unversioned_directory"?
Enter "y", "n" or "a" (or just press <return> for "n"): A         unversioned_file
A         versioned_directory
A         versioned_directory/unversioned_file_3
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm status after above tests
TEST_KEY=$TEST_KEY_BASE-fcm-add-c-no-args-status
run_pass "$TEST_KEY" fcm status
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<'__OUT__'
?       unversioned_directory
A       unversioned_file
A       versioned_directory
A       versioned_directory/unversioned_file_3
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
teardown
#-------------------------------------------------------------------------------
