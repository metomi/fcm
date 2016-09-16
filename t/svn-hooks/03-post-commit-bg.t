#!/bin/bash
#-------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-16 Met Office.
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
        "$REPOS_PATH/hooks/commit.cfg" \
        "$REPOS_PATH/log/post-commit.log" \
        'file1' \
        'file2' \
        'file3' \
        'file4' \
        'file5' \
        'svnperms.conf' \
        'mail.out'
}
#-------------------------------------------------------------------------------
tests 50
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
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip \\
    | (dd 'conv=fsync' "of=$PWD/svn-dumps/foo-$REV-tmp.gz" 2>/dev/null)
* Dumped revision $REV.
mv "$PWD/svn-dumps/foo-$REV-tmp.gz" "$PWD/svn-dumps/foo-$REV.gz"
REV_FILE_SIZE=??? # <1MB
RET_CODE=0
__LOG__
if [[ -n ${TRAC_ENV_PATH:-} ]] && ! $TRAC_RESYNC; then
    sqlite3 "$TRAC_ENV_PATH/db/trac.db" \
        'SELECT cast(rev as integer),message FROM revision;' \
        >"$TEST_KEY.trac.db.expected"
    file_cmp "$TEST_KEY.trac.db" \
        "$TEST_KEY.trac.db.expected" <<<"$REV|$TEST_KEY"
else
    skip 1 '"trac-admin changeset added" not available'
fi
run_pass "$TEST_KEY.dump" test -s "$PWD/svn-dumps/foo-$REV.gz"
run_fail "$TEST_KEY.mail.out" test -e mail.out
#-------------------------------------------------------------------------------
# Install and remove commit.conf, svnperms.conf
for NAME in 'commit.cfg' 'svnperms.conf'; do
    TEST_KEY="$TEST_KEY_BASE-no-add-${NAME}"
    test_tidy
    if [[ "${NAME}" == 'svnperms.conf' ]]; then
        cat >"${NAME}" <<'__CONF__'
[foo]
.*=*(add,remove,update)
__CONF__
    else
        touch "${NAME}"
    fi
    mkdir -p "svn-hooks/foo"
    if [[ "${NAME}" == 'svnperms.conf' ]]; then
        cat >"svn-hooks/foo/${NAME}" <<'__CONF__'
# This is the site override
[foo]
.*=*(add,remove,update)
__CONF__
    else
        cat >"svn-hooks/foo/${NAME}" <<'__CONF__'
# This is the site override
__CONF__
    fi
    cp -p "svn-hooks/foo/${NAME}" "$REPOS_PATH/hooks/${NAME}"
    svn import --no-auth-cache -q -m"${TEST_KEY}" "${NAME}" \
        "${REPOS_URL}/${NAME}"
    REV="$(<'rev')"
    poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
    date2datefmt "$REPOS_PATH/log/post-commit.log" \
        | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
        >"$TEST_KEY.log"
    file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $REV by $USER
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip \\
    | (dd 'conv=fsync' "of=$PWD/svn-dumps/foo-$REV-tmp.gz" 2>/dev/null)
* Dumped revision $REV.
mv "$PWD/svn-dumps/foo-$REV-tmp.gz" "$PWD/svn-dumps/foo-$REV.gz"
REV_FILE_SIZE=??? # <1MB
RET_CODE=0
__LOG__
    file_cmp "${TEST_KEY}.conf" \
        "svn-hooks/foo/${NAME}" "$REPOS_PATH/hooks/${NAME}"
    rm -fr 'svn-hooks'

    test_tidy
    svn delete --no-auth-cache -q -m"Delete ${TEST_KEY}" "${REPOS_URL}/${NAME}"

    TEST_KEY="$TEST_KEY_BASE-add-${NAME}"
    test_tidy
    if [[ "${NAME}" == 'svnperms.conf' ]]; then
        cat >"${NAME}" <<'__CONF__'
[foo]
.*=*(add,remove,update)
__CONF__
    else
        touch "${NAME}"
    fi
    svn import --no-auth-cache -q -m"$TEST_KEY" ${NAME} \
        "$REPOS_URL/${NAME}"
    REV=$(<rev)
    poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
    date2datefmt "$REPOS_PATH/log/post-commit.log" \
        | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
        >"$TEST_KEY.log"
    file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $REV by $USER
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip \\
    | (dd 'conv=fsync' "of=$PWD/svn-dumps/foo-$REV-tmp.gz" 2>/dev/null)
