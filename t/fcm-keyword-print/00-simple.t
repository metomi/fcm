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
# Basic tests for "fcm keyword-print".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
svnadmin create plants
URL="file://$PWD/plants"
svn mkdir --parents -q -m 'test' $URL/{daisy,ivy,holly}/trunk
mkdir -p conf
cat >conf/keyword.cfg <<__CFG__
location{primary}[daisy]=$URL/daisy/
location{primary}[ivy]=$URL/ivy//
location{primary}[holly]=$URL/holly
__CFG__
export FCM_CONF_PATH=$PWD/conf
#-------------------------------------------------------------------------------
tests 21
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE" # no argument
run_pass "$TEST_KEY" fcm kp
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
location{primary}[daisy] = $URL/daisy
location{primary}[holly] = $URL/holly
location{primary}[ivy] = $URL/ivy
__OUT__
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
#-------------------------------------------------------------------------------
for NS in daisy ivy holly; do
    TEST_KEY="$TEST_KEY_BASE-$NS" # normal mode
    run_pass "$TEST_KEY" fcm kp fcm:$NS
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
location{primary}[$NS] = $URL/$NS
__OUT__
    file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null

    TEST_KEY="$TEST_KEY_BASE-v-$NS" # verbose mode
    run_pass "$TEST_KEY" fcm kp -v fcm:$NS
    file_cmp "$TEST_KEY.out" "$TEST_KEY.out" <<__OUT__
location{primary}[$NS] = $URL/$NS
location[${NS}-br] = $URL/$NS/branches
location[${NS}-tg] = $URL/$NS/tags
location[${NS}-tr] = $URL/$NS/trunk
location[${NS}_br] = $URL/$NS/branches
location[${NS}_tg] = $URL/$NS/tags
location[${NS}_tr] = $URL/$NS/trunk
__OUT__
    file_cmp "$TEST_KEY.err" "$TEST_KEY.err" </dev/null
done
#-------------------------------------------------------------------------------
exit
