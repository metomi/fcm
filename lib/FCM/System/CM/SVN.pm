#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------
use strict;
use warnings;

#-------------------------------------------------------------------------------
package FCM::System::CM::SVN;
use base qw{FCM::Class::CODE};

use Cwd qw{cwd};
use FCM::Context::Event;
use FCM::Context::Locator;
use FCM::System::Exception;
use File::Basename qw{dirname};
use File::Spec::Functions qw{catfile rel2abs};
use HTTP::Date qw{str2time};
use XML::Parser;

my $E = 'FCM::System::Exception';

# Settings for the default repository layout
our %LAYOUT_CONFIG = (
    'depth-project' => undef,
    'depth-branch' => 3,
    'depth-tag' => 1,
    'dir-trunk' => 'trunk',
    'dir-branch' => 'branches',
    'dir-tag' => 'tags',
    'level-owner-branch' => 2,
    'level-owner-tag' => undef,
    'template-branch' => '{category}/{owner}/{name_prefix}{name}',
    'template-tag' => undef,
);

# Layout configuration file basename
our $LAYOUT_CFG_BASE = 'svn-repos-layout.cfg';

# "svn log --xml" handlers.
# -> element node start tag handlers
my %SVN_LOG_ELEMENT_START_HANDLER_FOR = (
#   tag        => handler
    'logentry' => \&_get_log_handle_element_enter_logentry,
    'path'     => \&_get_log_handle_element_enter_path,
);
# -> text node (after a start tag) handlers
my %SVN_LOG_TEXT_HANDLER_FOR = (
#   tag    => handler
    'date' => \&_get_log_handle_text_date,
    'path' => \&_get_log_handle_text_path,
);

my %ACTION_OF = (
    'call'        => \&_call,
    'get_info'    => \&_get_info,
    'get_layout'  => \&_get_layout,
    'get_list'    => \&_get_list,
    'get_log'     => \&_get_log,
    'get_wc_root' => \&_get_wc_root,
    'split_by_peg'=> \&_split_by_peg,
    'stdout'      => \&_stdout,
);

# Creates the class.
__PACKAGE__->class(
    {   layout_cfg_base => {isa => '$', default => $LAYOUT_CFG_BASE},
        layout_config_of=> '%',
        util            => '&',
    },
    {action_of => \%ACTION_OF},
);

# Calls "svn".
sub _call {
    my ($attrib_ref, @args) = @_;
    my @command = ('svn', @args);
    my $timer = $attrib_ref->{util}->timer();
    my $rc = system(@command);
    $attrib_ref->{util}->event(
        FCM::Context::Event->SHELL, \@command, $rc, $timer->());
    if ($rc) {
        $rc = $? == -1 ? $!
            : $? & 127 ? $? & 127
            :            $? >> 8
            ;
        return $E->throw($E->SHELL, {command_list => \@command, rc => $rc});
    }
    return;
}

# Invokes "svn info --xml @paths", and returns a LIST of info entries.
sub _get_info {
    my $attrib_ref = shift();
    my %option = ('recursive' => undef, 'revision' => undef);
    if (@_ && ref($_[0]) && ref($_[0]) eq 'HASH') {
        %option = (%option, %{shift()});
    }
    my @paths = @_;
    if (!@paths) {
        @paths = (q{.});
    }
    my (@entries, @stack);
    my $parser = XML::Parser->new(Handlers => {
        'Start' => sub {_get_info_handle_element_enter(\@entries, \@stack, @_)},
        'End'   => sub {_get_info_handle_element_leave(\@entries, \@stack, @_)},
        'Char'  => sub {_get_info_handle_text(         \@entries, \@stack, @_)},
    });
    $parser->parse(scalar(_stdout(
        $attrib_ref,
        qw{info --xml},
        ($option{'recursive'} ? '--recursive' : ()),
        ($option{'revision'} ? ('--revision', $option{'revision'}) : ()),
        @paths,
    )));
    \@entries;
}

