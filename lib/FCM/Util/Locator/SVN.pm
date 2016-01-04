# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-16 Met Office.
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
package FCM::Util::Locator::SVN;
use base qw{FCM::Class::CODE};

use File::Temp;
use POSIX qw{setlocale LC_ALL};
use Time::Piece;

our %ACTION_OF = (
    as_invariant      => \&_as_invariant,
    can_work_with     => \&_can_work_with,
    can_work_with_rev => \&_can_work_with_rev,
    cat               => \&_cat,
    dir               => \&_dir,
    export            => \&_export,
    export_ok         => \&_export_ok,
    find              => \&_find,
    origin            => \&_origin,
    parse             => \&_parse,
    reader            => \&_reader,
    read_property     => \&_read_property,
    test_exists       => \&_test_exists,
    trunk_at_head     => \&_trunk_at_head,
);

my %PATTERN_OF = (
    REVISION       => qr{\A(?:\d+|HEAD|BASE|COMMITTED|PREV|\{[^\}]+\})\z}ixms,
    TARGET_PEG     => qr{\A(.+?)(?:@([^/@]+))?\z}xms,
    URL_COMPONENTS => qr{\A([A-Za-z][\w\.\+\-]*://)([^/]*)(/?.*)\z}xms,
);

my %INFO_OF = (
    'Path'                => 'path',
    'URL'                 => 'URL',
    'Repository Root'     => 'repos_root_URL',
    'Repository UUID'     => 'repos_UUID',
    'Revision'            => 'rev',
    'Node Kind'           => 'kind',
    'Last Changed Author' => 'last_changed_author',
    'Last Changed Rev'    => 'last_changed_rev',
    'Last Changed Date'   => 'last_changed_date',
    # FIXME: currently omitting lock info and other WC info.
);

my %INFO_KIND_OF = (directory => 'dir', file => 'file');

my %INFO_MOD_OF = (
    last_changed_date => \&_svn_info_last_changed_date,
    kind => sub {exists($INFO_KIND_OF{$_[0]}) ? $INFO_KIND_OF{$_[0]} : $_[0]},
);

# Creates the class.
__PACKAGE__->class(
    {type_util_of => '%', util => '&'},
    {action_of => \%ACTION_OF},
);

# Returns the invariant version of $value.
sub _as_invariant {
    my ($attrib_ref, $value) = @_;
    my ($target, $revision) = _parse($attrib_ref, $value);
    if (!$attrib_ref->{util}->uri_match($target) && !$revision) {
        return;
    }
    $revision ||= $attrib_ref->{util}->uri_match($target) ? 'HEAD' : 'BASE';
    my %info_of;
    _svn_info(
        $attrib_ref,
        sub {%info_of = %{$_[0]}},
        [$value],
    );
    return _parse_simple($attrib_ref, $info_of{URL}, $info_of{rev});
}

# Returns true if $value looks like a legitimate SVN target.
sub _can_work_with {
    my ($attrib_ref, $value) = @_;
    my ($scheme) = $attrib_ref->{util}->uri_match($value);
    if ($scheme && grep {$_ eq $scheme} qw{svn file svn+ssh http https}) {
        return $value;
    }
    my ($target, $revision) = _parse($attrib_ref, $value);
    my $url;
    local($@);
    eval {_svn_info($attrib_ref, sub {$url = $_[0]->{URL}}, [$target])};
    return $url;
}

# Returns true if $revision looks like a legitimate SVN revision specifier.
sub _can_work_with_rev {
    my ($attrib_ref, $revision) = @_;
    if (!defined($revision)) {
        return;
    }
    return $revision =~ $PATTERN_OF{REVISION};
}

# Joins @paths to the end of $value.
sub _cat {
    my ($attrib_ref, $value, @paths) = @_;
    my ($target, $rev) = _parse($attrib_ref, $value);
    my $is_uri = $attrib_ref->{util}->uri_match($target);
    $target
        = $is_uri ? join('/', $target, @paths)
        :           $attrib_ref->{type_util_of}{fs}->cat($target, @paths)
        ;
    _parse_simple($attrib_ref, _tidy($target), $rev);
}

# Returns the directory containing $value.
sub _dir {
    my ($attrib_ref, $value) = @_;
    my ($target, $revision) = _parse($attrib_ref, $value);
    if ($attrib_ref->{util}->uri_match($target)) {
        my ($leader, $auth, $trailer) = $target =~ $PATTERN_OF{URL_COMPONENTS};
        if (!$trailer) {
            return _parse($attrib_ref, $target, $revision);
        }
        $trailer =~ s{/+ [^/]* \z}{}xms;
        $target = $leader . ($auth ? $auth : q{}) . $trailer;
    }
    else {
        $target = $attrib_ref->{type_util_of}{fs}->dir($target);
    }
    _parse_simple($attrib_ref, $target, $revision);
}

# Export $value to $dest.
sub _export {
    my ($attrib_ref, $value, $dest) = @_;
    _run_svn_simple($attrib_ref, 'export', [$value, $dest], {quiet => undef});
}

# Returns true if $value is a URL.
sub _export_ok {
    my ($attrib_ref, $value) = @_;
    $attrib_ref->{util}->uri_match($value);
}

# Searches directory tree of $value.
sub _find {
    my ($attrib_ref, $value, $callback) = @_;
    if (!$attrib_ref->{util}->uri_match($value)) {
        return $attrib_ref->{type_util_of}{fs}->find($value, $callback);
    }
    _svn_info(
        $attrib_ref,
        sub {
            my ($info_ref) = @_;
            $callback->(
                $info_ref->{URL} . '@' . $info_ref->{rev},
                {   is_dir        => $info_ref->{kind} eq 'dir',
                    last_mod_rev  => $info_ref->{last_changed_rev},
                    last_mod_time => $info_ref->{last_changed_date},
                    ns            => $info_ref->{path},
                },
            );
        },
        [$value],
        {recursive => undef},
    );
    return 1;
}

# Returns the URL version of $value.
sub _origin {
    my ($attrib_ref, $value) = @_;
    my ($target, $revision) = _parse($attrib_ref, $value);
    if ($attrib_ref->{util}->uri_match($target)) {
        return _parse_simple($attrib_ref, $value);
    }
    $revision ||= 'BASE';
    _as_invariant(
        $attrib_ref,
        scalar(_parse_simple($attrib_ref, $target, $revision)),
    );
}

# In list context, returns ($target, $revision). In scalar context, returns
# "$target@$revision".
sub _parse {
    my ($attrib_ref, $value, $revision) = @_;
    my ($target, $peg_revision) = $value =~ $PATTERN_OF{TARGET_PEG};
    if ($peg_revision) {
        $revision = $peg_revision;
    }
    $target
        = $attrib_ref->{util}->uri_match($value)
        ? _tidy($target)
        : $attrib_ref->{type_util_of}{fs}->parse($target)
        ;
    _parse_simple($attrib_ref, $target, $revision);
}

# Same as _parse, but without _tidy.
sub _parse_simple {
    my ($attrib_ref, $value, $revision) = @_;
    (
        wantarray() ? ($value, $revision)
        :             $value . ($revision ? q{@} . $revision : q{})
    );
}

# Returns a named property of a Subversion target.
sub _read_property {
    my ($attrib_ref, $value, $name) = @_;
    _run_svn_simple($attrib_ref, 'pg', [$name, $value]);
}

# Returns a reader (file handle) for a given Subversion target.
sub _reader {
    my ($attrib_ref, $value) = @_;
    my ($target, $revision) = _parse($attrib_ref, $value);
    if ($attrib_ref->{util}->uri_match($target) || $revision) {
        return _run_svn_handle($attrib_ref, 'cat', [$value]);
    }
    else {
        return $attrib_ref->{type_util_of}{fs}->reader($target);
    }
}

# Helper for _run_svn_*, generates the command.
sub _run_svn_command {
    my ($attrib_ref, $key, $args_ref, $option_ref) = @_;
    $args_ref   ||= [];
    $option_ref ||= {};
    my @options;
    while (my ($key, $value) = each(%{$option_ref})) {
        push(@options, '--' . $key . (defined($value) ? '=' . $value : q{}));
    }
    ['svn', $key, @options, @{$args_ref}];
}

# Runs "svn", sending standard output to a file handle.
sub _run_svn_handle {
    my ($attrib_ref, $key, $args_ref, $option_ref) = @_;
    local($ENV{LANG}) = $ENV{LANG};
    if (setlocale(LC_ALL, 'en_GB')) {
        $ENV{LANG} = 'en_GB';
    }
    my $handle = File::Temp->new();
    my $rc = $attrib_ref->{util}->shell(
        _run_svn_command(@_),
        {e => \my($err), o => sub {print($handle $_[0])}},
    );
    if ($rc || (!tell($handle) && $err)) { # cat, info, etc may return 0 on err
        chomp($err);
        die("$err\n");
    }
    seek($handle, 0, 0);
    return $handle;
}

# Runs a simple "svn" command.
sub _run_svn_simple {
    my ($attrib_ref, $key, $args_ref, $option_ref) = @_;
    local($ENV{LANG}) = $ENV{LANG};
    if (setlocale(LC_ALL, 'en_GB')) {
        $ENV{LANG} = 'en_GB';
    }
    my $value_hash_ref
        = $attrib_ref->{util}->shell_simple(_run_svn_command(@_));
    if ($value_hash_ref->{rc}) {
        die($value_hash_ref);
    }
    $value_hash_ref->{o};
}

# Runs "svn info".
sub _svn_info {
    my ($attrib_ref, $callback_ref, $args_ref, $option_ref) = @_;
    my $handle = _run_svn_handle($attrib_ref, 'info', $args_ref, $option_ref);
    my %hash;
    while (my $line = readline($handle)) {
        chomp($line);
        if ($line) {
            my ($key, $value) = split(qr{:\s*}msx, $line, 2);
            if (exists($INFO_OF{$key})) {
                my $id = $INFO_OF{$key};
                $hash{$id}
                    = exists($INFO_MOD_OF{$id}) ? $INFO_MOD_OF{$id}->($value)
                    :                             $value
                    ;
            }
        }
        else {
            $callback_ref->(\%hash);
        }
    }
}

# Parse last changed date from "svn info".
sub _svn_info_last_changed_date {
    my $text = (split(qr{\s+\(}msx, $_[0], 2))[0];
    my $head = Time::Piece->strptime(substr($text, 0, -6), '%Y-%m-%d %H:%M:%S');
    my $tail = substr($text, -5);
    my ($tz_sign, $tz_h, $tz_m) = $tail =~ qr{([\-\+])(\d\d)(\d\d)}msx;
    $head->epoch() - int($tz_sign . 1) * ($tz_h * 3600 + $tz_m * 60);
}

# Return a true value if the location $value exists.
sub _test_exists {
    my ($attrib_ref, $value) = @_;
    my $url;
    eval {_svn_info($attrib_ref, sub {$url = $_[0]->{URL}}, [$value])};
    return $url;
}

# Returns a tidied version of a Subversion URL.
sub _tidy {
    my ($url) = @_;
    my ($leader, $auth, $trailer) = $url =~ $PATTERN_OF{URL_COMPONENTS};
    if (!$trailer) {
        return $url;
    }
    my @tidied_names;
    my %handler_of = (
        q{}   => sub {push(@tidied_names, $_[0])},
        q{.}  => sub {},
        q{..} => sub {if (@tidied_names > 1) {pop(@tidied_names)}},
    );
    for my $name (split(qr{/+}xms, $trailer)) {
        my $handler
            = exists($handler_of{$name}) ? $handler_of{$name} : $handler_of{q{}};
        $handler->($name);
    }
    return $leader . ($auth ? $auth : q{}) . join(q{/}, @tidied_names);
}

# Returns trunk@HEAD for a URL.
sub _trunk_at_head {
    my ($attrib_ref, $target) = @_;
    if (!$attrib_ref->{util}->uri_match($target)) {
        return;
    }
    _cat($attrib_ref, $target, 'trunk@HEAD');
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Util::Locator::SVN

=head1 SYNOPSIS

    use FCM::Util;
    $util = FCM::Util->new(\%attrib);
    $reader = $util->loc_reader($locator);


=head1 DESCRIPTION

This is part of L<FCM::Util|FCM::Util>. Provides utilities for Subversion
targets.

=head1 ATTRIBUTES

=over 4

=item util

The L<FCM::Util|FCM::Util> object that initialised this object.

=head1 METHODS

=over 4

=item $util->as_invariant($value)

Returns the invariant version of $value. For example, if the current HEAD
revision is 1234, and $value is C<svn://foo/bar/baz> or
C<svn://foo/bar/baz@HEAD>, it will return C<svn://foo/bar/baz@1234>.

=item $util->can_work_with($value)

Returns the URL form of $value (true) if $value is a valid SVN target.

=item $util->can_work_with_rev($revision)

Returns true if $revision looks like a legitimate SVN revision specifier.

=item $util->cat($value,@paths)

Join @paths to the end of $value.

=item $util->dir($value)

Returns the directory name of $value.

=item $util->export($value,$dest)

Exports a clean directory tree of $value to $dest.

=item $util->export_ok($value)

Returns true if $value is a URL. (It is not safe to export a working copy.)

=item $util->find($value,$callback)

Searches directory tree of $value.

=item $util->origin($value)

Returns the URL version of $value.

=item $util->parse($value,$revision)

In scalar context, returns a string in C<TARGET@REV> for $value. In list
context, given C<TARGET@REV> returns (C<TARGET>, C<REV>). If $value has a peg
revision, it overrides the specified $revision.

=item $util->reader($value)

Returns a file handle for reading the content in $value, if possible.

=item $util->read_property($value,$name)

Returns the value of a property $name of $value.

=item $util->test_exists($value)

Return a true value if the location $value exists.

=item $util->trunk_at_head($value)

Returns "$value/trunk@HEAD' if $value is a URI or undef otherwise.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
