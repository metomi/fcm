# ------------------------------------------------------------------------------
# (C) British Crown Copyright 2006-14 Met Office.
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
package FCM::System::Old;
use base qw{FCM::Class::CODE};

use Cwd qw{cwd};
use FCM1::Build;
use FCM1::Config;
use FCM1::Extract;
#use FCM1::ExtractConfigComparator;
use FCM1::Keyword;

my %CLASS_OF = (build => 'FCM1::Build', extract => 'FCM1::Extract');

my %KEY_OF = (
    'archive'     => 'ARCHIVE',
    'clean'       => 'CLEAN',
    'full'        => 'FULL',
    'ignore-lock' => 'IGNORE_LOCK',
    'jobs'        => 'JOBS',
    'stage'       => 'STAGE',
    'targets'     => 'TARGETS',
);

__PACKAGE__->class(
    {util => '&'},
    {   init => \&_init,
        action_of => {
            build          => sub {_run('build', @_)},
            config_compare => \&_config_compare,
            extract        => sub {_run('extract', @_)},
        },
    },
);

sub _init {
    my ($attrib_ref) = @_;
    if (!defined(FCM1::Keyword::get_util())) {
        FCM1::Keyword::set_util($attrib_ref->{util});
    }
}

sub _config_compare {
    my ($attrib_ref, $option_hash_ref, @args) = @_;
    $attrib_ref->{util}->class_load('FCM1::CmUrl');
    $attrib_ref->{util}->class_load('FCM1::ExtractConfigComparator');
    if (exists($option_hash_ref->{verbosity})) {
        FCM1::Config->instance()->verbose($option_hash_ref->{verbosity});
    }
    my %option = %{$option_hash_ref};
    if (exists($option{'wiki-format'})) {
        $option{'wiki'} = delete($option{'wiki-format'});
    }
    my $system = FCM1::ExtractConfigComparator->new({files => \@args, %option});
    $system->invoke();
}

sub _run {
    my ($key, $attrib_ref, $option_hash_ref, @args) = @_;
    if (exists($option_hash_ref->{targets})) {
        @{$option_hash_ref->{targets}}
            = split(qr{:}msx, join(':', @{$option_hash_ref->{targets}}));
    }
    if (exists($option_hash_ref->{verbosity})) {
        FCM1::Config->instance()->verbose($option_hash_ref->{verbosity});
    }
    my $system = $CLASS_OF{$key}->new();
    my $path_to_cfg = @args ? $args[0] : cwd();
    $system->cfg()->src($path_to_cfg);
    my %option_of;
    while (my ($key, $value) = each(%{$option_hash_ref})) {
        if (exists($KEY_OF{$key})) {
            $option_of{$KEY_OF{$key}} = $value;
        }
    }
    $system->invoke(%option_of);
}

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::System::Old

=head1 SYNOPSIS

    use FCM::System::Old;
    my $system = FCM::System::Old->new();
    $system->('extract', \%option, \@args);

=head1 DESCRIPTION

Provides a compatibility layer for obsolete FCM 1 functionalities.

=head1 METHODS

=over 4

=item $class->new()

Creates and returns an instance of this class.

=item $instance->build(\%option,@args)

Invokes the FCM 1 build system.

=item $instance->config_compare(\%option,@args)

Invokes the FCM 1 cmp-ext-cfg application.

=item $instance->extract(\%option,@args)

Invokes the FCM 1 extract system.

=back

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