* Dumped revision $REV.
mv "$PWD/svn-dumps/foo-$REV-tmp.gz" "$PWD/svn-dumps/foo-$REV.gz"
REV_FILE_SIZE=??? # <1MB
svnlook cat $REPOS_PATH ${NAME} >$REPOS_PATH/hooks/${NAME}
RET_CODE=0
__LOG__
    file_cmp "$TEST_KEY.conf" ${NAME} "$REPOS_PATH/hooks/${NAME}"

    TEST_KEY="$TEST_KEY_BASE-modify-${NAME}"
    test_tidy
    svn co -q "$REPOS_URL" work
    if [[ "${NAME}" == 'svnperms.conf' ]]; then
        cat >"work/${NAME}" <<'__CONF__'
[foo]
.*=*(add,remove,update)

[bar]
__CONF__
    elif [[ "${NAME}" == 'commit.cfg' ]]; then
        cat >"work/${NAME}" <<'__CONF__'
permission-modes=branch
__CONF__
    fi
    svn commit --no-auth-cache -q -m"$TEST_KEY" work
    REV=$(<rev)
    poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
    date2datefmt "$REPOS_PATH/log/post-commit.log" \
        | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
        >"$TEST_KEY.log"
    file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $REV by $USER
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip \\
    | (dd 'conv=fsync' "of=$PWD/svn-dumps/foo-$REV-tmp.gz" 2>/dev/null)
* Dumped revision $REV.
mv "$PWD/svn-dumps/foo-$REV-tmp.gz" "$PWD/svn-dumps/foo-$REV.gz"
REV_FILE_SIZE=??? # <1MB
svnlook cat $REPOS_PATH ${NAME} >$REPOS_PATH/hooks/${NAME}
RET_CODE=0
__LOG__
    file_cmp "$TEST_KEY.conf" work/${NAME} "$REPOS_PATH/hooks/${NAME}"
    rm -f -r work

    TEST_KEY="$TEST_KEY_BASE-remove-${NAME}"
    test_tidy
    touch "$REPOS_PATH/hooks/${NAME}"
    svn rm --no-auth-cache -q -m'remove ${NAME}' "$REPOS_URL/${NAME}"
    REV=$(<rev)
    poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
    date2datefmt "$REPOS_PATH/log/post-commit.log" \
        | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
        >"$TEST_KEY.log"
    file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $REV by $USER
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip \\
    | (dd 'conv=fsync' "of=$PWD/svn-dumps/foo-$REV-tmp.gz" 2>/dev/null)
* Dumped revision $REV.
mv "$PWD/svn-dumps/foo-$REV-tmp.gz" "$PWD/svn-dumps/foo-$REV.gz"
REV_FILE_SIZE=??? # <1MB
rm -f $REPOS_PATH/hooks/${NAME}
RET_CODE=0
__LOG__
    run_fail "$TEST_KEY.conf" test -e "$REPOS_PATH/hooks/${NAME}"
done
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
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip \\
    | (dd 'conv=fsync' "of=$PWD/svn-dumps/foo-$REV-tmp.gz" 2>/dev/null)
* Dumped revision $REV.
mv "$PWD/svn-dumps/foo-$REV-tmp.gz" "$PWD/svn-dumps/foo-$REV.gz"
REV_FILE_SIZE=??? # >1MB <10MB
RET_CODE=1
__LOG__
date2datefmt mail.out \
    | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
    >"$TEST_KEY.mail.out"
file_cmp "$TEST_KEY.mail.out" "$TEST_KEY.mail.out" <<__LOG__
-s [post-commit-bg] $REPOS_PATH@$REV fcm.admin.team
YYYY-mm-ddTHH:MM:SSZ+ $REV by $USER
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip \\
    | (dd 'conv=fsync' "of=$PWD/svn-dumps/foo-$REV-tmp.gz" 2>/dev/null)
* Dumped revision $REV.
mv "$PWD/svn-dumps/foo-$REV-tmp.gz" "$PWD/svn-dumps/foo-$REV.gz"
REV_FILE_SIZE=??? # >1MB <10MB
RET_CODE=1
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-size-2"
test_tidy
perl -e 'map {print(rand())} 1..2097152' >'file3' # compress should be >10MB
svn import --no-auth-cache -q -m"${TEST_KEY}" 'file3' "${REPOS_URL}/file3"
REV="$(<'rev')"
poll 10 grep -q '^RET_CODE=' "${REPOS_PATH}/log/post-commit.log"
poll 10 test -e 'mail.out'
date2datefmt "${REPOS_PATH}/log/post-commit.log" \
    | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
    >"${TEST_KEY}.log"