# Helper for _get_info. Handle the start tag of an XML element.
sub _get_info_handle_element_enter {
    my ($entries_ref, $stack_ref, $expat, $tag, %attrib) = @_;
    # "entry": create a new entry in the list
    if ($tag eq 'entry') {
        push(@{$entries_ref}, {});
    }
    # "tree-conflict:version": need to handle differently
    if (    $tag eq 'version'
        &&  @{$stack_ref}
        &&  $stack_ref->[-1] eq 'tree-conflict'
    ) {
        my (undef, undef, @names) = @{$stack_ref};
        push(@names, delete($attrib{side}));
        while (my ($key, $value) = each(%attrib)) {
            my $name = join(':', @names, $key);
            $entries_ref->[-1]->{$name} = delete($attrib{$key});
        }
    }
    # Add current tag to stack
    push(@{$stack_ref}, $tag);
    # Add attributes to current entry, if appropriate
    if (@{$entries_ref} && @{$stack_ref} >= 2 && %attrib) {
        my (undef, undef, @names) = @{$stack_ref};
        while (my ($key, $value) = each(%attrib)) {
            my $name = join(':', @names, $key);
            $entries_ref->[-1]->{$name} = $value;
        }
    }
}

# Helper for _get_info. Handle the end tag of an XML element.
sub _get_info_handle_element_leave {
    my ($entries_ref, $stack_ref, $expat, $tag) = @_;
    pop(@{$stack_ref}) eq $tag;
}

# Helper for _get_info. Handle an XML text node.
sub _get_info_handle_text {
    my ($entries_ref, $stack_ref, $expat, $text) = @_;
    if (@{$stack_ref} <= 2 || !@{$entries_ref} || $text eq "\n") {
        return;
    }
    my (undef, undef, @names) = @{$stack_ref};
    my $name = join(':', @names);
    $entries_ref->[-1]->{$name} .= $text;
}

# Return an object containing the repository layout information of a URL.
sub _get_layout {
    my ($attrib_ref, $url_arg) = @_;
    my %info = %{_get_info($attrib_ref, $url_arg)->[0]};
    my ($url, $root, $peg_rev) = @info{'url', 'repository:root', 'revision'};
    my $path = substr($url, length($root));
    my %layout_config = _load_layout_config($attrib_ref, $root);
    my ($project, $branch, $category, $owner, $sub_tree);
    my @paths = split(qr{/+}msx, $path);
    shift(@paths); # element 1 should be an empty string
    # Search for the project
    my $depth = $layout_config{'depth-project'};
    if (defined($depth)) {
        if (@paths >= $depth) {
            my @project_paths = ();
            for (1 .. $layout_config{'depth-project'}) {
                push(@project_paths, shift(@paths));
            }
            $project = join('/', @project_paths);
        }
    }
    elsif (!grep {!defined($layout_config{"dir-$_"})} qw{trunk branch tag}) {
        # trunk, branches and tags are ALL in specific sub-directories under
        # the project
        my @dirs = map {$layout_config{"dir-$_"}} qw{trunk branch tag};
        my @head = ();
        my @tail = @paths;
        while (my $path = shift(@tail)) {
            if (grep {$_ eq $path} @dirs) {
                $project = join('/', @head);
                @paths = ($path, @tail);
                last;
            }
            push(@head, $path);
        }
        if (!defined($project)) {
            # $path does not contain the specific sub-directories that
            # contain the trunk, branches and tags, but $path itself may be
            # the project
            my $target
                = $url . '/' .  $layout_config{'dir-trunk'} . '@' . $peg_rev;
            my $target_url
                = eval {_get_info($attrib_ref, $target)->[0]->{url}};
            $@ = undef;
            if ($target_url) {
                $project = join('/', @paths);
            }
            @paths = ();
        }
    }
    else {
        # Can only assume that trunk is in a specific sub-directory under the
        # project
        my @head = ();
        my @tail = @paths;
        while (my $path = shift(@tail)) {
            if ($path eq $layout_config{'dir-trunk'}) {
                $project = join('/', @head);
                @paths = ($path, @tail);
                last;
            }
            push(@head, $path);
        }
        if (!defined($project)) {
            # $path does not contain the trunk sub-directory, need to search
            # for it 
            my @head = ();
            my @tail = @paths;
            while (@head <= @paths) {
                my $target
                    = join('/', $root, @head, $layout_config{'dir-trunk'})
                    . '@' . $peg_rev;
                my $target_url
                    = eval {_get_info($attrib_ref, $target)->[0]->{url}};
                $@ = undef;
                if ($target_url) {
                    $project = join('/', @head);
                    @paths = @tail;
                    last;
                }
                push(@head, shift(@tail));
            }
        }
    }
    # Search for the branch
    if (defined($project) && @paths) {
        KEY:
        for my $key (qw{trunk branch tag}) {
            my @branch_paths;
            if ($layout_config{"dir-$key"}) {
                if ($paths[0] eq $layout_config{"dir-$key"}) {
                    @branch_paths = (shift(@paths));
                }
                else {
                    next KEY;
                }
            }
            my $depth = $layout_config{"depth-$key"}
                ? $layout_config{"depth-$key"} : 0;
            if (@paths >= $depth) {
                for my $i (1 .. $depth) {
                    my $path = shift(@paths);
                    push(@branch_paths, $path);
                    if (    $layout_config{"level-owner-$key"}
                        &&  $layout_config{"level-owner-$key"} == $i
                    ) {
                        $owner = $path;
                    }
                }
                $branch = join('/', @branch_paths);
                $category = $key;
            }
            last KEY;
        }
    }
    # Remainder is the sub-tree under the branch
    if (defined($branch)) {
        $sub_tree = join('/', @paths);
    }
    FCM::System::CM::SVN::Layout->new({
        config          => \%layout_config,
        url             => $root . $path . '@' . $peg_rev,
        root            => $root, 
        path            => $path, 
        peg_rev         => $peg_rev, 
        project         => $project, 
        branch          => $branch, 
        branch_category => $category, 
        branch_owner    => $owner, 
        sub_tree        => $sub_tree,
    });
}

