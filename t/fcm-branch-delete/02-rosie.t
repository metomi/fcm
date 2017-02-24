#!/bin/bash
# ------------------------------------------------------------------------------
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
# ------------------------------------------------------------------------------
# Test "fcm branch-delete" does not produce warnings for rosie branches.
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
tests 3
#-------------------------------------------------------------------------------
# Tests fcm branch-delete with bad argument, and in a working copy
TEST_KEY="${TEST_KEY_BASE}"
setup
init_repos_layout_roses
svn copy -q -m 'create a branch' \
    "${REPOS_URL}/a/a/0/0/0/trunk" "${REPOS_URL}/a/a/0/0/0/my-branch"
run_pass "${TEST_KEY}" \
    fcm branch-delete --non-interactive "${REPOS_URL}/a/a/0/0/0/my-branch"
file_cmp "${TEST_DIR}/${TEST_KEY}.err" "${TEST_KEY}.err" <'/dev/null'
run_pass "${TEST_KEY}.out" \
    grep -q -F "Deleting branch ${REPOS_URL}/a/a/0/0/0/my-branch ..." \
    "../${TEST_KEY}.out"
teardown
#-------------------------------------------------------------------------------
exit