file_cmp "${TEST_KEY}.log" "${TEST_KEY}.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ ${REV} by ${USER}
svnadmin dump -r${REV} --incremental --deltas ${REPOS_PATH} | gzip \\
    | (dd 'conv=fsync' "of=${PWD}/svn-dumps/foo-${REV}-tmp.gz" 2>/dev/null)
* Dumped revision ${REV}.
mv "${PWD}/svn-dumps/foo-${REV}-tmp.gz" "${PWD}/svn-dumps/foo-${REV}.gz"
REV_FILE_SIZE=??? # >10MB
RET_CODE=1
__LOG__
date2datefmt mail.out \
    | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
    >"${TEST_KEY}.mail.out"
file_cmp "${TEST_KEY}.mail.out" "${TEST_KEY}.mail.out" <<__LOG__
-s [post-commit-bg] ${REPOS_PATH}@${REV} fcm.admin.team
YYYY-mm-ddTHH:MM:SSZ+ ${REV} by ${USER}
svnadmin dump -r${REV} --incremental --deltas ${REPOS_PATH} | gzip \\
    | (dd 'conv=fsync' "of=${PWD}/svn-dumps/foo-${REV}-tmp.gz" 2>/dev/null)
* Dumped revision ${REV}.
mv "${PWD}/svn-dumps/foo-${REV}-tmp.gz" "${PWD}/svn-dumps/foo-${REV}.gz"
REV_FILE_SIZE=??? # >10MB
RET_CODE=1
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-custom-1" # good custom
test_tidy
touch file4
cat >"$REPOS_PATH/hooks/post-commit-bg-custom" <<'__BASH__'
#!/bin/bash
echo "$@"
__BASH__
chmod +x "$REPOS_PATH/hooks/post-commit-bg-custom"
svn import --no-auth-cache -q -m"$TEST_KEY" file4 "$REPOS_URL/file4"
REV=$(<rev)
TXN=$(<txn)
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
date2datefmt "$REPOS_PATH/log/post-commit.log" \
    | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
    >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $REV by $USER
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip \\
    | (dd 'conv=fsync' "of=$PWD/svn-dumps/foo-$REV-tmp.gz" 2>/dev/null)
* Dumped revision $REV.
mv "$PWD/svn-dumps/foo-$REV-tmp.gz" "$PWD/svn-dumps/foo-$REV.gz"
REV_FILE_SIZE=??? # <1MB
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
touch file5
svn import --no-auth-cache -q -m"$TEST_KEY" file5 "$REPOS_URL/file5"
REV=$(<rev)
TXN=$(<txn)
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
poll 10 test -e 'mail.out'
date2datefmt "$REPOS_PATH/log/post-commit.log" \
    | sed '/^trac-admin/d; s/^\(REV_FILE_SIZE=\).*\( #\)/\1???\2/' \
    >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $REV by $USER
svnadmin dump -r$REV --incremental --deltas $REPOS_PATH | gzip \\
    | (dd 'conv=fsync' "of=$PWD/svn-dumps/foo-$REV-tmp.gz" 2>/dev/null)
* Dumped revision $REV.
mv "$PWD/svn-dumps/foo-$REV-tmp.gz" "$PWD/svn-dumps/foo-$REV.gz"
REV_FILE_SIZE=??? # <1MB
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
echo 'notification-modes=branch' >"${REPOS_PATH}/hooks/commit.cfg"
svn cp -q -m '' --parents \
    "$REPOS_URL/hello/trunk" \
    "$REPOS_URL/hello/branches/dev/$USER/whatever"
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
run_fail "$TEST_KEY.mail.out" test -s mail.out

TEST_KEY="$TEST_KEY_BASE-branch-create-owner-2" # create author not owner
test_tidy
echo 'notification-modes=branch' >"${REPOS_PATH}/hooks/commit.cfg"
svn cp -q -m '' --parents \
    --username=root \
    --no-auth-cache \
    "$REPOS_URL/hello/trunk" \
    "$REPOS_URL/hello/branches/test/$USER/whatever"
REV=$(<rev)
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
poll 10 test -e 'mail.out'
file_grep "$TEST_KEY.mail.out.1" \
    "^-rnotifications@localhost -sfoo@${REV} by root" mail.out
