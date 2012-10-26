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
use lib "$FindBin::Bin/../../../lib";
use File::Temp;
use Test::More (tests => 9);

BEGIN {
    use_ok('FCM::Util::Reporter');
}

if (!caller()) {
    test_normal();
}

# ------------------------------------------------------------------------------
# Tests default usage (but with file handles reset).
sub test_normal {
    my $C = 'FCM::Util::Reporter';
    my @tests = (
        {
            name        => 'default',
            expected    => {
                'err' => <<'ERR',
[WARN] burnt
[FAIL] overcooked
[WARN] 1
[WARN] 2
[WARN] 3
[WARN] 4
[WARN] 5
ERR
                'out' => <<'OUT',
[info] foo bar baz
[info] egg ham sausage
[info] rosemary thyme
[info] hen
[info] duck
[info] cow
OUT
            },
            reports     => [
                [                                             'foo bar baz'     ],
                [{level => $C->QUIET                       }, 'egg ham sausage' ],
                [{level => $C->MEDIUM                      }, 'beans'           ],
                [{                     type => $C->TYPE_ERR}, 'burnt'           ],
                [{level => $C->FAIL  , type => $C->TYPE_ERR}, 'overcooked'      ],
                [{level => $C->LOW                         }, 'rosemary thyme'  ],
                [                                             [qw{hen duck cow}]],
                [{level => $C->HIGH                        }, 'king queen jack' ],
                [{                     type => $C->TYPE_ERR}, sub {1 .. 5}      ],
            ],
            verbosity => $C->DEFAULT,
        },
        {
            name        => 'high verbosity',
            expected    => {
                'err' => <<'ERR',
[WARN] burnt
[FAIL] overcooked
[WARN] 1
[WARN] 2
[WARN] 3
[WARN] 4
[WARN] 5
ERR
                'out' => <<'OUT',
[info] foo bar baz
[info] egg ham sausage
[info] beans
[info] rosemary thyme
[info] hen
[info] duck
[info] cow
[info] king queen jack
OUT
            },
            reports     => [
                [                                             'foo bar baz'     ],
                [{level => $C->QUIET                       }, 'egg ham sausage' ],
                [{level => $C->MEDIUM                      }, 'beans'           ],
                [{                     type => $C->TYPE_ERR}, 'burnt'           ],
                [{level => $C->FAIL  , type => $C->TYPE_ERR}, 'overcooked'      ],
                [{level => $C->LOW                         }, 'rosemary thyme'  ],
                [                                             [qw{hen duck cow}]],
                [{level => $C->HIGH                        }, 'king queen jack' ],
                [{                     type => $C->TYPE_ERR}, sub {1 .. 5}      ],
            ],
            verbosity => $C->HIGH,
        },
        {
            name        => 'quiet verbosity',
            expected    => {
                'err' => <<'ERR',
[FAIL] overcooked
ERR
                'out' => <<'OUT',
[info] egg ham sausage
OUT
            },
            reports     => [
                [                                             'foo bar baz'     ],
                [{level => $C->QUIET                       }, 'egg ham sausage' ],
                [{level => $C->MEDIUM                      }, 'beans'           ],
                [{                     type => $C->TYPE_ERR}, 'burnt'           ],
                [{level => $C->FAIL  , type => $C->TYPE_ERR}, 'overcooked'      ],
                [{level => $C->LOW                         }, 'rosemary thyme'  ],
                [                                             [qw{hen duck cow}]],
                [{level => $C->HIGH                        }, 'king queen jack' ],
                [{                     type => $C->TYPE_ERR}, sub {1 .. 5}      ],
            ],
            verbosity => $C->QUIET,
        },
        {
            name        => 'prefix',
            expected    => {
                'err' => <<'ERR',
[WARN] burnt
[FAIL] overcooked
[WARN] 1
[WARN] 2
[WARN] 3
[WARN] 4
[WARN] 5
ERR
                'out' => <<'OUT',
[INFO:1] foo bar baz
[INFO:0] egg ham sausage
[INFO:1] rosemary thyme
[INFO:1] hen
[INFO:1] duck
[INFO:1] cow
OUT
            },
            prefix      => {out => sub {sprintf("[INFO:%d] ", $_[0])}},
            reports     => [
                [                                             'foo bar baz'     ],
                [{level => $C->QUIET                       }, 'egg ham sausage' ],
                [{level => $C->MEDIUM                      }, 'beans'           ],
                [{                     type => $C->TYPE_ERR}, 'burnt'           ],
                [{level => $C->FAIL  , type => $C->TYPE_ERR}, 'overcooked'      ],
                [{level => $C->LOW                         }, 'rosemary thyme'  ],
                [                                             [qw{hen duck cow}]],
                [{level => $C->HIGH                        }, 'king queen jack' ],
                [{                     type => $C->TYPE_ERR}, sub {1 .. 5}      ],
            ],
            verbosity => $C->DEFAULT,
        },
    );
    for my $test (@tests) {
        my %handle_of = (
            'err' => File::Temp->new(),
            'out' => File::Temp->new(),
        );
        my $reporter = $C->new();
        $reporter->get_ctx('stderr')->set_handle($handle_of{err});
        $reporter->get_ctx('stderr')->set_verbosity($test->{verbosity});
        if (exists($test->{prefix}{err})) {
            $reporter->get_ctx('stderr')->set_prefix($test->{prefix}{err});
        }
        $reporter->get_ctx('stdout')->set_handle($handle_of{out});
        $reporter->get_ctx('stdout')->set_verbosity($test->{verbosity});
        if (exists($test->{prefix}{out})) {
            $reporter->get_ctx('stdout')->set_prefix($test->{prefix}{out});
        }
        for my $item (@{$test->{reports}}) {
            $reporter->report(@{$item});
        }
        for my $key (qw{err out}) {
            seek($handle_of{$key}, 0, 0);
            my $result = do {local($/); readline($handle_of{$key})};
            is($result, $test->{expected}{$key}, "normal: $test->{name}: $key");
            close($handle_of{$key});
        }
    }
}

__END__