# Return a (filtered) recursive listing of $url_arg.
sub _get_list {
    my ($attrib_ref, $url_arg, $filter_func) = @_;
    my @list;
    my ($url0, $rev) = _split_by_peg($attrib_ref, $url_arg);
    my @items = ([$url0, 0]);
    while (my $item = shift(@items)) {
        my ($url, $depth) = @{$item};
        ++$depth;
        my @lines = _stdout($attrib_ref, 'list', $url . '@' . $rev);
        for my $line (@lines) {
            my ($this_name, $is_dir) = $line =~ qr{\A(.*?)(/?)\z};
            my $this_url = $url . '/' . $this_name ;
            my ($can_return, $can_recurse) = (1, $is_dir);
            if (defined($filter_func)) {
                ($can_return, $can_recurse)
                    = $filter_func->($this_url, $this_name, $is_dir, $depth);
            }
            if ($can_return) {
                push(@list, $this_url . '@' . $rev);
            }
            if ($can_recurse && $is_dir) {
                push(@items, [$this_url, $depth]);
            }
        }
    }
    @list;
}

# Invokes "svn log --xml".
sub _get_log {
    my $attrib_ref = shift();
    my %option = ('revision' => undef, 'stop-on-copy' => undef);
    if (@_ && ref($_[0]) && ref($_[0]) eq 'HASH') {
        %option = (%option, %{shift()});
    }
    my @paths = @_;
    if (!@paths) {
        @paths = (q{.});
    }
    my (@entries, @stack);
    my $parser = XML::Parser->new(Handlers => {
        'Start' => sub {_get_log_handle_element_enter(\@entries, \@stack, @_)},
        'End'   => sub {_get_log_handle_element_leave(\@entries, \@stack, @_)},
        'Char'  => sub {_get_log_handle_text(     \@entries, \@stack, @_)},
    });
    $parser->parse(scalar(_stdout(
        $attrib_ref,
        qw{log --xml -v},
        ($option{'revision'} ? ('--revision', $option{'revision'}) : ()),
        ($option{'stop-on-copy'} ? ('--stop-on-copy') : ()),
        @paths,
    )));
    \@entries;
}

# Helper for "_get_log", handle beginning of an XML element.
sub _get_log_handle_element_enter {
    my ($entries_ref, $stack_ref, $expat, $tag, %attrib) = @_;
    push(@{$stack_ref}, $tag);
    if (exists($SVN_LOG_ELEMENT_START_HANDLER_FOR{$tag})) {
        $SVN_LOG_ELEMENT_START_HANDLER_FOR{$tag}->(
            $entries_ref,
            $tag,
            %attrib,
        );
    }
}

# Helper for "_get_log", handle beginning of the "logentry" element.
sub _get_log_handle_element_enter_logentry {
    my ($entries_ref, $tag, %attrib) = @_;
    push(
        @{$entries_ref},
        {   'author'   => q{},
            'date'     => q{},
            'msg'      => q{},
            'paths'    => [],
            'revision' => $attrib{'revision'},
        },
    );
}

# Helper for "_get_log", handle beginning of the "path" element.
sub _get_log_handle_element_enter_path {
    my ($entries_ref, $tag, %attrib) = @_;
    push(@{$entries_ref->[-1]->{'paths'}}, {%attrib, 'path' => q{}});
}

