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
# Basic tests for "pre-commit".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
FCM_SVN_HOOK_ADMIN_EMAIL='your.admin.team'
. $TEST_SOURCE_DIR/test_header_more

test_tidy() {
    rm -f \
        "${REPOS_PATH}/hooks/pre-commit-custom" \
        "${REPOS_PATH}/hooks/pre-commit-size-threshold.conf" \
        "${REPOS_PATH}/hooks/commit.cfg" \
        "${REPOS_PATH}/hooks/svnperms.conf" \
        "${REPOS_PATH}/log/pre-commit.log" \
        'README' \
        'bin/svnperms.py' \
        'file1' \
        'file2' \
        'file3' \
        'file4' \
        'mail.out' \
        'pre-commit-custom.out' \
        'svnperms.py.out'
    rm -fr \
        'work'
}
#-------------------------------------------------------------------------------
tests 82
#-------------------------------------------------------------------------------
export FCM_CONF_DIR=
cp -p "$FCM_HOME/etc/svn-hooks/pre-commit" "$REPOS_PATH/hooks/"
sed -i "/set -eu/a\
echo \$2 >$PWD/txn" "$REPOS_PATH/hooks/pre-commit"
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-svnperm-1" # Blocked by svnperms.py
# Install fake svnperms.py
test_tidy
cat >bin/svnperms.py <<__BASH__
#!/bin/bash
echo "\$@" >$PWD/svnperms.py.out
echo "Access denied!" >&2
false
__BASH__
chmod +x "bin/svnperms.py"
echo '[foo]' >"$REPOS_PATH/hooks/svnperms.conf"
# Try commit
touch file1
run_fail "$TEST_KEY" \
    svn import --no-auth-cache -q -m'test' file1 "$REPOS_URL/file1"
TXN=$(<txn)
# Tests
file_grep "$TEST_KEY.err" 'Access denied!' "$TEST_KEY.err"
date2datefmt "$REPOS_PATH/log/pre-commit.log" \
    >"$TEST_KEY.pre-commit.log.expected"
file_cmp "$TEST_KEY.pre-commit.log" "$TEST_KEY.pre-commit.log.expected" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $TXN by $USER
A   file1
Access denied!
__LOG__
file_cmp "$TEST_KEY.svnperms.py.out" svnperms.py.out <<__OUT__
-r $REPOS_PATH -t $TXN -f $REPOS_PATH/hooks/svnperms.conf
__OUT__
date2datefmt mail.out >"$TEST_KEY.mail.out.expected"
file_cmp  "$TEST_KEY.mail.out" "$TEST_KEY.mail.out.expected" <<__LOG__
-s [pre-commit] $REPOS_PATH@$TXN your.admin.team
YYYY-mm-ddTHH:MM:SSZ+ $TXN by $USER
A   file1
Access denied!
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-svnperm-2" # svnperms.conf is bad symlink
# Install fake svnperms.py
test_tidy
ln -f -s "no-such-file" "$REPOS_PATH/hooks/svnperms.conf"
# Try commit
touch file1
run_fail "$TEST_KEY" \
    svn import --no-auth-cache -q -m'test' file1 "$REPOS_URL/file1"
TXN=$(<txn)
# Tests
file_grep "$TEST_KEY.err" 'foo: permission configuration file not found.' \
    "$TEST_KEY.err"
file_grep "$TEST_KEY.err-2" 'your.admin.team has been notified.' "$TEST_KEY.err"
date2datefmt "$REPOS_PATH/log/pre-commit.log" \
    >"$TEST_KEY.pre-commit.log.expected"
