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
use lib "$FindBin::Bin/../../lib";
use Test::More (tests => 211);

use Data::Dumper qw{Dumper};
use File::Basename qw{dirname};
use File::Spec::Functions qw{catfile rel2abs};
use File::Temp qw{tempdir};

BEGIN {
    use_ok('FCM::Util');
}

package FCM::Test::Event;
use base qw{FCM::Class::CODE};

__PACKAGE__->class({events => '@'}, {action_of => {main => \&_main}});

sub _main {
    my $attrib_ref = shift();
    push(@{$attrib_ref->{events}}, @_);
}

package main;

# Test configuration files, as FCM::Context::Locator
my %CONFIG_TEST_RES_FOR = map {
    my $name = $_;
    my ($prefix) = rel2abs($0) =~ qr{\A (.*) \.t \z}xms;
    (
        $name,
        FCM::Context::Locator->new(
            "$prefix/config-reader-$name.cfg",
            {value_level => FCM::Context::Locator->L_INVARIANT},
        ),
    );
} qw{
    comment
    cont-eof
    empty
    simple
    include
    include-cyclic
    include-empty
    invalid
    syntax
    variable
};
# Expected environment for in configuration tests
my %CONFIG_TEST_ENV = (
    FCM_TEST_ENV1 => 'test env value',
);
# Expected value in test configuration variables
my %CONFIG_TEST_VAR_VALUE_OF = (
    %CONFIG_TEST_ENV,
    modifier_of      => 'key1: value1, key2 :value2 ,key3:value3',
    more_modifier_of => 'key4: value4, key5: value5',
    more_names       => 'egg, ham, bacon',
    names            => 'some,comma ,"separated, values"',
    variable         => 'test value',
    variable_not_set => undef,
);
# Expected entries in test configuration files
my %CONFIG_TEST_ENTRIES_IN = (
    # Contents in ConfigReader-simple.cfg
    simple => [
        {
            stack       => [[$CONFIG_TEST_RES_FOR{simple}, 1]],
            label       => 'egg',
            modifier_of => {},
            ns_list     => [],
            value       => 'yes',
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{simple}, 2]],
            label       => 'bacon',
            modifier_of => {fried => 'true'},
            ns_list     => [],
            value       => 'I like crispy bacon.',
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{simple}, 4]],
            label       => 'sausage',
            modifier_of => {},
            ns_list     => ['pork'],
            value       => 'Taste good.',
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{simple}, 6]],
            label       => 'egg',
            modifier_of => {},
            ns_list     => [],
            value       => q{},
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{simple}, 7]],
            label       => 'bacon',
            modifier_of => {organic => 'true', streaky => 'false'},
            ns_list     => ['fried', 'olive oil'],
            value       => q{},
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{simple}, 12]],
            label       => 'egg',
            modifier_of => {},
            ns_list     => [],
            value       => '# not a comment',
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{simple}, 13]],
            label       => 'egg',
            modifier_of => {},
            ns_list     => [],
            value       => '',
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{simple}, 14]],
            label       => 'egg',
            modifier_of => {},
            ns_list     => [],
            value       => 'slow#cooked',
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{simple}, 15]],
            label       => 'egg',
            modifier_of => {},
            ns_list     => [],
            value       => 'slow "# cooked"',
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{simple}, 16]],
            label       => 'egg',
            modifier_of => {},
            ns_list     => [],
            value       => 'slow',
        },
        (map {{
            stack       => [[$CONFIG_TEST_RES_FOR{simple}, $_]],
            label       => 'drink',
            modifier_of => {},
            ns_list     => [],
            value       => 'fresh orange juice',
        }} qw{18 20 22 24 27}),
        {
            stack       => [[$CONFIG_TEST_RES_FOR{simple}, 31]],
            label       => 'meal.morning',
            modifier_of => {},
            ns_list     => [],
            value       => 'breakfast',
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{simple}, 32]],
            label       => 'meal.at-noon',
            modifier_of => {},
            ns_list     => [],
            value       => 'lunch',
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{simple}, 33]],
            label       => 'meal.in-the-evening',
            modifier_of => {},
            ns_list     => [],
            value       => 'tea or dinner',
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{simple}, 35]],
            label       => 'drink',
            modifier_of => {cold => 1, 'non-alcoholic' => 1},
            ns_list     => [],
            value       => 'coke',
        },
    ],
    # Contents in ConfigReader-variable.cfg
    variable => [
        (map {{
            stack       => [[$CONFIG_TEST_RES_FOR{variable}, $_]],
            label       => 'fred',
            modifier_of => {},
            ns_list     => [],
            value       => $CONFIG_TEST_VAR_VALUE_OF{variable},
        }} qw{2 3}),
        {
            stack       => [[$CONFIG_TEST_RES_FOR{variable}, 4]],
            label       => 'fred',
            modifier_of => {},
            ns_list     => [],
            value       => "pre$CONFIG_TEST_VAR_VALUE_OF{variable}",
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{variable}, 5]],
            label       => 'fred',
            modifier_of => {},
            ns_list     => [],
            value       => "$CONFIG_TEST_VAR_VALUE_OF{variable}post",
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{variable}, 6]],
            label       => 'fred',
            modifier_of => {},
            ns_list     => [],
            value       => "pre$CONFIG_TEST_VAR_VALUE_OF{variable}post",
        },
        (map {{
            stack       => [[$CONFIG_TEST_RES_FOR{variable}, $_]],
            label       => 'fred',
            modifier_of => {},
            ns_list     => [],
            value       => "pre $CONFIG_TEST_VAR_VALUE_OF{variable} post",
        }} qw{7 8 9}),
        {
            stack       => [[$CONFIG_TEST_RES_FOR{variable}, 11]],
            label       => 'fred',
            modifier_of => {},
            ns_list     => [],
            value       => "pre $CONFIG_TEST_VAR_VALUE_OF{variable}"
                              . "$CONFIG_TEST_VAR_VALUE_OF{variable} post",
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{variable}, 12]],
            label       => 'fred',
            modifier_of => {},
            ns_list     => [],
            value       => 'pre $HERE post',
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{variable}, 18]],
            label       => 'fred',
            modifier_of => {
                key1 => 'value1',
                key2 => 'value2',
                key3 => 'value3',
            },
            ns_list     => [qw{some comma}, 'separated, values'],
            value       => $CONFIG_TEST_VAR_VALUE_OF{variable},
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{variable}, 19]],
            label       => 'fred',
            modifier_of => {
                key1 => 'value1',
                key2 => 'value2',
                key3 => 'value3',
                key4 => 'value4',
                key5 => 'value5',
            },
            ns_list     => [],
            value       => $CONFIG_TEST_VAR_VALUE_OF{variable},
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{variable}, 20]],
            label       => 'fred',
            modifier_of => {},
            ns_list     => [
                qw{some comma},
                'separated, values',
                qw{egg ham bacon},
            ],
            value       => $CONFIG_TEST_VAR_VALUE_OF{variable},
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{variable}, 22]],
            label       => 'fred',
            modifier_of => {},
            ns_list     => [],
            value       => '',
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{variable}, 23]],
            label       => 'fred',
            modifier_of => {},
            ns_list     => [],
            value       => $CONFIG_TEST_VAR_VALUE_OF{FCM_TEST_ENV1},
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{variable}, 25]],
            label       => 'fred',
            modifier_of => {},
            ns_list     => [],
            value       => '$variable',
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{variable}, 26]],
            label       => 'fred',
            modifier_of => {},
            ns_list     => [],
            value       => '\\' . $CONFIG_TEST_VAR_VALUE_OF{variable},
        },
        {
            stack       => [[$CONFIG_TEST_RES_FOR{variable}, 29]],
            label       => 'fred',
            modifier_of => {},
            ns_list     => [],
            value       => $CONFIG_TEST_VAR_VALUE_OF{variable} . ' foo bar baz',
        },
    ],
);
# Items for config test
my @CONFIG_TEST_ITEMS = (
    {
        name           => 'test empty',
        locator        => $CONFIG_TEST_RES_FOR{empty},
        expt_events    => [['CONFIG_OPEN', [[$CONFIG_TEST_RES_FOR{empty}, 0]]]],
        expt_entries   => [],
        expt_e         => undef,
    },
    {
        name           => 'test comment only',
        locator        => $CONFIG_TEST_RES_FOR{comment},
        expt_events    => [['CONFIG_OPEN', [[$CONFIG_TEST_RES_FOR{comment}, 0]]]],
        expt_entries   => [],
        expt_e         => undef,
    },
    {
        name           => 'test simple configuration',
        locator        => $CONFIG_TEST_RES_FOR{simple},
        expt_events    => [['CONFIG_OPEN', [[$CONFIG_TEST_RES_FOR{simple}, 0]]]],
        expt_entries   => $CONFIG_TEST_ENTRIES_IN{simple},
        expt_e         => undef,
    },
    {
        name           => 'test configuration with variable',
        locator        => $CONFIG_TEST_RES_FOR{variable},
        expt_events    => [
            ['CONFIG_OPEN', [[$CONFIG_TEST_RES_FOR{variable}, 0]]],
        ],
        expt_entries   => $CONFIG_TEST_ENTRIES_IN{variable},
        expt_e         => undef,
    },
    {
        name           => 'test cyclic include',
        locator        => $CONFIG_TEST_RES_FOR{'include-cyclic'},
        expt_events    => [
            ['CONFIG_OPEN', [[$CONFIG_TEST_RES_FOR{'include-cyclic'}, 0]]],
        ],
        expt_entries   => [],
        expt_e         => ['FCM::Util::Exception', 'CONFIG_CYCLIC'],
    },
    {
        name           => 'test invalid assignment',
        locator        => $CONFIG_TEST_RES_FOR{'invalid'},
        expt_events    => [
            ['CONFIG_OPEN', [[$CONFIG_TEST_RES_FOR{'invalid'}, 0]]],
        ],
        expt_entries   => [],
        expt_e         => ['FCM::Util::Exception', 'CONFIG_USAGE'],
    },
    {
        name           => 'test syntax error',
        locator        => $CONFIG_TEST_RES_FOR{'syntax'},
        expt_events    => [
            ['CONFIG_OPEN', [[$CONFIG_TEST_RES_FOR{'syntax'}, 0]]],
        ],
        expt_entries   => [],
        expt_e         => ['FCM::Util::Exception', 'CONFIG_SYNTAX'],
    },
    {
        name           => 'test continuation at EOF',
        locator        => $CONFIG_TEST_RES_FOR{'cont-eof'},
        expt_events    => [
            ['CONFIG_OPEN', [[$CONFIG_TEST_RES_FOR{'cont-eof'}, 0]]],
        ],
        expt_entries   => [],
        expt_e         => ['FCM::Util::Exception', 'CONFIG_CONT_EOF'],
    },
    {
        name           => 'test include of empty files',
        locator        => $CONFIG_TEST_RES_FOR{'include-empty'},
        expt_events    => [
            ['CONFIG_OPEN', [[$CONFIG_TEST_RES_FOR{'include-empty'}, 0]]],
            [
                'CONFIG_OPEN',
                [
                    [$CONFIG_TEST_RES_FOR{'include-empty'}, 1],
                    [$CONFIG_TEST_RES_FOR{empty}          , 0],
                ]
            ],
            [
                'CONFIG_OPEN',
                [
                    [$CONFIG_TEST_RES_FOR{'include-empty'}, 4],
                    [$CONFIG_TEST_RES_FOR{comment}        , 0],
                ]
            ],
        ],
        expt_entries   => [],
        expt_e         => undef,
    },
    {
        name           => 'test include of multiple files',
        locator        => $CONFIG_TEST_RES_FOR{include},
        expt_events    => [
            ['CONFIG_OPEN', [[$CONFIG_TEST_RES_FOR{include}, 0]]],
            [
                'CONFIG_OPEN',
                [
                    [$CONFIG_TEST_RES_FOR{include}        , 3],
                    [$CONFIG_TEST_RES_FOR{'include-empty'}, 0],
                ]
            ],
            [
                'CONFIG_OPEN',
                [
                    [$CONFIG_TEST_RES_FOR{include}        , 3],
                    [$CONFIG_TEST_RES_FOR{'include-empty'}, 1],
                    [$CONFIG_TEST_RES_FOR{empty}          , 0],
                ]
            ],
            [
                'CONFIG_OPEN',
                [
                    [$CONFIG_TEST_RES_FOR{include}        , 3],
                    [$CONFIG_TEST_RES_FOR{'include-empty'}, 4],
                    [$CONFIG_TEST_RES_FOR{comment}        , 0],
                ]
            ],
            [
                'CONFIG_OPEN',
                [
                    [$CONFIG_TEST_RES_FOR{include}, 4],
                    [$CONFIG_TEST_RES_FOR{simple} , 0],
                ]
            ],
            [
                'CONFIG_OPEN',
                [
                    [$CONFIG_TEST_RES_FOR{include} , 5],
                    [$CONFIG_TEST_RES_FOR{variable}, 0],
                ]
            ],
        ],
        expt_entries   => [
            (map {
                my %hash = %{$_};
                my @stack = (
                    [$CONFIG_TEST_RES_FOR{include}, 4],
                    @{$hash{stack}},
                );
                $hash{stack} = \@stack;
                \%hash;
            } @{$CONFIG_TEST_ENTRIES_IN{simple}}),
            (map {
                my %hash = %{$_};
                my @stack = (
                    [$CONFIG_TEST_RES_FOR{include}, 5],
                    @{$hash{stack}},
                );
                $hash{stack} = \@stack;
                \%hash;
            } @{$CONFIG_TEST_ENTRIES_IN{variable}}),
        ],
        expt_e         => undef,
    },
);

