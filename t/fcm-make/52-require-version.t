#!/bin/bash
#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------
# Test "require-version" declaration. Note: Some tests will fail if we still
# have FCM releases after the year 9999 and beyond, but I am sure FCM will be
# retired long before that happens!
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
tests 10
#-------------------------------------------------------------------------------
FCM_VERSION="$(fcm --version | cut -d' ' -f 2)"
run_pass "${TEST_KEY_BASE}-min-older" fcm make "require-version=2015"
run_pass "${TEST_KEY_BASE}-min-current" \
    fcm make "require-version=${FCM_VERSION}"
TEST_KEY="${TEST_KEY_BASE}-min-future"
run_fail "${TEST_KEY}" fcm make "require-version=9999.12.0"
sed -i '/require-version/!d' "${TEST_KEY}.err"
file_cmp "${TEST_KEY}.err" "${TEST_KEY}.err" <<__ERR__
[FAIL] require-version = 9999.12.0: requested version mismatch
__ERR__
run_pass "${TEST_KEY_BASE}-min-current-max-current" \
    fcm make "require-version=${FCM_VERSION} ${FCM_VERSION}"
run_pass "${TEST_KEY_BASE}-min-old-max-future" \
    fcm make "require-version=2015 9999"
TEST_KEY="${TEST_KEY_BASE}-min-old-max-old"
run_fail "${TEST_KEY}" fcm make "require-version=2014 2015"
sed -i '/require-version/!d' "${TEST_KEY}.err"
file_cmp "${TEST_KEY}.err" "${TEST_KEY}.err" <<__ERR__
[FAIL] require-version = 2014 2015: requested version mismatch
__ERR__
TEST_KEY="${TEST_KEY_BASE}-min-future-max-future"
run_fail "${TEST_KEY}" fcm make "require-version=9999.01.0 9999.12.0"
sed -i '/require-version/!d' "${TEST_KEY}.err"
file_cmp "${TEST_KEY}.err" "${TEST_KEY}.err" <<__ERR__
[FAIL] require-version = 9999.01.0 9999.12.0: requested version mismatch
__ERR__
exit 0
