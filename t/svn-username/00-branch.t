#!/bin/bash
# ------------------------------------------------------------------------------
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
# ------------------------------------------------------------------------------
# Test "fcm branch-create" and "fcm branch-list", alternate username.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
setup
init_repos
cd $TEST_DIR
svn cp -m 't1' --parents -q \
    $ROOT_URL/trunk@1 $ROOT_URL/branches/dev/barn.owl/r1_wing
if ! svnserve -r $TEST_DIR -d --pid-file pid-file; then
    if [[ -s pid-file ]]; then
        kill $(cat pid-file)
    fi
    skip_all 'svnserve failed'
    teardown
    exit
fi
tests 9
#-------------------------------------------------------------------------------
# Tests fcm branch-create, alternate username
TEST_KEY="$TEST_KEY_BASE"
FCM_SUBVERSION_SERVERS_CONF="$PWD/$TEST_KEY-svn-servers-conf"
cat >$FCM_SUBVERSION_SERVERS_CONF <<'__CONF__'
[groups]
bar=localhost

[bar]
username=barn.owl
__CONF__
SVN_EDITOR=true \
FCM_SUBVERSION_SERVERS_CONF=$FCM_SUBVERSION_SERVERS_CONF run_pass "$TEST_KEY" \
    fcm branch-create hello svn://localhost/test_repos <<<'n'
echo >>"$TEST_KEY.out" # Insert newline
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] Source: svn://localhost/test_repos/trunk@1 (4)
[info] true: starting commit message editor...
Change summary:
--------------------------------------------------------------------------------
A    svn://localhost/test_repos/branches/dev/barn.owl/r1_hello
--------------------------------------------------------------------------------
Commit message is as follows:
--------------------------------------------------------------------------------
Created /branches/dev/barn.owl/r1_hello from /trunk@1.
--------------------------------------------------------------------------------
Create the branch?
Enter "y" or "n" (or just press <return> for "n") 
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-1
FCM_SUBVERSION_SERVERS_CONF="$PWD/$TEST_KEY-svn-servers-conf"
cat >$FCM_SUBVERSION_SERVERS_CONF <<'__CONF__'
[groups]
bar=localhost

[bar]
username=barn.owl
__CONF__
FCM_SUBVERSION_SERVERS_CONF=$FCM_SUBVERSION_SERVERS_CONF run_pass "$TEST_KEY" \
    fcm branch-list svn://localhost/test_repos
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<'__OUT__'
[info] svn://localhost/test_repos@4: 1 match(es)
svn://localhost/test_repos/branches/dev/barn.owl/r1_wing@4
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
TEST_KEY=$TEST_KEY_BASE-0
cat >$FCM_SUBVERSION_SERVERS_CONF <<'__CONF__'
[groups]
bar=localhost

[bar]
username=honey.bee
__CONF__
FCM_SUBVERSION_SERVERS_CONF=$FCM_SUBVERSION_SERVERS_CONF run_pass "$TEST_KEY" \
    fcm branch-list svn://localhost/test_repos
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<'__OUT__'
[info] svn://localhost/test_repos@4: 0 match(es)
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
kill $(cat pid-file)
teardown
exit
