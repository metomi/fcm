# FCM Changes

Go to https://github.com/metomi/fcm/issues/milestones?state=closed
for a full listing of issues for each release.

--------------------------------------------------------------------------------

## Next Release (2014-Q1?)

### Highlighted Changes

-none-

### Noteworthy Changes

\#80: fcm make: extract: support `extract.location` declarations reset.

\#79: fcm make: extract: SSH location: ignore dot files.

--------------------------------------------------------------------------------

## 2013-12 (2013-12-02)

### Highlighted Changes

-none-

### Noteworthy Changes

\#77: fcm make: mirror and build: fix etc files install. This was broken by #65
which causes etc files to be installed to `bin/`.

\#74: Handle date in `svn log --xml`, which may have trailing spaces and lines.

--------------------------------------------------------------------------------

## 2013-11 (2013-11-22)

### Highlighted Changes

\#65: fcm make: support declaration of class default properties using the
syntax e.g. `build.prop{class,fc}=my-fc`.

\#65: fcm make: build: support target name as name-space for target properties,
e.g. `build.prop{fc}[myprog.exe]=my-fc`. N.B. Dependency properties are
regarded as source properties, and so are not supported by this change.

### Noteworthy Changes

\#73: fcm mkpatch: use `/usr/bin/env bash` in generated scripts.

\#72: fcm conflicts: fix incompatibility with SVN 1.8.

\#70: fcm CLI: support new SVN 1.8 commands.

\#68: sbin/fcm-backup-\*: hotcopy before verifying the hotcopy.

\#63: fcm make: log file improvements. Print FCM version in beginning of log
file.

\#63: fcm --version: new command to print FCM version.

\#63: FCM is no longer dependent on the `HTTP::Date` Perl module.

--------------------------------------------------------------------------------

## 2013-10 (2013-10-30)

### Highlighted Changes

Changes that have significant impact on user experience.

\#52: fcm make: build: new properties for C++ source files, separated from
C source files. File extension for C and C++ source files is rationalised to
follow what is documented in the GCC manual.

\#50, \#54: fcm make: build/preprocess.prop: include-paths/lib-paths/libs:
New build properties to specify a list of include paths for compile
tasks, and library paths and libraries for link tasks.

### Noteworthy Changes

Bug fixes and minor enhancements:

\#59: fcm make: fix invalid cyclic dependency error when `build.prop{dep.o}` is
declared on the root name-space.

\#58: fcm make: build: improve diagnostics for duplicated targets and bad values
in `build.prop{ns-dep.o}` declarations.

\#55: fcm make: extract: can now extract from a location that is accessible via
`ssh` and `rsync`.

\#53: fcm make: `.fcm-make/log` can now be accessed as `fcm-make.log`.

\#51: FCM documentation: style updated using Bootstrap.

--------------------------------------------------------------------------------

## 2013-09 (2013-09-26)

### Highlighted Changes

Changes that have significant impact on user experience.

-None-

### Noteworthy Changes

Bug fixes and minor enhancements:

\#45: An attempt to allow FCM to work under a case insensitive file system.

\#39, #40, #41: CM commands are now tested under Subversion 1.8.

\#37: fcm make: build: fixed hanging of `ext-iface` tasks when there is an
unbalanced quote or bracket in a relevant Fortran source file.

\#20: fcm make: build: allow separate linker command and add ability to keep
the intermediate library archive while linking an executable.

\#19: added test suite for code management commands to the distribution.

r4955: fcm extract: fix failure caused by the checking of latest version of a
deleted branch.

--------------------------------------------------------------------------------

## FCM-2-3-1 and Prior Releases

See <http://metomi.github.io/fcm/doc/release_notes/>.
