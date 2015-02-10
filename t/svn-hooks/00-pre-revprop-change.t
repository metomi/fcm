#!/bin/bash
#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------
# Basic tests for "pre-revprop-change".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
FCM_SVN_HOOK_ADMIN_EMAIL=your.admin.team
. $TEST_SOURCE_DIR/test_header_more
#-------------------------------------------------------------------------------
tests 16
#-------------------------------------------------------------------------------
cp -p "$FCM_HOME/etc/svn-hooks/pre-revprop-change" "$REPOS_PATH/hooks/"
echo Hello >file
svn import -q -m'test' file "$REPOS_URL/file"
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE
rm -f mail.out
run_pass "$TEST_KEY" \
    svn propset -q --revprop -r 1 'svn:log' 'Add hello file' "$REPOS_URL"
run_fail "$TEST_KEY.mail.out" test -f mail.out
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-bad-prop
run_fail "$TEST_KEY" \
    svn propset -q --revprop -r 1 'svn:author' 'boogeyman' "$REPOS_URL"
file_grep "$TEST_KEY.err" \
    "\[M svn:author\] permission denied." \
    "$TEST_KEY.err"
EXPR="\[! .....*-..-..T..:..:..Z\] $REPOS_PATH 1 $USER svn:author M"
file_grep "$TEST_KEY.log" "$EXPR" "$REPOS_PATH/log/pre-revprop-change.log"
file_grep "$TEST_KEY.mail.out" "$EXPR" mail.out
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-bad-action
run_fail "$TEST_KEY" \
    svn propdel -q --revprop -r 1 'svn:log' "$REPOS_URL"
file_grep "$TEST_KEY.err" \
    "\[D svn:log\] permission denied. Can only do: \[M svn:log\]" \
    "$TEST_KEY.err"
EXPR="\[! .....*-..-..T..:..:..Z\] $REPOS_PATH 1 $USER svn:log D"
file_grep "$TEST_KEY.log" "$EXPR" "$REPOS_PATH/log/pre-revprop-change.log"
file_grep "$TEST_KEY.mail.out" "$EXPR" mail.out
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-conf-bad
cat >"$REPOS_PATH/hooks/pre-revprop-change-ok.conf" <<'__CONF__'
M svn:author
M svn:log
__CONF__
run_fail "$TEST_KEY" svn propdel -q --revprop -r 1 'svn:author' "$REPOS_URL"
file_grep "$TEST_KEY.err" \
    "\[D svn:author\] permission denied. Can only do: \[M svn:author\] \[M svn:log\]" \
    "$TEST_KEY.err"
EXPR="\[! .....*-..-..T..:..:..Z\] $REPOS_PATH 1 $USER svn:author D"
file_grep "$TEST_KEY.log" "$EXPR" "$REPOS_PATH/log/pre-revprop-change.log"
file_grep "$TEST_KEY.mail.out" "$EXPR" mail.out
rm -f "$REPOS_PATH/hooks/pre-revprop-change-ok.conf"
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-conf-good
rm -f mail.out
cat >"$REPOS_PATH/hooks/pre-revprop-change-ok.conf" <<'__CONF__'
M svn:author
M svn:log
__CONF__
run_pass "$TEST_KEY" \
    svn propset -q --revprop -r 1 'svn:author' 'arthur' "$REPOS_URL"
run_fail "$TEST_KEY.mail.out" test -f mail.out
rm -f "$REPOS_PATH/hooks/pre-revprop-change-ok.conf"
#-------------------------------------------------------------------------------
exit
