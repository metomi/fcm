#!/bin/bash
#-------------------------------------------------------------------------------
# Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.
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
# Tests for "fcm make", "extract", location reset and base eq diff cases.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
N_TESTS=34
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
    run_pass "$TEST_KEY" fcm make --new
    find extract -type f >"$TEST_KEY.find"
    file_cmp "$TEST_KEY.find" "$TEST_KEY.find" <<<'extract/t/hello.txt'
    sed '/^\[info\] location     t: /!d; s/^\[info\] location     t: //' \
        .fcm-make/log > "$TEST_KEY.log"
    file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
0: $T_REPOS/trunk@2 (1)
__LOG__
}
#-------------------------------------------------------------------------------
diff_tests() {
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
TEST_KEY="$TEST_KEY_BASE-base-0-with-eq-diff"
{
    cat fcm-make.cfg.0
    echo "extract.location{diff}[t]=$T_REPOS/trunk"
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
TEST_KEY="$TEST_KEY_BASE-base-with-eq-diff"
{
    cat fcm-make.cfg.0
    echo "extract.location[t]=$T_REPOS/trunk"
    echo "extract.location{diff}[t]=$T_REPOS/trunk"
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
diff_tests
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-base-with-1-eq-diff"
{
    cat fcm-make.cfg.0
    echo "extract.location[t]=$T_REPOS/trunk"
    echo "extract.location{diff}[t]=$T_REPOS/trunk $T_REPOS/branch"
    echo "extract.location[t]="
} >fcm-make.cfg
diff_tests
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
TEST_KEY="$TEST_KEY_BASE-inherit-base-eq-my-diff"
mkdir -p i0 i1
cat fcm-make.cfg.0 >i0/fcm-make.cfg
fcm make --new -q -C i0
{
    echo 'use=$HERE/../i0'
    echo "extract.location{diff}[t]=$T_REPOS/trunk"
} >i1/fcm-make.cfg
run_pass "$TEST_KEY" fcm make --new -C i1
sed '/^\[info\] location     t: /!d; s/^\[info\] location     t: //' \
    i1/.fcm-make/log > "$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
0: $T_REPOS/trunk@2 (1)
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-inherit-base-eq-1-of-my-diff"
# N.B. The 3 lines below have been done in the test above.
#      Uncomment them if the above test is removed.
#mkdir -p i0 i1
#cat fcm-make.cfg.0 >i0/fcm-make.cfg
#fcm make --new -q -C i0
{
    echo 'use=$HERE/../i0'
    echo "extract.location{diff}[t]=$T_REPOS/branch $T_REPOS/trunk"
} >i1/fcm-make.cfg
run_pass "$TEST_KEY" fcm make --new -C i1
sed '/^\[info\] location     t: /!d; s/^\[info\] location     t: //' \
    i1/.fcm-make/log > "$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
0: $T_REPOS/trunk@2 (1)
1: $T_REPOS/branch@2 (2)
__LOG__
#-------------------------------------------------------------------------------
exit 0
