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

# ------------------------------------------------------------------------------
package FCM::CLI::Exception;
use base qw{FCM::Exception};

use constant {
    APP => 'APP',
    OPT => 'OPT',
};

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::CLI::Exception

=head1 SYNOPSIS

    use FCM::CLI::Exception;
    FCM::CLI::Exception->throw(FCM::CLI::Exception->APP, \@argv, $e);
    FCM::CLI::Exception->throw(FCM::CLI::Exception->OPT, \@argv, $e);

=head1 DESCRIPTION

An exception associated with the FCM CLI. It is a sub-class of
L<FCM::Exception|FCM::Exception>. The $e->get_ctx() method returns an ARRAY
reference containing the argument list. The $e->get_code() method may return
either $e->APP (if an unknown application is specified) or $e->OPT (if an
unknown option is specified, i.e. the option parser returns some errors).

=head1 COPYRIGHT

Copyright (C) 2006-2019 British Crown (Met Office) & Contributors..

=cut
