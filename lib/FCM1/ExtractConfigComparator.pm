# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-17 Met Office.
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

################################################################################
# A generic reporter of the comparator's result
{
    package Reporter;

    ############################################################################
    # Class method: Constructor
    sub new {
        my ($class) = @_;
        return bless(\do{my $annon_scalar}, $class);
    }

    ############################################################################
    # Class method: Factory for Reporter object
    sub get_reporter {
        my ($self, $comparator) = @_;
        my $class = defined($comparator->get_wiki()) ? 'WikiReporter'
                  :                                    'TextReporter'
                  ;
        return $class->new();
    }

    ############################################################################
    # Reports the results
    sub report {
        my ($self, $comparator) = @_;
        if (keys(%{$comparator->get_log_of()})) {
            print("Revisions at which extract declarations are modified:\n\n");
        }
        $self->report_impl($comparator);
    }

    ############################################################################
    # Does the actual reporting
    sub report_impl {
        my ($self, $comparator) = @_;
    }
}

################################################################################
# Reports the comparator's result in Trac wiki format
{
    package WikiReporter;
    our @ISA = qw{Reporter};

    use FCM1::CmUrl;
    use FCM1::Keyword;
    use FCM1::Util qw{tidy_url};

    ############################################################################
    # Reports the comparator's result
    sub report_impl {
        my ($self, $comparator) = @_;
        # Output in wiki format
        my $wiki_url = FCM1::CmUrl->new(
            URL => tidy_url(FCM1::Keyword::expand($comparator->get_wiki()))
        );
        my $base_trac
            = $comparator->get_wiki()
            ? FCM1::Keyword::get_browser_url($wiki_url->project_url())
            : $wiki_url;
        if (!$base_trac) {
            $base_trac = $wiki_url;
        }

        for my $key (sort keys(%{$comparator->get_log_of()})) {
            my $branch_trac = FCM1::Keyword::get_browser_url($key);
            $branch_trac =~ s{\A $base_trac (?:/*|\z)}{source:}xms;
            print("[$branch_trac]:\n");
            my %branch_of = %{$comparator->get_log_of()->{$key}};
            for my $rev (sort {$b <=> $a} keys(%branch_of)) {
                print(
                    $branch_of{$rev}->display_svnlog($rev, $base_trac), "\n",
                );
            }
            print("\n");
        }
    }
}

################################################################################
# Reports the comparator's result in simple text format
{
    package TextReporter;
    our @ISA = qw{Reporter};

    use FCM1::Config;

    my $SEPARATOR = q{-} x 80 . "\n";

    ############################################################################
    # Reports the comparator's result
    sub report_impl {
        my ($self, $comparator) = @_;
        for my $key (sort keys(%{$comparator->get_log_of()})) {
            # Output in plain text format
            print $key, ':', "\n";
            my %branch_of = %{$comparator->get_log_of()->{$key}};
            if (FCM1::Config->instance()->verbose() > 1) {
                for my $rev (sort {$b <=> $a} keys(%branch_of)) {
                    print(
                        $SEPARATOR, $branch_of{$rev}->display_svnlog($rev), "\n"
                    );
                }
            }
            else {
                print(join(q{ }, sort {$b <=> $a} keys(%branch_of)), "\n");
            }
            print $SEPARATOR, "\n";
        }
    }
}

package FCM1::ExtractConfigComparator;

use FCM1::CmUrl;
use FCM1::Extract;

################################################################################
# Class method: Constructor
sub new {
    my ($class, $args_ref) = @_;
    return bless({%{$args_ref}}, $class);
}

################################################################################
# Returns an array containing the 2 configuration files to compare
sub get_files {
    my ($self) = @_;
    return (wantarray() ? @{$self->{files}} : $self->{files});
}

################################################################################
# Returns the wiki link on wiki mode
sub get_wiki {
    my ($self) = @_;
    return $self->{wiki};
}

################################################################################
# Returns the result log
sub get_log_of {
    my ($self) = @_;
    return (wantarray() ? %{$self->{log_of}} : $self->{log_of});
}

################################################################################
# Invokes the comparator
sub invoke {
    my ($self) = @_;

    # Reads the extract configurations
    my (@cfg, $rc);
    for my $i (0 .. 1) {
        $cfg[$i] = FCM1::Extract->new();
        $cfg[$i]->cfg()->src($self->get_files()->[$i]);
        $cfg[$i]->parse_cfg();
        $rc = $cfg[$i]->expand_cfg();
        if (!$rc) {
            e_report();
        }
    }

    # Get list of URLs
    # --------------------------------------------------------------------------
    my @urls = ();
    for my $i (0 .. 1) {
        # List of branches in each extract configuration file
        my @branches = @{$cfg[$i]->branches()};
        BRANCH:
        for my $branch (@branches) {
            # Ignore declarations of local directories
            if ($branch->type() eq 'user') {
                next BRANCH;
            }

            # List of SRC declarations in each branch
            my %dirs = %{$branch->dirs()};

            for my $dir (values(%dirs)) {
                # Set up a new instance of FCM1::CmUrl object for each SRC
                my $cm_url = FCM1::CmUrl->new (
                    URL => $dir . (
                        $branch->revision() ? '@' . $branch->revision() : q{}
                    ),
                );

                $urls[$i]{$cm_url->branch_url()}{$dir} = $cm_url;
            }
        }
    }

    # Compare
    # --------------------------------------------------------------------------
    $self->{log_of} = {};
    for my $i (0 .. 1) {
        # Compare the first file with the second one and then vice versa
        my $j = ($i == 0) ? 1 : 0;

        for my $branch (sort keys(%{$urls[$i]})) {
            if (exists($urls[$j]{$branch})) {
                # Same REPOS declarations in both files
                DIR:
                for my $dir (sort keys(%{$urls[$i]{$branch}})) {
                    if (exists($urls[$j]{$branch}{$dir})) {
                        if ($i == 1) {
                            next DIR;
                        }

                        my $this_url = $urls[$i]{$branch}{$dir};
                        my $that_url = $urls[$j]{$branch}{$dir};

                        # Compare their last changed revisions
                        my $this_rev
                            = $this_url->svninfo(FLAG => 'commit:revision');
                        my $that_rev
                            = $that_url->svninfo(FLAG => 'commit:revision');

                        # Make sure last changed revisions differ
                        if ($this_rev eq $that_rev) {
                            next DIR;
                        }

                        # Not interested in the log before the minimum revision
                        my $min_rev
                            = $this_url->pegrev() > $that_url->pegrev()
                              ? $that_url->pegrev() : $this_url->pegrev();

                        $this_rev = $min_rev if $this_rev < $min_rev;
                        $that_rev = $min_rev if $that_rev < $min_rev;

                        # Get list of changed revisions using the commit log
                        my $u = ($this_rev > $that_rev) ? $this_url : $that_url;
                        my %revs = $u->svnlog(REV => [$this_rev, $that_rev]);

                        REV:
                        for my $rev (keys %revs) {
                            # Check if revision is already in the list
                            if (
                                   exists($self->{log_of}{$branch}{$rev})
                                || $rev == $min_rev
                            ) {
                                next REV;
                            }

                            # Get list of changed paths. Accept this revision
                            # only if it contains changes in the current branch
                            my %paths  = %{$revs{$rev}{paths}};

                            PATH:
                            for my $path (keys(%paths)) {
                                my $change_url
                                    = FCM1::CmUrl->new(URL => $u->root() . $path);

                                if ($change_url->branch() eq $u->branch()) {
                                    $self->{log_of}{$branch}{$rev} = $u;
                                    last PATH;
                                }
                            }
                        }
                    }
                    else {
                        $self->_report_added(
                            $urls[$i]{$branch}{$dir}->url_peg(), $i, $j);
                    }
                }
            }
            else {
                $self->_report_added($branch, $i, $j);
            }
        }
    }

    my $reporter = Reporter->get_reporter($self);
    $reporter->report($self);
    return $rc;
}

################################################################################
# Reports added/deleted declaration
sub _report_added {
    my ($self, $branch, $i, $j) = @_;
    printf(
        "%s:\n  in    : %s\n  not in: %s\n\n",
        $branch, $self->get_files()->[$i], $self->get_files()->[$j],
    );
}

1;
__END__

=head1 NAME

FCM1::ExtractConfigComparator

=head1 SYNOPSIS

    use FCM1::ExtractConfigComparator;
    my $comparator = FCM1::ExtractConfigComparator->new({files => \@files});
    $comparator->invoke();

=head1 DESCRIPTION

An object of this class represents a comparator of FCM extract configuration.
It is used to compare the VC branch declarations in 2 FCM extract configuration
files.

=head1 METHODS

=over 4

=item C<new({files =E<gt> \@files, wiki =E<gt> $wiki})>

Constructor.

=item get_files()

Returns an array containing the 2 configuration files to compare.

=item get_wiki()

Returns the wiki link on wiki mode.

=item invoke()

Invokes the comparator.

=back

=head1 TO DO

More documentation.

Improve the parser for extract configuration.

Separate the comparator with the reporters.

Add reporter to display HTML.

More unit tests.

=head1 SEE ALSO

L<FCM1::Extract|FCM1::Extract>

=head1 COPYRIGHT

E<169> Crown copyright Met Office. All rights reserved.

=cut
