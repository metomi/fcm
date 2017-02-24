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
# ------------------------------------------------------------------------------
package FCM::Util::TaskRunner;
use base qw{FCM::Class::CODE};

my $P = 'FCM::Util::TaskRunner::Parallel';
my $S = 'FCM::Util::TaskRunner::Serial';

__PACKAGE__->class({util => '&'}, {action_of => {main => \&_main}});

sub _main {
    my ($attrib_ref, $action_ref, $n_workers) = @_;
    $n_workers ||= 1;
    my $class = $n_workers > 1 ? $P : $S;
    $attrib_ref->{runner} = $class->new({
        action    => $action_ref,
        n_workers => $n_workers,
        util      => $attrib_ref->{util},
    });
}

# ------------------------------------------------------------------------------
package FCM::Util::TaskRunner::Serial;
use base qw{FCM::Class::CODE};

__PACKAGE__->class(
    {action => '&', util => '&'},
    {action_of => {destroy => sub {}, main => \&_main}},
);

sub _main {
    my ($attrib_ref, $get_ref, $put_ref) = @_;
    my $n_done = 0;
    while (my $task = $get_ref->()) {
        my $timer = $attrib_ref->{util}->timer();
        eval {
            $task->set_state($task->ST_WORKING);
            $attrib_ref->{action}->($task->get_ctx());
            $task->set_state($task->ST_OK);
        };
        if ($@) {
            $task->set_error($@);
            $task->set_state($task->ST_FAILED);
        }
        $task->set_elapse($timer->());
        $put_ref->($task);
        ++$n_done;
    }
    $n_done;
}

# ------------------------------------------------------------------------------
package FCM::Util::TaskRunner::Parallel;
use base qw{FCM::Class::CODE};

use FCM::Context::Event;
use IO::Select;
use IO::Socket;
use List::Util qw{first};
use POSIX qw{WNOHANG};
use Socket qw{AF_UNIX SOCK_STREAM PF_UNSPEC};
use Storable qw{freeze thaw};

# Package name of worker event and state
my $CTX_EVENT = 'FCM::Context::Event';
my $CTX_STATE = 'FCM::Util::TaskRunner::WorkerState';

# Length of a packed long integer
my $LEN_OF_LONG = length(pack('N', 0));

# Time out for polling sockets to child processes
my $TIME_OUT = 0.05;

# Creates the class.
__PACKAGE__->class(
    {   action        => '&',
        n_workers     => '$',
        worker_states => '@',
        util          => '&',
    },
    {init => \&_init, action_of => {destroy => \&_destroy, main => \&_main}},
);

# Destroys the child processes.
sub _destroy {
    my $attrib_ref = shift();
    local($SIG{CHLD}) = 'IGNORE';
    my $select = IO::Select->new();
    my @worker_states = @{$attrib_ref->{worker_states}};
    for my $worker_state (@worker_states) {
        $select->add($worker_state->get_socket());
    }
    # TBD: reads $socket for any left over event etc?
    for my $socket ($select->can_write(0)) {
        my $worker_state = first {$_->get_socket() eq $socket} @worker_states;
        _item_send($socket);
        close($socket);
        waitpid($worker_state->get_pid(), 0);
    }
    while (waitpid(-1, WNOHANG) > 0) {
    }
    $attrib_ref->{util}->event(
        FCM::Context::Event->TASK_WORKERS, 'destroy', $attrib_ref->{n_workers},
    );
    1;
}

# On initialisation.
sub _init {
    my $attrib_ref = shift();
    for my $i (1 .. $attrib_ref->{n_workers}) {
        my ($from_boss, $from_worker)
            = IO::Socket->socketpair(AF_UNIX, SOCK_STREAM, PF_UNSPEC);
        if (!defined($from_boss) || !defined($from_worker)) {
            die("socketpair: $!");
        }
        $from_worker->autoflush(1);
        $from_boss->autoflush(1);
        if (my $pid = fork()) {
            # I am the boss
            if ($pid < 0) {
                die("fork: $!");
            }
            local($SIG{CHLD}, $SIG{INT}, $SIG{KILL}, $SIG{TERM}, $SIG{XCPU});
            for my $key (qw{CHLD INT KILL TERM XCPU}) {
                local($SIG{$key}) = sub {_destroy($attrib_ref, @_); die($!)};
            }
            close($from_worker);
            push(
                @{$attrib_ref->{worker_states}},
                $CTX_STATE->new($pid, $from_boss),
            );
        }
        elsif (defined($pid)) {
            # I am a worker
            close($from_boss);
            $attrib_ref->{worker_states} = [];
            open(STDIN, '/dev/null');
            # Ensures that events are sent back to the boss process
            my $util_of_event = bless(
                sub {_item_send($from_worker, @_)},
                __PACKAGE__ . '::WorkerEvent',
            );
            no strict 'refs';
            *{__PACKAGE__ . '::WorkerEvent::main'}
                = sub {my $self = shift(); $self->(@_)};
            use strict 'refs';
            $attrib_ref->{util}->util_of_event($util_of_event);
            _worker(
                $from_worker,
                $attrib_ref->{action},
                $attrib_ref->{util},
            );
            close($from_worker);
            exit();
        }
        else {
            die("fork: $!");
        }
    }
    $attrib_ref->{util}->event(
        FCM::Context::Event->TASK_WORKERS, 'init', $attrib_ref->{n_workers},
    );
}

