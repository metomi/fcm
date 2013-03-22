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
# NAME
#   Fcm::Util
#
# DESCRIPTION
#   This is a package of misc utilities used by the FCM command.
#
# ------------------------------------------------------------------------------

use warnings;
use strict;

package Fcm::Util;
require Exporter;
our @ISA = qw{Exporter};

sub expand_tilde;
sub e_report;
sub find_file_in_path;
sub get_command_string;
sub get_rev_of_wc;
sub get_url_of_wc;
sub get_url_peg_of_wc;
sub get_wct;
sub is_url;
sub is_wc;
sub print_command;
sub run_command;
sub svn_date;
sub tidy_url;
sub touch_file;
sub w_report;

our @EXPORT = qw{
    expand_tilde
    e_report
    find_file_in_path
    get_command_string
    get_rev_of_wc
    get_url_of_wc
    get_url_peg_of_wc
    get_wct
    is_url
    is_wc
    print_command
    run_command
    svn_date
    tidy_url
    touch_file
    w_report
};

# Standard modules
use Carp;
use Cwd;
use File::Basename;
use File::Find;
use File::Path;
use File::Spec;
use POSIX qw{strftime SIGINT SIGKILL SIGTERM WEXITSTATUS WIFSIGNALED WTERMSIG};

# FCM component modules
use Fcm::Timer;

# ------------------------------------------------------------------------------

# Module level variables
my %svn_info       = (); # "svn info" log, (key1 = path,
                         # key2 = URL, Revision, Last Changed Rev)

# ------------------------------------------------------------------------------
# SYNOPSIS
#   %srcdir = &Fcm::Util::find_file_in_path ($file, \@path);
#
# DESCRIPTION
#   Search $file in @path. Returns the full path of the $file if it is found
#   in @path. Returns "undef" if $file is not found in @path.
# ------------------------------------------------------------------------------