file_cmp "$TEST_KEY.pre-commit.log" "$TEST_KEY.pre-commit.log.expected" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $TXN by $USER
A   file1
foo: permission configuration file not found.
your.admin.team has been notified.
__LOG__
run_fail "$TEST_KEY.svnperms.py.out" test -e svnperms.py.out
date2datefmt mail.out >"$TEST_KEY.mail.out.expected"
file_cmp "$TEST_KEY.mail.out" "$TEST_KEY.mail.out.expected" <<__LOG__
-s [pre-commit] $REPOS_PATH@$TXN your.admin.team
YYYY-mm-ddTHH:MM:SSZ+ $TXN by $USER
A   file1
foo: permission configuration file not found.
your.admin.team has been notified.
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-svnperm-3" # Good svnperms.conf
test_tidy
cat >bin/svnperms.py <<__BASH__
#!/bin/bash
echo "\$@" >$PWD/svnperms.py.out
__BASH__
chmod +x bin/svnperms.py
echo '[foo]' >"$REPOS_PATH/hooks/svnperms.conf"
# Try commit
touch file1
run_pass "$TEST_KEY" \
    svn import --no-auth-cache -q -m'test' file1 "$REPOS_URL/file1"
TXN=$(<txn)
# Tests
run_fail "$TEST_KEY.pre-commit.log" test -s "$REPOS_PATH/log/pre-commit.log"
file_cmp "$TEST_KEY.svnperms.py.out" "svnperms.py.out" <<__OUT__
-r $REPOS_PATH -t $TXN -f $REPOS_PATH/hooks/svnperms.conf
__OUT__
run_fail "$TEST_KEY.mail.out" test -e mail.out
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-svnperm-4" # No svnperms.conf
test_tidy
# Try commit
touch file2
run_pass "$TEST_KEY" \
    svn import --no-auth-cache -q -m'test' file2 "$REPOS_URL/file2"
# Tests
run_fail "$TEST_KEY.pre-commit.log" test -s "$REPOS_PATH/log/pre-commit.log"
run_fail "$TEST_KEY.svnperms.py.out" test -e svnperms.py.out
run_fail "$TEST_KEY.mail.out" test -e mail.out
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-size-1" # bigger than default
test_tidy
perl -e 'map {print(rand())} 1..2097152' >file3 # a large file
run_fail "$TEST_KEY" \
    svn import --no-auth-cache -q -m'test' file3 "$REPOS_URL/file3"
TXN=$(<txn)
file_grep "$TEST_KEY.err" "foo@$TXN: changeset size ..MB exceeds 10MB." \
    "$TEST_KEY.err"
file_grep "$TEST_KEY.err-2" \
    'Email your.admin.team if you need to bypass this restriction.' "$TEST_KEY.err"
date2datefmt "$REPOS_PATH/log/pre-commit.log" \
    | sed 's/\(size \).*\(MB exceeds\)/\1??\2/' \
    >"$TEST_KEY.pre-commit.log.expected"
file_cmp "$TEST_KEY.pre-commit.log" "$TEST_KEY.pre-commit.log.expected" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $TXN by $USER
A   file3
foo@$TXN: changeset size ??MB exceeds 10MB.
Email your.admin.team if you need to bypass this restriction.
__LOG__
date2datefmt mail.out | sed 's/\(size \).*\(MB exceeds\)/\1??\2/' \
     >"$TEST_KEY.mail.out.expected"
file_cmp "$TEST_KEY.mail.out.expected" "$TEST_KEY.mail.out.expected" <<__OUT__
-s [pre-commit] $REPOS_PATH@$TXN your.admin.team
YYYY-mm-ddTHH:MM:SSZ+ $TXN by $USER
A   file3
foo@$TXN: changeset size ??MB exceeds 10MB.
Email your.admin.team if you need to bypass this restriction.
__OUT__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-size-2" # bigger than default, threshold increased
test_tidy
echo '20' >"$REPOS_PATH/hooks/pre-commit-size-threshold.conf"
perl -e 'map {print(rand())} 1..2097152' >file3 # a large file
run_pass "$TEST_KEY" \
    svn import --no-auth-cache -q -m'test' file3 "$REPOS_URL/file3"
TXN="$(<'txn')"
# Tests
date2datefmt "$REPOS_PATH/log/pre-commit.log" \
    | sed 's/\(size \).*\(MB exceeds\)/\1??\2/' \
    >"$TEST_KEY.pre-commit.log.expected"
