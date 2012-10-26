#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw{no_plan};

main();

sub main {
    my $class = 'Fcm::Interactive::InputGetter::GUI';
    use_ok($class);
    test_constructor($class);
}

################################################################################
# Tests usage of constructor
sub test_constructor {
    my ($class) = @_;
    my $prefix = 'constructor';
    my $input_getter = $class->new({
        title   => 'title-value',
        message => 'message-value',
        type    => 'type-value',
        default => 'default-value',
        geometry => 'geometry-value',
    });
    isa_ok($input_getter, $class);
    is($input_getter->get_geometry(), 'geometry-value', "$prefix: geometry");
}

# TODO: tests the invoke method

__END__
