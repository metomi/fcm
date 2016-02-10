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
package FCM::System::Misc;
use base qw{FCM::Class::CODE};

use Cwd qw{cwd};
use FCM::Context::Event;
use FCM::Context::Locator;
use FCM::System::Exception;
use FCM::Util::ConfigReader;
use File::Path qw{mkpath rmtree};
use File::Spec::Functions qw{catfile};
use List::Util qw{max};
use Text::ParseWords qw{shellwords};

# The (keys) named actions of this class and (values) their implementations.
our %ACTION_OF = (
    browse       => \&_browse,
    config_parse => \&_config_parse,
    export_items => \&_export_items,
    keyword_find => \&_keyword_find,
);
# Alias to exception class
my $E = 'FCM::System::Exception';

# Creates the class.
__PACKAGE__->class({util => '&'}, {action_of => \%ACTION_OF});

# Launches a web browser to display some version controlled resources.
sub _browse {
    my ($attrib_ref, $option_ref, @args) = @_;
    my $UTIL = $attrib_ref->{util};
    my @command = shellwords(
          exists($option_ref->{browser}) ? $option_ref->{browser}
        :                                  $UTIL->external_cfg_get('browser')
    );
    if (!@args) {
        @args = (cwd());
    }
    for my $value (@args) {
        my $locator = FCM::Context::Locator->new($value);
        my $url = $UTIL->loc_browser_url($locator);
        my %value_of = %{$UTIL->shell_simple([@command, $url])};
        if ($value_of{rc}) {
            return $E->throw(
                $E->SHELL,
                {command_list => [@command, $url], %value_of},
                $value_of{e},
            );
        }
        $attrib_ref->{util}->event(FCM::Context::Event->OUT, $value_of{o});
    }
    return;
}

# Parses and displays the content of a FCM configuration file.
sub _config_parse {
    my ($attrib_ref, $option_ref, @args) = @_;
    my $reader_attrib_ref;
    if (exists($option_ref->{'fcm1'})) {
        $reader_attrib_ref = \%FCM::Util::ConfigReader::FCM1_ATTRIB;
    }
    for my $value (@args) {
        my $locator = FCM::Context::Locator->new($value);
        my $iter = $attrib_ref->{util}->config_reader(
            $locator, $reader_attrib_ref,
        );
        while (my $entry = $iter->()) {
            $attrib_ref->{util}->event(
                FCM::Context::Event->CONFIG_ENTRY,
                $entry,
                exists($option_ref->{'fcm1'}),
            );
        }
    }
    return;
}

