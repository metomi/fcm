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
# ------------------------------------------------------------------------------

package FCM::Util::Exception;
use base qw{FCM::Exception};

use constant {
    CLASS_LOADER         => 'CLASS_LOADER',
    CONFIG_CONT_EOF      => 'CONFIG_CONT_EOF',
    CONFIG_CYCLIC        => 'CONFIG_CYCLIC',
    CONFIG_LOAD          => 'CONFIG_LOAD',
    CONFIG_SYNTAX        => 'CONFIG_SYNTAX',
    CONFIG_USAGE         => 'CONFIG_USAGE',
    CONFIG_VAR_UNDEF     => 'CONFIG_VAR_UNDEF',
    IO                   => 'IO',
    LOCATOR_AS_INVARIANT => 'LOCATOR_AS_INVARIANT',
    LOCATOR_BROWSER_URL  => 'LOCATOR_BROWSER_URL',
    LOCATOR_FIND         => 'LOCATOR_FIND',
    LOCATOR_KEYWORD_LOC  => 'LOCATOR_KEYWORD_LOC',
    LOCATOR_KEYWORD_REV  => 'LOCATOR_KEYWORD_REV',
    LOCATOR_READER       => 'LOCATOR_READER',
    LOCATOR_TYPE         => 'LOCATOR_TYPE',
    SHELL_OPEN3          => 'SHELL_OPEN3',
    SHELL_OS             => 'SHELL_OS',
    SHELL_SIGNAL         => 'SHELL_SIGNAL',
    SHELL_WHICH          => 'SHELL_WHICH',
};

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Util::Exception

=head1 SYNOPSIS

    use FCM::Util::Exception;
    eval {
        # something does not work ...
        FCM::Util::Exception->throw($code, $ctx, $exception);
    };
    if (my $e = $@) {
        if (FCM::Util::Exception->caught($e)) {
            # do something ...
        }
        else {
            # do something else ...
        }
    }

=head1 DESCRIPTION

This exception represents an error condition in an FCM utility. It is a
sub-class of L<FCM::Exception|FCM::Exception>.

=head1 CONSTANTS

The following are known error code:

=over 4

=item CLASS_LOADER

L<FCM::Util::ClassLoader|FCM::Util::ClassLoader>: The utility fails to load the
specified class. The $e->get_ctx() method returns the name of the class it fails
to load.

=item CONFIG_CONT_EOF

L<FCM::Util::ConfigReader|FCM::Util::ConfigReader>: The last line of the
configuration file has a continuation marker. Expects the $e->get_ctx() method
to return the L<FCM::Context::ConfigEntry|FCM::Context::ConfigEntry> object that
represents the problem entry.

=item CONFIG_CYCLIC

L<FCM::Util::ConfigReader|FCM::Util::ConfigReader>: There is a cyclic dependency
in the include hierarchy. Expects the $e->get_ctx() method to return an ARRAY
reference of the locator stack. (The last element of the ARRAY is the top of the
stack, and each element is a 2-element ARRAY reference, where the first element
is a L<FCM::Context::Locator|FCM::Context::Locator> object and the second
element is the line number.)

=item CONFIG_LOAD

L<FCM::Util::ConfigReader|FCM::Util::ConfigReader>: An error occurs when loading
a configuration file. Expects the $e->get_ctx() method to return an ARRAY
reference of the locator stack. (The last element of the ARRAY is the top of the
stack, and each element is a 2-element ARRAY reference, where the first element
is a L<FCM::Context::Locator|FCM::Context::Locator> object and the second
element is the line number.)

=item CONFIG_SYNTAX

L<FCM::Util::ConfigReader|FCM::Util::ConfigReader>: A syntax error in the
declaration. Expects the $e->get_ctx() method to return the
L<FCM::Context::ConfigEntry|FCM::Context::ConfigEntry> object that represents
the problem entry.

=item CONFIG_USAGE

