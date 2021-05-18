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
# Tests "fcm make", inherit, with context name, back compat.
#-------------------------------------------------------------------------------
. "$(dirname "$0")/test_header"

file_cmp_sorted() {
    sort - >"${1}.expected"
    file_cmp "$1" "${2}" "${1}.expected"
}

find_fcm_make_files() {
    find . "$@" -type f \
        '(' -path '*/build/*' -o \
            -path '*/extract/*' -o \
            -path '*/.fcm-make*/c*' ')' \
        | sort
}

tests 2

#-------------------------------------------------------------------------------
mkdir -p 'hello/src'
cat >'hello/fcm-make.cfg' <<'__CFG__'
steps=build
build.source=$HERE/src
build.target{task}=link
__CFG__
cat >'hello/src/friend.f90' <<'__FORTRAN__'
module friend
character(*), parameter :: name = 'friend'
end module friend
__FORTRAN__
cat >'hello/src/hello.f90' <<'__FORTRAN__'
program hello
use friend, only: name
write(*, '(a,1x,a)') 'Hello', name
end program hello
__FORTRAN__

fcm make -q -C "${PWD}/hello"

# Remove "name" from make ctx to make it look like a make ctx generated from an
# old version of "fcm make".
gunzip "${PWD}/hello/.fcm-make/ctx.gz"
perl - "${PWD}/hello/.fcm-make/ctx" <<'__PERL__'
use Storable qw{nstore retrieve};
my $m_ctx = retrieve($ARGV[0]);
delete $m_ctx->{'name'};
nstore($m_ctx, $ARGV[0]);
__PERL__
gzip "${PWD}/hello/.fcm-make/ctx"
#-------------------------------------------------------------------------------
mkdir -p 'greet/src'
cat >'greet/fcm-make-friend.cfg' <<'__CFG__'
use=$HERE/../hello
name=-friend
steps=build
build.source=$HERE/src
build.target{task}=link
__CFG__
cat >'greet/src/greet.f90' <<'__FORTRAN__'
program greet
use friend, only: name
write(*, '(a,1x,a)') 'Greet', name
end program greet
__FORTRAN__

run_pass "${TEST_KEY_BASE}" fcm make -C "${PWD}/greet" -n '-friend'
(cd 'greet' && find_fcm_make_files) >"${TEST_KEY_BASE}.find"
file_cmp_sorted "${TEST_KEY_BASE}.find" "${TEST_KEY_BASE}.find" <<'__FIND__'
./.fcm-make-friend/config-as-parsed.cfg
./.fcm-make-friend/config-on-success.cfg
./.fcm-make-friend/ctx.gz
./build/bin/greet.exe
./build/bin/hello.exe
./build/o/greet.o
__FIND__
#-------------------------------------------------------------------------------
exit
