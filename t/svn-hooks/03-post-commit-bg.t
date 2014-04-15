#!/bin/bash
#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------
# Basic tests for "post-commit-bg".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
FCM_SVN_HOOK_ADMIN_EMAIL=fcm.admin.team
. $TEST_SOURCE_DIR/test_header_more

test_tidy() {
    rm -f \
        "$REPOS_PATH/hooks/post-commit-bg-custom" \
        "$REPOS_PATH/hooks/post-commit-background-custom" \
        "$REPOS_PATH/log/post-commit.log" \
        file1 \
        file2 \
        file3 \
        file4 \
        svnperms.conf \
        mail.out
}
#-------------------------------------------------------------------------------
tests 25
#-------------------------------------------------------------------------------
cp -p "$FCM_HOME/etc/svn-hooks/post-commit" "$REPOS_PATH/hooks/"
sed -i "/set -eu/a\
echo \$2 >$PWD/rev; echo \$3 >$PWD/txn" "$REPOS_PATH/hooks/post-commit"
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-basic"
test_tidy
touch file1
svn import --no-auth-cache -q -m"$TEST_KEY" file1 "$REPOS_URL/file1"
REV=$(<rev)
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
date2datefmt "$REPOS_PATH/log/post-commit.log" \
    | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
    >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $REV by $USER
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip 1>$PWD/svn-dumps/foo-$REV.gz
* Dumped revision $REV.
REV_FILE_SIZE=??? # within 1048576
RET_CODE=0
__LOG__
if [[ -n ${TRAC_ENV_PATH:-} ]] && ! $TRAC_RESYNC; then
    sqlite3 "$TRAC_ENV_PATH/db/trac.db" \
        'SELECT cast(rev as integer),message FROM revision;' \
        >"$TEST_KEY.trac.db.expected"
    file_cmp "$TEST_KEY.trac.db" \
        "$TEST_KEY.trac.db.expected" <<<"$REV|$TEST_KEY"
    cat "$TEST_KEY.trac.db.expected"
else
    skip 1 '"trac-admin changeset added" not available'
fi
run_pass "$TEST_KEY.dump" test -s "$PWD/svn-dumps/foo-$REV.gz"
run_fail "$TEST_KEY.mail.out" test -e mail.out
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-add-svnperms.conf"
test_tidy
cat >svnperms.conf <<'__CONF__'
[foo]
.*=*(add,remove,update)
__CONF__
svn import --no-auth-cache -q -m"$TEST_KEY" svnperms.conf \
    "$REPOS_URL/svnperms.conf"
REV=$(<rev)
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
date2datefmt "$REPOS_PATH/log/post-commit.log" \
    | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
    >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $REV by $USER
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip 1>$PWD/svn-dumps/foo-$REV.gz
* Dumped revision $REV.
REV_FILE_SIZE=??? # within 1048576
svnlook cat $REPOS_PATH svnperms.conf >$REPOS_PATH/hooks/svnperms.conf
RET_CODE=0
__LOG__
file_cmp "$TEST_KEY.conf" svnperms.conf "$REPOS_PATH/hooks/svnperms.conf"
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-modify-svnperms.conf"
test_tidy
svn co -q "$REPOS_URL" work
cat >work/svnperms.conf <<'__CONF__'
[foo]
.*=*(add,remove,update)

[bar]
__CONF__
svn commit --no-auth-cache -q -m"$TEST_KEY" work
REV=$(<rev)
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
date2datefmt "$REPOS_PATH/log/post-commit.log" \
    | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
    >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $REV by $USER
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip 1>$PWD/svn-dumps/foo-$REV.gz
* Dumped revision $REV.
REV_FILE_SIZE=??? # within 1048576
svnlook cat $REPOS_PATH svnperms.conf >$REPOS_PATH/hooks/svnperms.conf
RET_CODE=0
__LOG__
file_cmp "$TEST_KEY.conf" work/svnperms.conf "$REPOS_PATH/hooks/svnperms.conf"
rm -f -r work
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-remove-svnperms.conf"
test_tidy
svn rm --no-auth-cache -q -m'remove svnperms.conf' "$REPOS_URL/svnperms.conf"
REV=$(<rev)
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
date2datefmt "$REPOS_PATH/log/post-commit.log" \
    | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
    >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $REV by $USER
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip 1>$PWD/svn-dumps/foo-$REV.gz
* Dumped revision $REV.
REV_FILE_SIZE=??? # within 1048576
rm -f $REPOS_PATH/hooks/svnperms.conf
RET_CODE=0
__LOG__
run_fail "$TEST_KEY.conf" test -e "$REPOS_PATH/hooks/svnperms.conf"
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-size"
test_tidy
perl -e 'map {print(rand())} 1..524288' >file2 # compress should be >1MB
svn import --no-auth-cache -q -m"$TEST_KEY" file2 "$REPOS_URL/file2"
REV=$(<rev)
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
date2datefmt "$REPOS_PATH/log/post-commit.log" \
    | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
    >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $REV by $USER
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip 1>$PWD/svn-dumps/foo-$REV.gz
* Dumped revision $REV.
REV_FILE_SIZE=??? # EXCEED 1048576
RET_CODE=1
__LOG__
date2datefmt mail.out \
    | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
    >"$TEST_KEY.mail.out"
