#!/usr/bin/perl

use strict;
use warnings;

################################################################################
# A sub-class of Fcm::Interactive::InputGetter for testing
{
    package TestInputGetter;
    use base qw{Fcm::Interactive::InputGetter};

    ############################################################################
    # A callback for testing
    sub get_callback {
        my ($self) = @_;
        return $self->{callback};
    }

    ############################################################################
    # Returns some pre-defined strings
    sub invoke {
        my ($self) = @_;
        $self->get_callback()->(
            $self->get_title(),
            $self->get_message(),
            $self->get_type(),
            $self->get_default(),
        );
        return 'answer';
    }
}

use Test::More qw{no_plan};

main();

sub main {
    use_ok('Fcm::Interactive');
    test_default_impl();
    test_set_impl();
    test_get_input();
}

################################################################################
# Tests default setting of input getter implementation
sub test_default_impl {
    my $prefix = 'default impl';
    my ($class_name, $class_options_ref) = Fcm::Interactive::get_default_impl();
    is($class_name, 'Fcm::Interactive::InputGetter::CLI', "$prefix: class name");
    is_deeply($class_options_ref, {}, "$prefix: class options");
}

################################################################################
# Tests setting the input getter implementation
sub test_set_impl {
    my $prefix = 'set impl';
    my %options = (extra => 'extra-value');
    my $name = 'TestInputGetter';
    Fcm::Interactive::set_impl($name, \%options);
    my ($class_name, $class_options_ref) = Fcm::Interactive::get_impl();
    is($class_name, $name, "$prefix: class name");
    is_deeply($class_options_ref, \%options, "$prefix: class options");
}

################################################################################
# Tests getting input with test input getter
sub test_get_input {
    my $prefix = 'get input';
    my %EXPECTED = (
        TITLE   => 'title-value',
        MESSAGE => 'message-value',
        TYPE    => 'type-value',
        DEFAULT => 'default-value',
        ANSWER  => 'answer',
    );
    Fcm::Interactive::set_impl('TestInputGetter', {
        callback => sub {
            my ($title, $message, $type, $default) = @_;
            is($title, $EXPECTED{TITLE}, "$prefix: title");
            is($message, $EXPECTED{MESSAGE}, "$prefix: message");
            is($type, $EXPECTED{TYPE}, "$prefix: type");
            is($default, $EXPECTED{DEFAULT}, "$prefix: default");
        },
    });
    my $ans = Fcm::Interactive::get_input(
        title   => $EXPECTED{TITLE},
        message => $EXPECTED{MESSAGE},
        type    => $EXPECTED{TYPE},
        default => $EXPECTED{DEFAULT},
    );
    is($ans, $EXPECTED{ANSWER}, "$prefix: answer");
}

__END__
