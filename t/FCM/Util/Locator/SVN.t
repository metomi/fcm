#!/usr/bin/env perl
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

use FindBin;
use lib "$FindBin::Bin/../../../../lib";
use FCM::Util;
use FCM::Util::Locator::FS;
use File::Basename qw{basename dirname};
use File::Spec::Functions qw{catfile rel2abs};
use File::Temp qw{tempdir};
use SVN::Core;
use SVN::Repos;
use Test::More (tests => 81);

BEGIN {
    use_ok('FCM::Util::Locator::SVN');
}

if (!caller()) {
    my $util = FCM::Util->new();
    my $util_of_svn = FCM::Util::Locator::SVN->new({
        type_util_of => {fs => FCM::Util::Locator::FS->new()},
        util         => FCM::Util->new(),
    });
    my $data_getter = _init();
    for my $function_ref (
        \&test_as_invariant,
        \&test_can_work_with_rev,
        \&test_cat,
        \&test_dir,
        \&test_parse,
        \&test_read_property,
        \&test_reader,
    ) {
        $function_ref->($util_of_svn, $data_getter);
    }
}

# ------------------------------------------------------------------------------
# Tests the "as_invariant" method.
sub test_as_invariant {
    my ($util, $data_getter) = @_;
    my $data_ref = $data_getter->('as_invariant');
    my $format = "as_invariant: %s: %s";

    for my $item (@{$data_ref->{ok}}) {
        is(
            $util->as_invariant($item->{url}),
            $item->{expected},
            sprintf($format, 'ok', $item->{url}),
        );
    }
    for my $item (@{$data_ref->{not_ok}}) {
        eval {
            my $target = $util->as_invariant($item->{url});
        };
        ok(defined($@), sprintf($format, 'not ok', $item->{url}));
    }
}

# ------------------------------------------------------------------------------
# Tests the "cat" method.
sub test_cat {
    my ($util) = @_;
    for (
        # $input                              # $expected
        [['svn://foo'        , 'bar'       ], 'svn://foo/bar'         ],
        [['svn://foo@1234'   , 'bar'       ], 'svn://foo/bar@1234'    ],
        [['svn://foo@vn10.0' , 'bar'       ], 'svn://foo/bar@vn10.0'  ],
        [['svn://foo@1234'   , '/bar'      ], 'svn://foo/bar@1234'    ],
        [['svn://foo'        , './bar'     ], 'svn://foo/bar'         ],
        [['svn://foo@1234'   , '../bar/baz'], 'svn://foo/bar/baz@1234'],
        [['svn://foo/bar'    , 'baz'       ], 'svn://foo/bar/baz'     ],
        [['svn://foo/bar/egg', 'baz'       ], 'svn://foo/bar/egg/baz' ],
        [['svn://foo/bar/baz', '../egg/ham'], 'svn://foo/bar/egg/ham' ],
    ) {
        my ($input_ref, $expected) = @{$_};
        is(
            scalar($util->cat(@{$input_ref})),
            $expected,
            q{scalar: } . join(q{, }, @{$input_ref}),
        );
    }
}

# ------------------------------------------------------------------------------
# Tests the "dir" method.
sub test_dir {
    my ($util) = @_;
    for (
        # $input                  # $expected
        ['svn://foo/bar'        , 'svn://foo'       ],
        ['svn://foo/bar@1234'   , 'svn://foo@1234'  ],
        ['svn://foo/bar@vn10.0' , 'svn://foo@vn10.0'],
        ['svn://foo/bar/@1234'  , 'svn://foo@1234'  ],
        ['svn://foo/bar/.'      , 'svn://foo'       ],
        ['svn://foo/bar/.@1234' , 'svn://foo@1234'  ],
        ['svn://foo/bar/./@1234', 'svn://foo@1234'  ],
        ['svn://foo/bar/./baz'  , 'svn://foo/bar'   ],
        ['svn://foo/bar/baz/..' , 'svn://foo'       ],
        ['svn://foo/bar/../baz' , 'svn://foo'       ],
    ) {
        my ($input, $expected) = @{$_};
        is(scalar($util->dir($input)), $expected, "scalar: $input");
    }
}

# ------------------------------------------------------------------------------
# Tests the "can_work_with_rev" method.
sub test_can_work_with_rev {
    my ($util) = @_;
    # Legitimate ones
    for my $revision (
        qw{1234 635864 head HEAD base BASE PREV prev COMMITTED committed},
        '{2009-06-23T15:48}',
        '{2010-12-31T00:00}',
    ) {
        ok($util->can_work_with_rev($revision), "rev=$revision");
    }
    # Illegitimate ones
    for my $revision (undef, q{}, qw{foo bar baz vn1.10 v2}) {
        ok(
            !$util->can_work_with_rev($revision),
            (defined($revision) ? "rev=$revision" : "rev=undef"),
        );
    }
}

