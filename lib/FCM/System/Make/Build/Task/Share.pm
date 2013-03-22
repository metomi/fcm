# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-2013 Met Office.
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

# ------------------------------------------------------------------------------
package FCM::System::Make::Build::Task::Share;
use base qw{Exporter};

use Text::ParseWords qw{shellwords};

our @EXPORT = qw{_props_to_opts};

sub _props_to_opts {
    # $opt_value should be an sprintf format with one %s.
    my ($opt_value, @props) = @_;
    if (!$opt_value) {
        return;
    }
    my @opt_values = shellwords($opt_value);
    my $index = -1;
    I:
    for my $i (0 .. $#opt_values) {
        if (index($opt_values[$i], '%s') >= 0) {
            $index = $i;
            last I;
        }
    }
    if ($index == -1) {
        return (@opt_values, @props);
    }
    my @return;
    for my $prop (@props) {
        push(@return, @opt_values[0 .. $index - 1]);
        push(@return, sprintf($opt_values[$index], $prop));
        push(@return, @opt_values[$index + 1 .. $#opt_values]);
    }
    return @return;
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::Task::Share

=head1 SYNOPSIS

    use FCM::System::Make::Build::Task::Share

=head1 DESCRIPTION

Provides common "local" functions for a make build task.

=head1 FUNCTIONS

The following functions are automatically exported by this module.

=over 4

=item _props_to_opts($opt_value, @props)

Expect $opt_value to be an sprintf format containing one %s, and @props is a
list of values. Return a list that can be used in a shell command. E.g.:

    _props_to_opts('-D%s', 'HELLO="greetings"', 'WORLD="mars and venus"')
    # => ('-DHELLO="greetings"', '-DWORLD="mars and venus"')
    
    _props_to_opts('-I %s', '/path/1', '/path/2')
    # => ('-I', '/path/1', '-I', '/path/2')

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
