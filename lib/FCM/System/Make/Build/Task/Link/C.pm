# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-14 Met Office.
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
package FCM::System::Make::Build::Task::Link::C;
use base qw{FCM::System::Make::Build::Task::Link};

use FCM::System::Make::Build::Task::Compile::C;

our %PROP_OF = (
    %FCM::System::Make::Build::Task::Link::PROP_OF,
    (   map {$_ => $FCM::System::Make::Build::Task::Compile::C::PROP_OF{$_}}
        qw{cc cc.flag-omp cc.flag-output}
    ),
    'cc.flags-ld'      => '',
    'cc.flag-lib'      => '-l%s',
    'cc.flag-lib-path' => '-L%s',
    'cc.libs'          => '',
    'cc.lib-paths'     => '',
);

sub new {
    my ($class, $attrib_ref) = @_;
    bless(
        $class->SUPER::new(
            {name => 'cc', prop_of => {%PROP_OF}, %{$attrib_ref}},
        ),
        $class,
    );
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Make::Build::Task::Link::C

=head1 SYNOPSIS

    use FCM::System::Make::Build::Task::Link::C;
    my $task = FCM::System::Make::Build::Task::Link::C->new(\%attrib);
    $task->main($target);

=head1 DESCRIPTION

Wraps L<FCM::System::Make::Build::Task::Link> to link a C object into an
executable.

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
