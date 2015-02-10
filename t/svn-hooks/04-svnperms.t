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
# Basic tests for "pre-commit".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
FCM_SVN_HOOK_ADMIN_EMAIL='your.admin.team'
. $TEST_SOURCE_DIR/test_header_more

svn mkdir --parents $REPOS_URL/foo/trunk -m "create foo trunk"
svn mkdir --parents $REPOS_URL/foo/branches -m "create foo branches"
svn mkdir --parents $REPOS_URL/bar/trunk -m "create bar trunk"
svn mkdir --parents $REPOS_URL/bar/branches -m "create bar branches"

test_tidy() {
    rm -f \
        "$REPOS_PATH/hooks/pre-commit-custom" \
        "$REPOS_PATH/hooks/pre-commit-size-threshold.conf" \
        "$REPOS_PATH/hooks/commit.conf" \
        "$REPOS_PATH/hooks/svnperms.conf" \
        "$REPOS_PATH/log/pre-commit.log" \
        README \
        bin/svnperms.py \
        file1 \
        file2 \
        file3 \
        file4 \
        mail.out \
        pre-commit-custom.out \
        svnperms.py.out
}
#-------------------------------------------------------------------------------
tests 9
#-------------------------------------------------------------------------------
cp -p "$FCM_HOME/etc/svn-hooks/pre-commit" "$REPOS_PATH/hooks/"
sed -i "/set -eu/a\
echo \$2 >$PWD/txn" "$REPOS_PATH/hooks/pre-commit"
#-------------------------------------------------------------------------------
cp "$FCM_HOME/sbin/svnperms.py" "$REPOS_PATH/hooks/"
REPOS_SHORTNAME=$(basename $REPOS_PATH)
cat >"$REPOS_PATH/hooks/svnperms.conf" <<__CONF__
[$REPOS_SHORTNAME groups]
admin = barry bazzy quxxy xyzzy wibbley
users = wibbley wobbley wubbley $LOGNAME

[$REPOS_SHORTNAME]
.* = @admin(add,remove,update)

foo/trunk/.* = @admin(add,remove,update)
foo/branches/[^/]+/.* = *(add,remove,update)
foo/tags/[^/]+/.* = @admin(add,remove,update)

bar/trunk/.* = @users(add,remove,update)
bar/branches/[^/]+/.* = @users(add,remove,update)
bar/tags/[^/]+/.* = @admin(add,remove,update)

[something_else_svn groups]
admin = $LOGNAME whoever
somepeople = bla blubb blabla

[something_else_svn]
foo/trunk/.* = @admin(add,remove,update)
foo/branches/[^/]+/.* = @somepeople(add,remove,update)
foo/tags/[^/]+/.* = @admin(add,remove,update)
__CONF__
touch file1
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-trunk-fail"
run_fail "$TEST_KEY" \
    svn import --no-auth-cache -q -m'test' file1 "$REPOS_URL/foo/trunk/file1"
file_grep "$TEST_KEY.foo-trunk.err" \
    "error: you don't have enough permissions for this transaction:" \
    "$TEST_KEY.err"
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-trunk-fail-custom-err-message"
echo "
[message]
permerrors_prefix = Bad User!" >>"$REPOS_PATH/hooks/svnperms.conf"
run_fail "$TEST_KEY" \
    svn import --no-auth-cache -q -m'test' file1 "$REPOS_URL/foo/trunk/file1"
file_grep "$TEST_KEY.foo-trunk.err" "Bad User!" "$TEST_KEY.err"
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-trunk-fail-custom-err-message-repos"
echo "
[$REPOS_SHORTNAME message]
permerrors_prefix = FCM police notified" >>"$REPOS_PATH/hooks/svnperms.conf"
run_fail "$TEST_KEY" \
    svn import --no-auth-cache -q -m'test' file1 "$REPOS_URL/foo/trunk/file1"
file_grep "$TEST_KEY.foo-trunk.err" "FCM police notified" "$TEST_KEY.err"
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-branch-pass-all"
run_pass "$TEST_KEY" \
    svn mkdir --parents --no-auth-cache -q -m 'test' \
    "$REPOS_URL/foo/branches/dev/$LOGNAME/"$(date +%s.%N)
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-trunk-pass"
run_pass "$TEST_KEY" \
    svn import --no-auth-cache -q -m'test' file1 "$REPOS_URL/bar/trunk/file1"
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-branch-pass-group"
run_pass "$TEST_KEY" \
    svn mkdir --parents --no-auth-cache -q -m 'test' \
    "$REPOS_URL/bar/branches/dev/$LOGNAME/"$(date +%s.%N)
#-------------------------------------------------------------------------------
exit
