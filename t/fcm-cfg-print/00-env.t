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
# Configuration file load and dump. Test environment variable substitution
# issues.
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
tests 15

echo 'include=$FCM_WHATEVER' >'foo.cfg'
echo >'bar.cfg'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-undef"
run_fail "${TEST_KEY}" fcm 'cfg-print' 'foo.cfg'
file_cmp "${TEST_KEY}.out" "${TEST_KEY}.out" <'/dev/null'
file_cmp "${TEST_KEY}.err" "${TEST_KEY}.err" <<__ERR__
[FAIL] ${PWD}/foo.cfg:1: reference to undefined variable
[FAIL] include = 
[FAIL] undef(\$FCM_WHATEVER)

__ERR__
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-null"
FCM_WHATEVER= run_pass "${TEST_KEY}" fcm 'cfg-print' 'foo.cfg'
file_cmp "${TEST_KEY}.out" "${TEST_KEY}.out" <'/dev/null'
file_cmp "${TEST_KEY}.err" "${TEST_KEY}.err" <'/dev/null'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-bad-0"
FCM_WHATEVER='0' run_fail "${TEST_KEY}" fcm 'cfg-print' 'foo.cfg'
file_cmp "${TEST_KEY}.out" "${TEST_KEY}.out" <'/dev/null'
file_cmp "${TEST_KEY}.err" "${TEST_KEY}.err" <<__ERR__
[FAIL] config-file=${PWD}/foo.cfg:1
[FAIL] ${PWD}/foo.cfg: cannot load config file
[FAIL] include=0

__ERR__
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-bad"
FCM_WHATEVER='bad.cfg' run_fail "${TEST_KEY}" fcm 'cfg-print' 'foo.cfg'
file_cmp "${TEST_KEY}.out" "${TEST_KEY}.out" <'/dev/null'
file_cmp "${TEST_KEY}.err" "${TEST_KEY}.err" <<__ERR__
[FAIL] config-file=${PWD}/foo.cfg:1
[FAIL] ${PWD}/foo.cfg: cannot load config file
[FAIL] include=bad.cfg

__ERR__
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-good"
FCM_WHATEVER='bar.cfg' run_pass "${TEST_KEY}" fcm 'cfg-print' 'foo.cfg'
file_cmp "${TEST_KEY}.out" "${TEST_KEY}.out" <'/dev/null'
file_cmp "${TEST_KEY}.err" "${TEST_KEY}.err" <'/dev/null'
#-------------------------------------------------------------------------------
exit 0
