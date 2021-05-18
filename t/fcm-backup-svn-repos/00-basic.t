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
# Basic tests for "fcm-backup-svn-repos".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
#-------------------------------------------------------------------------------
if ! which svnadmin 1>/dev/null 2>/dev/null; then
    skip_all 'svnadmin not available'
fi
tests 32
#-------------------------------------------------------------------------------
set -e
mkdir -p etc srv/svn var/svn/{backups,cache,dumps}
# Configuration
export FCM_CONF_PATH="$PWD/etc"
cat >etc/admin.cfg <<__CONF__
svn_backup_dir=$PWD/var/svn/backups
svn_dump_dir=$PWD/var/svn/dumps
svn_live_dir=$PWD/srv/svn
__CONF__
# Create some repositories and populate them
# Repository 1
svnadmin create srv/svn/bar
svn co -q file://$PWD/srv/svn/bar
echo 'A man walks into a bar.' >bar/walk
echo 'Barley drink.' >bar/barley
svn add -q bar/*
svn ci -q -m'test 1' bar
svnadmin dump srv/svn/bar -r 1 --incremental --deltas -q \
        | gzip >var/svn/dumps/bar-1.gz
# Repository 2
svnadmin create srv/svn/foo
svn co -q file://$PWD/srv/svn/foo
echo 'Food is yummy.' >foo/food
svn add -q foo/*
svn ci -q -m'test 1' foo
svnadmin dump srv/svn/foo -r 1 --incremental --deltas -q \
    | gzip >var/svn/dumps/foo-1.gz
rm -fr bar foo
set +e

run_tests() {
    local TEST_KEY=$1
    run_pass "$TEST_KEY" "$FCM_HOME/sbin/fcm-backup-svn-repos"
    for NAME in bar foo; do
        file_test "$TEST_KEY-$NAME" var/svn/backups/$NAME.tgz
        tar -xzf var/svn/backups/$NAME.tgz
        svnlook youngest srv/svn/$NAME >"$TEST_KEY-$NAME.youngest.orig"
        svnlook youngest $NAME >"$TEST_KEY-$NAME.youngest"
        file_cmp "$TEST_KEY-$NAME.youngest" \
            "$TEST_KEY-$NAME.youngest" "$TEST_KEY-$NAME.youngest.orig"
        rm -fr $NAME
        for REV in $(seq 1 $(<"$TEST_KEY-$NAME.youngest")); do
            run_fail "$TEST_KEY-dumps-$NAME-$REV" ls var/svn/dumps/$NAME-$REV.gz
        done
    done
}
#-------------------------------------------------------------------------------
run_tests "$TEST_KEY_BASE-1-1"
run_tests "$TEST_KEY_BASE-1-2" # Re-run test
#-------------------------------------------------------------------------------
# Add more stuffs to repository 1
svn co -q file://$PWD/srv/svn/bar
for REV in {2..9}; do
    echo "$REV men walk into a bar." >bar/walk
    svn ci -m"test: $REV" bar/walk
    svnadmin dump srv/svn/bar -r $REV --incremental --deltas -q \
            | gzip >var/svn/dumps/bar-$REV.gz
done
# Add more stuffs to a copy of repository 1, to generate some more dumps To
# prove that command will not housekeep dumps that are newer than the backed up
# youngest.
svnadmin hotcopy srv/svn/bar var/svn/cache/bar
svn relocate file://$PWD/srv/svn/bar file://$PWD/var/svn/cache/bar bar
for REV in {10..12}; do
    echo "$REV men walk into a bar." >bar/walk
    svn ci -m"test: $REV" bar/walk
    svnadmin dump var/svn/cache/bar -r $REV --incremental --deltas -q \
            | gzip >var/svn/dumps/bar-$REV.gz
done
run_tests "$TEST_KEY_BASE-2-1"
for REV in {10..12}; do
    file_test "$TEST_KEY_BASE-2-1-dumps-bar-$REV" var/svn/dumps/bar-$REV.gz
done
#-------------------------------------------------------------------------------
exit
