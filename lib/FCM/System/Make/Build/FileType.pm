# ------------------------------------------------------------------------------
# Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.
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
package FCM::System::Make::Build::FileType;
use base qw{FCM::Class::CODE};

use Text::ParseWords qw{shellwords};

# Creates the class.
__PACKAGE__->class(
    {   id                         => '$',
        file_ext                   => '$',
        file_pat                   => '$',
        file_she                   => '$',
        source_analyse_always      => '$',
        source_analyse_dep_of      => '%',
        source_analyse_more        => '&',
        source_analyse_more_init   => '&',
        source_to_targets          => '&',
        target_deps_filter         => '&',
        target_file_ext_of         => '%',
        target_file_name_option_of => '%',
        task_class_of              => '%',
        task_of                    => '%',
        util                       => '&',
    },
    {   init => \&_init,
        action_of => {
            (map {my $key = $_; ($key => sub {$_[0]->{$key}})}
                qw{
                    id
                    file_ext
                    file_pat
                    file_she
                    source_analyse_always
                    target_file_ext_of
                    target_file_name_option_of
                    task_of
                }
            ),
            source_analyse      => \&_source_analyse,
            source_analyse_deps => sub {keys(%{$_[0]->{source_analyse_dep_of}})},
            source_to_targets   => sub {$_[0]->{source_to_targets}->(@_)},
            target_deps_filter  => sub {$_[0]->{target_deps_filter}->(@_)},
        },
    },
);

# Initialises some attributes.
sub _init {
    my ($attrib_ref) = @_;
    while (my ($key, $class) = each(%{$attrib_ref->{task_class_of}})) {
        $attrib_ref->{util}->class_load($class);
        $attrib_ref->{task_of}{$key}
            = $class->new({util => $attrib_ref->{util}});
    }
}

# Reads information according to the $source.
sub _source_analyse {
    my ($attrib_ref, $source) = @_;
    my %no_dep_of;
    my %dep_type_of
        = map {($_ => 1)} keys(%{$attrib_ref->{source_analyse_dep_of}});
    while (my $type = each(%dep_type_of)) {
        my $key = 'no-dep.' . $type;
        if ($source->get_prop_of($key)) {
            for my $v (shellwords($source->get_prop_of($key))) {
                if ($v eq '*') {
                    delete($dep_type_of{$type});
                }
                else {
                    $no_dep_of{$type}{$v} = 1;
                }
            }
        }
    }
    if (!keys(%dep_type_of) && !$attrib_ref->{source_analyse_always}) {
        return;
    }
    my $path = $source->get_path();
    my $handle = $attrib_ref->{util}->file_load_handle($path);

    my @dep_types = keys(%dep_type_of)
        ? keys(%dep_type_of) : (_source_analyse_deps($attrib_ref));
    my (%dep_of, %info_of, %state);
    $attrib_ref->{source_analyse_more_init}->(\%info_of, \%state);
    LINE:
    while (my $line = readline($handle)) {
        chomp($line);
        TYPE:
        for my $type (@dep_types) {
            my ($item, $can_analyse_more)
                = $attrib_ref->{source_analyse_dep_of}{$type}->($line);
            if ($item) {
                $dep_of{$type}{$item} = 1;
                if ($can_analyse_more) {
                    last TYPE;
                }
                else {
                    next LINE;
                }
            }
        }
        $attrib_ref->{source_analyse_more}->($line, \%info_of, \%state);
    }

    close($handle);
    $source->set_info_of(\%info_of);
    while (my ($type, $hash_ref) = each(%dep_of)) {
        while (my $item = each(%{$hash_ref})) {
            if (!exists($no_dep_of{$type}{$item})) {
                push(@{$source->get_deps()}, [$item, $type]);
            }
        }
    }
}

1;
__END__

=head1 NAME

FCM::System::Make::Build::FileType

=head1 SYNOPSIS

    use FCM::System::Make::Build::FileType;
    my $file_type_util = FCM::System::Make::Build::FileType->new(\%attrib);
    $file_type_util->source_analyse($handle);

=head1 DESCRIPTION

An abstract class to implement the shared methods for gathering information to
build different types of source files.

=head1 METHODS

=over 4

=item $class->new(\%attrib)

Creates and returns a new instance.

=item $instance->id()

Returns the recommended ID of this file type.

=item $instance->file_ext()
=item $instance->file_pat()
=item $instance->file_she()

Returns the recommended file name extension, file name pattern and file she-bang
line pattern of this file type.

=item $instance->source_analyse($source)

Analysis $source for dependencies and other information. Add or modify items in
@{$source->get_deps()} and %{$source->get_info_of()}.

=item $instance->source_analyse_deps()

Returns a list containing the possible dependency types.

=item $instance->source_analyse_always()

Returns true if $instance->source_analyse($handle,\@dep_types) can read
information other than dependencies.

=item $instance->source_to_targets($source,\%prop_of)

Using the information in $source, creates and returns the contexts of a list of
suitable build targets. Where appropriate, the %prop_of should contain a mapping
of the names of the properties used by this method and their values.

=item $instance->target_deps_filter($target)

This may modify @{$target->get_deps()} in place based on values in
%{$target->get_prop_of()}. This method is normally implemented by sub-classes.

=item $instance->target_file_ext_of()

Returns a HASH reference containing a map between the named types of file
extensions used by the $instance->source_to_targets($source,\%prop_of) method
and their default values.

=item $instance->target_file_name_option_of()

Returns a HASH reference containing a map between the named types of files
used by the $instance->source_to_targets($source,\%prop_of) method
and their default settings for other file naming options.

=item $instance->task_of()

Returns a HASH reference containing a map between the named tasks for this file
type and their implementation objects. Each task should have a
$task->main($target) method to update a target and optionally a $task->prop_of()
method to return a HASH reference containing a map between the named properties
used by the task and their default values.

=back

=head1 COPYRIGHT

Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.

=cut
