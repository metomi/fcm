#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw{no_plan};

main();

sub main {
    my $class = 'Fcm::Interactive::InputGetter::CLI';
    use_ok($class);
    test_constructor($class);
}

################################################################################
# Tests usage of constructor
sub test_constructor {
    my ($class) = @_;
    my $prefix = 'constructor';
    my $input_getter = $class->new({});
    isa_ok($input_getter, $class);
}

# TODO: tests the invoke method

__END__