# ------------------------------------------------------------------------------
if (!caller()) {
    main(@ARGV);
}

sub main {
    my $util = FCM::Util->new();
    isa_ok($util, 'FCM::Util');
    for my $code_ref (
        \&test_config_reader,
        \&test_hash_cmp,
        \&test_loc,
        \&test_ns_cat,
        \&test_ns_common,
        \&test_ns_iter,
        \&test_shell,
        \&test_uri_match,
    ) {
        $code_ref->($util);
    }
}

sub test_config_reader {
    my ($util) = @_;
    # Dummy code to ensure that keyword configuration is parsed
    my $locator = FCM::Context::Locator->new(q{.});
    $util->loc_as_parsed($locator);

    test_config_reader_fcm2(@_);
}

sub test_config_reader_fcm2 {
    my ($util) = @_;
    my @events;
    my $event = $util->util_of_event();
    $util->util_of_event(FCM::Test::Event->new({events => \@events}));
    is($util->config_reader(), undef, 'config_reader: undef');
    for my $item_ref (@CONFIG_TEST_ITEMS) {
        my $path = $item_ref->{locator}->get_value();
        my $reader = $util->config_reader($item_ref->{locator});
        local($@);
        eval {
            local(%ENV) = %CONFIG_TEST_ENV;
            @events = ();
            my @c_entries;
            while (my $c_entry = $reader->()) {
                push(@c_entries, $c_entry);
            }
            is(
                scalar(@c_entries),
                scalar(@{$item_ref->{expt_entries}}),
                "$item_ref->{name}: number of entries",
            );
            for my $i (0 .. $#{$item_ref->{expt_entries}}) {
                is_deeply(
                    $c_entries[$i],
                    $item_ref->{expt_entries}->[$i],
                    "$item_ref->{name}: entry $i"
                );
            }
            is(
                scalar(@events),
                scalar(@{$item_ref->{expt_events}}),
                "$item_ref->{name}: number of events",
            );
            if (scalar(@events) == scalar(@{$item_ref->{expt_events}})) {
                for my $i (0 .. $#{$item_ref->{expt_events}}) {
                    is( $events[$i]->get_code(),
                        $item_ref->{expt_events}->[$i][0],
                        "$item_ref->{name}: code",
                    );
                    is_deeply(
                        $events[$i]->get_args()->[0],
                        $item_ref->{expt_events}->[$i][1],
                        "$item_ref->{name}: args",
                    );
                }
            }
            else {
                for (1 .. scalar(@{$item_ref->{expt_events}})) {
                    fail("$item_ref->{name}: number of events");
                }
            }
            if ($item_ref->{expt_e}) {
                fail("$item_ref->{name}: expect exception");
            }
        };
        if ($@) {
            if (!$item_ref->{expt_e}) {
                die($@);
            }
            my ($class, $code) = @{$item_ref->{expt_e}};
            isa_ok($@, $class, "$item_ref->{name}: e class") || die($@);
            if ($code) {
                is($@->get_code(), $code, "$item_ref->{name}: e code");
            }
        }
    }
    $util->util_of_event($event);
}

