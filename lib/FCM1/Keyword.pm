#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------
use strict;
use warnings;

package FCM1::Keyword;

use FCM::Context::Locator;

# Returns/Sets the FCM 2 utility functional object.
{   my $UTIL;
    sub get_util {
        $UTIL;
    }
    sub set_util {
        $UTIL = $_[0];
    }
}

# Expands (the keywords in) the specfied location (and REV), and returns them
sub expand {
    my ($in_loc, $in_rev) = @_;
    my $target = $in_rev ? $in_loc . '@' . $in_rev : $in_loc;
    my $locator = FCM::Context::Locator->new($target);
    _unparse_loc(get_util()->loc_as_normalised($locator), $in_rev);
}

# Returns the corresponding browser URL for the input VC location
sub get_browser_url {
    my ($in_loc, $in_rev) = @_;
    my $target = $in_rev ? $in_loc . '@' . $in_rev : $in_loc;
    my $locator = FCM::Context::Locator->new($target);
    get_util()->loc_browser_url($locator);
}

# Un-expands the specfied location (and REV) to keywords, and returns them
sub unexpand {
    my ($in_loc, $in_rev) = @_;
    my $target = $in_rev ? $in_loc . '@' . $in_rev : $in_loc;
    my $locator = FCM::Context::Locator->new($target);
    _unparse_loc(get_util()->loc_as_keyword($locator), $in_rev);
}

# If $in_rev, returns (LOC, REV). Otherwise, returns LOC@REV
sub _unparse_loc {
    my ($loc, $in_rev) = @_;
    if (!$loc) {
        return;
    }
    if ($in_rev) {
        my ($l, $r) = $loc =~ qr{\A (.*?) @([^@]+) \z}msx;
        if ($l && $r) {
            return ($l, $r);
        }
    }
    return $loc;
}

1;
__END__

=head1 NAME

FCM1::Keyword

=head1 SYNOPSIS

    use FCM1::Keyword;

    $loc = FCM1::Keyword::expand('fcm:namespace/path@rev-keyword');
    $loc = FCM1::Keyword::unexpand('svn://host/namespace/path@1234');

    ($loc, $rev) = FCM1::Keyword::expand('fcm:namespace/path', 'rev-keyword');
    ($loc, $rev) = FCM1::Keyword::unexpand('svn://host/namespace/path', 1234);

    $loc = FCM1::Keyword::get_browser_url('fcm:namespace/path');
    $loc = FCM1::Keyword::get_browser_url('svn://host/namespace/path');

    $loc = FCM1::Keyword::get_browser_url('fcm:namespace/path@1234');
    $loc = FCM1::Keyword::get_browser_url('svn://host/namespace/path@1234');

    $loc = FCM1::Keyword::get_browser_url('fcm:namespace/path', 1234);
    $loc = FCM1::Keyword::get_browser_url('svn://host/namespace/path', 1234);

=head1 DESCRIPTION

Provides a compatibility layer for code in FCM1::* name space by wrapping the
keyword related functions in L<FCM::Util|FCM::Util>. An instance of
L<FCM::Util|FCM::Util> must be set via the set_util($value) function before
using the other functions.

=head1 FUNCTIONS

=over 4

=item expand($loc)

Expands FCM keywords in $loc and returns the result.

If $loc is a I<fcm> scheme URI, the leading part (before any "/" or "@"
characters) of the URI opaque is the namespace of a FCM location keyword. This
is expanded into the actual value. Optionally, $loc can be suffixed with a peg
revision (an "@" followed by any characters). If a peg revision is a FCM
revision keyword, it is expanded into the actual revision.

=item expand($loc,$rev)

Same as C<expand($loc)>, but $loc should not contain a peg revision. Returns a
list containing the expanded version of $loc and $rev.

=item get_browser_url($loc)

Given a repository $loc in a known keyword namespace, returns the corresponding
URL for the code browser.

Optionally, $loc can be suffixed with a peg revision (an "@" followed by any
characters).

=item get_browser_url($loc,$rev)

Same as get_browser_url($loc), but the revision should be specified using $rev
but not pegged with $loc.

=item get_util()

Returns the L<FCM::Util|FCM::Util> instance (set by set_util($value)).

=item set_util($value)

Sets the L<FCM::Util|FCM::Util> instance.

=item unexpand($loc)

Does the opposite of expand($loc). Returns the FCM location keyword equivalence
of $loc. If the $loc can be mapped using 2 or more namespaces, the namespace
that results in the longest substitution is used. Optionally, $loc can be
suffixed with a peg revision (an "@" followed by any characters). If a peg
revision is a known revision, it is turned into its corresponding revision
keyword.

=item unexpand($loc,$rev)

Same as unexpand($loc), but $loc should not contain a peg revision. Returns a
list containing the unexpanded version of $loc and $rev 

=item 

=back

=head1 SEE ALSO

L<FCM::System|FCM::System>,
L<FCM::Util|FCM::Util>

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
