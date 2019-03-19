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
# Basic tests for "fcm-recover-svn-repos".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
if ! which svnadmin 1>/dev/null 2>/dev/null; then
    skip_all 'svnadmin not available'
fi
tests 26
#-------------------------------------------------------------------------------
set -e
mkdir -p etc srv/svn var/svn/{backups,cache,dumps}
# Configuration
export FCM_CONF_PATH="$PWD/etc"
cat >etc/admin.cfg <<__CONF__
svn_backup_dir=$PWD/var/svn/backups
svn_dump_dir=$PWD/var/svn/dumps
svn_group=
svn_live_dir=$PWD/srv/svn
__CONF__
# Create some repositories and populate them
# Repository 1
svnadmin create srv/svn/bar
svn co -q file://$PWD/srv/svn/bar
echo 'Barley drink.' >bar/barley
svn add -q bar/*
svn ci -q -m'test 1' bar
svnadmin hotcopy srv/svn/bar var/svn/backups/bar
tar -C var/svn/backups -czf $PWD/var/svn/backups/bar.tgz bar
svnadmin dump srv/svn/bar -r 1 --incremental --deltas -q \
        | gzip >var/svn/dumps/bar-1.gz
# Repository 2
svnadmin create srv/svn/foo
svn co -q file://$PWD/srv/svn/foo
echo 'Number of football players = 0' >foo/football
echo 'Food is yummy.' >foo/food
svn add -q foo/*
svn ci -q -m'test 1' foo
svnadmin hotcopy srv/svn/foo var/svn/backups/foo
tar -C var/svn/backups -czf $PWD/var/svn/backups/foo.tgz foo
rm -fr var/svn/backups/foo
echo 'Fool is a clown.' >foo/fool
svn add -q foo/fool
svn ci -q -m'test 2' foo
for I in {1..11}; do
    echo "Number of football players = $I" >foo/football
    svn ci -q -m"incr football player" foo
done
for I in {1..13}; do
    svnadmin dump srv/svn/foo -r $I --incremental --deltas -q \
        | gzip >var/svn/dumps/foo-$I.gz
done
rm -fr bar foo
set +e
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE-live-exists"
run_fail "$TEST_KEY" "$FCM_HOME/sbin/fcm-recover-svn-repos"
file_cmp "$TEST_KEY.out" "$TEST_KEY.out" </dev/null
file_cmp "$TEST_KEY.err" "$TEST_KEY.err" <<__ERR__
$PWD/srv/svn/bar: live repository exists.
__ERR__
#-------------------------------------------------------------------------------
TEST_KEY="$TEST_KEY_BASE"
mv srv/svn/{bar,foo} var/svn/cache
run_pass "$TEST_KEY" "$FCM_HOME/sbin/fcm-recover-svn-repos"
# Check revisions
for NAME in bar foo; do
    svnlook youngest var/svn/cache/$NAME >"$TEST_KEY-youngest-$NAME.exp"
    svnlook youngest srv/svn/$NAME >"$TEST_KEY-youngest-$NAME"
    file_cmp "$TEST_KEY-youngest-$NAME" \
        "$TEST_KEY-youngest-$NAME" "$TEST_KEY-youngest-$NAME.exp"
    for I in $(seq 1 $(<"$TEST_KEY-youngest-$NAME.exp")); do
        svnlook changed -r $I var/svn/cache/$NAME \
            >"$TEST_KEY-changed-$NAME-$I.exp"
        svnlook changed -r $I srv/svn/$NAME >"$TEST_KEY-changed-$NAME-$I"
        file_cmp "$TEST_KEY-changed-$NAME-$I" \
            "$TEST_KEY-changed-$NAME-$I" "$TEST_KEY-changed-$NAME-$I.exp"
    done
    svn export -q file://$PWD/var/svn/cache/$NAME $NAME.orig
    svn export -q file://$PWD/srv/svn/$NAME $NAME
    FILES_ORIG=$(cd $NAME.orig; find -type f)
    FILES=$(cd $NAME; find -type f)
    run_pass "$TEST_KEY-$NAME-n-files" \
        test $(wc -l <<<"$FILES_ORIG") -eq $(wc -l <<<"$FILES")
    for FILE in $FILES_ORIG; do
        file_cmp "$TEST_KEY-cmp-$NAME-$FILE" "$NAME.orig/$FILE" "$NAME/$FILE"
    done
done
#-------------------------------------------------------------------------------
exit
