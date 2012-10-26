#!/usr/bin/perl

use strict;
use warnings;

################################################################################
# A class for testing the loader
{
    package MyTestClass;

    sub new {
        my ($class) = @_;
        return bless(\do{my $annon_scalar}, $class);
    }
}

use Test::More (tests => 9);

main();

sub main {
    use_ok('Fcm::Util::ClassLoader');
    test_normal();
    test_bad();
}

################################################################################
# Tests loading classes that should load OK
sub test_normal {
    my $prefix = 'normal';
    my @CLASSES = (
        'Fcm::Exception',
        'MyTestClass',
        'Fcm::Exception',
    );
    for my $class (@CLASSES) {
        ok(Fcm::Util::ClassLoader::load($class), "$prefix: load $class");
    }
}

################################################################################
# Tests loading classes that should fail
sub test_bad {
    my $prefix = 'bad';
    my @CLASSES = ('Foo', 'Bar', 'Baz', 'No::Such::Class', 'Foo');
    for my $class (@CLASSES) {
        eval {
            Fcm::Util::ClassLoader::load($class);
        };
        isa_ok($@, 'Fcm::Exception', "$prefix: load $class");
    }
}

__END__
