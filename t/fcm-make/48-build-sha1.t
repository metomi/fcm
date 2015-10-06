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
# Test "fcm make", build, using SHA1 checksum to determine changes.
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"

get-hello-checksum() {
    PERL5LIB="${FCM_HOME}/lib" perl - <<'__PERL__'
use strict;
use warnings;
use IO::Uncompress::Gunzip qw{gunzip};
use Storable;
gunzip('.fcm-make/ctx.gz', 'ctx');
my $m_ctx = retrieve('ctx');
printf(
    "%s  %s\n",
    $m_ctx->{'ctx_of'}{'build'}{'source_of'}{'hello.f90'}{'checksum'},
    'src/hello.f90',
);
unlink('ctx')
__PERL__
}
#-------------------------------------------------------------------------------
tests 8
cp -r "${TEST_SOURCE_DIR}/${TEST_KEY_BASE}/"* .
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}"
sha1sum 'src/hello.f90' >'hello.f90.sha1sum'
run_pass "${TEST_KEY}" fcm make
run_pass "${TEST_KEY}-sha1sum-check" sha1sum -c - <<<"$(get-hello-checksum)"
HELLO_O_MTIME="$(stat -c '%Y' 'build/o/hello.o')"
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-incr"
run_pass "${TEST_KEY}" fcm make
run_pass "${TEST_KEY}-sha1sum-check" sha1sum -c - <<<"$(get-hello-checksum)"
HELLO_O_MTIME_INCR="$(stat -c '%Y' 'build/o/hello.o')"
run_pass "${TEST_KEY}-mtime-of-hello.o" \
    test "${HELLO_O_MTIME_INCR}" -eq "${HELLO_O_MTIME}"
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}-incr-2"
sed -i 's/Hello/Greet/' 'src/hello.f90'
sha1sum 'src/hello.f90' >'hello.f90.sha1sum'
sleep 1  # In case computer is very fast, when everything can happen within 1s.
run_pass "${TEST_KEY}" fcm make
run_pass "${TEST_KEY}-sha1sum-check" sha1sum -c - <<<"$(get-hello-checksum)"
HELLO_O_MTIME_INCR="$(stat -c '%Y' 'build/o/hello.o')"
run_pass "${TEST_KEY}-mtime-of-hello.o" \
    test "${HELLO_O_MTIME_INCR}" -gt "${HELLO_O_MTIME}"
#-------------------------------------------------------------------------------
exit 0