sub test_hash_cmp {
    my ($util) = @_;
    for (
        ['empty'   , {}            , {}            , {}         , {}         ],
        ['added'   , {}            , {foo => 'bar'}, {foo =>  1}, {foo =>  1}],
        ['deleted' , {foo => 'bar'}, {}            , {foo => -1}, {foo => -1}],
        ['modified', {foo => 'bar'}, {foo => 'baz'}, {foo =>  0}, {}         ],
    ) {
        my ($key, $hash_1_ref, $hash_2_ref, $exp, $keys_only_exp) = @{$_};
        is_deeply({$util->hash_cmp($hash_1_ref, $hash_2_ref)}, $exp, $key);
        is_deeply(
            {$util->hash_cmp($hash_1_ref, $hash_2_ref, 1)},
            $keys_only_exp,
            "$key: keys only",
        );
    }
}

sub test_loc {
    my $DATA_REF = [
        # label      modifier_of     namespace          value
        ['location', {            }, ['foo'        ], 'svn://foo'        ],
        ['revision', {            }, ['foo:bar'    ], 1234               ],
        ['location', {qw{type svn}}, ['egg'        ], 'file://egg'       ],
        ['revision', {            }, ['foo:baz'    ], 43734              ],
        ['revision', {            }, ['egg:ham'    ], 3636               ],
        ['location', {            }, ['foo-bar'    ], 'svn://foo/bar'    ],
        ['location', {            }, ['foo-bar-baz'], 'svn://foo/bar/baz'],

        ['browser.comp-pat', {}, [], '(?msx-i:\A//([^/]+)/*(.*)\z)'       ],
        ['browser.loc-tmpl', {}, [], 'http://{1}/intertrac/source:/{2}{3}'],
        ['browser.rev-tmpl', {}, [], '@{1}'                               ],
    ];
    my $util = FCM::Util->new();
    my @c_entries = map {
        FCM::Context::ConfigEntry->new({
            label       => $_->[0],
            modifier_of => $_->[1],
            ns_list     => $_->[2],
            value       => $_->[3],
        })
    } @{$DATA_REF};
    $util->loc_kw_ctx_load(sub {shift(@c_entries)});
    for my $func (
        \&test_loc_as_normalised,
        \&test_loc_as_keyword,
        \&test_loc_browser_url,
        \&test_loc_kw_ctx,
        \&test_loc_kw_iter,
    ) {
        $func->($util, $DATA_REF);
    }
}

