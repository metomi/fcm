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
# Tests for "fcm make", "extract", location reset.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
N_TESTS=21
tests $N_TESTS
#-------------------------------------------------------------------------------
svnadmin create repos
T_REPOS=file://$PWD/repos
mkdir t
echo "Hello World" >t/hello.txt
echo "Hi World" >t/hi.txt
svn import -q -m'Test' t/hello.txt $T_REPOS/trunk/hello.txt
svn import -q -m'Test' t $T_REPOS/branch
rm t/hello.txt t/hi.txt
rmdir t
#-------------------------------------------------------------------------------
cat >fcm-make.cfg.0 <<__FCM_MAKE_CFG__
steps=extract
extract.ns=t
extract.location{primary}[t]=$T_REPOS
__FCM_MAKE_CFG__
#-------------------------------------------------------------------------------
base_tests() {
    local HEAD=${1:-2}
    run_pass "$TEST_KEY" fcm make --new
    find extract -type f >"$TEST_KEY.find"
    file_cmp "$TEST_KEY.find" "$TEST_KEY.find" <<<'extract/t/hello.txt'
    sed '/^\[info\] location     t: /!d; s/^\[info\] location     t: //' \
        .fcm-make/log > "$TEST_KEY.log"
    file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
0: $T_REPOS/trunk@$HEAD (1)
__LOG__
}
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-primary"
{
    cat fcm-make.cfg.0
    echo "extract.location{primary}[t]="
    echo "extract.location[t]=$T_REPOS/trunk"
} >fcm-make.cfg
base_tests
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-base-0"
{
    cat fcm-make.cfg.0
    echo "extract.location[t]="
} >fcm-make.cfg
base_tests
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-base"
{
    cat fcm-make.cfg.0
    echo "extract.location[t]=$T_REPOS/trunk"
    echo "extract.location[t]="
} >fcm-make.cfg
base_tests
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-base-with-diff"
{
    cat fcm-make.cfg.0
    echo "extract.location[t]=$T_REPOS/trunk"
    echo "extract.location{diff}[t]=$T_REPOS/branch"
    echo "extract.location[t]="
} >fcm-make.cfg
run_pass "$TEST_KEY" fcm make --new
find extract -type f | sort >"$TEST_KEY.find"
file_cmp "$TEST_KEY.find" "$TEST_KEY.find" <<'__FIND__'
extract/t/hello.txt
extract/t/hi.txt
__FIND__
sed '/^\[info\] location     t: /!d; s/^\[info\] location     t: //' \
    .fcm-make/log > "$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
0: $T_REPOS/trunk@2 (1)
1: $T_REPOS/branch@2 (2)
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-diff-0"
{
    cat fcm-make.cfg.0
    echo "extract.location{diff}[t]="
} >fcm-make.cfg
base_tests
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-diff"
{
    cat fcm-make.cfg.0
    echo "extract.location{diff}[t]=$T_REPOS/branch"
    echo "extract.location{diff}[t]="
} >fcm-make.cfg
base_tests
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-diff-with-base"
{
    cat fcm-make.cfg.0
    echo "extract.location{diff}[t]=$T_REPOS/branch"
    echo "extract.location[t]=$T_REPOS/trunk"
    echo "extract.location{diff}[t]="
} >fcm-make.cfg
base_tests
#-------------------------------------------------------------------------------
exit 0