# Helper for "_get_log", handle end of an element.
sub _get_log_handle_element_leave {
    my ($entries_ref, $stack_ref, $expat, $tag) = @_;
    pop(@{$stack_ref}) eq $tag;
}

# Helper for "_get_log", handle text node.
sub _get_log_handle_text {
    my ($entries_ref, $stack_ref, $expat, $text) = @_;
    if (!exists($stack_ref->[-1])) {
        return;
    }
    if (exists($SVN_LOG_TEXT_HANDLER_FOR{$stack_ref->[-1]})) {
        $SVN_LOG_TEXT_HANDLER_FOR{$stack_ref->[-1]}->($entries_ref, $text);
    }
    elsif ( @{$entries_ref}
        &&  exists($entries_ref->[-1]->{$stack_ref->[-1]})
        &&  !ref($entries_ref->[-1]->{$stack_ref->[-1]})
    ) {
        $entries_ref->[-1]->{$stack_ref->[-1]} .= $text;
    }
}

# Helper for "_get_log", handle text node in a "date" element.
sub _get_log_handle_text_date {
    my ($entries_ref, $text) = @_;
    $entries_ref->[-1]->{'date'} = str2time($text);
}

# Helper for "_get_log", handle text node in a "path" element.
sub _get_log_handle_text_path {
    my ($entries_ref, $text) = @_;
    $entries_ref->[-1]->{'paths'}->[-1]->{'path'} .= $text;
}

# Return path to the root working copy directory of the argument.
sub _get_wc_root {
    my ($attrib_ref, $path) = @_;
    $path ||= cwd();
    if (-f $path) {
        $path = dirname($path);
    }
    $path = rel2abs($path);
    my $return;
    if (-e catfile($path, qw{.svn entries})) {
        while (-e catfile($path, qw{.svn entries}) &&
               $path ne dirname($path)) {
            $return = $path;
            $path = dirname($path);
        }
    }
    else {
        while (! -e catfile($path, qw{.svn entries}) &&
               $path ne dirname($path)) {
            $path = dirname($path);
            $return = $path;
        }
    }
    return $return;
}