file_grep "$TEST_KEY.mail.out.2" "^r${REV} | root" mail.out

TEST_KEY="$TEST_KEY_BASE-branch-create-owner-3" # same as 2, but no notify
test_tidy
svn cp -q -m '' --parents \
    --username=root \
    --no-auth-cache \
    "$REPOS_URL/hello/trunk" \
    "$REPOS_URL/hello/branches/test/$USER/whatever2"
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
run_fail "$TEST_KEY.mail.out" test -s mail.out

TEST_KEY="$TEST_KEY_BASE-branch-modify-owner-1" # modify author is owner
test_tidy
echo 'notification-modes=branch' >"${REPOS_PATH}/hooks/commit.cfg"
svn co -q "$REPOS_URL/hello/branches/dev/$USER/whatever" hello
echo 'Hello Earth' >hello/file
svn ci -q -m'Hello Earth' hello/file
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
run_fail "$TEST_KEY.mail.out" test -s mail.out

TEST_KEY="$TEST_KEY_BASE-branch-modify-owner-2" # modify author not owner
test_tidy
echo 'notification-modes=branch' >"${REPOS_PATH}/hooks/commit.cfg"
#svn co -q "$REPOS_URL/hello/branches/dev/$USER/whatever" hello
echo 'Hello Alien' >hello/file
svn ci -q -m'Hello Earth' --username=root --no-auth-cache hello/file
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
poll 10 test -e 'mail.out'
REV=$(<rev)
file_grep "$TEST_KEY.mail.out.1" \
    "^-rnotifications@localhost -sfoo@${REV} by root" mail.out
file_grep "$TEST_KEY.mail.out.2" "^r${REV} | root" mail.out

TEST_KEY="$TEST_KEY_BASE-share-branch-owner-1" # modify share author is owner
test_tidy
echo 'notification-modes=branch' >"${REPOS_PATH}/hooks/commit.cfg"
svn cp -q -m '' --parents \
    "$REPOS_URL/hello/trunk" \
    "$REPOS_URL/hello/branches/dev/Share/whatever"
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
run_fail "$TEST_KEY.create.mail.out" test -s mail.out
test_tidy
echo 'Greet Alien' >'greet.txt'
svn import -q -m '' 'greet.txt' \
    "$REPOS_URL/hello/branches/dev/Share/whatever/greet.txt"
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
run_fail "$TEST_KEY.modify.mail.out" test -s mail.out

TEST_KEY="$TEST_KEY_BASE-share-branch-owner-2" # modify share author not owner
test_tidy
echo 'notification-modes=branch' >"${REPOS_PATH}/hooks/commit.cfg"
echo 'Hail Alien' >'hail.txt'
svn import -q -m '' --username=root --no-auth-cache 'hail.txt' \
    "$REPOS_URL/hello/branches/dev/Share/whatever/hail.txt"
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
poll 10 test -e 'mail.out'
REV=$(<rev)
file_grep "$TEST_KEY.mail.out.1" \
    "^-rnotifications@localhost -sfoo@${REV} by root" 'mail.out'
file_grep "$TEST_KEY.mail.out.2" "^r${REV} | root" 'mail.out'

TEST_KEY="$TEST_KEY_BASE-branch-delete-owner-1" # delete author is owner
test_tidy
echo 'notification-modes=branch' >"${REPOS_PATH}/hooks/commit.cfg"
svn rm -q -m'No Hello' "$REPOS_URL/hello/branches/dev/$USER/whatever"
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
run_fail "$TEST_KEY.mail.out" test -s mail.out

TEST_KEY="$TEST_KEY_BASE-branch-delete-owner-2" # delete author not owner
test_tidy
echo 'notification-modes=branch' >"${REPOS_PATH}/hooks/commit.cfg"
svn rm -q -m'No Hello' --username=root --no-auth-cache \
    "$REPOS_URL/hello/branches/test/$USER/whatever"
poll 10 grep -q '^RET_CODE=' "$REPOS_PATH/log/post-commit.log"
poll 10 test -e 'mail.out'
REV=$(<rev)
file_grep "$TEST_KEY.mail.out.1" \
    "^-rnotifications@localhost -sfoo@${REV} by root" mail.out