file_cmp "${TEST_KEY}.pre-commit.log" "${TEST_KEY}.pre-commit.log.expected" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ ${TXN} by ${USER}
A   file3
foo@${TXN}: changeset size ??MB exceeds 1MB.
__LOG__
run_fail "$TEST_KEY.mail.out" test -e 'mail.out'
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-custom-1" # block by custom script
test_tidy
cat >"$REPOS_PATH/hooks/pre-commit-custom" <<__BASH__
#!/bin/bash
echo "\$@" >$PWD/pre-commit-custom.out
echo 'I am a blocker.' >&2
false
__BASH__
chmod +x "$REPOS_PATH/hooks/pre-commit-custom"
touch file4
run_fail "$TEST_KEY" \
    svn import --no-auth-cache -q -m'test' file4 "$REPOS_URL/file4"
TXN=$(<txn)
# Tests
file_grep "$TEST_KEY.err" 'I am a blocker.' "$TEST_KEY.err"
file_cmp "$TEST_KEY-custom.out" pre-commit-custom.out <<__OUT__
$REPOS_PATH $TXN
__OUT__
date2datefmt "$REPOS_PATH/log/pre-commit.log" \
    | sed 's/\(size \).*\(MB exceeds\)/\1??\2/' \
     >"$TEST_KEY.pre-commit.log"
file_cmp "$TEST_KEY.pre-commit.log" "$TEST_KEY.pre-commit.log" <<__OUT__
YYYY-mm-ddTHH:MM:SSZ+ $TXN by $USER
A   file4
I am a blocker.
__OUT__
date2datefmt mail.out | sed 's/\(size \).*\(MB exceeds\)/\1??\2/' \
     >"$TEST_KEY.mail.out.expected"
file_cmp "$TEST_KEY.mail.out.expected" "$TEST_KEY.mail.out.expected" <<__OUT__
-s [pre-commit] $REPOS_PATH@$TXN your.admin.team
YYYY-mm-ddTHH:MM:SSZ+ $TXN by $USER
A   file4
I am a blocker.
__OUT__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-custom-2" # custom script OK
test_tidy
cat >"$REPOS_PATH/hooks/pre-commit-custom" <<__BASH__
#!/bin/bash
echo "\$@" >$PWD/pre-commit-custom.out
__BASH__
chmod +x "$REPOS_PATH/hooks/pre-commit-custom"
touch file4
run_pass "$TEST_KEY" \
    svn import --no-auth-cache -q -m'test' file4 "$REPOS_URL/file4"
TXN=$(<txn)
# Tests
file_cmp "$TEST_KEY-custom.out" pre-commit-custom.out <<__OUT__
$REPOS_PATH $TXN
__OUT__
run_fail "$TEST_KEY.pre-commit.log" test -s "$REPOS_PATH/log/pre-commit.log"
run_fail "$TEST_KEY.mail.out" test -e mail.out
#-------------------------------------------------------------------------------
# Permission check, create user and share branches in normal layout
echo 'Hello World' >README
svn import --no-auth-cache -q -m "hello: new project" \
    README "$REPOS_URL/hello/trunk/README"
rm README
for KEY in $USER Share Config Rel; do
    test_tidy
    TEST_KEY="$TEST_KEY_BASE-branch-owner-$KEY"
    echo 'permission-modes=project branch' >"$REPOS_PATH/hooks/commit.cfg"
    run_pass "$TEST_KEY" svn cp --no-auth-cache --parents -m "$TEST_KEY" \
        "$REPOS_URL/hello/trunk" "$REPOS_URL/hello/branches/dev/$KEY/whatever"
    run_fail "$TEST_KEY.pre-commit.log" test -s "$REPOS_PATH/log/pre-commit.log"
