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
package FCM::Util::Locator::SSH;
use base qw{FCM::Class::CODE};

use FCM::Util::Exception;
use File::Temp;
use Text::ParseWords qw{shellwords};

our %ACTION_OF = (
    can_work_with     => \&_can_work_with,
    can_work_with_rev => sub {},
    cat               => \&_cat,
    dir               => \&_dir,
    export            => \&_export,
    export_ok         => sub {1},
    find              => \&_find,
    origin            => \&_parse,
    parse             => \&_parse,
    reader            => \&_reader,
    read_property     => sub {},
    test_exists       => \&_test_exists,
    trunk_at_head     => sub {},
);
# Alias to the exception class
my $E = 'FCM::Util::Exception';

# Creates the class.
__PACKAGE__->class(
    {type_util_of => '%', util => '&'},
    {action_of => \%ACTION_OF},
);

# Returns true if $value looks like a legitimate HOST:PATH.
sub _can_work_with {
    my ($attrib_ref, $value) = @_;
    if (!$value) {
        return;
    }
    my ($auth) = split(':', $value, 2);
    if (!$auth) {
        return;
    }
    my $host = index($auth, '@') >= 0 ? (split('@', $auth, 2))[1] : $auth;
    $host ? gethostbyname($host) : undef;
}

# Joins @paths to the end of $value.
sub _cat {
    my ($attrib_ref, $value, @paths) = @_;
    my ($auth, $path) = split(':', $value, 2);
    $auth . ':' . $attrib_ref->{type_util_of}{fs}->cat($path, @paths);
}

# Returns the directory name of $value.
sub _dir {
    my ($attrib_ref, $value) = @_;
    my ($auth, $path) = split(':', $value, 2);
    $auth . ':' . $attrib_ref->{type_util_of}{fs}->dir($path);
}

# Rsync $value to $dest.
sub _export {
    my ($attrib_ref, $value, $dest) = @_;
    my ($auth, $path) = _dir($attrib_ref, $value);
    my $value_hash_ref = $attrib_ref->{util}->shell_simple([
        _shell_cmd_list($attrib_ref, 'rsync'),
        $value . '/',
        $dest,
    ]);
    if ($value_hash_ref->{rc}) {
        die($value_hash_ref);
    }
}

# Searches directory tree.
sub _find {
    my ($attrib_ref, $value, $callback) = @_;
    my ($auth, $path) = split(':', $value, 2);
    my $value_hash_ref = $attrib_ref->{util}->shell_simple([
        _shell_cmd_list($attrib_ref, 'ssh'),
        $auth,
        "find $path -type f -not -path \"*/.*\" -printf \"%T@ %p\\\\n\"",
    ]);
    if ($value_hash_ref->{rc}) {
        die($value_hash_ref);
    }
    my $found;
    LINE:
    for my $line (grep {$_} split("\n", $value_hash_ref->{o})) {
        $found ||= 1;
        my ($mtime, $name) = split(q{ }, $line, 2);
        my $ns = substr($name, length($path) + 1);
        $callback->(
            $auth . ':' . $name,
            {   is_dir        => undef,
                last_mod_rev  => undef,
                last_mod_time => $mtime,
                ns            => $ns,
            },
        );
    }
    $found;
}

# Returns a reader (file handle) for a given file system value.
sub _reader {
    my ($attrib_ref, $value) = @_;
    my ($auth, $path) = split(':', $value, 2);
    my $handle = File::Temp->new();
    my $e;
    my $rc = $attrib_ref->{util}->shell(
        [_shell_cmd_list($attrib_ref, 'ssh'), $auth, 'cat', $path],
        {'e' => \$e, 'o' => sub {print($handle $_[0])}},
    );
    if ($rc) {
        die($e);
    }
    seek($handle, 0, 0);
    return $handle;
}

# Returns $value in scalar context, or ($value,undef) in list context.
sub _parse {
    my ($attrib_ref, $value) = @_;
    my ($auth, $path) = split(':', $value, 2);
    $value = $auth . ':' . $attrib_ref->{type_util_of}{fs}->parse($path);
    return (wantarray() ? ($value, undef) : $value);
}

# Return a true value if the location $value exists.
sub _test_exists {
    my ($attrib_ref, $value) = @_;
    my ($auth, $path) = split(':', $value, 2);
    my $value_hash_ref = $attrib_ref->{util}->shell_simple([
        _shell_cmd_list($attrib_ref, 'ssh'), $auth, "test -e '$path'",
    ]);
    return !$value_hash_ref->{rc};
}

# Get a named command and its flags, return a list.
sub _shell_cmd_list {
    my ($attrib_ref, $key) = @_;
    map {shellwords($_)} (
        $attrib_ref->{util}->external_cfg_get($key),
        $attrib_ref->{util}->external_cfg_get($key . '.flags'),
    );
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Util::Locator::SSH

=head1 SYNOPSIS

    use FCM::Util::Locator::SSH;
    $util = FCM::Util::Locator::SSH->new(\%option);
    $handle = $util->reader($value);

=head1 DESCRIPTION

Provides utilities to manipulate the values of locators on file systems on
remote hosts accessible via SSH and RSYNC.

=head1 METHODS

=over 4

=item $util->can_work_with($value)

Returns true if $value is in the form AUTH:PATH and AUTH is a valid user@host.

=item $util->can_work_with_rev($revision)

Dummy. Always returns false.

=item $util->cat($value,@paths)

Joins @paths to the end of $value.

=item $util->dir($value)

Returns the auth:parent-directory of $value.

=item $util->export($value,$dest)

Rsync a clean directory tree of $value to $dest.

=item $util->export_ok($value)

Returns true if $util->can_work_with($value).

=item $util->find($value,$callback)

Searches directory tree of $value.

=item $util->origin($value)

Alias of $util->parse($value).

=item $util->parse($value)

In scalar context, returns $value. In list context, returns ($value,undef).

=item $util->reader($value)

Returns a file handle for $value, if it is a readable regular file.

=item $util->read_property($value,$property_name)

Dummy. Always returns undef.

=item $util->test_exists($value)

Return a true value if the location $value exists.

=item $util->trunk_at_head($value)

Dummy. Always returns undef.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
