#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw{no_plan};

main();

sub main {
    my $class = 'Fcm::ExtractConfigComparator';
    use_ok($class);
}

# TODO: more real tests

__END__