file_cmp "$TEST_KEY.mail.out" "$TEST_KEY.mail.out" <<__LOG__
-s [post-commit-bg] $REPOS_PATH@$REV fcm.admin.team
YYYY-mm-ddTHH:MM:SSZ+ $REV by $USER
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip 1>$PWD/svn-dumps/foo-$REV.gz
* Dumped revision $REV.
REV_FILE_SIZE=??? # EXCEED 1048576
RET_CODE=1
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-custom-1" # good custom
test_tidy
touch file3
cat >"$REPOS_PATH/hooks/post-commit-bg-custom" <<'__BASH__'
#!/bin/bash
echo "$@"
__BASH__
chmod +x "$REPOS_PATH/hooks/post-commit-bg-custom"
svn import --no-auth-cache -q -m"$TEST_KEY" file3 "$REPOS_URL/file3"
REV=$(<rev)
TXN=$(<txn)
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
date2datefmt "$REPOS_PATH/log/post-commit.log" \
    | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
    >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $REV by $USER
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip 1>$PWD/svn-dumps/foo-$REV.gz
* Dumped revision $REV.
REV_FILE_SIZE=??? # within 1048576
$REPOS_PATH/hooks/post-commit-bg-custom $REPOS_PATH $REV $TXN
$REPOS_PATH $REV $TXN
RET_CODE=0
__LOG__
run_fail "$TEST_KEY.mail.out" test -e mail.out
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-custom-2" # bad custom
test_tidy
cat >"$REPOS_PATH/hooks/post-commit-background-custom" <<'__BASH__'
#!/bin/bash
echo 'I have gone to the dark side.' >&2
false
__BASH__
chmod +x "$REPOS_PATH/hooks/post-commit-background-custom"
touch file4
svn import --no-auth-cache -q -m"$TEST_KEY" file4 "$REPOS_URL/file4"
REV=$(<rev)
TXN=$(<txn)
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
date2datefmt "$REPOS_PATH/log/post-commit.log" \
    | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
    >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $REV by $USER
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip 1>$PWD/svn-dumps/foo-$REV.gz
* Dumped revision $REV.
REV_FILE_SIZE=??? # within 1048576
$REPOS_PATH/hooks/post-commit-background-custom $REPOS_PATH $REV $TXN
I have gone to the dark side.
RET_CODE=1
__LOG__
file_test "$TEST_KEY.mail.out" mail.out
#-------------------------------------------------------------------------------
# Test branch owner notification
echo 'Hello World' >file
svn import -q -m'hello world' file "$REPOS_URL/hello/trunk/file"
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"

TEST_KEY="$TEST_KEY_BASE-branch-create-owner-1" # create author is owner
test_tidy
svn cp -q -m '' --parents \
    "$REPOS_URL/hello/trunk" \
    "$REPOS_URL/hello/branches/dev/$USER/whatever"
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
run_fail "$TEST_KEY.mail.out" test -s mail.out

TEST_KEY="$TEST_KEY_BASE-branch-create-owner-2" # create author not owner
test_tidy
svn cp -q -m '' --parents \
    --username=root \
    --no-auth-cache \
    "$REPOS_URL/hello/trunk" \
    "$REPOS_URL/hello/branches/test/$USER/whatever"
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
file_grep "$TEST_KEY.mail.out.1" \
    '^-rnotifications@localhost -sfoo@10 by root' mail.out
file_grep "$TEST_KEY.mail.out.2" '^r10 | root' mail.out

TEST_KEY="$TEST_KEY_BASE-branch-modify-owner-1" # modify author is owner
test_tidy
svn co -q "$REPOS_URL/hello/branches/dev/$USER/whatever" hello
echo 'Hello Earth' >hello/file
svn ci -q -m'Hello Earth' hello/file
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
run_fail "$TEST_KEY.mail.out" test -s mail.out

TEST_KEY="$TEST_KEY_BASE-branch-modify-owner-2" # modify author not owner
test_tidy
#svn co -q "$REPOS_URL/hello/branches/dev/$USER/whatever" hello
echo 'Hello Alien' >hello/file
svn ci -q -m'Hello Earth' --username=root --no-auth-cache hello/file
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
file_grep "$TEST_KEY.mail.out.1" \
    '^-rnotifications@localhost -sfoo@12 by root' mail.out
file_grep "$TEST_KEY.mail.out.2" '^r12 | root' mail.out

TEST_KEY="$TEST_KEY_BASE-branch-delete-owner-1" # delete author is owner
test_tidy
svn rm -q -m'No Hello' "$REPOS_URL/hello/branches/dev/$USER/whatever"
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
run_fail "$TEST_KEY.mail.out" test -s mail.out

TEST_KEY="$TEST_KEY_BASE-branch-delete-owner-2" # delete author not owner
test_tidy
svn rm -q -m'No Hello' --username=root --no-auth-cache \
    "$REPOS_URL/hello/branches/test/$USER/whatever"
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
file_grep "$TEST_KEY.mail.out.1" \
    '^-rnotifications@localhost -sfoo@14 by root' mail.out
file_grep "$TEST_KEY.mail.out.2" '^r14 | root' mail.out
#-------------------------------------------------------------------------------
exit
