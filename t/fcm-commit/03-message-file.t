#!/bin/bash
# ------------------------------------------------------------------------------
# Copyright (C) 2006-2019 British Crown (Met Office) & Contributors.
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
# Tests for "fcm commit", attempt to add commit message file.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
check_svn_version
tests 6
#-------------------------------------------------------------------------------
svnadmin create foo
svn co -q file://$PWD/foo 'test-work'
touch 'test-work/#commit_message#'
svn add 'test-work/#commit_message#'
export SVN_EDITOR='cat'
#-------------------------------------------------------------------------------
# Tests fcm commit, bad commit file 1
TEST_KEY="$TEST_KEY_BASE-1"
run_fail "$TEST_KEY" fcm commit --svn-non-interactive 'test-work'
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
$PWD/test-work: working directory changed to top of working copy.
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" <<'__ERR__'
[ERROR] Attempt to add commit message file:
A       #commit_message#
[FAIL] FCM1::Cm::Abort: abort

__ERR__
#-------------------------------------------------------------------------------
# Tests fcm commit, bad commit file 2
TEST_KEY="$TEST_KEY_BASE-2"
cd 'test-work'
run_fail "$TEST_KEY" fcm commit --svn-non-interactive
cd ..
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" </dev/null
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" <<'__ERR__'
[ERROR] Attempt to add commit message file:
A       #commit_message#
[FAIL] FCM1::Cm::Abort: abort

__ERR__
#-------------------------------------------------------------------------------
exit