sub test_loc_browser_url {
    my ($util, $DATA_REF) = @_;
    for my $item (
        ['fcm:foo'             , 'http://foo/intertrac/source:/'             ],
        ['fcm:foo/'            , 'http://foo/intertrac/source:/'             ],
        ['fcm:foo@bar'         , 'http://foo/intertrac/source:/@1234'        ],
        ['fcm:foo/bar/baz@baz' , 'http://foo/intertrac/source:/bar/baz@43734'],
        ['fcm:foo/bar/baz@HEAD', 'http://foo/intertrac/source:/bar/baz@HEAD' ],
        ['svn://foo'           , 'http://foo/intertrac/source:/'             ],
        ['svn://foo@bar'       , 'http://foo/intertrac/source:/@1234'        ],
    ) {
        my ($input, $expected) = @{$item};
        my $locator = FCM::Context::Locator->new($input);
        is(
            $util->loc_browser_url($locator),
            $expected,
            "browser_url: $input"
        );
    }
}

sub test_loc_kw_ctx {
    my ($util, $DATA_REF) = @_;
    my $name_of = sub {
        my ($name, $label, $modifier_ref, $ns_ref) = @_;
        sprintf(
            "keyword_ctx: %s: %s[%s]",
            $name, $label, join(q{, }, @{$ns_ref}),
        )
    };
    my $do_tests_for = sub {
        my ($label, $modifier_ref, $ns_ref, $value, $entry, $index) = @_;
        my @ns = @{$ns_ref} ? split(':', $ns_ref->[0]) : ();
        is($entry->get_key(), $ns[$index], $name_of->('key', @_));
        is($entry->get_value(), $value, $name_of->('value', @_));
    };
    my %HANDLER_OF = (
        'location' => sub {
            my $entry = shift();
            $do_tests_for->(@_, $entry, 0);
        },
        'revision' => sub {
            my $entry = shift();
            my ($label, $modifier_ref, $ns_ref, $value) = @_;
            my $ctx_of_rev = $entry->get_ctx_of_rev();
            my ($k, $key) = @{$ns_ref} ? split(':', $ns_ref->[0]) : ();
            $do_tests_for->(@_, $ctx_of_rev->get_entry_by_key($key), 1);
        },
    );
    my $ctx = $util->loc_kw_ctx();
    for my $item (@{$DATA_REF}) {
        my ($label, $modifier_ref, $ns_ref, $value) = @{$item};
        my ($ns) = @{$ns_ref} ? split(':', $ns_ref->[0]) : ();
        my $entry = $ctx->get_entry_by_key($ns);
        if ($HANDLER_OF{$label}) {
            $HANDLER_OF{$label}->($entry, @{$item});
        }
    }
}

