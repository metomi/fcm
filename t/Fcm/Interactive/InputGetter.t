#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw{no_plan};

main();

sub main {
    my $class = 'Fcm::Interactive::InputGetter';
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
    });
    isa_ok($input_getter, $class);
    is($input_getter->get_title(), 'title-value', "$prefix: get title");
    is($input_getter->get_message(), 'message-value', "$prefix: get message");
    is($input_getter->get_type(), 'type-value', "$prefix: get type");
    is($input_getter->get_default(), 'default-value', "$prefix: get default");
}

__END__
