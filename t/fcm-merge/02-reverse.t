#!/bin/bash
# ------------------------------------------------------------------------------
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
# ------------------------------------------------------------------------------
# Basic tests for "fcm merge --reverse".
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"
tests 13

svnadmin create 'foo'
URL_FOO="file://${PWD}/foo"
svn mkdir -q -m"season greetings" --no-auth-cache "${URL_FOO}/greet"
echo 'Merry Xmas' >'xmas.txt'
echo 'Happy New Year' >'new-year.txt'
for NAME in 'xmas.txt' 'new-year.txt'; do
    svn import -q -m"import ${NAME}" --no-auth-cache \
        "${NAME}" "${URL_FOO}/greet/${NAME}"
done
svn mkdir -q -m"hello world" --no-auth-cache --parents "${URL_FOO}/hello/trunk"
svn co -q "${URL_FOO}/hello/trunk" 'hello-wc'
cat >'hello-wc/world.txt' <<'__TXT__'
Hello Mercury!
Hello Venus!
Hollow Earth!
Hello Mars!
__TXT__
svn add -q 'hello-wc/world.txt'
svn ci -q -m'hollow worlds' --no-auth-cache 'hello-wc'
cat >'hello-wc/world.txt' <<'__TXT__'
Hello Mercury!
Hello Venus!
Hello Earth!
Hello Mars!
__TXT__
svn ci -q -m'hello worlds' --no-auth-cache 'hello-wc'
rm -fr 'hello-wc'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-r3"
svn co -q "${URL_FOO}/greet" 'greet-wc'
cd 'greet-wc'
run_pass "${TEST_KEY}" fcm merge --reverse --non-interactive
cd ..
svn status 'greet-wc' >"${TEST_KEY}.status"
file_cmp "${TEST_KEY}.status" "${TEST_KEY}.status" <<'__STATUS__'
D       greet-wc/new-year.txt
__STATUS__
file_cmp "${TEST_KEY}.message" 'greet-wc/#commit_message#' <<'__MESSAGE__'
--FCM message (will be inserted automatically)--
Reversed r3 of /greet

__MESSAGE__
rm -rf 'greet-wc'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-r2"
svn co -q "${URL_FOO}/greet" 'greet-wc'
cd 'greet-wc'
run_pass "${TEST_KEY}" fcm merge --reverse -r 2 --non-interactive
cd ..

svn status 'greet-wc' >"${TEST_KEY}.status"
file_cmp "${TEST_KEY}.status" "${TEST_KEY}.status" <<'__STATUS__'
D       greet-wc/xmas.txt
__STATUS__
file_cmp "${TEST_KEY}.message" 'greet-wc/#commit_message#' <<'__MESSAGE__'
--FCM message (will be inserted automatically)--
Reversed r2 of /greet

__MESSAGE__
rm -rf 'greet-wc'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-r2-r3"
svn co -q "${URL_FOO}/greet" 'greet-wc'
cd 'greet-wc'
run_pass "${TEST_KEY}" fcm merge --reverse -r 3:1 --non-interactive
cd ..

svn status 'greet-wc' | sort >"${TEST_KEY}.status"
file_cmp "${TEST_KEY}.status" "${TEST_KEY}.status" <<'__STATUS__'
D       greet-wc/new-year.txt
D       greet-wc/xmas.txt
__STATUS__
file_cmp "${TEST_KEY}.message" 'greet-wc/#commit_message#' <<'__MESSAGE__'
--FCM message (will be inserted automatically)--
Reversed r3:1 of /greet

__MESSAGE__
rm -rf 'greet-wc'
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-r6"
svn co -q "${URL_FOO}/hello/trunk" 'hello-wc'
cd 'hello-wc'
run_pass "${TEST_KEY}" fcm merge --reverse --non-interactive
cd ..
svn status 'hello-wc' >"${TEST_KEY}.status"
file_cmp "${TEST_KEY}.status" "${TEST_KEY}.status" <<'__STATUS__'
M       hello-wc/world.txt
__STATUS__
svn diff 'hello-wc' >"${TEST_KEY}.diff"
file_cmp "${TEST_KEY}.diff" "${TEST_KEY}.diff" <<'__DIFF__'
Index: hello-wc/world.txt
===================================================================
--- hello-wc/world.txt	(revision 6)
+++ hello-wc/world.txt	(working copy)
@@ -1,4 +1,4 @@
 Hello Mercury!
 Hello Venus!
-Hello Earth!
+Hollow Earth!
 Hello Mars!
__DIFF__
file_cmp "${TEST_KEY}.message" 'hello-wc/#commit_message#' <<'__MESSAGE__'
--FCM message (will be inserted automatically)--
Reversed r6 of /hello/trunk

__MESSAGE__
rm -rf 'hello-wc'
#-------------------------------------------------------------------------------
exit