sub test_loc_kw_iter {
    my ($util, $DATA_REF) = @_;
    for my $item (
        ['svn://foo/bar'         , [qw{foo-bar foo}            ]],
        ['svn://foo/bar/baz'     , [qw{foo-bar-baz foo-bar foo}]],
        ['svn://foo/bar/baz/'    , [qw{foo-bar-baz foo-bar foo}]],
        ['svn://foo/bar/baz/fred', [qw{foo-bar-baz foo-bar foo}]],
        ['svn://egg/ham/bacon'   , [                           ]],
        ['file://egg/ham/bacon'  , [qw{egg}                    ]],
    ) {
        my ($input, $expected_keys_ref) = @{$item};
        my $locator = FCM::Context::Locator->new($input);
        my $iter = $util->loc_kw_iter($locator);
        my @entries;
        while (my $entry = $iter->()) {
            push(@entries, $entry);
        }
        is_deeply(
            [map {$_->get_key()} @entries],
            $expected_keys_ref,
            "keyword_entry_iter: $input",
        );
    }
}

sub test_loc_as_normalised {
    my ($util, $DATA_REF) = @_;
    for my $item (
        ['fcm:foo'             , 'svn://foo'              ],
        ['fcm:foo/'            , 'svn://foo'              ],
        ['fcm:foo@bar'         , 'svn://foo@1234'         ],
        ['fcm:foo/bar/baz@baz' , 'svn://foo/bar/baz@43734'],
        ['fcm:foo/bar/baz@HEAD', 'svn://foo/bar/baz@HEAD' ],
        ['svn://foo'           , 'svn://foo'              ],
        ['svn://foo@bar'       , 'svn://foo@1234'         ],
    ) {
        my ($input, $expected) = @{$item};
        my $locator = FCM::Context::Locator->new($input);
        is(
            scalar($util->loc_as_normalised($locator)),
            $expected,
            "as_normalised: $input"
        );
    }
}