file_grep "$TEST_KEY.mail.out.2" "^r${REV} | root" mail.out
#-------------------------------------------------------------------------------
# Test owner notification, repository
TEST_KEY="${TEST_KEY_BASE}-owner-1"
test_tidy
cat >"${REPOS_PATH}/hooks/commit.cfg" <<__CONF__
notification-modes=repository
owner=${USER}
__CONF__
rm -fr 'hello'
svn co -q "${REPOS_URL}/hello/trunk" 'hello'
echo 'Hello' >'hello/file'
svn ci -q -m 'hello whatever' '--no-auth-cache' '--username=root' 'hello'
poll 10 grep -q '^RET_CODE=' "${REPOS_PATH}/log/post-commit.log"
poll 10 test -e 'mail.out'
REV="$(<rev)"
file_grep "${TEST_KEY}.mail.out.1" \
    "^-rnotifications@localhost -sfoo@${REV} by root" 'mail.out'
file_grep "${TEST_KEY}.mail.out.2" "^r${REV} | root" 'mail.out'
#-------------------------------------------------------------------------------
# Test owner notification, project
TEST_KEY="${TEST_KEY_BASE}-owner-2"
test_tidy
cat >"${REPOS_PATH}/hooks/commit.cfg" <<__CONF__
notification-modes=project
owner[hello/]=${USER}
__CONF__
rm -fr 'hello'
svn co -q "${REPOS_URL}/hello/trunk" 'hello'
echo 'Hello Hello' >'hello/file'
svn ci -q -m 'hello 2 whatever' '--no-auth-cache' '--username=root' 'hello'
poll 10 grep -q '^RET_CODE=' "${REPOS_PATH}/log/post-commit.log"
poll 10 test -e 'mail.out'
REV="$(<rev)"
file_grep "${TEST_KEY}.mail.out.1" \
    "^-rnotifications@localhost -sfoo@${REV} by root" 'mail.out'
file_grep "${TEST_KEY}.mail.out.2" "^r${REV} | root" 'mail.out'
#-------------------------------------------------------------------------------
# Test owner notification, project mode, repository level owner only
# No notification
TEST_KEY="${TEST_KEY_BASE}-owner-3"
test_tidy
cat >"${REPOS_PATH}/hooks/commit.cfg" <<__CONF__
notification-modes=project
owner=${USER}
__CONF__
rm -fr 'hello'
svn co -q "${REPOS_URL}/hello/trunk" 'hello'
echo 'Hello Hello Hello' >'hello/file'
svn ci -q -m 'hello 2 whatever' '--no-auth-cache' '--username=root' 'hello'
poll 10 grep -q '^RET_CODE=' "${REPOS_PATH}/log/post-commit.log"
run_fail "${TEST_KEY}.mail.out" test -s 'mail.out'
#-------------------------------------------------------------------------------
# Test subscriber notification, configuration as in "owner-2" test, but
# subscriber set to empty.
# No notification
TEST_KEY="${TEST_KEY_BASE}-subscriber-1"
test_tidy
cat >"${REPOS_PATH}/hooks/commit.cfg" <<__CONF__
notification-modes=project
owner[hello/]=${USER}
subscriber[hello/]=
__CONF__
rm -fr 'hello'
svn co -q "${REPOS_URL}/hello/trunk" 'hello'
echo 'Hello Hello' >'hello/file'
svn ci -q -m 'hello 2 whatever' '--no-auth-cache' '--username=root' 'hello'
poll 10 grep -q '^RET_CODE=' "${REPOS_PATH}/log/post-commit.log"
run_fail "${TEST_KEY}.mail.out" test -s 'mail.out'
#-------------------------------------------------------------------------------
# Test subscriber notification, configuration as in "owner-2" test, but
# owner unset, and subscriber set to $USER.
# No notification
TEST_KEY="${TEST_KEY_BASE}-subscriber-2"
test_tidy
cat >"${REPOS_PATH}/hooks/commit.cfg" <<__CONF__
notification-modes=project
subscriber[hello/]=${USER}
__CONF__
rm -fr 'hello'
svn co -q "${REPOS_URL}/hello/trunk" 'hello'
echo 'Hello Hello Hello' >'hello/file'
svn ci -q -m 'hello 2 whatever' '--no-auth-cache' '--username=root' 'hello'
poll 10 grep -q '^RET_CODE=' "${REPOS_PATH}/log/post-commit.log"
poll 10 test -e 'mail.out'
REV="$(<rev)"
file_grep "${TEST_KEY}.mail.out.1" \
    "^-rnotifications@localhost -sfoo@${REV} by root" 'mail.out'
file_grep "${TEST_KEY}.mail.out.2" "^r${REV} | root" 'mail.out'
#-------------------------------------------------------------------------------
exit
