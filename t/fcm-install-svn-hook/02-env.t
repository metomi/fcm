#!/bin/bash
#-------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-17 Met Office.
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
# Test "fcm-install-svn-hook", "hooks-env" installation.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
. $TEST_SOURCE_DIR/test_header_more
#-------------------------------------------------------------------------------
if ! which svnadmin 1>/dev/null 2>/dev/null; then
    skip_all 'svnadmin not available'
fi
tests 2
FCM_REAL_HOME=$(readlink -f "$FCM_HOME")
mkdir conf svn-repos
export FCM_CONF_PATH="$PWD/conf"
cat >conf/admin.cfg <<__CONF__
admin_email=robert.fitzroy@metoffice.gov.uk
notification_from=notifications@localhost
svn_dump_dir=$PWD/svn/dumps
svn_group=
svn_hook_path_env=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
svn_live_dir=$PWD/svn-repos
svn_project_suffix=.svn
trac_live_dir=$PWD/trac
__CONF__
svnadmin create svn-repos/foo.svn
cat >hooks-env <<__CONF__
[default]
FCM_HOME=$FCM_REAL_HOME
FCM_SVN_HOOK_ADMIN_EMAIL=robert.fitzroy@metoffice.gov.uk
FCM_SVN_HOOK_COMMIT_DUMP_DIR=$PWD/svn/dumps
FCM_SVN_HOOK_NOTIFICATION_FROM=notifications@localhost
FCM_SVN_HOOK_REPOS_SUFFIX=.svn
FCM_SVN_HOOK_TRAC_ROOT_DIR=$PWD/trac
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
TZ=UTC
__CONF__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
run_pass "$TEST_KEY" "$FCM_HOME/sbin/fcm-install-svn-hook"
file_cmp "$TEST_KEY.foo.hooks-env" svn-repos/foo.svn/conf/hooks-env hooks-env
#-------------------------------------------------------------------------------
exit
