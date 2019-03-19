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

package FCM::Util;
use base qw{FCM::Class::CODE};

use Digest::MD5;
use Digest::SHA;
use FCM::Context::Event;
use FCM::Context::Locator;
use FCM::Util::ConfigReader;
use FCM::Util::ConfigUpgrade;
use FCM::Util::Event;
use FCM::Util::Exception;
use FCM::Util::Locator;
use FCM::Util::Reporter;
use FCM::Util::Shell;
use FCM::Util::TaskRunner;
use File::Basename qw{basename dirname};
use File::Path qw{mkpath};
use File::Spec::Functions qw{catfile};
use FindBin;
use Scalar::Util qw{blessed reftype};
use Text::ParseWords qw{shellwords};
use Time::HiRes qw{gettimeofday tv_interval};

use constant {NS_ITER_UP => 1};

# The (keys) named actions of this class and (values) their implementations.
our %ACTION_OF = (
    cfg_init             => \&_cfg_init,
    class_load           => \&_class_load,
    config_reader        => _util_of_func('config_reader', 'main'),
    external_cfg_get     => \&_external_cfg_get,
    event                => \&_event,
    file_checksum        => \&_file_checksum,
    file_ext             => \&_file_ext,
    file_head            => \&_file_head,
    file_load            => \&_file_load,
    file_load_handle     => \&_file_load_handle,
    file_md5             => \&_file_md5,
    file_save            => \&_file_save,
    file_tilde_expand    => \&_file_tilde_expand,
    hash_cmp             => \&_hash_cmp,
    loc_as_invariant     => _util_of_loc_func('as_invariant'),
    loc_as_keyword       => _util_of_loc_func('as_keyword'),
    loc_as_normalised    => _util_of_loc_func('as_normalised'),
    loc_as_parsed        => _util_of_loc_func('as_parsed'),
    loc_browser_url      => _util_of_loc_func('browser_url'),
    loc_cat              => _util_of_loc_func('cat'),
    loc_dir              => _util_of_loc_func('dir'),
    loc_export           => _util_of_loc_func('export'),
    loc_export_ok        => _util_of_loc_func('export_ok'),
    loc_exists           => _util_of_loc_func('test_exists'),
    loc_find             => _util_of_loc_func('find'),
    loc_kw_ctx           => _util_of_loc_func('kw_ctx'),
    loc_kw_ctx_load      => _util_of_loc_func('kw_ctx_load'),
    loc_kw_iter          => _util_of_loc_func('kw_iter'),
    loc_kw_load_rev_prop => _util_of_loc_func('kw_load_rev_prop'),
    loc_kw_prefix        => _util_of_func('locator', 'kw_prefix'),
    loc_origin           => _util_of_loc_func('origin'),
    loc_reader           => _util_of_loc_func('reader'),
    loc_rel2abs          => _util_of_loc_func('rel2abs'),
    loc_trunk_at_head    => _util_of_loc_func('trunk_at_head'),
    loc_what_type        => _util_of_loc_func('what_type'),
    loc_up_iter          => _util_of_loc_func('up_iter'),
    ns_cat               => \&_ns_cat,
    ns_common            => \&_ns_common,
    ns_in_set            => \&_ns_in_set,
    ns_iter              => \&_ns_iter,
    ns_sep               => sub {$_[0]->{ns_sep}},
    report               => _util_of_func('reporter', 'report'),
    shell                => _util_of_func('shell', 'invoke'),
    shell_simple         => _util_of_func('shell', 'invoke_simple'),
    shell_which          => _util_of_func('shell', 'which'),
    task_runner          => _util_of_func('task_runner', 'main'),
    timer                => \&_timer,
    uri_match            => \&_uri_match,
    util_of_event        => _util_impl_func('event'),
    util_of_report       => _util_impl_func('reporter'),
    version              => \&_version,
);
# The default paths to the configuration files.
our @FCM1_KEYWORD_FILES = (
    catfile((getpwuid($<))[7], qw{.fcm}),
);
our @CONF_PATHS = (
    catfile($FindBin::Bin, qw{.. etc fcm}),
    catfile((getpwuid($<))[7], qw{.met-um fcm}),
    catfile((getpwuid($<))[7], qw{.metomi fcm}),
);
our %CFG_BASENAME_OF = (
    external => 'external.cfg',
    keyword  => 'keyword.cfg',
);
# Values of external commands
our %EXTERNAL_VALUE_OF = (
    'browser'       => 'firefox',
    'diff3'         => 'diff3',
    'diff3.flags'   => '-E -m',
    'graphic-diff'  => 'xxdiff',
    'graphic-merge' => 'xxdiff',
    'ssh'           => 'ssh',
    'ssh.flags'     => '-n -oBatchMode=yes',
    'rsync'         => 'rsync',
    'rsync.flags'   => '-a --exclude=.* --delete-excluded --timeout=900'
                       . ' --rsh="ssh -oBatchMode=yes"',
);
# The name-space separator
our $NS_SEP = '/';
# The (keys) named utilities and their implementation classes.
our %UTIL_CLASS_OF = (
    config_reader => 'FCM::Util::ConfigReader',
    event         => 'FCM::Util::Event',
    locator       => 'FCM::Util::Locator',
    reporter      => 'FCM::Util::Reporter',
    shell         => 'FCM::Util::Shell',
    task_runner   => 'FCM::Util::TaskRunner',
);

