#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw{no_plan};

main();

sub main {
    use_ok('Fcm::Util');
    test_tidy_url();
}

################################################################################
# Tests tidy_url
sub test_tidy_url {
    my $prefix = "tidy_url";
    my %RESULT_OF = (
        ''                         => '',
        'foo'                      => 'foo',
        'foo/bar'                  => 'foo/bar',
        'http://foo/bar'           => 'http://foo/bar',
        'http://foo/bar@1234'      => 'http://foo/bar@1234',
        'http://foo/bar/@1234'     => 'http://foo/bar@1234',
        'http://foo/bar/.'         => 'http://foo/bar',
        'http://foo/bar/.@1234'    => 'http://foo/bar@1234',
        'http://foo/bar/./@1234'   => 'http://foo/bar@1234',
        'http://foo/bar/./baz'     => 'http://foo/bar/baz',
        'http://foo/bar/..'        => 'http://foo',
        'http://foo/bar/..@1234'   => 'http://foo@1234',
        'http://foo/bar/../@1234'  => 'http://foo@1234',
        'http://foo/bar/../baz'    => 'http://foo/baz',
        'http://foo/bar/../.'      => 'http://foo',
        'http://foo/bar/baz/../..' => 'http://foo',
    );
    for my $key (sort keys(%RESULT_OF)) {
        is(tidy_url($key), $RESULT_OF{$key}, "$prefix: $key");
    }
}

# TODO: more unit tests

__END__
