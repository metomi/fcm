#!/bin/bash
# ------------------------------------------------------------------------------
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
# ------------------------------------------------------------------------------
# Test "fcm branch-delete" with bad argument and in a working copy.
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
tests 3
#-------------------------------------------------------------------------------
# Tests fcm branch-delete with bad argument, and in a working copy
TEST_KEY="${TEST_KEY_BASE}"
setup
init_repos
init_branch 'branch_test' "${REPOS_URL}"
init_branch_wc 'my_branch_test' "${REPOS_URL}"
cd "${TEST_DIR}/wc"
run_fail "${TEST_KEY}" fcm branch-delete --non-interactive 'dark-matter'
file_cmp "${TEST_DIR}/${TEST_KEY}.out" "${TEST_KEY}.out" </dev/null
file_cmp "${TEST_DIR}/${TEST_KEY}.err" "${TEST_KEY}.err" <<'__ERR__'
[FAIL] dark-matter: not a valid working copy or URL.

__ERR__
teardown
#-------------------------------------------------------------------------------
exit
