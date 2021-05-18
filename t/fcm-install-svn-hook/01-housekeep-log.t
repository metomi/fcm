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
# Tests housekeep hook logs functionalities provided by "fcm-install-svn-hook".
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header
. $TEST_SOURCE_DIR/test_header_more
#-------------------------------------------------------------------------------
if ! which svnadmin 1>/dev/null 2>/dev/null; then
    skip_all 'svnadmin not available'
fi
tests 14
#-------------------------------------------------------------------------------
FCM_REAL_HOME=$(readlink -f "$FCM_HOME")
TODAY=$(date -u +%Y%m%d)
mkdir -p conf/ svn-repos/
export FCM_CONF_PATH="$PWD/conf"
cat >conf/admin.cfg <<__CONF__
svn_group=
svn_live_dir=$PWD/svn-repos
svn_project_suffix=
__CONF__
#-------------------------------------------------------------------------------
# Newly created logs
svnadmin create svn-repos/bar
svnadmin create svn-repos/foo

# 1st run, create logs
KEY="0-cmd0"
TEST_KEY="$TEST_KEY_BASE-$KEY"
run_pass "$TEST_KEY" "$FCM_HOME/sbin/fcm-install-svn-hook"
date2datefmt "$TEST_KEY.out" >"$TEST_KEY.out.parsed"
m4 -DFCM_HOME="$FCM_REAL_HOME" -DPWD="$PWD" -DTODAY="$TODAY" \
    "$TEST_SOURCE_DIR/$TEST_KEY_BASE/$KEY.out" >"$TEST_KEY.out.exp"
diff -u "$TEST_KEY.out.parsed" "$TEST_KEY.out.exp" >&2
file_cmp "$TEST_KEY.out" "$TEST_KEY.out.parsed" "$TEST_KEY.out.exp"

