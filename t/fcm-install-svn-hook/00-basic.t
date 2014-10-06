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
# Basic tests for "fcm-install-svn-hook".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
. $TEST_SOURCE_DIR/test_header_more
#-------------------------------------------------------------------------------
if ! which svnadmin 1>/dev/null 2>/dev/null; then
    skip_all 'svnadmin not available'
fi
tests 149
#-------------------------------------------------------------------------------
FCM_REAL_HOME=$(readlink -f "$FCM_HOME")
TODAY=$(date -u +%Y%m%d)
mkdir -p conf/
export FCM_CONF_PATH="$PWD/conf"
cat >conf/admin.cfg <<__CONF__
svn_group=
svn_live_dir=$PWD/svn-repos
svn_project_suffix=
__CONF__
cat >hooks-env <<__CONF__
[default]
FCM_HOME=$FCM_REAL_HOME
FCM_SVN_HOOK_ADMIN_EMAIL=$USER
FCM_SVN_HOOK_COMMIT_DUMP_DIR=/var/svn/dumps
FCM_SVN_HOOK_TRAC_ROOT_DIR=/srv/trac
TZ=UTC
__CONF__
#-------------------------------------------------------------------------------
# Live directory does not exist
TEST_KEY="$TEST_KEY_BASE-no-live-dir"
run_pass "$TEST_KEY" "$FCM_HOME/sbin/fcm-install-svn-hook"
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" /dev/null
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" /dev/null
#-------------------------------------------------------------------------------
# Project does not exist
TEST_KEY="$TEST_KEY_BASE-no-project"
run_fail "$TEST_KEY" "$FCM_HOME/sbin/fcm-install-svn-hook" foo
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" /dev/null
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" <<'__ERR__'
foo: not found
__ERR__
#-------------------------------------------------------------------------------
# Live directory is empty
TEST_KEY="$TEST_KEY_BASE-empty"
mkdir svn-repos
run_pass "$TEST_KEY" "$FCM_HOME/sbin/fcm-install-svn-hook"
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" /dev/null
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" /dev/null
#-------------------------------------------------------------------------------
run_tests() {
    # Create repository and add content if necessary
    rm -fr svn-repos/foo
    svnadmin create svn-repos/foo
    if [[ -d svn-import ]]; then
        svn import -q -m't' svn-import file://$PWD/svn-repos/foo
    fi
    # Hooks before
    local HOOK_TMPLS=$(ls svn-repos/foo/hooks/*)
    # Install
    run_pass "$TEST_KEY" "$FCM_HOME/sbin/fcm-install-svn-hook" "$@"
    # Hooks env
    file_cmp "$TEST_KEY-hooks-env" svn-repos/foo/conf/hooks-env hooks-env
    # Make sure all hooks are installed
    local FILE=
    for FILE in $(cd "$FCM_HOME/etc/svn-hooks" && ls); do
        file_cmp "$TEST_KEY-$FILE" \
            "$FCM_HOME/etc/svn-hooks/$FILE" "svn-repos/foo/hooks/$FILE"
        file_test "$TEST_KEY-$FILE-chmod" "svn-repos/foo/hooks/$FILE" -x
        file_test "$TEST_KEY-$FILE.log.$TODAY" \
            "svn-repos/foo/log/$FILE.log.$TODAY"
        readlink "svn-repos/foo/log/$FILE.log" >"$TEST_KEY-$FILE.log.link"
        file_cmp "$TEST_KEY-$FILE.log" \
            "$TEST_KEY-$FILE.log.link" <<<"$FILE.log.$TODAY"
    done
    # Hooks after
    if [[ "$@" == *--clean* ]]; then
        run_fail "$TEST_KEY-ls-tmpl" ls $HOOK_TMPLS
    else
        run_pass "$TEST_KEY-ls-tmpl" ls $HOOK_TMPLS
    fi
    # STDOUT and STDERR
    date2datefmt "$TEST_KEY.out" >"$TEST_KEY.out.parsed"
    m4 -DFCM_REAL_HOME=$FCM_REAL_HOME -DPWD=$PWD -DTODAY=$TODAY \
        "$TEST_SOURCE_DIR/$TEST_KEY_BASE/$NAME.out" >"$TEST_KEY.out.exp"
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out.parsed" "$TEST_KEY.out.exp"
    file_cmp "$TEST_KEY.err" "$TEST_KEY.err" /dev/null
    # Run command a second time, should no longer install logs
    run_pass "$TEST_KEY-2" "$FCM_HOME/sbin/fcm-install-svn-hook" "$@"
    date2datefmt "$TEST_KEY-2.out" >"$TEST_KEY-2.out.parsed"
    m4 -DFCM_REAL_HOME=$FCM_REAL_HOME -DPWD=$PWD \
        "$TEST_SOURCE_DIR/$TEST_KEY_BASE/$NAME-2.out" >"$TEST_KEY-2.out.exp"
    file_cmp "$TEST_KEY-2.out" "$TEST_KEY-2.out.parsed" "$TEST_KEY-2.out.exp"
}

# New install, single repository
TEST_KEY="$TEST_KEY_BASE-new"
NAME=new run_tests
TEST_KEY="$TEST_KEY_BASE-new-foo"
NAME=new run_tests foo

# Clean install, single repository
TEST_KEY="$TEST_KEY_BASE-clean"
NAME=clean run_tests --clean
TEST_KEY="$TEST_KEY_BASE-clean-foo"
NAME=clean run_tests --clean foo

# New install, single repository, with svnperms.conf
TEST_KEY="$TEST_KEY_BASE-svnperms.conf"
mkdir -p 'svn-import'
echo '[foo]' >'svn-import/svnperms.conf'
NAME='svnperms-conf' run_tests
file_cmp "$TEST_KEY-ls-svnperms.conf" \
    'svn-repos/foo/hooks/svnperms.conf' 'svn-import/svnperms.conf'

# New install, single repository, with commit.conf
TEST_KEY="$TEST_KEY_BASE-commit.conf"
{
    echo 'notify-branch-owner'
    echo 'verify-branch-owner'
} >'svn-import/commit.conf'
NAME='commit-conf' run_tests
file_cmp "$TEST_KEY-ls-svnperms.conf" \
    'svn-repos/foo/hooks/commit.conf' 'svn-import/commit.conf'
#-------------------------------------------------------------------------------
exit
