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
package FCM::System::CM::Prompt;
use base qw{FCM::Class::CODE};

use FCM::Context::Event;

our $TYPE_YN = 'TYPE_YN';

# Format string table
my %S = (
    'BRANCH_CREATE'     => 'Create the branch?',
    'OVERWRITE'         => '%s: file exists, overwrite?',
    'PROJECT_CREATE'    => 'Create the project?',
    'RESOLVE'           => 'Run "svn resolve --accept working %s"?',
    'TC'                => "Locally: %s.\n"
                           . "Externally: %s.\n"
                           . "Answer (y) to %s.\n"
                           . "Answer (n) to %s.\n"
                           . '%s'
                           . 'Keep the local version?',
    'TC_ACTION'         => 'accept the %s %s',
    'TC_ACTION_ADD'     => 'keep the %s file filename',
    'TC_ACTION_EDIT'    => 'keep the file',
    'TC_ACTION_DELETE'  => 'delete the file',
    'TC_FROM_LOC'       => 'local',
    'TC_FROM_INC'       => 'external',
    'TC_MERGE'          => "You can then merge in changes.\n",
    'TC_ST_ADD'         => 'added',
    'TC_ST_DELETE'      => 'deleted',
    'TC_ST_EDIT'        => 'edited',
    'TC_ST_RENAME'      => 'renamed to %s',
);

# Configuration for questions
# KEY => {'format' => $|&, 'type' => $}
my %Q_CONF = (
    # Simple question prompts
    (   map {($_ => {'format' => $S{$_}, 'type' => q{}})}
            qw{BRANCH_CREATE OVERWRITE PROJECT_CREATE RESOLVE}
    ),
    # Tree conflicts prompts: TC_LxIy, for local x, incoming y
    # where x and y correspond to:
    # A => add,
    # D => delete,
    # E => edit,
    # M => missing,
    # R => rename
    (   map {('TC_' . $_ => {'format' => \&_q_tree_conflict, 'type' => $TYPE_YN})}
            qw(LAIA LDID LDIE LDIR LEID LEIR LRID LRIE LRIR)
    ),
);

__PACKAGE__->class(
    {gui => '$', util => '&'},
    {init => \&_init, action_of => {question => \&_q}},
);

sub _init {
    my $attrib_ref = shift();
    my $class = $attrib_ref->{gui}
        ? 'FCM::System::CM::Prompt::Zenity' : 'FCM::System::CM::Prompt::Simple';
    $attrib_ref->{impl} = $class->new({util => $attrib_ref->{util}});
}

sub _q {
    my ($attrib_ref, $key, @args) = @_;
    my $format = $Q_CONF{$key}{'format'};
    my $prompt = ref($format) ? $format->(@args) : sprintf($format, @args);
    $attrib_ref->{'impl'}->question($Q_CONF{$key}{'type'}, $prompt);
}

# Tree conflict prompt.
# $tree_key is the FCM::System::CM::TreeConflictKey for the conflict.
# $rename_loc is the new local name for the conflict file, if any.
# $rename_inc is the new incoming name for the conflict file, if any.
sub _q_tree_conflict {
    my ($tree_key, $rename_loc, $rename_inc) = @_;
    my %opt_of = (
        'loc' => {'key' => $tree_key->get_local()   , 'rename' => $rename_loc},
        'inc' => {'key' => $tree_key->get_incoming(), 'rename' => $rename_inc},
    );
    sprintf($S{'TC'}, (
        (   map {
                my $opt = $_;
                my $message = $S{'TC_ST_' . uc($opt->{'key'})};
                if ($opt->{'key'} eq 'rename') {
                    $message = sprintf($message, $opt->{'rename'});
                }
                $message;
            }
            @opt_of{'loc', 'inc'}
        ),
        (   map {
                my $location_key = $_;
                my $from = $S{'TC_FROM_' . uc($location_key)};
                my $key = $opt_of{$location_key}->{'key'};
                  $key eq 'add'     ? sprintf($S{'TC_ACTION_ADD'}, $from)
                : $key eq 'delete'  ? $S{'TC_ACTION_DELETE'}
                : $key eq 'edit'    ? $S{'TC_ACTION_EDIT'}
                :                     sprintf($S{'TC_ACTION'}, $from, $key)
                ;
            }
            ('loc', 'inc')
        ),
        (   (        (grep {$opt_of{'loc'}{'key'} eq $_} qw{rename edit})
                &&   (grep {$opt_of{'inc'}{'key'} eq $_} qw{rename edit})
            )
            ? $S{'TC_MERGE'} : q{}
        ),
    ));
}

#-------------------------------------------------------------------------------
package FCM::System::CM::Prompt::Simple;
use base qw{FCM::Class::CODE};

use FCM::Context::Event;

our %SETTING_OF = (
    q{}       => {'choices' => [qw{y n}], 'default' => 'n', 'positive' => 'y'},
    'TYPE_YN' => {'choices' => [qw{y n}], 'default' => 'n', 'positive' => 'y'},
);

__PACKAGE__->class({util => '&'}, {action_of => {question => \&_question}});

sub _question {
    my ($attrib_ref, $type, $question) = @_;
    my %setting = %{$SETTING_OF{$type}};
    _prompt($attrib_ref, $question, $setting{'choices'}, $setting{'default'})
        eq $setting{'positive'};
}

sub _prompt {
    my ($attrib_ref, $question, $choices_ref, $default) = @_;
    my ($tail, @heads) = reverse(@{$choices_ref});
    my $prompt
        = $question . "\n"
        . sprintf('Enter "%s" or "%s"', join(q{, }, reverse(@heads)), $tail)
        . sprintf(' (or just press <return> for "%s") ', $default);
    my $answer;
    while (!defined($answer)) {
        $attrib_ref->{util}->event(FCM::Context::Event->OUT, $prompt);
        $answer = readline(STDIN);
        chomp($answer);
        if (!$answer) {
            $answer = $default;
        }
        if (!grep {$_ eq $answer} @{$choices_ref}) {
            $answer = undef;
        }
    }
    return $answer;
}

#-------------------------------------------------------------------------------
package FCM::System::CM::Prompt::Zenity;
use base qw{FCM::Class::CODE};

our %OPTIONS_OF = (
    q{}       => [],
    'TYPE_YN' => ['--ok-label=_Yes', '--cancel-label=_No'],
);

__PACKAGE__->class({util => '&'}, {action_of => {question => \&_question}});

sub _question {
    my ($attrib_ref, $type, $question) = @_;
    _zenity($attrib_ref, qw{--question --text}, $question, @{$OPTIONS_OF{$type}});
}

sub _zenity {
    my ($attrib_ref, @args) = @_;
    my @command = ('zenity', @args);
    my %value_of = %{$attrib_ref->{util}->shell_simple(\@command)};
    !$value_of{rc};
}

1;
__END__

=head1 NAME

FCM::System::CM::Prompt

=head1 SYNOPSIS

    use FCM::System::CM::Prompt;
    my $prompt = FCM::System::CM::Prompt->new(\%attrib);
    if ($prompt->question($key, @args)) {
        # do something
    }

=head1 DESCRIPTION

Helper module for prompts in the FCM code management sub-system.
See L<FCM::System::CM|FCM::System::CM> for detail.

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