# Exports directories in a project as sequential versioned items.
sub _export_items {
    my ($attrib_ref, $option_ref, $location) = @_;
    if (!$location) {
        return $E->throw($E->EXPORT_ITEMS_SRC);
    }
    $location ||= q{.};
    my $UTIL = $attrib_ref->{util};
    # Options and arguments
    $option_ref->{directory} ||= cwd();
    $option_ref->{'config-file'} ||= ['fcm-export-items.cfg'];
    my $locator = FCM::Context::Locator->new($location);
    $UTIL->loc_as_invariant($locator);
    # Timer
    my $time_start = time();
    my $timer = $UTIL->timer();
    my %EVENT = (
        'create' => sub {
            $UTIL->event(FCM::Context::Event->EXPORT_ITEM_CREATE, @_);
        },
        'delete' => sub {
            $UTIL->event(FCM::Context::Event->EXPORT_ITEM_DELETE, @_);
        },
        'timer' => sub {
            $UTIL->event(
                FCM::Context::Event->TIMER, 'export-items', $time_start, @_,
            );
        },
    );
    $EVENT{'timer'}->();
    # Reads configuration file
    my $config_reader = $attrib_ref->{util}->config_reader(
        FCM::Context::Locator->new($option_ref->{'config-file'}->[0]),
        {   %FCM::Util::ConfigReader::FCM1_ATTRIB,
            event_level => $attrib_ref->{util}->util_of_report()->LOW,
        },
    );
    my %conditions_of;
    while (defined(my $entry = $config_reader->())) {
        # Value: conditions
        my @conditions;
        for my $word (shellwords($entry->get_value())) {
            my ($operator, $rev) = $word =~ qr{\A ([<>]=?|[!=]=) (.+) \z}imsx;
            if (!$operator || !$rev) {
                return $E->throw($E->CONFIG_VALUE, $entry);
            }
            push(@conditions, $operator . $rev); # FIXME: keyword?
        }
        # Label: targets and namespaces
        my ($target) = $entry->get_label() =~ qr{\A (.+) / \*\z}msx;
        if ($target) {
            my $l_target = $UTIL->loc_cat($locator, $target);
            $UTIL->loc_find(
                $l_target,
                sub {
                    my ($l_child, $attrib_of_child_ref) = @_;
                    if (!$attrib_of_child_ref->{is_dir}) {
                        my $ns_of_child = $attrib_of_child_ref->{ns};
                        my $iter
                            = $UTIL->ns_iter($ns_of_child, $UTIL->NS_ITER_UP);
                        $iter->(); # discard
                        my $ns = $UTIL->ns_cat($target, $iter->());
                        if (!exists($conditions_of{$ns})) {
                            $conditions_of{$ns} = \@conditions;
                        }
                    }
                },
            );
        }
        else {
            $conditions_of{$entry->get_label()} = \@conditions;
        }
    }
    # Export
    NS:
    while (my ($ns, $conditions_ref) = each(%conditions_of)) {
        # FIXME: this should be encapsulated by the locator util.
        my @command_list = (
            qw{svn log -q},
            $UTIL->loc_cat($locator, $ns)->get_value(),
        );
        my %value_of = %{$UTIL->shell_simple(\@command_list)};
        if ($value_of{rc}) {
            return $E->throw(
                $E->SHELL,
                {command_list => \@command_list, %value_of},
                $value_of{e},
            );
        }
        my @revs = map {($_ =~ qr{\Ar(\d+)})} split("\n", $value_of{o});
        my %v_of;
        my $v = 0;
        for my $rev (reverse(@revs)) {
            $v_of{$rev} = 'v' . ++$v;
        }
        my %cur_v_of = %v_of;
        # Exports only revisions matching the conditions
        for my $condition (@{$conditions_ref}) {
            for my $rev (keys(%cur_v_of)) {
                if (!eval($rev . $condition)) {
                    delete($cur_v_of{$rev});
                }
            }
        }
        # Destination directory
        my $path = catfile($option_ref->{directory}, $ns);
        if (-d $path) {
            if ($option_ref->{new} || !keys(%cur_v_of)) {
                rmtree($path);
            }
            else {
                # Delete excluded revisions if they exist in incremental mode
                if (opendir(my $handle, $path)) {
                    while (my $item = readdir($handle)) {
                        if (exists($v_of{$item}) && !exists($cur_v_of{$item})) {
                            for (($item, $v_of{$item})) {
                                my $p = catfile($path, $_);
                                rmtree($p);
                                $EVENT{'delete'}->($ns, $item, $p);
                            }
                        }
                    }
                    closedir($handle);
                }
            }
        }
        if (!keys(%cur_v_of)) {
            next NS;
        }
        if (!-d $path) {
            mkpath($path);
        }

        # Exports each revision, and creates symlink for each v
        while (my ($rev, $v) = each(%cur_v_of)) {
            my $target = catfile($option_ref->{directory}, $ns, $v);
            if (-l $target || -f $target) {
                unlink($target);
                $EVENT{'delete'}->($ns, $v, $target);
            }
            if (!-d $target) {
                my $url_peg_rev = $UTIL->loc_cat($locator, $ns)->get_value();
                my ($url) = $url_peg_rev =~ qr{\A(.*?)(?:@[^@/]+)?\z}msx;
                my @command_list = (qw{svn export -q -r}, $rev, $url, $target);
                my %value_of = %{$UTIL->shell_simple(\@command_list)};
                if ($value_of{rc} || !-d $target) {
                    return $E->throw(
                        $E->SHELL,
                        {command_list => \@command_list, %value_of},
                        $value_of{e},
                    );
                }
                $EVENT{'create'}->($ns, $v, $target);
            }
            my $link = catfile($option_ref->{directory}, $ns, $rev);
            if (-e $link && !-l $link) {
                rmtree($link);
                $EVENT{'delete'}->($ns, $rev, $link);
            }
            elsif (-l $link && readlink($link) ne $v) {
                unlink($link);
                $EVENT{'delete'}->($ns, $rev, $link);
            }
            if (!-e $link) {
                symlink($v, $link);
                $EVENT{'create'}->($ns, $rev, $link);
            }
        }

        # Symbolic link to the "latest" version directory
        my $link_of_latest = catfile($option_ref->{directory}, $ns, 'latest');
        my $v_of_latest = $cur_v_of{max(keys(%cur_v_of))};
        if (-e $link_of_latest && !-l $link_of_latest) {
            rmtree($link_of_latest);
            $EVENT{'delete'}->($ns, 'latest', $link_of_latest);
        }
        elsif (-l $link_of_latest && readlink($link_of_latest) ne $v_of_latest) {
            unlink($link_of_latest);
            $EVENT{'delete'}->($ns, 'latest', $link_of_latest);
        }
        if (!-l $link_of_latest) {
            symlink($v_of_latest, $link_of_latest);
            $EVENT{'create'}->($ns, 'latest', $link_of_latest);
        }
    }
    $EVENT{'timer'}->($timer->());
}

# Searches FCM keywords.
sub _keyword_find {
    my ($attrib_ref, $option_ref, @args) = @_;
    my $UTIL = $attrib_ref->{util};
    my @entries;
    if (@args) {
        for my $key (@args) {
            my $iter = $UTIL->loc_kw_iter(FCM::Context::Locator->new($key));
            while (my $entry = $iter->()) {
                if (!$entry->get_implied()) {
                    $UTIL->loc_kw_load_rev_prop($entry);
                    push(@entries, $entry);
                }
            }
        }
    }
    else {
        @entries = values(%{$UTIL->loc_kw_ctx()->get_entry_by_key()});
    }
    for my $entry (sort {$a->get_key() cmp $b->get_key()} @entries) {
        $UTIL->event(FCM::Context::Event->KEYWORD_ENTRY, $entry);
    }
    return;
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Misc

=head1 SYNOPSIS

    use FCM::System::Misc;
    my $system = FCM::System::Misc->new(\%attrib);
    $system->keyword_find(@args);

=head1 DESCRIPTION

The rest of the FCM system.

=head1 METHODS

Implements the browse(), config_parse(), export_items() and keyword_find()
methods for L<FCM::System|FCM::System>. See L<FCM::System|FCM::System> for a
description of the calling interfaces of these functions.

=head1 DIAGNOSTICS

=head2 FCM::System::Exception

Methods of this class may throw a FCM::System::Exception.

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
