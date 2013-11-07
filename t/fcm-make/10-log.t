#!/bin/bash
#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------
# Basic tests for "fcm make".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 7
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
run_pass "$TEST_KEY" fcm make
if [[ -d $FCM_HOME/.git ]]; then
    VERSION="FCM $(git --git-dir=$FCM_HOME/.git describe)"
else
    VERSION=$(sed '/FCM\.VERSION/!d; s/^.*="\(.*\)";$/\1/' \
        $FCM_HOME/doc/etc/fcm-version.js)
fi
file_grep "$TEST_KEY.log.version" "\\[info\\] $VERSION" .fcm-make/log
file_grep "$TEST_KEY.log.mode" '\[info\] mode=new' .fcm-make/log
if [[ $(ls .fcm-make/log-* | wc -l) == 1 ]]; then
    pass "$TEST_KEY-n-logs"
else
    fail "$TEST_KEY-n-logs"
fi
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-incr"
sleep 1
run_pass "$TEST_KEY" fcm make
file_grep "$TEST_KEY.log.mode" '\[info\] mode=incremental' .fcm-make/log
if [[ $(ls .fcm-make/log-* | wc -l) == 2 ]]; then
    pass "$TEST_KEY-n-logs"
else
    fail "$TEST_KEY-n-logs"
fi
#-------------------------------------------------------------------------------
exit 0
