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
# Tests for "fcm make", "extract" from SSH location.
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
N_TESTS=6
tests $N_TESTS
#-------------------------------------------------------------------------------
# Get a remote host for testing
T_HOST=
for FILE in $HOME/.metomi/fcm/t.cfg $FCM_HOME/etc/fcm/t.cfg; do
    if [[ ! -f $FILE || ! -r $FILE ]]; then
        continue
    fi
    T_HOST=$(fcm cfg $FILE | sed '/^ *host *=/!d; s/^ *host *= *//' | tail -1)
    if [[ -n $T_HOST ]]; then
        break
    fi
done
if [[ -z $T_HOST ]]; then
    skip $N_TESTS 'fcm/t.cfg: "host" not defined'
    exit 0
fi
#-------------------------------------------------------------------------------
# Create a source tree on the remote host
mkdir -p hello/{greet,hello,hi,.secret}
for NAME in mercury venus earth mars; do
    echo "Greet $NAME" >hello/greet/greet_${NAME}.txt
    echo "Hello $NAME" >hello/hello/hello_${NAME}.txt
    echo "[Alien-speak] $NAME" >hello/.secret/hello_${NAME}.txt
    echo "Hi $NAME" >hello/hi/hi_${NAME}.txt
done
T_HOST_WORK_DIR=$(ssh -oBatchMode=yes $T_HOST mktemp -d)
rsync -a hello $T_HOST:$T_HOST_WORK_DIR
rm -r hello
#-------------------------------------------------------------------------------
# Create a fcm-make.cfg
cat >fcm-make.cfg <<__FCM_MAKE_CFG__
steps=extract
extract.ns=hello
extract.location[hello]=$T_HOST:$T_HOST_WORK_DIR/hello
__FCM_MAKE_CFG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
run_pass "$TEST_KEY" fcm make
grep -e '\[info\] location hello: 0' -e '\[info\] AU hello:0' fcm-make.log \
    >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
[info] location hello: 0: $T_HOST:$T_HOST_WORK_DIR/hello
[info] AU hello:0      hi/hi_mars.txt
[info] AU hello:0      greet/greet_venus.txt
[info] AU hello:0      hello/hello_mercury.txt
[info] AU hello:0      hello/hello_venus.txt
[info] AU hello:0      greet/greet_mars.txt
[info] AU hello:0      hi/hi_mercury.txt
[info] AU hello:0      greet/greet_earth.txt
[info] AU hello:0      greet/greet_mercury.txt
[info] AU hello:0      hi/hi_earth.txt
[info] AU hello:0      hello/hello_earth.txt
[info] AU hello:0      hello/hello_mars.txt
[info] AU hello:0      hi/hi_venus.txt
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-incr0"
run_pass "$TEST_KEY" fcm make
grep -e '\[info\]   dest:' -e '\[info\] source:' fcm-make.log \
    >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
[info]   dest:   12 [U unchanged]
[info] source:   12 [U from base]
__LOG__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-incr1"
echo 'Hello Martians' \
    | ssh -oBatchMode=yes $T_HOST "cat >$T_HOST_WORK_DIR/hello/hello/hello_mars.txt"
run_pass "$TEST_KEY" fcm make
grep \
    -e '\[info\]   dest:' \
    -e '\[info\] source:' \
    -e '\[info\] MU hello:0' \
    fcm-make.log >"$TEST_KEY.log"
file_cmp "$TEST_KEY.log" "$TEST_KEY.log" <<__LOG__
[info] MU hello:0      hello/hello_mars.txt
[info]   dest:    1 [M modified]
[info]   dest:   11 [U unchanged]
[info] source:   12 [U from base]
__LOG__
#-------------------------------------------------------------------------------
ssh -oBatchMode=yes $T_HOST rm -r $T_HOST_WORK_DIR
exit 0