done
#-------------------------------------------------------------------------------
# Branch create owner verify, bad
test_tidy
TEST_KEY="$TEST_KEY_BASE-branch-owner-bad"
echo 'permission-modes=project branch' >"$REPOS_PATH/hooks/commit.cfg"
run_fail "$TEST_KEY" svn cp --no-auth-cache --parents -m "$TEST_KEY" \
    "$REPOS_URL/hello/trunk" "$REPOS_URL/hello/branches/dev/nosuchuser/whatever"
TXN=$(<txn)
file_grep "$TEST_KEY.err" \
    'PERMISSION DENIED: A   hello/branches/dev/nosuchuser/whatever/' \
    "$TEST_KEY.err"
date2datefmt "$REPOS_PATH/log/pre-commit.log" \
    >"$TEST_KEY.pre-commit.log.expected"
file_cmp "$TEST_KEY.pre-commit.log" \
    "$TEST_KEY.pre-commit.log.expected" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $TXN by $USER
A   hello/branches/dev/nosuchuser/
A   hello/branches/dev/nosuchuser/whatever/
PERMISSION DENIED: A   hello/branches/dev/nosuchuser/whatever/
__LOG__
date2datefmt mail.out >"$TEST_KEY.mail.out.expected"
file_cmp  "$TEST_KEY.mail.out" "$TEST_KEY.mail.out.expected" <<__LOG__
-s [pre-commit] $REPOS_PATH@$TXN your.admin.team
YYYY-mm-ddTHH:MM:SSZ+ $TXN by $USER
A   hello/branches/dev/nosuchuser/
A   hello/branches/dev/nosuchuser/whatever/
PERMISSION DENIED: A   hello/branches/dev/nosuchuser/whatever/
__LOG__
#-------------------------------------------------------------------------------
# Branch create owner verify, bad by repository owner
test_tidy
TEST_KEY="$TEST_KEY_BASE-branch-owner-bad-by-repository-owner"
cat >"$REPOS_PATH/hooks/commit.cfg" <<__CONF__
owner=${USER}
permission-modes=project branch
__CONF__
run_fail "$TEST_KEY" svn cp --no-auth-cache --parents -m "$TEST_KEY" \
    "$REPOS_URL/hello/trunk" "$REPOS_URL/hello/branches/dev/nosuchuser/whatever"
TXN=$(<txn)
file_grep "$TEST_KEY.err" \
    'PERMISSION DENIED: A   hello/branches/dev/nosuchuser/whatever/' \
    "$TEST_KEY.err"
date2datefmt "$REPOS_PATH/log/pre-commit.log" \
    >"$TEST_KEY.pre-commit.log.expected"
file_cmp "$TEST_KEY.pre-commit.log" \
    "$TEST_KEY.pre-commit.log.expected" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ $TXN by $USER
A   hello/branches/dev/nosuchuser/
A   hello/branches/dev/nosuchuser/whatever/
PERMISSION DENIED: A   hello/branches/dev/nosuchuser/whatever/
__LOG__
date2datefmt mail.out >"$TEST_KEY.mail.out.expected"
file_cmp  "$TEST_KEY.mail.out" "$TEST_KEY.mail.out.expected" <<__LOG__
-s [pre-commit] $REPOS_PATH@$TXN your.admin.team
YYYY-mm-ddTHH:MM:SSZ+ $TXN by $USER
A   hello/branches/dev/nosuchuser/
A   hello/branches/dev/nosuchuser/whatever/
PERMISSION DENIED: A   hello/branches/dev/nosuchuser/whatever/
__LOG__
#-------------------------------------------------------------------------------
# Branch create owner no verify, bad
test_tidy
TEST_KEY="$TEST_KEY_BASE-branch-owner-no-verify-bad"
run_pass "$TEST_KEY" svn cp --no-auth-cache --parents -m "$TEST_KEY" \
    "$REPOS_URL/hello/trunk" "$REPOS_URL/hello/branches/dev/nosuchuser/whatever"