sub find_file_in_path {
  my ($file, $path) = @_;

  for my $dir (@$path) {
    my $full_file = File::Spec->catfile ($dir, $file);
    return $full_file if -e $full_file;
  }

  return undef;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $expanded_path = &Fcm::Util::expand_tilde ($path);
#
# DESCRIPTION
#   Returns an expanded path if $path is a path that begins with a tilde (~).
# ------------------------------------------------------------------------------

sub expand_tilde {
  my $file = $_[0];

  $file =~ s#^~([^/]*)#$1 ? (getpwnam $1)[7] : ($ENV{HOME} || $ENV{LOGDIR})#ex;

  # Expand . and ..
  while ($file =~ s#/+\.(?:/+|$)#/#g) {next}
  while ($file =~ s#/+[^/]+/+\.\.(?:/+|$)#/#g) {next}

  # Remove trailing /
  $file =~ s#/*$##;

  return $file;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $rc = &Fcm::Util::touch_file ($file);
#
# DESCRIPTION
#   Touch $file if it exists. Create $file if it does not exist. Return 1 for
#   success or 0 otherwise.
# ------------------------------------------------------------------------------

sub touch_file {
  my $file = $_[0];
  my $rc   = 1;

  if (-e $file) {
    my $now = time;
    $rc = utime $now, $now, $file;

  } else {
    mkpath dirname ($file) unless -d dirname ($file);

    $rc = open FILE, '>', $file;
    $rc = close FILE if $rc;
  }

  return $rc;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $flag = &is_wc ([$path]);
#
# DESCRIPTION
#   Returns true if current working directory (or $path) is a Subversion
#   working copy.
# ------------------------------------------------------------------------------

sub is_wc {
  my $path = shift() || cwd();
  my $path_of_dir = -f $path ? dirname($path) : $path;
  -e File::Spec->catfile($path_of_dir, qw{.svn entries});
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $flag = &is_url ($url);
#
# DESCRIPTION
#   Returns true if $url is a URL.
# ------------------------------------------------------------------------------

sub is_url {
  # This should handle URL beginning with svn://, http:// and svn+ssh://
  return ($_[0] =~ m#^[\+\w]+://#);
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $url = tidy_url($url);
#
# DESCRIPTION
#   Returns a tidied version of $url by removing . and .. in the path.
# ------------------------------------------------------------------------------

sub tidy_url {
    my ($url) = @_;
    if (!is_url($url)) {
        return $url;
    }
    my $DOT_PATTERN     = qr{/+ \. (?:/+|(@|\z))}xms;
    my $DOT_DOT_PATTERN = qr{/+ [^/]+ /+ \.\. (?:/+|(@|\z))}xms;
    my $TRAILING_SLASH_PATTERN = qr{([^/]+) /* (@|\z)}xms;
    my $RIGHT_EVAL = q{'/' . ($1 ? $1 : '')};
    DOT:
    while ($url =~ s{$DOT_PATTERN}{$RIGHT_EVAL}eegxms) {
        next DOT;
    }
    DOT_DOT:
    while ($url =~ s{$DOT_DOT_PATTERN}{$RIGHT_EVAL}eegxms) {
        next DOT_DOT;
    }
    $url =~ s{$TRAILING_SLASH_PATTERN}{$1$2}xms;
    return $url;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = &get_wct ([$dir]);
#
# DESCRIPTION
#   If current working directory (or $dir) is a Subversion working copy,
#   returns the top directory of this working copy; otherwise returns an empty
#   string.
# ------------------------------------------------------------------------------

sub get_wct {
  my $dir = @_ ? $_[0] : cwd ();

  return '' if not &is_wc ($dir);

  my $updir = dirname $dir;
  while (&is_wc ($updir)) {
    $dir   = $updir;
    $updir = dirname $dir;
    last if $updir eq $dir;
  }

  return $dir;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = &get_url_of_wc ([$path[, $refresh]]);
#
# DESCRIPTION
#   If current working directory (or $path) is a Subversion working copy,
#   returns the URL of the associated Subversion repository; otherwise returns
#   an empty string. If $refresh is specified, do not use the cached
#   information.
# ------------------------------------------------------------------------------

sub get_url_of_wc {
  my $path    = @_ ? $_[0] : cwd ();
  my $refresh = exists $_[1] ? $_[1] : 0;
  my $url  = '';

  if (&is_wc ($path)) {
    delete $svn_info{$path} if $refresh;
    &_invoke_svn_info (PATH => $path) unless exists $svn_info{$path};
    $url = $svn_info{$path}{URL};
  }

  return $url;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = &get_url_peg_of_wc ([$path[, $refresh]]);
#
# DESCRIPTION
#   If current working directory (or $path) is a Subversion working copy,
#   returns the URL@REV of the associated Subversion repository; otherwise
#   returns an empty string. If $refresh is specified, do not use the cached
#   information.
# ------------------------------------------------------------------------------

sub get_url_peg_of_wc {
  my $path    = @_ ? $_[0] : cwd ();
  my $refresh = exists $_[1] ? $_[1] : 0;
  my $url  = '';

  if (&is_wc ($path)) {
    delete $svn_info{$path} if $refresh;
    &_invoke_svn_info (PATH => $path) unless exists $svn_info{$path};
    $url = $svn_info{$path}{URL} . '@' . $svn_info{$path}{Revision};
  }

  return $url;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   &_invoke_svn_info (PATH => $path);
#
# DESCRIPTION
#   The function is internal to this module. It invokes "svn info" on $path to
#   gather information on URL, Revision and Last Changed Rev. The information
#   is stored in a hash table at the module level, so that the information can
#   be re-used.
# ------------------------------------------------------------------------------

sub _invoke_svn_info {
  my %args = @_;
  my $path = $args{PATH};
  my $cfg  = Fcm::Config->instance();

  return if exists $svn_info{$path};

  # Invoke "svn info" command
  my @info = &run_command (
    [qw/svn info/, $path],
    PRINT => $cfg->verbose > 2, METHOD => 'qx', DEVNULL => 1, ERROR => 'ignore',
  );
  for (@info) {
    chomp;

    if (/^(URL|Revision|Last Changed Rev):\s*(.+)$/) {
      $svn_info{$path}{$1} = $2;
    }
  }

  return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $string = &get_command_string ($cmd);
#   $string = &get_command_string (\@cmd);
#
# DESCRIPTION
#   The function returns a string by converting the list in @cmd or the scalar
#   $cmd to a form, where it can be executed as a shell command.
# ------------------------------------------------------------------------------

sub get_command_string {
  my $cmd    = $_[0];
  my $return = '';

  if (ref ($cmd) and ref ($cmd) eq 'ARRAY') {
    # $cmd is a reference to an array

    # Print each argument
    for my $i (0 .. @{ $cmd } - 1) {
      my $arg = $cmd->[$i];

      $arg =~ s/./*/g if $i > 0 and $cmd->[$i - 1] eq '--password';

      if ($arg =~ /[\s'"*?]/) {
        # Argument contains a space, quote it
        if (index ($arg, "'") >= 0) {
          # Argument contains an apostrophe, quote it with double quotes
          $return .= ($i > 0 ? ' ' : '') . '"' . $arg . '"';

        } else {
          # Otherwise, quote argument with apostrophes
          $return .= ($i > 0 ? ' ' : '') . "'" . $arg . "'";
        }

      } else {
        # Argument does not contain a space, just print it
        $return .= ($i > 0 ? ' ' : '') . ($arg eq '' ? "''" : $arg);
      }
    }

  } else {
    # $cmd is a scalar, just print it "as is"
    $return = $cmd;
  }

  return $return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   &print_command ($cmd);
#   &print_command (\@cmd);
#
# DESCRIPTION
#   The function prints the list in @cmd or the scalar $cmd, as it would be
#   executed by the shell.
# ------------------------------------------------------------------------------

sub print_command {
  my $cmd = $_[0];

  print '=> ', &get_command_string ($cmd) , "\n";
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   @return = &run_command (\@cmd, <OPTIONS>);
#   @return = &run_command ($cmd , <OPTIONS>);
#
# DESCRIPTION
#   This function executes the command in the list @cmd or in the scalar $cmd.
#   The remaining are optional arguments in a hash table. Valid options are
#   listed below. If the command is run using "qx", the function returns the
#   standard output from the command. If the command is run using "system", the
#   function returns true on success. By default, the function dies on failure.
#
# OPTIONS
#   METHOD  => $method - this can be "system", "exec" or "qx". This determines
#                        how the command will be executed. If not set, the
#                        default is to run the command with "system".
#   PRINT   => 1       - if set, print the command before executing it.
#   ERROR   => $flag   - this should only be set if METHOD is set to "system"
#                        or "qx". The $flag can be "die" (default), "warn" or
#                        "ignore". If set to "die", the function dies on error.
#                        If set to "warn", the function issues a warning on
#                        error, and the function returns false. If set to
#                        "ignore", the function returns false on error.
#   RC      => 1       - if set, must be a reference to a scalar, which will be
#                        set to the return code of the command.
#   DEVNULL => 1       - if set, re-direct STDERR to /dev/null before running
#                        the command.
#   TIME    => 1       - if set, print the command with a timestamp before
#                        executing it, and print the time taken when it
#                        completes. This option supersedes the PRINT option.
# ------------------------------------------------------------------------------

sub run_command {
  my ($cmd, %input_opt_of) = @_;
  my %opt_of = (
    DEVNULL => undef,
    ERROR   => 'die',
    METHOD  => 'system',
    PRINT   => undef,
    RC      => undef,
    TIME    => undef,
    %input_opt_of,
  );
  local($|) = 1; # Make sure STDOUT is flushed before running command

  # Print the command before execution, if necessary
  if ($opt_of{TIME}) {
    print(timestamp_command(get_command_string($cmd)));
  }
  elsif ($opt_of{PRINT}) {
    print_command($cmd);
  }

  # Re-direct STDERR to /dev/null if necessary
  if ($opt_of{DEVNULL}) {
    no warnings;
    open(OLDERR, ">&STDERR") || croak("Cannot dup STDERR ($!), abort");
    use warnings;
    open(STDERR, '>', File::Spec->devnull())
      || croak("Cannot redirect STDERR ($!), abort");
    # Make sure the channels are unbuffered
    my $select = select();
    select(STDERR); local($|) = 1;
    select($select);
  }

  my @return = ();
  if (ref($cmd) && ref($cmd) eq 'ARRAY') {
    # $cmd is an array
    my @command = @{$cmd};
    if ($opt_of{METHOD} eq 'qx') {
      @return = qx(@command);
    }
    elsif ($opt_of{METHOD} eq 'exec') {
      exec(@command);
    }
    else {
      system(@command);
      @return = $? ? () : (1);
    }
  }
  else {
    # $cmd is an scalar
    if ($opt_of{METHOD} eq 'qx') {
      @return = qx($cmd);
    }
    elsif ($opt_of{METHOD} eq 'exec') {
      exec($cmd);
    }
    else {
      system($cmd);
      @return = $? ? () : (1);
    }
  }
  my $rc = $?;

  # Put STDERR back to normal, if redirected previously
  if ($opt_of{DEVNULL}) {
    close(STDERR);
    open(STDERR, ">&OLDERR") || croak("Cannot dup STDERR ($!), abort");
  }

  # Print the time taken for command after execution, if necessary
  if ($opt_of{TIME}) {
    print(timestamp_command(get_command_string($cmd), 'end'));
  }

  # Signal and return code
  my ($signal, $status) = (WTERMSIG($rc), WEXITSTATUS($rc));
  if (exists($opt_of{RC})) {
    ${$opt_of{RC}} = $status;
  }
  if (WIFSIGNALED($rc) && grep {$signal == $_} (SIGINT, SIGKILL, SIGTERM)) {
    croak(sprintf('%s terminated (%d)', get_command_string($cmd), $signal));
  }
  if ($status && $opt_of{ERROR} ne 'ignore') {
    my $func_ref = $opt_of{ERROR} eq 'warn' ? \&carp : \&croak;
    $func_ref->(sprintf('%s failed (%d)', get_command_string($cmd), $status));
  }
  return @return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   &e_report (@message);
#
# DESCRIPTION
#   The function prints @message to STDERR and aborts with a error.
# ------------------------------------------------------------------------------

sub e_report {
  print STDERR @_, "\n" if @_;

  exit 1;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   &w_report (@message);
#
# DESCRIPTION
#   The function prints @message to STDERR and returns.
# ------------------------------------------------------------------------------

sub w_report {
  print STDERR @_, "\n" if @_;

  return;
}

# ------------------------------------------------------------------------------
# SYNOPSIS
#   $date = &svn_date ($time);
#
# DESCRIPTION
#   The function returns a date, formatted as by Subversion. The argument $time
#   is the number of seconds since epoch.
# ------------------------------------------------------------------------------

sub svn_date {
  my $time = shift;

  return strftime ('%Y-%m-%d %H:%M:%S %z (%a, %d %b %Y)', localtime ($time));
}

# ------------------------------------------------------------------------------

1;

__END__
