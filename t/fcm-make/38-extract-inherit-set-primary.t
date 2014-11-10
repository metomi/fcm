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
# Tests for "fcm make", "extract", location{primary} reset in inheritance.
#-------------------------------------------------------------------------------
. "$(dirname $0)/test_header"
#-------------------------------------------------------------------------------
tests 5
#-------------------------------------------------------------------------------
set -e
svnadmin create 'repos'
T_REPOS="file://${PWD}/repos"
mkdir 't'
echo "Hello World" >'t/hello.txt'
echo "Hi World" >'t/hi.txt'
svn import --no-auth-cache -q -m'Test' \
    't/hello.txt' "${T_REPOS}/trunk/hello.txt"
rm -fr 't'
mkdir 'etc' 'i0' 'i1' 'junk'
export FCM_CONF_PATH="${PWD}/etc"
echo "location{primary}[t]=${T_REPOS}" >"${PWD}/etc/keyword.cfg"
cat >'i0/fcm-make.cfg' <<__FCM_MAKE_CFG__
steps=extract
extract.ns=t
extract.location{primary}[t]=${T_REPOS}
__FCM_MAKE_CFG__
fcm make -q -C 'i0'
set +e
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-reset"
cat >'i1/fcm-make.cfg' <<__FCM_MAKE_CFG__
use=${PWD}/i0
extract.location{primary}[t]=${PWD}/junk
__FCM_MAKE_CFG__
run_fail "${TEST_KEY}" fcm make --new -C 'i1'
file_cmp "${TEST_KEY}.err" "${TEST_KEY}.err" <<__ERR__
[FAIL] extract.location{primary}[t] = ${PWD}/junk: cannot modify, value is inherited
[FAIL] config-file=${PWD}/i1/fcm-make.cfg:1

__ERR__
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-set-identical"
cat >'i1/fcm-make.cfg' <<__FCM_MAKE_CFG__
use=${PWD}/i0
extract.location{primary}[t]=${T_REPOS}
__FCM_MAKE_CFG__
run_pass "${TEST_KEY}" fcm make --new -C 'i1'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-set-same-1"
cat >'i1/fcm-make.cfg' <<__FCM_MAKE_CFG__
use=${PWD}/i0
extract.location{primary}[t]=${T_REPOS}/
__FCM_MAKE_CFG__
run_pass "${TEST_KEY}" fcm make --new -C 'i1'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-set-same-2"
cat >'i1/fcm-make.cfg' <<__FCM_MAKE_CFG__
use=${PWD}/i0
extract.location{primary}[t]=fcm:t
__FCM_MAKE_CFG__
run_pass "${TEST_KEY}" fcm make --new -C 'i1'
#-------------------------------------------------------------------------------
exit 0
