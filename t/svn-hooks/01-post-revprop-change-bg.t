#!/bin/bash
#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------
# Basic tests for "post-revprop-change-bg".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
. $TEST_SOURCE_DIR/test_header_more
#-------------------------------------------------------------------------------
tests 9
#-------------------------------------------------------------------------------
# Add pre-revprop-change to allow revprop change.
cat >"$REPOS_PATH/hooks/pre-revprop-change" <<__BASH__
#!/bin/bash
exit
__BASH__
chmod +x "$REPOS_PATH/hooks/pre-revprop-change"
# Add post-revprop-change
cp -p "$FCM_HOME/etc/svn-hooks/post-revprop-change" \
    "$REPOS_PATH/hooks/post-revprop-change"
echo Hello >file
svn import --no-auth-cache -q -m'test' file "$REPOS_URL/file"
if [[ -n ${TRAC_ENV_PATH:-} ]]; then
    if $TRAC_RESYNC; then
        trac-admin "$TRAC_ENV_PATH" resync 1>/dev/null
    else
        trac-admin "$TRAC_ENV_PATH" changeset added "$REPOS_PATH" 1 1>/dev/null
    fi
fi
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE
run_pass "$TEST_KEY" \
    svn propset --no-auth-cache -q --revprop -r 1 'svn:log' 'Add hello file' \
    "$REPOS_URL"
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-revprop-change.log"
date2datefmt "$REPOS_PATH/log/post-revprop-change.log" \
    | sed '/^trac-admin/,$d; /^RET_CODE=/d' >"$TEST_KEY.log.expected"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log.expected" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ M svn:log @1 by $USER
--- old-value
+++ new-value
@@ -1 +1 @@
-test
\ No newline at end of file
+Add hello file
\ No newline at end of file
__LOG__
run_fail "$TEST_KEY.mail.out" test -f mail.out
if [[ -z ${TRAC_ENV_PATH:-} ]]; then
    skip 1 "$TEST_KEY.trac.db: Trac unavailable"
else
    sqlite3 "$TRAC_ENV_PATH/db/trac.db" \
        'SELECT cast(rev as integer),message FROM revision;' \
        >"$TEST_KEY.trac.db.expected"
    file_cmp "$TEST_KEY.trac.db" \
        "$TEST_KEY.trac.db.expected" <<<'1|Add hello file'
fi
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-author
cat /dev/null >"$REPOS_PATH/log/post-revprop-change.log"
run_pass "$TEST_KEY" \
    svn propset --no-auth-cache --username=not-a-user --revprop -r 1 'svn:log' \
    'Add welcome file' "$REPOS_URL"
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-revprop-change.log"
date2datefmt "$REPOS_PATH/log/post-revprop-change.log" \
    | sed '/^trac-admin/,$d; /^RET_CODE=/d' >"$TEST_KEY.log.expected"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log.expected" <<'__LOG__'
YYYY-mm-ddTHH:MM:SSZ+ M svn:log @1 by not-a-user
--- old-value
+++ new-value
@@ -1 +1 @@
-Add hello file
\ No newline at end of file
+Add welcome file
\ No newline at end of file
__LOG__
if [[ -z ${TRAC_ENV_PATH:-} ]]; then
    skip 1 "$TEST_KEY.trac.db: Trac unavailable"
else
    sqlite3 "$TRAC_ENV_PATH/db/trac.db" \
        'SELECT cast(rev as integer),message FROM revision;' \
        >"$TEST_KEY.trac.db.expected"
    file_cmp "$TEST_KEY.trac.db" \
        "$TEST_KEY.trac.db.expected" <<<'1|Add welcome file'
fi
date2datefmt mail.out | sed '/^trac-admin/,$d; /^RET_CODE=/d' \
    >"$TEST_KEY.mail.out.expected"
file_grep  "$TEST_KEY.mail.out.01" \
    '-rnotifications@localhost -sfoo@1 \[M svn:log\] by not-a-user' \
    "$TEST_KEY.mail.out.expected"
sed '1d' "$TEST_KEY.mail.out.expected" >"$TEST_KEY.mail.out.expected.02"
file_cmp  "$TEST_KEY.mail.out.02" "$TEST_KEY.mail.out.expected.02" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ M svn:log @1 by not-a-user
========================================================================
--- old-value
+++ new-value
@@ -1 +1 @@
-Add hello file
\ No newline at end of file
+Add welcome file
\ No newline at end of file
__LOG__
#-------------------------------------------------------------------------------
exit