sub test_loc_as_keyword {
    my ($util, $DATA_REF) = @_;
    for my $item (
        ['svn://foo'              , 'fcm:foo'             ],
        ['svn://foo/'             , 'fcm:foo'             ],
        ['svn://foo@1234'         , 'fcm:foo@bar'         ],
        ['svn://foo/bar/baz@43734', 'fcm:foo-bar-baz@baz' ],
        ['svn://foo/bar/baz@HEAD' , 'fcm:foo-bar-baz@HEAD'],
        ['fcm:foo'                , 'fcm:foo'             ],
        ['fcm:foo@1234'           , 'fcm:foo@bar'         ],
    ) {
        my ($input, $expected) = @{$item};
        my $locator = FCM::Context::Locator->new($input);
        is(
            scalar($util->loc_as_keyword($locator)),
            $expected,
            "as_keyword: $input"
        );
    }
}

sub test_ns_cat {
    my ($util) = @_;
    for (
        [q{}             , q{}              , q{}                            ],
        [q{}             , q{egg}           , q{egg}                         ],
        [q{egg}          , q{}              , q{egg}                         ],
        [q{egg}          , q{ham}           , q{egg/ham}                     ],
        [q{egg/bacon}    , q{egg/sausage}   , q{egg/bacon/egg/sausage}       ],
        [q{egg/bacon}    , q{egg/bacon}     , q{egg/bacon/egg/bacon}         ],
        [q{egg/bacon/ham}, q{egg/bacon/bean}, q{egg/bacon/ham/egg/bacon/bean}],
    ) {
        my ($ns1, $ns2, $result) = @{$_};
        is($util->ns_cat($ns1, $ns2), $result, "$ns1 + $ns2");
    }
}

