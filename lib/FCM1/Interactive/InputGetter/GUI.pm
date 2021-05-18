# ------------------------------------------------------------------------------
# Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.
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

package FCM1::Interactive::InputGetter::GUI;
use base qw{FCM1::Interactive::InputGetter};

use Tk;

################################################################################
# Returns the geometry string for the pop up message box
sub get_geometry {
    my ($self) = @_;
    return $self->{geometry};
}

################################################################################
# Invokes the getter
sub invoke {
    my ($self) = @_;
    my $answer;
    local $| = 1;

    # Create a main window
    my $mw = MainWindow->new();
    $mw->title($self->get_title());

    # Define the default which applies if the dialog box is just closed or
    # the user selects 'cancel'
    $answer = $self->get_default() ? $self->get_default() : q{};

    if (defined($self->get_type()) && $self->get_type() =~ qr{\A yn}ixms) {
        # Create a yes-no(-all) dialog box

        # If TYPE is YNA then add a third button: 'all'
        my $buttons = $self->get_type() =~ qr{a \z}ixms ? 3 : 2;

        # Message of the dialog box
        $mw->Label('-text' => $self->get_message())->grid(
            '-row'        => 0,
            '-column'     => 0,
            '-columnspan' => $buttons,
            '-padx'       => 10,
            '-pady'       => 10,
        );

        # The "yes" button
        my $y_b = $mw->Button(
            '-text'      => 'Yes',
            '-underline' => 0,
            '-command'   => sub {$answer = 'y'; $mw->destroy()},
        )
        ->grid('-row' => 1, '-column' => 0, '-padx' => 5, '-pady' => 5);

        # The "no" button
        my $n_b = $mw->Button (
            '-text'      => 'No',
            '-underline' => 0,
            '-command'   => sub {$answer = 'n'; $mw->destroy()},
        )
        ->grid('-row' => 1, '-column' => 1, '-padx' => 5, '-pady' => 5);

        # The "all" button
        my $a_b;
        if ($buttons == 3) {
            $a_b = $mw->Button(
                '-text'      => 'All',
                '-underline' => 0,
                '-command'   => sub {$answer = 'a'; $mw->destroy()},
            )
            ->grid('-row' => 1, '-column' => 2, '-padx' => 5, '-pady' => 5);
        }

        # Keyboard binding
        if ($buttons == 3) {
            $mw->bind('<Key>' => sub {
                my $button
                    = $Tk::event->K() eq 'Y' || $Tk::event->K() eq 'y' ? $y_b
                    : $Tk::event->K() eq 'N' || $Tk::event->K() eq 'n' ? $n_b
                    : $Tk::event->K() eq 'A' || $Tk::event->K() eq 'a' ? $a_b
                    :                                                    undef
                    ;
                if (defined($button)) {
                    $button->invoke();
                }
            });
        }
        else {
            $mw->bind('<Key>' => sub {
                my $button
                    = $Tk::event->K() eq 'Y' || $Tk::event->K() eq 'y' ? $y_b
                    : $Tk::event->K() eq 'N' || $Tk::event->K() eq 'n' ? $n_b
                    :                                                    undef
                    ;
                if (defined($button)) {
                    $button->invoke();
                }
            });
        }

        # Handle the situation when the user attempts to quit the window
        $mw->protocol('WM_DELETE_WINDOW', sub {
            if (self->get_default()) {
                $answer = $self->get_default();
            }
            $mw->destroy();
        });
    }
    else {
        # Create a dialog box to obtain an input string
        # Message of the dialog box
        $mw->Label('-text' => $self->get_message())->grid(
            '-row'    => 0,
            '-column' => 0,
            '-padx'   => 5,
            '-pady'   => 5,
        );

        # Entry box for the user to type in the input string
        my $entry   = $answer;
        my $input_e = $mw->Entry(
            '-textvariable' => \$entry,
            '-width'        => 40,
        )
        ->grid(
            '-row'    => 0,
            '-column' => 1,
            '-sticky' => 'ew',
            '-padx'   => 5,
            '-pady'   => 5,
        );

        my $b_f = $mw->Frame->grid(
            '-row'        => 1,
            '-column'     => 0,
            '-columnspan' => 2,
            '-sticky'     => 'e',
        );

        # An OK button to accept the input string
        my $ok_b = $b_f->Button (
            '-text' => 'OK',
            '-command' => sub {$answer = $entry; $mw->destroy()},
        )
        ->grid('-row' => 0, '-column' => 0, '-padx' => 5, '-pady' => 5);

        # A Cancel button to reject the input string
        my $cancel_b = $b_f->Button(
            '-text' => 'Cancel',
            '-command' => sub {$answer = undef; $mw->destroy()},
        )
        ->grid('-row' => 0, '-column' => 1, '-padx' => 5, '-pady' => 5);

        # Keyboard binding
        $mw->bind ('<Key>' => sub {
            if ($Tk::event->K eq 'Return' or $Tk::event->K eq 'KP_Enter') {
                $ok_b->invoke();
            }
            elsif ($Tk::event->K eq 'Escape') {
                $cancel_b->invoke();
            }
        });

        # Allow the entry box to expand
        $mw->gridColumnconfigure(1, '-weight' => 1);

        # Set initial focus on the entry box
        $input_e->focus();
        $input_e->icursor('end');
    }

    $mw->geometry($self->get_geometry());

    # Switch on "always on top" property for $mw
    $mw->property(
        qw/set _NET_WM_STATE ATOM/,
        32,
        ['_NET_WM_STATE_STAYS_ON_TOP'],
        ($mw->toplevel()->wrapper())[0],
    );

    MainLoop();
    return $answer;
}

1;
__END__

=head1 NAME

FCM1::Interactive::InputGetter::GUI

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
reply from a TK pop up message box.

=head1 METHODS

See L<FCM1::Interactive::InputGetter|FCM1::Interactive::InputGetter> for a list of
inherited methods.

=over 4

=item new($args_ref)

As in L<FCM1::Interactive::InputGetter|FCM1::Interactive::InputGetter>, but also
accept a I<geometry> element for setting the geometry string of the pop up
message box.

=item get_geometry()

Returns the geometry string for the pop up message box.

=back

=head1 TO DO

Tidy up the logic of invoke(). Separate the logic for YN/A box and string input
box, probably using a strategy pattern. Factor out the logic for the display
and the return value.

=head1 SEE ALSO

L<FCM1::Interactive|FCM1::Interactive>,
L<FCM1::Interactive::InputGetter|FCM1::Interactive::InputGetter>,
L<FCM1::Interactive::InputGetter::CLI|FCM1::Interactive::InputGetter::CLI>

=head1 COPYRIGHT

Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.

=cut