# Add something to logs between runs
for FILE in svn-repos/{foo,bar}/log/*.log; do
    echo "$FILE: time passes, and contents were written to me." >"$FILE"
done
sha1sum svn-repos/{foo,bar}/log/*.log >logs.shalsum
#-------------------------------------------------------------------------------
# 2nd run on same day, should leave logs alone
KEY="0-cmd1"
TEST_KEY="$TEST_KEY_BASE-$KEY"
run_pass "$TEST_KEY" "$FCM_HOME/sbin/fcm-install-svn-hook"
date2datefmt "$TEST_KEY.out" >"$TEST_KEY.out.parsed"
m4 -DFCM_HOME="$FCM_REAL_HOME" -DPWD="$PWD" -DTODAY="$TODAY" \
    "$TEST_SOURCE_DIR/$TEST_KEY_BASE/$KEY.out" >"$TEST_KEY.out.exp"
file_cmp "$TEST_KEY.out" "$TEST_KEY.out.parsed" "$TEST_KEY.out.exp"
# Logs should not be modified
run_pass "$TEST_KEY.sha1sum" sha1sum -c logs.shalsum
#-------------------------------------------------------------------------------
# Pretend that logs were created 3 days ago
TEST_KEY="$TEST_KEY_BASE-3"
DATE_P3D=$(date --date='3 days ago' +%Y%m%d)

# Add something to logs
# Pretend that they were created 3 days ago
for FILE in svn-repos/{foo,bar}/log/*.log; do
    echo "$FILE: time flies in the world of testing." >>"$FILE"
    NAME=$(readlink "$FILE")
    mv "$(dirname $FILE)/$NAME" "$FILE.$DATE_P3D"
    ln -f -s "$(basename $FILE).$DATE_P3D" "$FILE"
done
sha1sum svn-repos/{foo,bar}/log/*.log >logs.shalsum

# Run with logs created 3 days ago
# STDOUT should be identical to "0-cmd1".
run_pass "$TEST_KEY" "$FCM_HOME/sbin/fcm-install-svn-hook"
date2datefmt "$TEST_KEY.out" >"$TEST_KEY.out.parsed"
m4 -DFCM_HOME="$FCM_REAL_HOME" -DPWD="$PWD" -DTODAY="$TODAY" \
    "$TEST_SOURCE_DIR/$TEST_KEY_BASE/0-cmd1.out" >"$TEST_KEY.out.exp"
file_cmp "$TEST_KEY.out" "$TEST_KEY.out.parsed" "$TEST_KEY.out.exp"

# Logs should not be modified
run_pass "$TEST_KEY.sha1sum" sha1sum -c logs.shalsum
#-------------------------------------------------------------------------------
# Pretend that logs were created 7 days ago
TEST_KEY="$TEST_KEY_BASE-7"
DATE_P7D=$(date --date='7 days ago' +%Y%m%d)

# Add something to logs
# Pretend that they were created 7 days ago
for FILE in svn-repos/{foo,bar}/log/*.log; do
    echo "$FILE: time continues to fly in the world of testing." >>"$FILE"
    NAME=$(readlink "$FILE")
    mv "$(dirname $FILE)/$NAME" "$FILE.$DATE_P7D"
    ln -f -s "$(basename $FILE).$DATE_P7D" "$FILE"
done
sha1sum svn-repos/{foo,bar}/log/*.log >logs.shalsum

# Run with logs created 7 days ago, should gzip old logs and create new ones
run_pass "$TEST_KEY" "$FCM_HOME/sbin/fcm-install-svn-hook"
date2datefmt "$TEST_KEY.out" >"$TEST_KEY.out.parsed"
m4 -DFCM_HOME="$FCM_REAL_HOME" -DPWD="$PWD" -DTODAY="$TODAY" \
    -DDATE_P7D="$DATE_P7D" \
    "$TEST_SOURCE_DIR/$TEST_KEY_BASE/7-cmd.out" >"$TEST_KEY.out.exp"
file_cmp "$TEST_KEY.out" "$TEST_KEY.out.parsed" "$TEST_KEY.out.exp"

# Unzip old logs and check that their contents are unchanged
mkdir -p old-logs/svn-repos/{foo,bar}/log
for FILE in svn-repos/{foo,bar}/log/*.log.*.gz; do
    gunzip -c "$FILE" >old-logs/${FILE%.$DATE_P7D.gz}
done
cd old-logs
run_pass "$TEST_KEY.sha1sum" sha1sum -c ../logs.shalsum
cd "$OLDPWD"
#-------------------------------------------------------------------------------
# Pretend that logs were created between 7 to 28 days ago
TEST_KEY="$TEST_KEY_BASE-28"
DATE_P14D=$(date --date='14 days ago' +%Y%m%d)
DATE_P21D=$(date --date='21 days ago' +%Y%m%d)
DATE_P28D=$(date --date='28 days ago' +%Y%m%d)

# Create fake logs
rm -f svn-repos/{foo,bar}/log/*.log*
for FILE in svn-repos/{foo,bar}/log/{pre,post}-commit.log; do
    for DATE in $DATE_P14D $DATE_P21D $DATE_P28D; do
        echo "$FILE $DATE whatever" >"$FILE.$DATE"
        gzip "$FILE.$DATE"
    done
    echo "$FILE $DATE_P7D whatever" >"$FILE.$DATE_P7D"
    ln -s $(basename "$FILE.$DATE_P7D") "$FILE"
done
for FILE in svn-repos/{foo,bar}/log/{pre,post}-revprop-change.log; do
    echo "$FILE $DATE_P7D whatever" >"$FILE.$DATE_P7D"
    ln -s $(basename "$FILE.$DATE_P7D") "$FILE"
done

# Run with logs created 7 to 28 days ago.
# Should remove oldest and empty ones, gzip old ones and create new ones
run_pass "$TEST_KEY" "$FCM_HOME/sbin/fcm-install-svn-hook"
date2datefmt "$TEST_KEY.out" >"$TEST_KEY.out.parsed"
m4 -DFCM_HOME="$FCM_REAL_HOME" -DPWD="$PWD" -DTODAY="$TODAY" \
    -DDATE_P7D="$DATE_P7D" -DDATE_P28D="$DATE_P28D" \
    "$TEST_SOURCE_DIR/$TEST_KEY_BASE/28-cmd.out" >"$TEST_KEY.out.exp"
file_cmp "$TEST_KEY.out" "$TEST_KEY.out.parsed" "$TEST_KEY.out.exp"
ls svn-repos/{foo,bar}/log/*.log* | sort >"$TEST_KEY.ls.out"
file_cmp "$TEST_KEY.ls" "$TEST_KEY.ls.out" <<__LIST__
svn-repos/bar/log/post-commit.log
svn-repos/bar/log/post-commit.log.$DATE_P21D.gz
svn-repos/bar/log/post-commit.log.$DATE_P14D.gz
svn-repos/bar/log/post-commit.log.$DATE_P7D.gz
svn-repos/bar/log/post-commit.log.$TODAY
svn-repos/bar/log/post-revprop-change.log
svn-repos/bar/log/post-revprop-change.log.$DATE_P7D.gz
svn-repos/bar/log/post-revprop-change.log.$TODAY
svn-repos/bar/log/pre-commit.log
svn-repos/bar/log/pre-commit.log.$DATE_P21D.gz
svn-repos/bar/log/pre-commit.log.$DATE_P14D.gz
svn-repos/bar/log/pre-commit.log.$DATE_P7D.gz
svn-repos/bar/log/pre-commit.log.$TODAY
svn-repos/bar/log/pre-revprop-change.log
svn-repos/bar/log/pre-revprop-change.log.$DATE_P7D.gz
svn-repos/bar/log/pre-revprop-change.log.$TODAY
svn-repos/foo/log/post-commit.log
svn-repos/foo/log/post-commit.log.$DATE_P21D.gz
svn-repos/foo/log/post-commit.log.$DATE_P14D.gz
svn-repos/foo/log/post-commit.log.$DATE_P7D.gz
svn-repos/foo/log/post-commit.log.$TODAY
svn-repos/foo/log/post-revprop-change.log
svn-repos/foo/log/post-revprop-change.log.$DATE_P7D.gz
svn-repos/foo/log/post-revprop-change.log.$TODAY
svn-repos/foo/log/pre-commit.log
svn-repos/foo/log/pre-commit.log.$DATE_P21D.gz
svn-repos/foo/log/pre-commit.log.$DATE_P14D.gz
svn-repos/foo/log/pre-commit.log.$DATE_P7D.gz
svn-repos/foo/log/pre-commit.log.$TODAY
svn-repos/foo/log/pre-revprop-change.log
svn-repos/foo/log/pre-revprop-change.log.$DATE_P7D.gz
svn-repos/foo/log/pre-revprop-change.log.$TODAY
__LIST__
#-------------------------------------------------------------------------------
exit
