#!/usr/bin/env perl
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

use FindBin;
use lib "$FindBin::Bin/../../../../lib";
use Cwd qw{cwd};
use File::Basename qw{dirname};
use File::Spec;
use File::Temp qw{tempdir};
use Test::More (tests => 80);

BEGIN {
    use_ok('FCM::Util::Locator::FS');
}

if (!caller()) {
    test_cat(@ARGV);
    test_dir(@ARGV);
    test_parse(@ARGV);
    test_reader(@ARGV);
    test_can_work_with_rev(@ARGV);
}

# ------------------------------------------------------------------------------
# Tests the "dir" method.
sub test_dir {
    my $util = FCM::Util::Locator::FS->new();
    my ($user, $home) = (getpwuid($<))[0, 7];
    for (
        # $input             # $expected
        ['/'                 , '/'                                  ],
        ['.'                 , dirname(cwd())                       ],
        ['..'                , dirname(dirname(cwd()))              ],
        ['~'                 , dirname($home)                       ],
        ["~$user"            , dirname($home)                       ],
        ["~$user/foo/bar/baz", "$home/foo/bar"                      ],
        ["/foo/bar/baz"      , '/foo/bar'                           ],
        ["foo/bar/baz"       , File::Spec->catfile(cwd(), 'foo/bar')],
    ) {
        my ($input, $expected) = @{$_};
        is(scalar($util->dir($input)), $expected, "scalar: $input");
    }
}

# ------------------------------------------------------------------------------
# Tests the "reader" method.
sub test_reader {
    my $temp_dir = tempdir(CLEANUP => 1);
    my %PATH_OF = map {($_, File::Spec->catfile($temp_dir, $_))} qw{ok not_ok};
    my $CONTENT_IN_OK = "foo bar baz\negg ham bacon\nbeer wine spirit\n";
    open(my $ok_handle, '>', $PATH_OF{ok}) || die($!);
    print({$ok_handle} $CONTENT_IN_OK) || die($!);
    close($ok_handle) || die($!);

    my $util = FCM::Util::Locator::FS->new();
    my $handle = $util->reader($PATH_OF{ok});
    is(do {local($/); readline($handle)}, $CONTENT_IN_OK, 'reader: ok');
    close($handle) || fail($!);

    local($@);
    ok(!defined(eval {$util->reader($PATH_OF{not_ok})}), 'reader: not ok');
}

# ------------------------------------------------------------------------------
# Tests the "can_work_with_rev" method.
sub test_can_work_with_rev {
    my $util = FCM::Util::Locator::FS->new();
    for my $revision (
        undef,
        q{},
        qw{foo bar baz vn1.10 v2},
        qw{1234 635864 head HEAD base BASE PREV prev COMMITTED committed},
        '{2009-06-23T15:48}',
        '{2010-12-31T00:00}',
    ) {
        ok(
            !$util->can_work_with_rev($revision),
            (defined($revision) ? "rev=$revision" : "rev=undef"),
        );
    }
}

# ------------------------------------------------------------------------------
# Tests the "cat" method.
sub test_cat {
    my $util = FCM::Util::Locator::FS->new();
    for (
        # $input                         # $expected
        [['/foo'        , 'bar'       ], '/foo/bar'    ],
        [['/foo'        , '/bar'      ], '/foo/bar'    ],
        [['/foo/'       , '/bar'      ], '/foo/bar'    ],
        [['/foo'        , './bar'     ], '/foo/bar'    ],
        [['/foo'        , '../bar/baz'], '/bar/baz'    ],
        [['/foo/bar'    , 'baz'       ], '/foo/bar/baz'],
        [['/foo/bar/.'  , 'baz'       ], '/foo/bar/baz'],
        [['/foo/bar/'   , '../egg/ham'], '/foo/egg/ham'],
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
# Tests the "parse" method.
sub test_parse {
    my $util = FCM::Util::Locator::FS->new();
    my ($user, $home) = (getpwuid($<))[0, 7];
    for (
        # $input               # $expected
        ['/'                   , '/'                                      ],
        ['/.'                  , '/'                                      ],
        ['/..'                 , '/'                                      ],
        ['//'                  , '/'                                      ],
        ['.'                   , cwd()                                    ],
        ['./'                  , cwd()                                    ],
        ['..'                  , dirname(cwd())                           ],
        ['../'                 , dirname(cwd())                           ],
        ['~'                   , $home                                    ],
        ['~/'                  , $home                                    ],
        ["~$user"              , $home                                    ],
        ["~$user/"             , $home                                    ],
        ["~$user/foo/bar/baz"  , "$home/foo/bar/baz"                      ],
        ["/foo/bar/baz"        , '/foo/bar/baz'                           ],
        ["/foo/bar/./baz"      , '/foo/bar/baz'                           ],
        ["/foo/bar/../baz"     , '/foo/baz'                               ],
        ["/foo///bar//baz/"    , '/foo/bar/baz'                           ],
        ["/foo/bar/../../baz"  , '/baz'                                   ],
        ["/foo/bar/../.././baz", '/baz'                                   ],
        ["/foo/././bar/baz"    , '/foo/bar/baz'                           ],
        ["foo/bar/baz"         , File::Spec->catfile(cwd(), 'foo/bar/baz')],
    ) {
        my ($input, $expected) = @{$_};
        is(scalar($util->parse($input)), $expected, "scalar: $input");
        is_deeply([$util->parse($input)], [$expected, undef], "array: $input");
    }
}

__END__
