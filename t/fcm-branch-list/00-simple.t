#!/bin/bash
# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-2013 Met Office.
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
# Basic tests for "fcm branch-list".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 23
#-------------------------------------------------------------------------------
setup
init_repos
init_branch sibling_branch_test $REPOS_URL
init_branch_wc branch_test $REPOS_URL
cd $TEST_DIR/wc
fcm branch-create --rev-flag=NONE \
                  --non-interactive \
                  --branch-of-branch my_branch_test >/dev/null
ROOT_PATH=
if [[ -n ${TEST_PROJECT:-} ]]; then
    ROOT_PATH=/$TEST_PROJECT
fi
MESSAGE=$(echo -e "Created $ROOT_PATH/branches/dev/fred/donuts from /trunk@1.")
# Please note: if $LOGNAME is drfooeybar or Share, some tests will fail.
svn mkdir -q -m "Dr Fooeybar branch" $ROOT_URL/branches/dev/drfooeybar/
svn copy -q -r1 $ROOT_URL/trunk $ROOT_URL/branches/dev/drfooeybar/donuts \
            -m "Made a branch $MESSAGE" --non-interactive
FILE_LIST=$(find . -type f | sed "/\.svn/d" | sort | head -5)
for FILE in $FILE_LIST; do 
    sed -i "s/for/FOR/g; s/fi/end if/g; s/in/IN/g;" $FILE
    sed -i "/#/d; /^ *!/d" $FILE
    sed -i "s/!/!!/g; s/q/\nq/g; s/[(]/(\n/g" $FILE
done
svn commit -q -m "add branch commit"
svn update -q
svn switch -q $ROOT_URL/branches/dev/Share/branch_test
#-------------------------------------------------------------------------------
# Tests fcm branch-list
TEST_KEY=$TEST_KEY_BASE-list
run_pass "$TEST_KEY" fcm branch-list
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] $ROOT_URL@9: 1 match(es)
$ROOT_URL/branches/dev/$LOGNAME/my_branch_test@9
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm branch-list -a
TEST_KEY=$TEST_KEY_BASE-a
run_pass "$TEST_KEY" fcm branch-list -a
sed -i "/ Date/d;" $TEST_DIR/$TEST_KEY.out
TMPFILE=$(mktemp)
sort > $TMPFILE <<__OUT__
[info] $ROOT_URL@9: 4 match(es)
$ROOT_URL/branches/dev/Share/branch_test@9
$ROOT_URL/branches/dev/Share/sibling_branch_test@9
$ROOT_URL/branches/dev/$LOGNAME/my_branch_test@9
$ROOT_URL/branches/dev/drfooeybar/donuts@9
__OUT__
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <$TMPFILE
rm -f $TMPFILE
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm branch-list --user
TEST_KEY=$TEST_KEY_BASE-a
run_pass "$TEST_KEY" fcm branch-list --user=drfooeybar
sed -i "/ Date/d;" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] $ROOT_URL@9: 1 match(es)
$ROOT_URL/branches/dev/drfooeybar/donuts@9
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm branch-list --only (1)
TEST_KEY=$TEST_KEY_BASE-only-1
run_pass "$TEST_KEY" fcm branch-list --only=3:donut
sed -i "/ Date/d;" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] $ROOT_URL@9: 1 match(es)
$ROOT_URL/branches/dev/drfooeybar/donuts@9
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm branch-list --only (2)
TEST_KEY=$TEST_KEY_BASE-only-2
run_pass "$TEST_KEY" fcm branch-list --only=2:Share
sed -i "/ Date/d;" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] $ROOT_URL@9: 2 match(es)
$ROOT_URL/branches/dev/Share/branch_test@9
$ROOT_URL/branches/dev/Share/sibling_branch_test@9
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm branch-list --only (3)
TEST_KEY=$TEST_KEY_BASE-only-3
run_pass "$TEST_KEY" fcm branch-list --only=2:Share --only=3:sibling
sed -i "/ Date/d;" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] $ROOT_URL@9: 1 match(es)
$ROOT_URL/branches/dev/Share/sibling_branch_test@9
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm branch-list --only (4)
TEST_KEY=$TEST_KEY_BASE-only-4
run_pass "$TEST_KEY" fcm branch-list --only=1:something-not-right
sed -i "/ Date/d;" $TEST_DIR/$TEST_KEY.out
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
[info] $ROOT_URL@9: 0 match(es)
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
# Tests fcm branch-list --only (5)
TEST_KEY=$TEST_KEY_BASE-only-5
run_fail "$TEST_KEY" fcm branch-list --only=1:\)
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" </dev/null
teardown
#-------------------------------------------------------------------------------