L<FCM::Util::ConfigReader|FCM::Util::ConfigReader>: An attempt to assign a value
to a reserved variable. Expects the $e->get_ctx() method to return the
L<FCM::Context::ConfigEntry|FCM::Context::ConfigEntry> object that represents
the problem entry.

=item CONFIG_VAR_UNDEF

L<FCM::Util::ConfigReader|FCM::Util::ConfigReader>: References to an undefined
variable. Expects the $e->get_ctx() method to return the
L<FCM::Context::ConfigEntry|FCM::Context::ConfigEntry> object that represents
the problem entry, and $e->get_exception() to return a string that looks like
"undef($symbol)" where $symbol is the symbol that references the variable.

=item IO

L<FCM::Util::IO|FCM::Util::IO>: I/O exception. Expects $e->get_ctx() to return
the path that triggers the exception, and the $e->get_exception() to return the
$! string.

=item LOCATOR_AS_INVARIANT

L<FCM::Util::Locator|FCM::Util::Locator>: The invariant value of the locator
cannot be determined. Expects $e->get_ctx() method to return the associated
L<FCM::Context::Locator|FCM::Context::Locator> object.

=item LOCATOR_BROWSER_URL

L<FCM::Util::Locator|FCM::Util::Locator>: The locator cannot be mapped to a
browser URL. Expects $e->get_ctx() method to return the associated
L<FCM::Context::Locator|FCM::Context::Locator> object.

=item LOCATOR_FIND

L<FCM::Util::Locator|FCM::Util::Locator>: The locator does not exist. Expects
$e->get_ctx() method to return the associated
L<FCM::Context::Locator|FCM::Context::Locator> object.

=item LOCATOR_KEYWORD_LOC

L<FCM::Util::Locator|FCM::Util::Locator>: The location keyword as specified in
the locator is not defined. Expects $e->get_ctx() method to return the
associated L<FCM::Context::Locator|FCM::Context::Locator> object.

=item LOCATOR_KEYWORD_REV

L<FCM::Util::Locator|FCM::Util::Locator>: The revision keyword as specified in
the locator is not defined. Expects $e->get_ctx() method to return the
associated L<FCM::Context::Locator|FCM::Context::Locator> object.

=item LOCATOR_READER

L<FCM::Util::Locator|FCM::Util::Locator>: The locator cannot be read. Expects
$e->get_ctx() method to return the associated
L<FCM::Context::Locator|FCM::Context::Locator> object.

=item LOCATOR_TYPE

L<FCM::Util::Locator|FCM::Util::Locator>: The locator type cannot be determined
or cannot be supported. Expects $e->get_ctx() method to return the associated
L<FCM::Context::Locator|FCM::Context::Locator> object.

=item LOCATOR_WHEN

L<FCM::Util::Locator|FCM::Util::Locator>: The last modified date and revision of
the locator cannot be determined. Expects $e->get_ctx() method to return the
associated L<FCM::Context::Locator|FCM::Context::Locator> object.

=item SHELL_OPEN3

L<FCM::Util::Shell|FCM::Util::Shell>: The utility fails to invoke
IPC::Open3::open3(). Expects $e->get_ctx() to return an ARRAY reference of the
command line, and $e->get_exception() to return the error from open3().

=item SHELL_OS

L<FCM::Util::Shell|FCM::Util::Shell>: An OS error occurs when invoking a shell
command. Expects $e->get_ctx() to return an ARRAY reference of the
command line, and $e->get_exception() to return $!.

=item SHELL_SIGNAL

L<FCM::Util::Shell|FCM::Util::Shell>: The system receives a signal when invoking
a shell command. Expects $e->get_ctx() to return an ARRAY reference of the
command line, and $e->get_exception() to return the signal number.

=item SHELL_WHICH

L<FCM::Util::Shell|FCM::Util::Shell>: The shell command does not exist in the
PATH. Expects $e->get_ctx() to return an ARRAY reference of the command line.

=back

=head1 COPYRIGHT

Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.

=cut
