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
# Test "fcm make", build.target{category} and build.target{task} with namespace.
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
#-------------------------------------------------------------------------------
tests 12
mkdir 'i0'
cp -r "${TEST_SOURCE_DIR}/${TEST_KEY_BASE}/"* 'i0'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}"
run_pass "${TEST_KEY}" fcm make -C 'i0'

grep -F 'build.target{category}' 'i0/.fcm-make/config-on-success.cfg' \
    >'edited-config-on-success.cfg'
file_cmp "${TEST_KEY}-edited-config-on-success.cfg" \
    'edited-config-on-success.cfg' <<'__CFG__'
build.target{category}[hello] = bin
__CFG__

find 'i0/build' -type f | sort >'find-i0-build.out'
file_cmp "${TEST_KEY}-find-i0-build.out" 'find-i0-build.out' <<'__FIND__'
i0/build/bin/hello
i0/build/o/hello.o
__FIND__

"${PWD}/i0/build/bin/hello" <<<'&world_nl /' >'hello.out'
file_cmp "${TEST_KEY}-hello.out" 'hello.out' <<<'Hello World'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-inherit"
run_pass "${TEST_KEY}" fcm make -C 'i1' \
    "use=${PWD}/i0" \
    'build.target{category}[greet] = etc'

grep -F 'build.target{category}' 'i1/.fcm-make/config-on-success.cfg' \
    >'edited-config-on-success.cfg'
file_cmp "${TEST_KEY}-edited-config-on-success.cfg" \
    'edited-config-on-success.cfg' <<'__CFG__'
build.target{category}[greet] = etc
build.target{category}[hello] = bin
__CFG__

find 'i1/build' -type f | sort >'find-i1-build.out'
file_cmp "${TEST_KEY}-find-i1-build.out" 'find-i1-build.out' <<'__FIND__'
i1/build/bin/hello
i1/build/etc/greet/.etc
i1/build/etc/greet/world.nl
__FIND__

"${PWD}/i1/build/bin/hello" <'i1/build/etc/greet/world.nl' >'hello.out'
file_cmp "${TEST_KEY}-hello.out" 'hello.out' <<<'Hello Earth'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-inherit-incr"
touch 'before'
run_pass "${TEST_KEY}" fcm make -C 'i1' \
    "use=${PWD}/i0" \
    'build.target{category}[greet] = bin etc'

grep -F 'build.target{category}' 'i1/.fcm-make/config-on-success.cfg' \
    >'edited-config-on-success.cfg'
file_cmp "${TEST_KEY}-edited-config-on-success.cfg" \
    'edited-config-on-success.cfg' <<'__CFG__'
build.target{category}[greet] = bin etc
build.target{category}[hello] = bin
__CFG__

find 'i1/build' -type f -newer 'before' | sort >'find-i1-build.out'
file_cmp "${TEST_KEY}-find-i1-build.out" 'find-i1-build.out' <<'__FIND__'
i1/build/bin/greet
i1/build/o/greet.o
__FIND__

"${PWD}/i1/build/bin/greet" <'i1/build/etc/greet/world.nl' >'greet.out'
file_cmp "${TEST_KEY}-greet.out" 'greet.out' <<<'Greet Earth'
#-------------------------------------------------------------------------------
exit 0
