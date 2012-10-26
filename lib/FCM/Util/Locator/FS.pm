# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-2012 Met Office.
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
package FCM::Util::Locator::FS;
use base qw{FCM::Class::CODE};

use File::Basename qw{dirname};
use File::Find qw{};
use File::Spec;

our %ACTION_OF = (
    can_work_with     => sub {1},
    can_work_with_rev => sub {},
    cat               => \&_cat,
    dir               => \&_dir,
    find              => \&_find,
    origin            => \&_parse,
    parse             => \&_parse,
    reader            => \&_reader,
    read_property     => sub {},
    trunk_at_head     => sub {},
);

# Creates the class.
__PACKAGE__->class({}, {action_of => \%ACTION_OF});

# Joins @paths to the end of $value.
sub _cat {
    my ($attrib_ref, $value, @paths) = @_;
    _parse(
        $attrib_ref,
        File::Spec->catfile(_parse($attrib_ref, $value), @paths),
    );
}

# Returns the directory name of $value.
sub _dir {
    my ($attrib_ref, $value) = @_;
    dirname(_parse($attrib_ref, $value));
}

# Searches directory tree.
sub _find {
    my ($attrib_ref, $value, $callback) = @_;
    my $found;
    File::Find::find(
        sub {
            $found ||= 1;
            my $path = $File::Find::name;
            my ($vol, $dir_name, $base) = File::Spec->splitpath($path);
            for my $name (File::Spec->splitdir($dir_name), $base) {
                if (index($name, q{.}) == 0) {
                    return; # ignore Unix hidden/system files
                }
            }
            my $ns = File::Spec->abs2rel($path, $value);
            if ($ns eq q{.}) {
                $ns = q{};
            }
            my $last_modified_time = (-l $path ? lstat($path) : stat($path))[9];
            $callback->(
                $path,
                {   is_dir             => scalar(-d $path),
                    last_modified_rev  => undef,
                    last_modified_time => $last_modified_time,
                    ns                 => $ns,
                },
            );
        },
        $value,
    );
    return $found;
}

# Returns a reader (file handle) for a given file system value.
sub _reader {
    my ($attrib_ref, $value) = @_;
    $value = _parse($attrib_ref, $value);
    if (!-f $value || !-r _) {
        die("$!\n");
    }
    open(my $handle, '<', $value) || die("$!\n");
    return $handle;
}

# Returns $value in scalar context, or ($value,undef) in list context.
sub _parse {
    my ($attrib_ref, $value) = @_;
    $value =~ s{\A~([^/]*)}{$1 ? (getpwnam($1))[7] : (getpwuid($<))[7]}exms;
    $value = File::Spec->rel2abs($value);
    my ($vol, $dir_name, $base) = File::Spec->splitpath($value);
    my @dir_names;
    my %HANDLER_OF = (
        q{}   => sub {push(@dir_names, $_[0])},
        q{.}  => sub {},
        q{..} => sub {if (@dir_names > 1) {pop(@dir_names)}},
    );
    for my $name (File::Spec->splitdir($dir_name)) {
        my $handler
            = exists($HANDLER_OF{$name}) ? $HANDLER_OF{$name} : $HANDLER_OF{q{}};
        $handler->($name);
    }
    $value = File::Spec->catpath($vol, File::Spec->catdir(@dir_names), $base);
    return (wantarray() ? ($value, undef) : $value);
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Util::Locator::FS

=head1 SYNOPSIS

    use FCM::Util::Locator::FS;
    $util = FCM::Util::Locator::FS->new(\%option);
    $handle = $util->reader($value);

=head1 DESCRIPTION

Provides utilities to manipulate the values of file system locators.

=head1 METHODS

=over 4

=item $util->can_work_with($value)

Dummy. Always returns true.

=item $util->can_work_with_rev($revision)

Dummy. Always returns false.

=item $util->cat($value,@paths)

Joins @paths to the end of $value.

=item $util->dir($value)

Returns the parent directory of $value.

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

=item $util->trunk_at_head($value)

Dummy. Always returns undef.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