run_fail "$TEST_KEY.pre-commit.log" test -s "$REPOS_PATH/log/pre-commit.log"
#-------------------------------------------------------------------------------
# Reject bad "commit.cfg"
for KEY in $(ls "${TEST_SOURCE_DIR}/${TEST_KEY_BASE}/bad-commit.cfg.d"); do
    test_tidy
    TEST_KEY="${TEST_KEY_BASE}-bad-commit-conf-${KEY}"
    run_fail "${TEST_KEY}" svn import --no-auth-cache -q -m "${TEST_KEY}" \
        "${TEST_SOURCE_DIR}/${TEST_KEY_BASE}/bad-commit.cfg.d/${KEY}" \
        "${REPOS_URL}/commit.cfg"
    TXN=$(<'txn')
    date2datefmt "${REPOS_PATH}/log/pre-commit.log" \
        >"${TEST_KEY}.pre-commit.log"
    sed '/^#LOG /!d; s/^#LOG //; '"s/\$USER/${USER}/; s/\$TXN/$TXN/" \
        "${TEST_SOURCE_DIR}/${TEST_KEY_BASE}/bad-commit.cfg.d/${KEY}" \
        >"${TEST_KEY}.pre-commit.log.expected"
    file_cmp "${TEST_KEY}.pre-commit.log" \
        "${TEST_KEY}.pre-commit.log" "${TEST_KEY}.pre-commit.log.expected"
done
#-------------------------------------------------------------------------------
# Accept good "commit.cfg"
test_tidy
TEST_KEY="${TEST_KEY_BASE}-commit-conf-empty"
touch 'commit.cfg'
run_pass "${TEST_KEY}" svn import --no-auth-cache -q -m "${TEST_KEY}" \
    'commit.cfg' "${REPOS_URL}/commit.cfg"
run_fail "$TEST_KEY.pre-commit.log" test -s "$REPOS_PATH/log/pre-commit.log"
rm -f 'commit.cfg'

test_tidy
svn co -q -N "${REPOS_URL}" 'work'
for KEY in $(ls "${TEST_SOURCE_DIR}/${TEST_KEY_BASE}/good-commit.cfg.d"); do
    TEST_KEY="${TEST_KEY_BASE}-good-commit-conf-${KEY}"
    cp "${TEST_SOURCE_DIR}/${TEST_KEY_BASE}/good-commit.cfg.d/${KEY}" \
        'work/commit.cfg'
    sed -i "s/\$USER/${USER}/" 'work/commit.cfg'
    run_pass "${TEST_KEY}" svn commit --no-auth-cache -q -m "${TEST_KEY}" \
        'work/commit.cfg'
    run_fail "${TEST_KEY}.pre-commit.log" \
        test -s "${REPOS_PATH}/log/pre-commit.log"
done
rm -fr 'work'

test_tidy
TEST_KEY="${TEST_KEY_BASE}-commit-conf-delete"
run_pass "${TEST_KEY}" svn delete --no-auth-cache -q -m "${TEST_KEY}" \
    "${REPOS_URL}/commit.cfg"
run_fail "$TEST_KEY.pre-commit.log" test -s "$REPOS_PATH/log/pre-commit.log"
#-------------------------------------------------------------------------------
# Check project A/U/D blocked when "permission-modes=repository" and
# "owner=nosuchuser".
# Check project A/U/D OK when "permission-modes=branch".

# Create, bad
test_tidy
TEST_KEY="${TEST_KEY_BASE}-project-create-on-perm-mode-eq-repository"
cat >"${REPOS_PATH}/hooks/commit.cfg" <<__CONF__
owner=nosuchuser
permission-modes=repository
__CONF__
echo 'Greeting Earthlings' >'README'
run_fail "${TEST_KEY}" svn import --no-auth-cache -q -m 'greet: new project' \
    'README' "${REPOS_URL}/greet/trunk/README"
