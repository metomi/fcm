#!/bin/bash
#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------
# Tests "fcm make", generation of log files.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 12
cp -r $TEST_SOURCE_DIR/$TEST_KEY_BASE/* .
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
run_pass "$TEST_KEY" fcm make
if [[ -d $FCM_HOME/.git ]]; then
    VERSION="FCM $(git --git-dir=$FCM_HOME/.git describe)"
else
    VERSION=$(sed '/FCM\.VERSION/!d; s/^.*="\(.*\)";$/\1/' \
        $FCM_HOME/doc/etc/fcm-version.js)
    VERSION="FCM $VERSION"
fi
file_grep "${TEST_KEY}.log.version" "\\[info\\] ${VERSION}" '.fcm-make/log'
file_grep "${TEST_KEY}.log.mode" '\[info\] mode=new' '.fcm-make/log'
file_grep "${TEST_KEY}.log.description" \
    '\[info\] description=There is nothing like a good test' '.fcm-make/log'
if [[ $(ls .fcm-make/log-* | wc -l) == 1 ]]; then
    pass "$TEST_KEY-n-logs"
else
    fail "$TEST_KEY-n-logs"
fi
run_pass "$TEST_KEY-symlink-1" \
    test "$(readlink 'fcm-make.log')" '=' '.fcm-make/log'
run_pass "$TEST_KEY-symlink-2" \
    test "$(readlink '.fcm-make/log')" \
    '=' "$(cd '.fcm-make'; ls 'log-'* | sort | tail -1)"
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
run_pass "$TEST_KEY-symlink-1" \
    test "$(readlink 'fcm-make.log')" '=' '.fcm-make/log'
run_pass "$TEST_KEY-symlink-2" \
    test "$(readlink '.fcm-make/log')" \
    '=' "$(cd '.fcm-make'; ls 'log-'* | sort | tail -1)"
#-------------------------------------------------------------------------------
exit 0