sub test_ns_common {
    my ($util) = @_;
    for (
        ['empty'  , q{}             , q{}              , q{}         ],
        ['empty1' , q{}             , q{egg}           , q{}         ],
        ['empty2' , q{egg}          , q{}              , q{}         ],
        ['level0' , q{egg}          , q{ham}           , q{}         ],
        ['level1' , q{egg/bacon}    , q{egg/sausage}   , q{egg}      ],
        ['level2-', q{egg/bacon}    , q{egg/bacon}     , q{egg/bacon}],
        ['level2' , q{egg/bacon/ham}, q{egg/bacon/bean}, q{egg/bacon}],
    ) {
        my ($name, $ns1, $ns2, $common) = @{$_};
        is($util->ns_common($ns1, $ns2), $common, $name);
    }
}

sub test_ns_iter {
    my ($util) = @_;
    for (
        ['empty', q{}        , (q{})                           ],
        ['empty', 'a'        , (q{}, q{a})                     ],
        ['empty', 'a/bee/cee', (q{}, 'a', 'a/bee', 'a/bee/cee')],
    ) {
        my ($name, $ns, @items) = @{$_};
        for my $up (0, 1) {
            my @results;
            my $iter = $util->ns_iter($ns, $up);
            while (defined(my $item = $iter->())) {
                push(@results, $item);
            }
            if ($up) {
                @results = reverse(@results);
            }
            is_deeply(\@items, \@results, $name);
        }
    }
}

