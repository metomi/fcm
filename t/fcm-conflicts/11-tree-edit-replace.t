#!/bin/bash
# ------------------------------------------------------------------------------
# Copyright (C) British Crown (Met Office) & Contributors.
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
# Tree conflict: local file edit, incoming file replace upon merge
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
#-------------------------------------------------------------------------------
check_svn_version
tests 6
#-------------------------------------------------------------------------------
setup
init_repos
init_branch replace "${REPOS_URL}"
init_branch_wc edit "${REPOS_URL}"
cd "${TEST_DIR}/wc"
svn switch -q "${ROOT_URL}/branches/dev/Share/replace"
HELLO="$(<'pro/hello.pro')"
svn delete -q 'pro/hello.pro'
svn commit -q -m 'Remove local copy of conflict file'
echo 'Replace contents (1)' >'pro/hello.pro'
svn add 'pro/hello.pro'
svn commit -q -m 'Replace local copy of conflict file'
svn switch -q "${ROOT_URL}/branches/dev/Share/edit"
echo 'Merge contents (1)' >>'pro/hello.pro'
svn commit -q -m 'Modified and renamed merge copy of conflict file'
svn update -q
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-leip-y"
fcm merge --non-interactive "${ROOT_URL}/branches/dev/Share/replace" >'/dev/null'
run_pass "${TEST_KEY}" fcm conflicts <<<'y'
sed -i "/^Resolved conflicted state of 'pro\/hello.pro'$/d" \
    ${TEST_DIR}/"${TEST_KEY}.out"
file_cmp_filtered "${TEST_KEY}.out" "${TEST_KEY}.out" <<'__OUT__'
[info] pro/hello.pro: in tree conflict.
Locally: edited.
Externally: replaced.
Answer (y) to keep the file.
Answer (n) to accept the external replace.
Keep the local version?
#IF SVN1.8/9 Enter "y" or "n" (or just press <return> for "n") Resolved conflicted state of 'pro/hello.pro'
#IF SVN1.10 Enter "y" or "n" (or just press <return> for "n") Tree conflict at 'pro/hello.pro' marked as resolved.
__OUT__
file_cmp "${TEST_KEY}.err" "${TEST_KEY}.err" <'/dev/null'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-leip-n"
svn revert -R -q .
rm '#commit_message#'
fcm merge --non-interactive "${ROOT_URL}/branches/dev/Share/replace" >'/dev/null'
run_pass "${TEST_KEY}" fcm conflicts <<<'n'
sed -i "/^Resolved conflicted state of 'pro\/hello.pro'$/d" \
    ${TEST_DIR}/"${TEST_KEY}.out"
file_cmp "${TEST_KEY}.out" "${TEST_KEY}.out" <<'__OUT__'
[info] pro/hello.pro: in tree conflict.
Locally: edited.
Externally: replaced.
Answer (y) to keep the file.
Answer (n) to accept the external replace.
Keep the local version?
Enter "y" or "n" (or just press <return> for "n") D         pro/hello.pro
A         pro/hello.pro
__OUT__
file_cmp "${TEST_KEY}.err" "${TEST_KEY}.err" <'/dev/null'
#-------------------------------------------------------------------------------
exit