# Alias
my $E = 'FCM::Util::Exception';

# Regular expression: match a URI
my $RE_URI = qr/
    \A              (?# start)
    (               (?# capture 1, scheme, start)
        [A-Za-z]    (?# alpha)
        [\w\+\-\.]* (?# optional alpha, numeric, plus, minus and dot)
    )               (?# capture 1, scheme, end)
    :               (?# colon)
    (.*)            (?# capture 2, opaque, rest of string)
    \z              (?# end)
/xms;

# Creates the class.
__PACKAGE__->class(
    {   cfg_basename_of   => {isa => '%', default => {%CFG_BASENAME_OF}},
        conf_paths        => {isa => '@', default => [@CONF_PATHS]},
        event             => '&',
        external_value_of => {isa => '%', default => {%EXTERNAL_VALUE_OF}},
        ns_sep            => {isa => '$', default => $NS_SEP},
        util_class_of     => {isa => '%', default => {%UTIL_CLASS_OF}},
        util_of           => '%',
    },
    {init => \&_init, action_of => \%ACTION_OF},
);

# Initialises attributes.
sub _init {
    my ($attrib_ref, $self) = @_;
    # Initialise the utilities
    while (my ($key, $util_class) = each(%{$attrib_ref->{util_class_of}})) {
        if (!defined($attrib_ref->{util_of}{$key})) {
            _class_load($attrib_ref, $util_class);
            $attrib_ref->{util_of}{$key} = $util_class->new({util => $self});
        }
    }
    if (exists($ENV{FCM_CONF_PATH})) {
        $attrib_ref->{conf_paths} = [shellwords($ENV{FCM_CONF_PATH})];
    }
}

# Loads the named configuration from its configuration files.
sub _cfg_init {
    my ($attrib_ref, $basename, $action_ref) = @_;
    if (exists($ENV{FCM_CONF_PATH})) {
        $attrib_ref->{conf_paths} = [shellwords($ENV{FCM_CONF_PATH})];
    }
    for my $path (
        grep {-f} map {catfile($_, $basename)} @{$attrib_ref->{conf_paths}}
    ) {
        my $config_reader = $ACTION_OF{config_reader}->(
            $attrib_ref, FCM::Context::Locator->new($path),
        );
        $action_ref->($config_reader);
    }
}

# Loads a class/package.
sub _class_load {
    my ($attrib_ref, $name, $test_method) = @_;
    $test_method ||= 'new';
    if (!UNIVERSAL::can($name, $test_method)) {
        eval('require ' . $name);
        if (my $e = $@) {
            return $E->throw($E->CLASS_LOADER, $name, $e);
        }
    }
    return $name;
}

# Invokes an event.
sub _event {
    my ($attrib_ref, $event, @args) = @_;
    if (!blessed($event)) {
        $event = FCM::Context::Event->new({code => $event, args => \@args}),
    }
    $attrib_ref->{'util_of'}{'event'}->main($event);
}

# Returns the value of an external tool.
{   my $EXTERNAL_CFG_INIT;
    sub _external_cfg_get {
        my ($attrib_ref, $key) = @_;
        my $value_hash_ref = $attrib_ref->{external_value_of};
        if (!$EXTERNAL_CFG_INIT) {
            $EXTERNAL_CFG_INIT = 1;
            _cfg_init(
                $attrib_ref,
                $attrib_ref->{cfg_basename_of}{external},
                sub {
                    my $config_reader = shift();
                    while (defined(my $entry = $config_reader->())) {
                        my $k = $entry->get_label();
                        if ($k && exists($value_hash_ref->{$k})) {
                            $value_hash_ref->{$k} = $entry->get_value();
                        }
                    }
                }
            );
        }
        if (!$key || !exists($value_hash_ref->{$key})) {
            return;
        }
        return $value_hash_ref->{$key};
    }
}

# Returns the checksum of the content in a file system path.
sub _file_checksum {
    my ($attrib_ref, $path, $algorithm) = @_;
    my $handle = _file_load_handle($attrib_ref, $path);
    binmode($handle);
    $algorithm ||= 'md5';
    my $digest = $algorithm eq 'md5'
        ? Digest::MD5->new() : Digest::SHA->new($algorithm);
    $digest->addfile($handle);
    my $checksum = $digest->hexdigest();
    close($handle);
    return $checksum;
}

# Returns the file extension of a file system path.
sub _file_ext {
    my ($attrib_ref, $path) = @_;
    my $pos_of_dot = rindex($path, q{.});
    if ($pos_of_dot == -1) {
        return (wantarray() ? (undef, $path) : undef);
    }
    my $ext = substr($path, $pos_of_dot + 1);
    wantarray() ? ($ext, substr($path, 0, $pos_of_dot)) : $ext;
}

# Loads the first $n lines from a file system path.
sub _file_head {
    my ($attrib_ref, $path, $n) = @_;
    $n ||= 1;
    my $handle = _file_load_handle(@_);
    my $content = q{};
    for (1 .. $n) {
        $content .= readline($handle);
    }
    close($handle);
    (wantarray() ? (map {$_ . "\n"} split("\n", $content)) : $content);
}

# Loads the contents from a file system path.
sub _file_load {
    my ($attrib_ref, $path) = @_;
    my $handle = _file_load_handle(@_);
    my $content = do {local($/); readline($handle)};
    close($handle);
    (wantarray() ? (map {$_ . "\n"} split("\n", $content)) : $content);
}

# Opens a file handle to read from a file system path.
sub _file_load_handle {
    my ($attrib_ref, $path) = @_;
    open(my($handle), '<', $path) || return $E->throw($E->IO, $path, $!);
    $handle;
}

# Returns the MD5 checksum of the content in a file system path.
sub _file_md5 {
    my ($attrib_ref, $path) = @_;
    _file_checksum($attrib_ref, $path, 'md5');
}

# Saves content to a file system path.
sub _file_save {
    my ($attrib_ref, $path, $content) = @_;
    if (!-e dirname($path)) {
        eval {mkpath(dirname($path))};
        if (my $e = $@) {
            return $E->throw($E->IO, $path, $e);
        }
    }
    open(my($handle), '>', $path) || return $E->throw($E->IO, $path, $!);
    if (ref($content) && ref($content) eq 'ARRAY') {
        print($handle @{$content}) || return $E->throw($E->IO, $path, $!);
    }
    else {
        print($handle $content) || return $E->throw($E->IO, $path, $!);
    }
    close($handle) || return $E->throw($E->IO, $path, $!);
}

# Expand leading ~ and ~USER syntax in $path and return the resulting string.
sub _file_tilde_expand {
    my ($attrib_ref, $path) = @_;
    $path =~ s{\A~([^/]*)}{$1 ? (getpwnam($1))[7] : (getpwuid($<))[7]}exms;
    return $path;
}

# Compares contents of 2 HASH references.
sub _hash_cmp {
    my ($attrib_ref, $hash_1_ref, $hash_2_ref, $keys_only) = @_;
    my %hash_2 = %{$hash_2_ref};
    my %modified;
    while (my ($key, $v1) = each(%{$hash_1_ref})) {
        if (exists($hash_2{$key})) {
            my $v2 = $hash_2{$key};
            if (    !$keys_only
                &&  (
                        defined($v1) && defined($v2) && $v1 ne $v2
                    ||  defined($v1) && !defined($v2)
                    ||  !defined($v1) && defined($v2)
                )
            ) {
                $modified{$key} = 0;
            }
            delete($hash_2{$key});
        }
        else {
            $modified{$key} = -1;
        }
    }
    while (my $key = each(%hash_2)) {
        if (!exists($hash_1_ref->{$key})) {
            $modified{$key} = 1;
        }
    }
    return %modified;
}

# Concatenates 2 name-spaces.
sub _ns_cat {
    my ($attrib_ref, @ns_list) = @_;
    join(
        $attrib_ref->{ns_sep},
        grep {$_ && $_ ne $attrib_ref->{ns_sep}} @ns_list,
    );
}

# Returns the common parts of 2 name-spaces.
sub _ns_common {
    my ($attrib_ref, $ns1, $ns2) = @_;
    my $iter1 = _ns_iter($attrib_ref, $ns1);
    my $iter2 = _ns_iter($attrib_ref, $ns2);
    my $common_ns = q{};
    while (defined(my $s1 = $iter1->()) && defined(my $s2 = $iter2->())) {
        if ($s1 ne $s2) {
            return $common_ns;
        }
        $common_ns = $s1;
    }
    return $common_ns;
}

# Returns true if $ns is in one of the name-spaces given by keys(%set).
sub _ns_in_set {
    my ($attrib_ref, $ns, $ns_set_ref) = @_;
    if (!keys(%{$ns_set_ref})) {
        return;
    }
    my @ns_list;
    my $ns_iter = _ns_iter($attrib_ref, $ns);
    while (defined(my $n = $ns_iter->())) {
        push(@ns_list, $n);
    }
    grep {exists($ns_set_ref->{$_})} @ns_list;
}

# Returns an iterator to walk up/down a name-space.
sub _ns_iter {
    my ($attrib_ref, $ns, $up) = @_;
    if ($ns eq $attrib_ref->{ns_sep}) {
        $ns = q{};
    }
    my @give = split($attrib_ref->{ns_sep}, $ns);
    my @take = ();
    my $next = q{};
    if ($up) {
        @give = reverse(@give);
        $next = $ns;
    }
    sub {
        my $ret = $next;
        $next = undef;
        if (@give) {
            push(@take, shift(@give));
            $next = join($attrib_ref->{ns_sep}, ($up ? reverse(@give) : @take));
        }
        return $ret;
    };
}

# Returns a timer.
sub _timer {
    my ($attrib_ref, $start_ref) = @_;
    $start_ref ||= [gettimeofday()];
    sub {tv_interval($start_ref)};
}

# Matches a URI.
sub _uri_match {
    my ($attrib_ref, $string) = @_;
    $string =~ $RE_URI;
}

# Returns a function to return/set the object in the "util_of" basket.
sub _util_impl_func {
    my ($id) = @_;
    sub {
        my ($attrib_ref, $value) = @_;
        if (defined($value) && ref($value) && reftype($value) eq 'CODE') {
            $attrib_ref->{'util_of'}{$id} = $value;
        }
        $attrib_ref->{'util_of'}{$id};
    };
}

# Returns a function to delegate a method to a utility in the "util_of" basket.
sub _util_of_func {
    my ($id, $method) = @_;
    sub {
        my $attrib_ref = shift();
        $attrib_ref->{util_of}{$id}->(($method ? ($method) : ()), @_);
    };
}

# Returns a function to delegate a method to the locator utility.
{   my $KEYWORD_CFG_INIT;
    sub _util_of_loc_func {
        my ($method) = @_;
        sub {
            my $attrib_ref = shift();
            if (!$KEYWORD_CFG_INIT) {
                $KEYWORD_CFG_INIT = 1;
                my $config_upgrade = FCM::Util::ConfigUpgrade->new();
                for my $path (grep {-f} @FCM1_KEYWORD_FILES) {
                    my $config_reader = $ACTION_OF{config_reader}->(
                        $attrib_ref,
                        FCM::Context::Locator->new($path),
                        \%FCM::Util::ConfigReader::FCM1_ATTRIB,
                    );
                    $ACTION_OF{loc_kw_ctx_load}->(
                        $attrib_ref,
                        sub {$config_upgrade->upgrade($config_reader->())},
                    );
                }
                _cfg_init(
                    $attrib_ref,
                    $attrib_ref->{cfg_basename_of}{keyword},
                    sub {$ACTION_OF{loc_kw_ctx_load}->($attrib_ref, @_)},
                );
            }
            $attrib_ref->{util_of}{locator}->($method, @_);
        };
    }
}

# Returns the FCM version string.
{   my $FCM_VERSION;
    sub _version {
        my ($attrib_ref) = @_;
        if (!defined($FCM_VERSION)) {
            my $fcm_home = dirname($FindBin::Bin);
            # Try "git describe"
            my $value_hash_ref = eval {
                $ACTION_OF{shell_simple}->(
                    $attrib_ref,
                    ['git', "--git-dir=$FindBin::Bin/../.git", 'describe'],
                );
            };
            if (my $e = $@) {
                if (!$E->caught($e)) {
                    die($e);
                }
                $@ = undef;
            }
            my $version;
            if ($value_hash_ref->{o} && !$value_hash_ref->{rc}) {
                chomp($value_hash_ref->{o});
                $version = $value_hash_ref->{o};
            }
            else {
                # Read fcm-version.js file
                my $path = catfile($fcm_home, qw{doc etc fcm-version.js});
                open(my($handle), '<', $path) || die("$path: $!");
                my $content = do {local($/); readline($handle)};
                close($handle);
                ($version) = $content =~ qr{\AFCM\.VERSION="(.*)";}msx;
            }
            $FCM_VERSION = sprintf("%s (%s)", $version, $fcm_home);
        }
        return $FCM_VERSION;
    }
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Util

=head1 SYNOPSIS

    use FCM::Util;
    $u = FCM::Util->new();
    $u->class_load('Foo');

=head1 DESCRIPTION

Utilities used by the FCM system.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Returns a new instance. The %attrib hash can be used configure the behaviour of
the instance:

=over 4

=item conf_paths

The search paths to the configuration files. The default is the value in
@FCM::Util::CONF_PATHS.

=item cfg_basename_of

A HASH to map the named configuration with the base names of their paths.
(default=%CFG_BASENAME_OF)

=item external_value_of

A HASH to map the named external tools with their default values.
(default=%EXTERNAL_VALUE_OF)

=item event

A CODE to handle event.

=item ns_sep

The name space separator. (default=/)

=item util_class_of

A HASH to map (keys) utility names to (values) their implementation classes. See
%FCM::System::UTIL_CLASS_OF.

=item util_of

A HASH to map (keys) utility names to (values) their implementation instances.

=back

=item $u->cfg_init($basename,\&action)

Search site/user configuration given by $basename. Invoke the callback
&action($config_reader) for each configuration file found.

=item $u->class_load($name,$test_method)

If $name can call $test_method, returns $name. (If $test_method is not defined,
the default is "new".) Otherwise, calls require($name). Returns $name.

=item $u->config_reader($locator,\%reader_attrib)

Returns an iterator for getting the configuration entries from $locator (which
should be an instance of L<FCM::Context::Locator|FCM::Context::Locator>.

The iterator returns the next useful entry of the configuration file as an
object of L<FCM::Context::ConfigEntry|FCM::Context::ConfigEntry>. It returns
under if there is no more useful entry to return.

The %reader_attrib may be used to override the default attributes. The HASH
should contain a {parser} and a {processor}. The {parser} is a CODE reference to
parse a declaration in the configuration file into an entry. The {processor} is
a CODE reference to process the entry. If the {processor} returns true, the
entry is considered a special entry (e.g. a variable declaration or an
C<include> declaration) that is processed, and will not be returned by the
iterator.

The %reader_attrib can be defined using the following pre-defined sets:

=over 4

=item %FCM::Util::ConfigReader::FCM1_ATTRIB

Using this will generate a reader for configuration files written in the FCM 1
format.

=item %FCM::Util::ConfigReader::FCM2_ATTRIB

Using this will generate a reader for configuration files written in the FCM 2
format. (default)

=back

In addition, $reader_attrib{event_level} can be used to adjust the event
verbosity level.

The parser and the processor are called with a %state, which contains the
current state of the reader, and has the following elements:

=over 4

=item cont

This is set to true if there is a continue marker at the end of the current
line. The next line should be parsed as part of the current context.

=item ctx

The context of the current entry, which should be an instance of
L<FCM::Context::ConfigEntry|FCM::Context::ConfigEntry>.

=item line

The content of the current line.

=item stack

An ARRAY reference that represents an include stack. The top of the stack
(the final element) represents the most current file being read. An include file
will be put on top of the stack, and removed when EOF is reached. When the stack
is empty, the iterator is exhausted.

Each element of the stack is an 4-element ARRAY reference. Element 1 is the
L<FCM::Context::Locator|FCM::Context::Locator> object that represents the
current file. Element 2 is the line number of the current file. Element 3 is the
file handle for reading the current file. Element 4 is a CODE reference with an
interface $f->($path), for turning $path from a relative location under the
container of the current file into an absolute location.

=item var

A HASH reference containing the variables (from the environment and local to the
configuration file) that can be used for substitution.

=back

=item $u->external_cfg_get($key)

Returns the value of a named tool.

=item $u->event($event,@args)

Raises an event. The 1st argument $event can either be a blessed reference of
L<FCM::Context::Event|FCM::Context::Event> or a valid event code. If the former
is true, @args is not used, otherwise, @args should be the event arguments for
the specified event code.

=item $u->file_checksum($path, $algorithm)

Returns the checksum of $path. If $algorithm is not specified, the default
algorithm to use is MD5. Otherwise, any algorithm supported by Perl's
Digest::SHA module can be used.

=item $u->file_ext($path)

Returns file extension of $path. E.g.:

    my $path = '/foo/bar.baz';
    my $extension = $u->file_ext($path); # 'baz'
    my ($extension, $root) = $u->file_ext($path); # ('baz', '/foo/bar')

=item $u->file_head($path, $n)

Loads $n lines (or 1 line if $n not specified) from a $path in the file system.
In scalar context, returns the content in a scalar. In list context, separate
the content by the new line character "\n", and returns the resulting list.

=item $u->file_load($path)

Loads contents from a $path in the file system. In scalar context, returns the
content in a scalar. In list context, separate the content by the new line
character "\n", and returns the resulting list.

=item $u->file_load_handle($path)

Returns a file handle for loading contents from $path.

=item $u->file_md5($path)

Deprecated. Equivalent to $u->file_checksum($path, 'md5').

=item $u->file_save($path, $content)

Saves $content to a $path in the file system.

=item $u->file_tilde_expand($path)

Expand any leading "~" or "~USER" syntax to the HOME directory of the current
user or the HOME directory of USER. Return the modified string.

=item $u->hash_cmp(\%hash_1,\%hash_2,$keys_only)

Compares the contents of 2 HASH references. If $keys_only is specified, only
compares the keys. Returns a HASH where each element represents a difference
between %hash_1 and %hash_2 - if the value is positive, the key exists in
%hash_2 but not %hash_1, if the value is negative, the key exists in %hash_1 but
not %hash_2, and if the value is zero, the key exists in both, but the values
are different.

=item $u->loc_as_invariant($locator)

If the $locator->get_value_level() is below FCM::Context::Locator->L_INVARIANT,
determines the invariant value of $locator, and sets its value to the result.
Returns $locator->get_value(). 

See L<FCM::Context::Locator|FCM::Context::Locator> for information on locator
value level.

=item $u->loc_as_keyword($locator)

Calls $u->loc_as_normalised($locator) if $locator->get_value_level() is below
FCM::Context::Locator->L_NORMALISED. Returns the value of the locator as an FCM
keyword, where possible.

=item $u->loc_as_normalised($locator)

If the $locator->get_value_level() is below FCM::Context::Locator->L_NORMALISED,
determines the normalised value of $locator, and sets its value to the result.
Returns $locator->get_value().

See L<FCM::Context::Locator|FCM::Context::Locator> for information on locator
value level.

=item $u->loc_as_parsed($locator)

If the $locator->get_value_level() is below FCM::Context::Locator->L_PARSED,
determines the parsed value of $locator, and sets its value to the result.
Returns $locator->get_value().

See L<FCM::Context::Locator|FCM::Context::Locator> for information on locator
value level.

=item $u->loc_browser_url($locator)

Calls $u->loc_as_normalised($locator) if $locator->get_value_level() is below
FCM::Context::Locator->L_NORMALISED. Returns the value of the locator as a
browser URL, where possible.

=item $u->loc_cat($locator,@paths)

Calls $u->loc_as_parsed($locator) if $locator->get_value_level() is below
FCM::Context::Locator->L_PARSED. Concatenates the value of the $locator with the
given @paths according to the $locator type. Returns a new FCM::Context::Locator
that represents the concatenated value.

=item $u->loc_dir($locator)

Calls $u->loc_as_parsed($locator) if $locator->get_value_level() is below
FCM::Context::Locator->L_PARSED. Determines the "directory" name of the value of
the $locator according to the $locator type. Returns a new FCM::Context::Locator
that represents the resulting value.

=item $u->loc_exists($locator)

Calls $u->loc_as_normalised($locator) if $locator->get_value_level() is below
FCM::Context::Locator->L_NORMALISED. Return a true value if the location
represented by $locator exists.

=item $u->loc_export($locator,$dest)

Calls $u->loc_as_normalised($locator) if $locator->get_value_level() is below
FCM::Context::Locator->L_NORMALISED. Exports the file or directory tree
represented by $locator to a file system $dest.

=item $u->loc_export_ok($locator)

Calls $u->loc_as_parsed($locator) if $locator->get_value_level() is below
FCM::Context::Locator->L_PARSED. Returns true if it is possible and safe to
call $u->loc_export($locator).

=item $u->loc_find($locator,\&callback)

Searches the directory tree of $locator. Invokes &callback for each node with
the following interface:

    $callback_ref->($locator_of_child_node, \%target_attrib);

where %target_attrib contains the keys:

=over 4

=item {is_dir}

This is set to true if the child node is a directory.

=item {last_modified_rev}

This is set to the last modified revision of the child node, if relevant.

=item {last_modified_time}

This is set to the last modified time of the child node.

=item {ns}

This is set to the relative name-space (i.e. the relative path) of the child
node.

=back

=item $u->loc_kw_ctx()

Returns the keyword context (an instance of FCM::Context::Keyword).

=item $u->loc_kw_ctx_load(@config_entry_iterators)

Loads configuration entries into the keyword context. The
@config_entry_iterators should be a list of CODE references, with the following
calling interfaces:

    while (my $config_entry = $config_entry_iterator->()) {
        # ... $config_entry should be an instance of FCM::Context::ConfigEntry
    }

=item $u->loc_kw_iter($locator)

Returns an iterator. When called, the iterator returns location keyword entry
context (as an instance of
L<FCM::Context::Keyword::Entry::Location|FCM::Context::Keyword>) for $locator
until exhausted.

    my $iterator = $u->loc_kw_iter($locator)
    while (my $kw_ctx_entry = $iterator->()) {
        # ... do something with $kw_ctx_entry
    }

=item $u->loc_kw_load_rev_prop($entry)

Loads the revision keywords to $entry
(L<FCM::Context::Keyword::Entry::Location|FCM::Context::Keyword>), assuming that
$entry is not an implied location keyword, and that the keyword locator points
to a VCS location that supports setting up revision keywords in properties.

=item $u->loc_kw_prefix()

Returns the prefix of a FCM keyword. This should be "fcm".

=item $u->loc_origin($locator)

Calls $u->loc_as_parsed($locator) if $locator->get_value_level() is below
FCM::Context::Locator->L_PARSED. Determines the origin of $locator, and returns
a new FCM::Context::Locator that represents the result. E.g. if $locator points
to a Subversion working copy, it returns a new locator that represents the URL
of the working copy.

=item $u->loc_reader($locator)

Calls $u->loc_as_normalised($locator) if $locator->get_value_level() is below
FCM::Context::Locator->L_NORMALISED. Returns a file handle for reading the
content from $locator.

=item $u->loc_rel2abs($locator,$locator_base)

If the value of $locator is a relative path, sets it to an absolute path base on
the $locator_base, provided that $locator and $locator_base is the same type.

=item $u->loc_trunk_at_head($locator)

Returns a string to represent the relative path to the latest main tree, if it
is relevant for $locator.

=item $u->loc_what_type($locator)

Sets $locator->get_type() and returns its value. Currently, this can either be
"svn" for a locator pointing to a Subversion resource or "fs" for a locator
pointing to a file system resource.

=item $u->loc_up_iter($locator)

Returns an iterator that walks up the hierarchy of the $locator, according to
its type.

=item $u->ns_cat(@name_spaces)

Concatenates name-spaces and returns the result.

=item $u->ns_common($ns1,$ns2)

Returns the common parts of 2 name-spaces. For example, if $ns1 is
"egg/ham/bacon" and $ns2 is "egg/ham/sausage", it should return "egg/ham".

=item $u->ns_in_set($ns,\%set)

Returns true if $ns is in a name-space given by the keys of %set.

=item $u->ns_iter($ns,$up)

Returns an iterator that walks up or down a name-space. E.g.:

    $iter_ref = $u->ns_iter('a/bee/cee', $u->NS_ITER_UP);
    while (defined(my $item = $iter_ref->())) {
        print("[$item]");
    }
    # should print: [a/bee/cee][a/bee][a][]

    $iter_ref = $u->ns_iter('a/bee/cee');
    while (defined(my $item = $iter_ref->())) {
        print("[$item]");
    }
    # should print: [][a][a/bee][a/bee/cee]

=item $u->ns_sep()

Returns the name-space separator, (i.e. normally "/").

=item $u->report(\%option,$message)

Reports messages using $u->util_of_report(). The default is an instance of
L<FCM::Util::Reporter|FCM::Util::Reporter>. See
L<FCM::Util::Reporter|FCM::Util::Reporter> for detail.

=item $u->shell($command,\%action_of)

Invokes the $command, which can be scalar or a reference to an ARRAY. If a
scalar is specified, it will be separated into an array using the shellwords()
function in L<Text::ParseWords|Text::ParseWords>. If it is a reference to an
ARRAY, the ARRAY will be passed to open3() as is.

The %action_of should contain the actions for i: standard input, e: standard
error output and o: standard output. The default for each of these is an
anonymous subroutinue that does nothing.

Each time the pipe to the child standard input is available for writing, it will
call $action_of{i}->(). If it returns a defined value, the value will be written
to the pipe. If it returns undef, the pipe will be closed.

Each time the pipe from the child standard (error) output is available for
reading, it will read some values to a buffer, and invoke the callback
$action_of{o}->($buffer) (or $action_of{e}->($buffer)). The return value of the
callback will be ignored.

On normal completion, it returns the status code of the command and raises an
FCM::Context::Event->SHELL event:

Any abnormal failure will cause an instance of FCM::Util::Exception to be
thrown. (The return of a non-zero status code by the child is considered a
normal completion.)

=item $u->shell_simple($command)

Wraps $u->shell(), and returns a HASH reference containing {e} (the
standard error), {o} (the standard output) and {rc} (the return code).

=item $u->shell_which($name)

Returns the full path of an executable command $name if it can be found in the
system PATH.

=item $u->task_runner($action_code_ref,$n_workers)

Returns a runner of tasks. It can be configured to work in serial (default) or
parallel. The runner has the following methods:

    $n_done = $runner->main($get_code_ref,$put_code_ref);
    $runner->destroy();

For each $task (L<FCM::Context::Task|FCM::Context::Task>) returned by the
$get_code_ref->() iterator, invokes $action_ref->($task->get_ctx()). When
$action_ref returns, send the $task back to the caller by calling
$put_code_ref->($task). When it is done, the runner returns the number of tasks
it has done.

The $runner->destroy() method should be called to destroy the $runner when it is
not longer used.

=item $u->timer(\@start)

Returns a CODE reference, which can be called to return the elapsed time. The
@start argument is optional. If specified, it should be in a format as returned
by Time::HiRes::gettimeofday(). If not specified, the current gettimeofday() is
used.

=item $u->uri_match($string)

Returns true if $string is a URI. In array context, returns the scheme and the
opague part of the URI if $string is a URI, or an empty list otherwise.

=item $u->util_of_event($value)

Returns and/or sets the L<FCM::Util::Event|FCM::Util::Event> object that is used
to handle the $u->report() method.

=item $u->util_of_report($value)

Returns and/or sets the L<FCM::Util::Reporter|FCM::Util::Reporter> object that
is used to handle the $u->report() method.

=item $u->version()

Returns the FCM version string in the form C<VERSION (BIN)> where VERSION is the
version string returned by "git describe" or the version file and BIN is
absolute path of the "fcm" command.

=back

=head1 DIAGNOSTICS

=head2 FCM::Util::Exception

This exception is a sub-class of L<FCM::Exception|FCM::Exception> and is thrown
by methods of this class on error.

=head1 COPYRIGHT

Copyright (C) 2006-2019 British Crown (Met Office) & Contributors..

=cut