# ------------------------------------------------------------------------------
# Tests the "parse" method.
sub test_parse {
    my ($util) = @_;
    for (
        # $input                    # $expected
        ['svn://foo/bar'          , ['svn://foo/bar'    , undef   ]],
        ['svn://foo/bar@1234'     , ['svn://foo/bar'    , '1234'  ]],
        ['svn://foo/bar@vn10.0'   , ['svn://foo/bar'    , 'vn10.0']],
        ['svn://foo/bar/@1234'    , ['svn://foo/bar'    , '1234'  ]],
        ['svn://foo/bar/.'        , ['svn://foo/bar'    , undef   ]],
        ['svn://foo/bar/.@1234'   , ['svn://foo/bar'    , '1234'  ]],
        ['svn://foo/bar/./@1234'  , ['svn://foo/bar'    , '1234'  ]],
        ['svn://foo/bar/./baz'    , ['svn://foo/bar/baz', undef   ]],
        ['svn://foo/bar/..'       , ['svn://foo'        , undef   ]],
        ['svn://foo/bar/..@1234'  , ['svn://foo'        , '1234'  ]],
        ['svn://foo/bar/../@1234' , ['svn://foo'        , '1234'  ]],
        ['svn://foo/bar/../baz'   , ['svn://foo/baz'    , undef   ]],
        ['svn://foo/bar/../.'     , ['svn://foo'        , undef   ]],
        ['svn://foo/bar/./..'     , ['svn://foo'        , undef   ]],
        ['svn://foo/bar/baz/../..', ['svn://foo'        , undef   ]],
    ) {
        my ($input, $exp_ref) = @{$_};
        my $exp_scalar
            = $exp_ref->[0] . ($exp_ref->[1] ? '@' .  $exp_ref->[1] : q{});
        is(scalar($util->parse($input)), $exp_scalar, "scalar: $input");
        is_deeply([$util->parse($input)], $exp_ref, "array: $input");
    }
}

# ------------------------------------------------------------------------------
# Tests the "reader" method.
sub test_reader {
    my ($util, $data_getter) = @_;
    my $data_ref = $data_getter->('reader');
    my $format = "reader: %s: %s";

    for my $item (@{$data_ref->{ok}}) {
        my $handle = $util->reader($item->{url});
        is(
            do {local($/); readline($handle)},
            $item->{content},
            sprintf($format, 'ok', $item->{url}),
        );
        close($handle) || die($!);
    }
    for my $item (@{$data_ref->{not_ok}}) {
        eval {
            my $handle = $util->reader($item->{url});
        };
        ok(defined($@), sprintf($format, 'not ok', $item->{url}));
    }
}

# ------------------------------------------------------------------------------
# Tests the "read_property" method.
sub test_read_property {
    my ($util, $data_getter) = @_;
    my $data_ref = $data_getter->('read_property');
    my $format = "read_property: %s: %s: %s";

    for my $item (@{$data_ref->{ok}}) {
        is(
            $util->read_property($item->{url}, $item->{property}),
            $item->{content},
            sprintf($format, 'ok', $item->{url}, $item->{property}),
        );
    }
    for my $item (@{$data_ref->{not_ok}}) {
        eval {
            my $content = $util->read_property($item->{url}, $item->{property});
        };
        ok(
            defined($@),
            sprintf($format, 'not ok', $item->{url}, $item->{property}),
        );
    }
}

# ------------------------------------------------------------------------------
# Creates a repos and loads a dump. Returns the URL.
sub _init {
    # Creates a temporary directory to host a temporary repository
    my ($name) = basename($0) =~ qr{\A(.*)\.t\z}xms;
    my $path = catfile(tempdir(CLEANUP => 1), $name);
    my $pool = SVN::Pool->new_default();
    my $repos = SVN::Repos::create($path, undef, undef, undef, undef, $pool);
    my $dump_file = catfile(dirname($0), $name . '.dump');
    open(my $dump, '<', $dump_file) || die($!);
    $repos->load_fs($dump, undef, 0, undef, undef, undef, $pool);
    close($dump) || die($!);
    my $url = 'file://' . rel2abs($path);

    # NOTE: this is hard coded in the dump.
    my %data = (
        as_invariant => {
            ok     => [
                {
                    url      => $url . '/file',
                    expected => $url . '/file@1'
                },
                {
                    url      => $url . '/file@HEAD',
                    expected => $url . '/file@1'
                },
                {
                    url      => $url . '/file@1',
                    expected => $url . '/file@1'
                },
            ],
            not_ok => [
                {url => $url . '/file@2'},
                {url => $url . '/no-such-file'},
            ],
        },
        read_property  => {
            ok     => [
                {
                    url      => $url . '/file-with-property',
                    property => 'fcm:test',
                    content  => "egg ham bacon\nbeer wine spirit\n\n",
                },
                {
                    url      => $url . '/file-with-property@1',
                    property => 'fcm:test',
                    content  => "egg ham bacon\nbeer wine spirit\n\n",
                },
            ],
            not_ok => [
                {property => 'fcm:test', url => $url . '/file'},
                {property => 'fcm:test', url => $url . '/no-such-file'},
            ],
        },
        reader  => {
            ok     => [
                {
                    url     => $url . '/file',
                    content => "foo bar baz\negg ham bacon\nbeer wine spirit\n",
                },
                {
                    url     => $url . '/file@1',
                    content => "foo bar baz\negg ham bacon\nbeer wine spirit\n",
                },
            ],
            not_ok => [
                {url => $url . '/no-such-file'},
            ],
        },
    );

    return sub {return $data{$_[0]}};
}

__END__
