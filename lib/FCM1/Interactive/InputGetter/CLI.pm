# ------------------------------------------------------------------------------
# Copyright (C) 2006-2019 British Crown (Met Office) & Contributors.
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

package FCM1::Interactive::InputGetter::CLI;
use base qw{FCM1::Interactive::InputGetter};

my $DEF_MSG = q{ (or just press <return> for "%s")};
my %EXTRA_MSG_FOR = (
    yn  => qq{\nEnter "y" or "n"},
    yna => qq{\nEnter "y", "n" or "a"},
);
my %CHECKER_FOR = (
    yn  => sub {$_[0] eq 'y' || $_[0] eq 'n'},
    yna => sub {$_[0] eq 'y' || $_[0] eq 'n' || $_[0] eq 'a'},
);

sub invoke {
    my ($self) = @_;
    my $type = $self->get_type() ? lc($self->get_type()) : q{};
    my $message
        = $self->get_message()
        . (exists($EXTRA_MSG_FOR{$type}) ? $EXTRA_MSG_FOR{$type} : q{})
        . ($self->get_default() ? sprintf($DEF_MSG, $self->get_default()) : q{})
        . q{: }
        ;
    while (1) {
        print($message);
        my $answer = readline(STDIN);
        chomp($answer);
        if (!$answer && $self->get_default()) {
            $answer = $self->get_default();
        }
        if (!exists($CHECKER_FOR{$type}) || $CHECKER_FOR{$type}->($answer)) {
            return $answer;
        }
    }
    return;
}

1;
__END__

=head1 NAME

FCM1::Interactive::InputGetter::CLI

=head1 SYNOPSIS

    use FCM1::Interactive;
    $answer = FCM1::Interactive::get_input(
        title   => 'My title',
        message => 'Would you like to ...?',
        type    => 'yn',
        default => 'n',
    );

=head1 DESCRIPTION

This is a solid implementation of
L<FCM1::Interactive::InputGetter|FCM1::Interactive::InputGetter>. It gets a user
reply from STDIN using a prompt on STDOUT.

=head1 METHODS

See L<FCM1::Interactive::InputGetter|FCM1::Interactive::InputGetter> for a list of
methods.

=head1 TO DO

Use IO::Prompt.

=head1 SEE ALSO

L<FCM1::Interactive|FCM1::Interactive>,
L<FCM1::Interactive::InputGetter|FCM1::Interactive::InputGetter>,
L<FCM1::Interactive::InputGetter::GUI|FCM1::Interactive::InputGetter::GUI>

=head1 COPYRIGHT

Copyright (C) 2006-2019 British Crown (Met Office) & Contributors..

=cut