TXN=$(<'txn')
date2datefmt "${REPOS_PATH}/log/pre-commit.log" >"${TEST_KEY}.pre-commit.log"
file_cmp "${TEST_KEY}.pre-commit.log" "${TEST_KEY}.pre-commit.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ ${TXN} by ${USER}
A   greet/
A   greet/trunk/
A   greet/trunk/README
PERMISSION DENIED: A   greet/
PERMISSION DENIED: A   greet/trunk/
PERMISSION DENIED: A   greet/trunk/README
__LOG__

# Create, good
test_tidy
TEST_KEY="${TEST_KEY_BASE}-project-create-on-perm-mode-eq-branch"
cat >"${REPOS_PATH}/hooks/commit.cfg" <<__CONF__
permission-modes=branch
__CONF__
echo 'Greeting Earthlings' >'README'
run_pass "${TEST_KEY}" svn import --no-auth-cache -q -m 'greet: new project' \
    'README' "${REPOS_URL}/greet/trunk/README"
run_fail "${TEST_KEY}.pre-commit.log" test -s "${REPOS_PATH}/log/pre-commit.log"

# Modify, bad
test_tidy
TEST_KEY="${TEST_KEY_BASE}-project-modify-on-perm-mode-eq-repository"
svn co -q "${REPOS_URL}/greet/trunk" 'work'
echo 'Greeting Earthlings!' >'work/README'
cat >"${REPOS_PATH}/hooks/commit.cfg" <<__CONF__
owner=nosuchuser
permission-modes=repository
__CONF__
run_fail "${TEST_KEY}" svn commit --no-auth-cache -q -m "${TEST_KEY}" 'work'
TXN=$(<'txn')
date2datefmt "${REPOS_PATH}/log/pre-commit.log" >"${TEST_KEY}.pre-commit.log"
file_cmp "${TEST_KEY}.pre-commit.log" "${TEST_KEY}.pre-commit.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ ${TXN} by ${USER}
U   greet/trunk/README
PERMISSION DENIED: U   greet/trunk/README
__LOG__

# Modify, good
test_tidy
TEST_KEY="${TEST_KEY_BASE}-project-modify-on-perm-mode-eq-branch"
svn co -q "${REPOS_URL}/greet/trunk" 'work'
echo 'Greeting Earthlings!' >'work/README'
cat >"${REPOS_PATH}/hooks/commit.cfg" <<__CONF__
permission-modes=branch
__CONF__
run_pass "${TEST_KEY}" svn commit --no-auth-cache -q -m "${TEST_KEY}" 'work'
run_fail "${TEST_KEY}.pre-commit.log" test -s "${REPOS_PATH}/log/pre-commit.log"

# Delete, bad
test_tidy
TEST_KEY="${TEST_KEY_BASE}-project-delete-on-perm-mode-eq-repository"
cat >"${REPOS_PATH}/hooks/commit.cfg" <<__CONF__
owner=nosuchuser
permission-modes=repository
__CONF__
run_fail "${TEST_KEY}" \
    svn delete --no-auth-cache -q -m "${TEST_KEY}" "${REPOS_URL}/greet"
TXN=$(<'txn')
date2datefmt "${REPOS_PATH}/log/pre-commit.log" >"${TEST_KEY}.pre-commit.log"
file_cmp "${TEST_KEY}.pre-commit.log" "${TEST_KEY}.pre-commit.log" <<__LOG__
YYYY-mm-ddTHH:MM:SSZ+ ${TXN} by ${USER}
D   greet/
PERMISSION DENIED: D   greet/
__LOG__

# Delete, good
test_tidy
TEST_KEY="${TEST_KEY_BASE}-project-delete-on-perm-mode-eq-branch"
cat >"${REPOS_PATH}/hooks/commit.cfg" <<__CONF__
permission-modes=branch
__CONF__
run_pass "${TEST_KEY}" \
    svn delete --no-auth-cache -q -m "${TEST_KEY}" "${REPOS_URL}/greet"
run_fail "${TEST_KEY}.pre-commit.log" test -s "${REPOS_PATH}/log/pre-commit.log"
#-------------------------------------------------------------------------------
exit
