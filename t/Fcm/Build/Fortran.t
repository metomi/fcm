#!/usr/bin/perl
# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-2013 Met Office.
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

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../../lib";

use Test::More (tests => 3);

if (!caller()) {
    main(@ARGV);
}

sub main {
    my $CLASS = 'Fcm::Build::Fortran';
    use_ok($CLASS);
    my $util = $CLASS->new();
    isa_ok($util, $CLASS);
    test_extract_interface($util);
}

sub test_extract_interface {
    my ($util) = @_;
    my $root = ($0 =~ qr{\A(.+)\.t\z}msx)[0];
    my $f90 = $root . '-extract-interface-source.f90';
    my $f90_interface = $root . '-extract-interface-result.f90';
    open(my($handle_for_source), '<', $f90) || die("$f90: $!");
    my @actual_lines = $util->extract_interface($handle_for_source);
    close($handle_for_source);
    open(my($handle_for_result), '<', $f90_interface)
        || die("$f90_interface: $!");
    my @expected_lines = readline($handle_for_result);
    close($handle_for_result);
    is_deeply(\@actual_lines, \@expected_lines, 'extract_interface');
}

__END__