# Main function of the class.
sub _main {
    my ($attrib_ref, $get_ref, $put_ref) = @_;
    my $n_done = 0;
    my $n_wait = 0;
    my $done_something = 1;
    my $get_task_ref = _get_task_func($get_ref, $attrib_ref->{n_workers});
    my $select = IO::Select->new();
    my @worker_states = @{$attrib_ref->{worker_states}};
    for my $worker_state (@worker_states) {
        $select->add($worker_state->get_socket());
    }
    while ($n_wait || $done_something) {
        $done_something = 0;
        # Handles tasks back from workers
        while (my @sockets = $select->can_read($TIME_OUT)) {
            for my $socket (@sockets) {
                my $worker_state
                    = first {$socket eq $_->get_socket()} @worker_states;
                my $item = _item_receive($socket);
                if (defined($item)) {
                    $done_something = 1;
                    if ($item->isa('FCM::Context::Event')) {
                        # Item is only an event, handles it
                        $attrib_ref->{util}->event($item);
                    }
                    else {
                        # Sends something back to the worker immediately
                        if (defined(my $task = $get_task_ref->())) {
                            _item_send($socket, $task);
                        }
                        else {
                            --$n_wait;
                            $worker_state->set_idle(1);
                        }
                        $put_ref->($item);
                        ++$n_done;
                    }
                }
            }
        }
        # Sends something to the idle workers
        my @idle_worker_states = grep {$_->get_idle()} @worker_states;
        if (@idle_worker_states) {
            for my $worker_state (@idle_worker_states) {
                if (defined(my $task = $get_task_ref->())) {
                    _item_send($worker_state->get_socket(), $task);
                    ++$n_wait;
                    $done_something = 1;
                    $worker_state->set_idle(0);
                }
            }
        }
        else {
            $get_task_ref->(); # only adds more tasks to queue
        }
    }
    $n_done;
}

# Returns a function to fetch more tasks into a queue.
sub _get_task_func {
    my ($get_ref, $n_workers) = @_;
    my $max_n_in_queue = $n_workers * 2;
    my @queue;
    sub {
        while (@queue < $max_n_in_queue && defined(my $task = $get_ref->())) {
            push(@queue, $task);
        }
        if (!defined(wantarray())) {
            return;
        }
        shift(@queue);
    };
}

# Receives an item from a socket.
sub _item_receive {
    my ($socket) = @_;
    my $len_of_data = unpack('N', _item_travel($socket, $LEN_OF_LONG));
    $len_of_data ? thaw(_item_travel($socket, $len_of_data)) : undef;
}

# Sends an item to a socket.
sub _item_send {
    my ($socket, $item) = @_;
    my $item_as_data = $item ? freeze($item) : q{};
    my $message = pack('N', length($item_as_data)) . $item_as_data;
    _item_travel($socket, length($message), $message);
}

# Helper for _item_receive/_item_send.
sub _item_travel {
    my ($socket, $len_to_travel, $data) = @_;
    my $action
        = defined($data) ? sub {syswrite($socket, $data, $_[0], $_[1])}
        :                  sub {sysread( $socket, $data, $_[0], $_[1])}
        ;
    $data ||= q{};
    my $n_bytes = 0;
    while ($n_bytes < $len_to_travel) {
        my $len_remain = $len_to_travel - $n_bytes;
        my $n = $action->($len_remain, $n_bytes);
        if (!defined($n)) {
            die($!);
        }
        $n_bytes += $n;
    }
    $data;
}

# Performs the function of a worker. Receives a task. Actions it. Sends it back.
sub _worker {
    my ($socket, $action, $util) = @_;
    while (defined(my $task = _item_receive($socket))) {
        my $timer = $util->timer();
        eval {
            $task->set_state($task->ST_WORKING);
            $action->($task->get_ctx());
            $task->set_state($task->ST_OK);
        };
        if ($@) {
            $task->set_state($task->ST_FAILED);
            $task->set_error($@);
        }
        $task->set_elapse($timer->());
        _item_send($socket, $task);
    }
    1;
}

# ------------------------------------------------------------------------------
# The state of a worker.
package FCM::Util::TaskRunner::WorkerState;
use base qw{FCM::Class::HASH};

__PACKAGE__->class(
    {   'idle'   => {isa => '$', default => 1}, # worker is idle?
        'pid'    => '$',                        # worker's PID
        'socket' => '*',                        # socket to worker
    },
    {   init_attrib => sub {
            my ($pid, $socket) = @_;
            {'pid' => $pid, 'socket' => $socket};
        },
    },
);

# ------------------------------------------------------------------------------
1;
__END__

=head1 NAME

FCM::Util::TaskRunner

=head1 SYNOPSIS

    use FCM::Context::Task;
    use FCM::Util;
    my $util = FCM::Util->new(\%attrib);
    # ... time passes
    my $runner = $util->task_runner(\&do_task, 4); # run with 4 workers
    # ... time passes
    my $get_ref = sub {
        # ... an iterator to return an FCM::Context::Task object
        # one at a time, returns undef if there is no currently available task
    };
    my $put_ref = sub {
        my ($task) = @_;
        # ... callback at end of each task
    };
    my $n_done = $runner->main($get_ref, $put_ref);

=head1 DESCRIPTION

This module is part of L<FCM::Util|FCM::Util>. See the description of the
task_runner() method for details.

An instance of this class is a runner of tasks. It can be configured to work in
serial (default) or parallel. The class is a sub-class of
L<FCM::Class::CODE|FCM::Class::CODE>.

=head1 SEE ALSO

This module is inspired by the CPAN modules Parallel::Fork::BossWorker and
Parallel::Fork::BossWorkerAsync.

L<FCM::Context::Task|FCM::Context::Task>,
L<FCM::Util::TaskManager|FCM::Util::TaskManager>

=head1 COPYRIGHT

(C) Crown copyright Met Office. All rights reserved.

=cut