# Load layout related configuration for a given URL root.
sub _load_layout_config {
    my ($attrib_ref, $root) = @_;
    if (exists($attrib_ref->{layout_config_of}{$root})) {
        return %{$attrib_ref->{layout_config_of}{$root}};
    }
    my %site_layout_config;
    if (exists($attrib_ref->{layout_config_of}{q{}})) {
        %site_layout_config = %{$attrib_ref->{layout_config_of}{q{}}};
    }
    else {
        %site_layout_config = %LAYOUT_CONFIG;
        for my $path (
            grep {-f $_ && -r _}
                map {catfile($_, $attrib_ref->{layout_cfg_base})}
                    $attrib_ref->{util}->cfg_paths()
        ) {
            my $config_reader_ref = $attrib_ref->{util}->config_reader(
                FCM::Context::Locator->new($path),
            );
            my @unknown_entries;
            while (defined(my $entry = $config_reader_ref->())) {
                if (exists($site_layout_config{$entry->get_label()})) {
                    my $value
                        = $entry->get_value() ? $entry->get_value() : undef;
                    $site_layout_config{$entry->get_label()} = $value;
                }
                else {
                    push(@unknown_entries, $entry);
                }
            }
            if (@unknown_entries) {
                return $E->throw($E->CONFIG_UNKNOWN, \@unknown_entries);
            }
        }
        $attrib_ref->{layout_config_of}{q{}} = {%site_layout_config};
    }
    $attrib_ref->{layout_config_of}{$root} = {%site_layout_config};
    my @prop_lines = eval {_stdout($attrib_ref, 'propget', 'fcm:layout', $root)};
    if ($@) {
        $@ = undef;
    }
    PROP_LINE:
    while (defined(my $prop_line = shift(@prop_lines))) {
        chomp($prop_line);
        if ($prop_line =~ qr{\A\s*(?:\#|\z)}msx) { # comment line
            next PROP_LINE;
        }
        ($prop_line) = $prop_line =~ qr{\A\s*(.+?)\s*\z}msx; # trim
        my ($key, $value) = split(qr{\s*=\s*}msx, $prop_line, 2);
        if (exists($attrib_ref->{layout_config_of}{$root}{$key})) {
            $attrib_ref->{layout_config_of}{$root}{$key} = $value;
        }
    }
    %{$attrib_ref->{layout_config_of}{$root}};
}

# Splits a URL@REV by the @.
sub _split_by_peg {
    my ($attrib_ref, $url) = @_;
    $url =~ qr{\A(.*?)(?:@([^@/]+))?\z}msx;
}

# Calls "svn", return its standard output.
sub _stdout {
    my ($attrib_ref, @args) = @_;
    my @command = ('svn', @args);
    my %value_of = %{$attrib_ref->{util}->shell_simple(\@command)};
    if ($value_of{rc}) {
        return $E->throw(
            $E->SHELL,
            {command_list => \@command, %value_of}
        );
    }
    wantarray() ? split("\n", $value_of{o}) : $value_of{o};
}

#-------------------------------------------------------------------------------
# Represent the layout information of a Subversion URL.
package FCM::System::CM::SVN::Layout;
use base qw{FCM::Class::HASH};

__PACKAGE__->class({
    config          => '%',
    url             => '$',
    root            => '$',
    path            => '$',
    peg_rev         => '$',
    project         => '$',
    branch          => '$',
    branch_category => '$',
    branch_owner    => '$',
    sub_tree        => '$',
});

sub is_trunk {
    $_[0]->{branch_category} && $_[0]->{branch_category} eq 'trunk';
}

sub is_branch {
    $_[0]->{branch_category} && $_[0]->{branch_category} eq 'branch';
}

sub is_tag {
    $_[0]->{branch_category} && $_[0]->{branch_category} eq 'tag';
}

sub is_owned_by_user {
    my ($self, $user) = @_;
    $user ||= scalar(getpwuid($<));
    $self->{branch_owner} && $self->{branch_owner} eq $user;
}

sub is_shared {
    my ($self) = @_;
    $self->{branch_owner}
        && grep {$_ eq $self->{branch_owner}} qw{Share Config Rel};
}

sub as_string {
    my ($self) = @_;
    my $return = q{};
    for my $key (qw{
        url
        root
        path
        peg_rev
        project
        branch
        branch_category
        branch_owner
        sub_tree
    }) {
        my $value = $self->{$key};
        if ($key ne 'config' && defined($value)) {
            $return .= "$key: $value\n";
        }
    }
    return $return;
}

1;
__END__

=head1 NAME

FCM::System::CM::SVN

=head1 DESCRIPTION

Part of L<FCM::System::CM|FCM::System::CM>. Provides an interface for common SVN
functionalities used in the FCM CM sub-system.

=head1 METHODS

This is a sub-class of L<FCM::Class::CODE|FCM::Class::CODE>.

=over 4

=item $class->new(\%attrib)

Return a new instance of this class. %attrib accepts a single "util" key for an
instance of an L<FCM::Util|FCM::Util> object.

=item $instance->call(@args)

Call the command line "svn" with a list of arguments in @args.

=item $instance->get_info(@path)
=item $instance->get_info(\%option, @path)

Invokes "svn info --xml @paths", and returns a LIST of info entries. If @paths
is not specified, use ("."). If %option is specified, it may contain the keys:

=over 4

=item recursive

If value of this key is not undef, add --recursive to "svn info".

=item revision

If value of this key is not undef, add --revision VALUE to "svn info".

=back

Each info entry is a HASH with keys reflecting the tag or attribute name in an
entry element. The original hierarchy below the entry element is delimited by a
colon in the name. For example, a return structure may look like this:
    [   {   'commit:author' => 'fred',
            'commit:date' => '2011-11-09T15:41:14.514665Z',
            'commit:revision' => '4549',
            'kind' => 'dir',
            'path' => 'trunk',
            'revision' => '4552',
            'repository:root' => 'svn://host/my-repos',
            'repository:uuid' => '91f685bf-fbee-0310-99e6-f3aa9e660bd5'
            'url' => 'svn://host/my-repos/FCM/trunk',
        },
    ]

=item $instance->get_layout($url)

Return an instance of L<FCM::System::CM::SVN::Layout|/FCM::System::CM::SVN::Layout>
containing the repository layout information of $url:

=item $instance->get_list($url_arg, $filter_func)

Call "svn list" multiple times to obtain a recursive listing of files and
directories under $url_arg. Return a list containing the listing. If
$filter_func is defined, it should be a CODE reference, which would be invoked
for each file/directory found. It should have the interface:

    ($can_return, $can_recurse)
        = $filter_func->($this_url, $this_name, $is_dir, $depth);

where $this_url is the URL of the file/directory found, $this_name is the
base name of the file/directory found, $is_dir is true if it is a directory,
$depth is the directory depth of $this_url relative to $url_arg.

The $filter_func CODE reference should return a 2-element list ($can_return,
$can_recurse). The get_list method will only return $this_url in the listing
if $can_return is set to true. If $is_dir is true and $can_recurse is true, the
get_list method will go down to do more listing in $this_url.

=item $instance->get_log(@path)
=item $instance->get_log(\%option, @path)

Invokes "svn log --xml".  If @paths is not specified, use ("."). If %option is
specified, it may contain the keys:

=over 4

=item revision

If value of this key is not undef, add --revision VALUE to "svn log".

=item stop-on-copy

If value of this key is not undef, add --stop-on-copy to "svn log".

=back

Returns an ARRAY reference. Each element is a data structure that represents a
log entry. The data structure should look like:
    [   {   'author'   => $author,
            'date'     => $date, # seconds since epoch
            'msg'      => $msg,
            'paths'    => [
                {   'path'          => $path,
                    'action'        => $action,
                    'copyfrom-path' => $p,
                    'copyfrom-rev'  => $r,
                },
                # ...
            ],
            'revision' => $revision,
        },
    ]

=item $instance->get_wc_root($path)

Return the path to the root working copy directory of the argument.

=item $instance->split_by_peg($location)

Split a location string (either a URL@PEG or a PATH@PEG) and return a
two-element list: either (URL, PEG) or (PATH, PEG).

=item $instance->stdout(@args)

Call the command line "svn" with a list of arguments in @args, capture and
return the STDOUT on success. In scalar context, return the STDOUT as-is. In
array context, return it as a list of lines with the new line characters
removed.

=back

=head1 EXCEPTION

Methods in this class may throw an
L<FCM::System::Exception|FCM::System::Exception> on error.

=head1 FCM::System::CM::SVN::Layout

The FCM::System::CM::SVN::Layout class inherits from
L<FCM::Class::HASH|FCM::Class::HASH>. An instance represents the layout
information in a Subversion URL based on the default or specified FCM layout
information. It has the following attributes:

=over 4

=item config

is a HASH containing the layout configuration applied to this URL.
Valid keys and their default values are:

=over 4

=item depth-project => undef
Number of sub-directories used by the name of a project.

=item depth-branch => 3
Number of sub-directories (under "branches") used by the name of branch.

=item depth-tag => 1
Number of sub-directories (under "tags") used by the name of branch.

=item dir-trunk => 'trunk'
Name of the master/trunk directory.

=item dir-branch => 'branches'
Name of the directory where all branches live. May be empty.

=item dir-tag => 'tags'
Name of the directory where all tags live. May be empty.

=item level-owner-branch => 2
Sub-directory level in the name of a branch containing the its owner.

=item level-owner-branch => undef
Sub-directory level in the name of a tag containing the its owner.

=item template-branch => '{category}/{owner}/{name_prefix}{name}'
Branch name template.

=item template-tag => undef
Tag name template.

=back

=item url

is the full URL@PEG.

=item root

is the repository root.

=item path

is the path below the repository root.

=item peg_rev

is the (peg) revision of the URL.

=item project

is the project name in the URL. It is undef if the URL does not contain a valid
project name for the given repository. An empty string is possible, for example,
if the layout means that the trunk is at the root level.

=item branch

is the "branch" name in the URL, (which may be the name of the master/trunk
branch or the name of a tag). It is undef if the URL does not contain a valid
branch name for the given repository.

=item branch_category

is the category (i.e. "trunk", "branch" or "tag") of the branch.

=item branch_owner

is the owner of the branch, if it can be derived from the URL.

=item sub_tree

is the path in the URL under the branch of a project tree. It is undef if the
URL is not at or below the level of a branch of the project tree. An empty
string means the that the URL is at root level of the project tree.

=back

An FCM::System::CM::SVN::Layout instance has the following convenient methods:

=over 4

=item $layout->is_trunk()

The URL is in the trunk of a project.

=item $layout->is_branch()

The URL is in a branch of a project.

=item $layout->is_tag()

The URL is in a tag of a project.

=item $layout->is_owned_by_user($user)

The URL is in a branch owned by $user. If $user is not defined, it defaults to
the current user ID.

=item $layout->is_shared()

The URL is in a shared branch.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