sub test_shell {
    my ($util) = @_;
    # Tests using content of this file!
    open(my $handle, '<', $0) || die($!);
    my $content = do {local($/); readline($handle)};
    close($handle);
    eval {
        test_shell_with_cat_e($util);
        test_shell_with_cat_io_0($util, $content);
        test_shell_with_cat_io_1($util, $content);
        test_shell_with_cat_io_2($util, $content);
        test_shell_with_cat_o($util, $content);
    };
    if (my $e = $@) {
        die(Dumper($e));
    }
}

sub test_shell_with_cat_e {
    my ($util) = @_;
    # Simple error test
    my $path = catfile(tempdir(CLEANUP => 1), 'no-such-file');
    my %value_of = (e => q{}, o => q{});
    my %handler_of;
    for my $key (keys(%value_of)) {
        $handler_of{$key} = sub {$value_of{$key} .= $_[0]};
    }
    my $rc = $util->shell(['cat', $path], \%handler_of);
    isnt($rc, 0, 'e: rc');
    ok($value_of{e}, 'e: stderr');
    is($value_of{o}, q{}, 'e: stdout');
}

sub test_shell_with_cat_io_0 {
    my ($util, $content) = @_;
    # Simple input/output test
    my %value_of = (e => q{}, o => q{});
    my %handler_of;
    for my $key (keys(%value_of)) {
        $handler_of{$key} = sub {$value_of{$key} .= $_[0]};
    }
    my @value_of_i = map {$_ . "\n"} split("\n", $content);
    $handler_of{i} = sub {shift(@value_of_i)};
    my $rc = $util->shell(['cat'], \%handler_of);
    is($rc, 0, 'io-0: rc');
    is($value_of{e}, q{}, 'io-0: stderr');
    is($value_of{o}, $content, 'io-0: stdout');
}

sub test_shell_with_cat_io_1 {
    my ($util, $content) = @_;
    # Simple input/output test, alternate interface
    my $rc = $util->shell(
        ['cat'], {e => \my($err), i => \$content, o => \my($out)},
    );
    is($rc, 0, 'io-1: rc');
    is($err, q{}, 'io-1: stderr');
    is($out, $content, 'io-1: stdout');
}

sub test_shell_with_cat_io_2 {
    my ($util, $content) = @_;
    my @i = map {$_ . "\n"} split("\n", $content);
    # Simple input/output test, alternate interface
    my $rc = $util->shell(
        ['cat'], {e => \my($err), i => \@i, o => \my($out)},
    );
    is($rc, 0, 'io-2: rc');
    is($err, q{}, 'io-2: stderr');
    is($out, $content, 'io-2: stdout');
}

sub test_shell_with_cat_o {
    my ($util, $content) = @_;
    # Simple output test
    my %value_of = (e => q{}, o => q{});
    my %handler_of;
    for my $key (keys(%value_of)) {
        $handler_of{$key} = sub {$value_of{$key} .= $_[0]};
    }
    my $rc = $util->shell(['cat', $0], \%handler_of);
    is($rc, 0, 'o: rc');
    is($value_of{e}, q{}, 'o: stderr');
    is($value_of{o}, $content, 'o: stdout');
}

sub test_uri_match {
    my ($util) = @_;
    for (
        [q{}       , []],
        [q{fcm:foo}, [qw{fcm foo}]],
    ) {
        my ($string, $expected_list_ref) = @{$_};
        my $scalar = $util->uri_match($string);
        my @array  = $util->uri_match($string);
        if (@{$expected_list_ref}) {
            ok($scalar, "scalar: $string");
        }
        else {
            ok(!$scalar, "scalar: $string");
        }
        is_deeply(\@array, $expected_list_ref, "array: $string");
    }
}

__END__
