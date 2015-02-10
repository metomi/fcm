#!/bin/bash
#-------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-15 Met Office.
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
# Tests "fcm make", bad arguments.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
tests 4
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
run_fail "$TEST_KEY" fcm make 'foo'
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" <<'__ERROR__'
[FAIL] arg 0 (foo): invalid config declaration

__ERROR__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-cfg"
run_fail "$TEST_KEY" fcm make 'foo.cfg'
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" <<'__ERROR__'
[FAIL] arg 0 (foo.cfg): invalid config declaration
[FAIL] did you mean "-f foo.cfg"?

__ERROR__
#-------------------------------------------------------------------------------
exit 0
