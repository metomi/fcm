#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw{no_plan};

main();

sub main {
    my $class = 'Fcm::Exception';
    use_ok($class);
    test_constructor_empty($class);
    test_normal($class);
}

################################################################################
# Tests empty constructor
sub test_constructor_empty {
    my ($class) = @_;
    my $prefix = 'empty constructor';
    my $e = $class->new();
    isa_ok($e, $class, $prefix);
    isnt("$e", undef, "$prefix: as_string() not undef");
}

################################################################################
# Tests normal usage
sub test_normal {
    my ($class) = @_;
    my $prefix = 'normal';
    my $e = $class->new({message => 'message'});
    isa_ok($e, $class, $prefix);
    is("$e", "$class: message\n", "$prefix: as_string()");
    is($e->get_message(), 'message', "$prefix: get_message()");
}

__END__
