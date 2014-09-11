# FCM Changes

Go to https://github.com/metomi/fcm/milestones?state=closed
for a full listing of issues for each release.

--------------------------------------------------------------------------------

## Next Release (2014-Q3?)

This will be the 20th release of FCM.

### Highlighted Changes

[#138](https://github.com/metomi/fcm/pull/138):
fcm make: build: continue on failure.
* The build system will continue as much as possible after a failure, and
  only repeat failed tasks in incremental modes.
* This change also fixes a problem where the system could lose information
  after a failure. Tasks that would be run after the failed task would not get
  their context recorded correctly. In a subsequent incremental build, the
  system would end up doing more work than necessary.

[#135](https://github.com/metomi/fcm/pull/135):
fcm make: multiple config files and search paths.
* You can now specify multiple `-F PATH` options to specify the search paths
  for locating configuration files specified as relative paths.
* You can now specify multiple `-f FILE` options.
* New `include-path` configuration declaration for specifying the search path
  for configuration files specified as relative paths.
* Improve CLI argument diagnostics.
  * The command dies if an argument is missing an equal sign.
  * Suggest command line syntax if argument ends with `.cfg`.

[#136](https://github.com/metomi/fcm/pull/136),
[#129](https://github.com/metomi/fcm/pull/129):
Major improvements to the admin sub-system:
* Improve hook installation.
  Write, store and housekeep hook logs at `$REPOS/log/`.
  Clean options for hook installation.
  Install `svnperms.conf` from repository root.
  `TZ=UTC` for all hook scripts.
* Improve diagnostics for hooks.
  Custom configuations per repositories.
  No longer support custom executables.
  Configurable `pre-revprop-change` permissions.
  Hooks to work best under Subversion 1.8+.
  Add modified `svnperms.py` in distribution.
  Trac 0.12+ changeset added and modified notification.
* Trac URL template.
* `fcm-add-trac-env`: add Trac comment edit permission.
* Separate `InterTrac` configurations from `trac.ini` into `intertrac.ini`.
* Fix usage of `FCM_CONF_PATH` for admin.
* Improve documentation and logic for admin configuration.
* Get user info via LDAP or traditional Unix password file.
* New admin commands:
  * `fcm-add-svn-repos-and-trac-env`
  * `fcm-add-svn-repos`
  * `fcm-manage-trac-env-session`
* `pre-commit`: block branch create with bad owner.
* `post-commit-bg`: rename repository dump.
* `post-commit-bg`: branch owner notification.
* `post-*` hooks: configurable notification `From:` field.
* Test batteries for hooks, and selected admin utilities.

### Noteworthy Changes

[#140](https://github.com/metomi/fcm/pull/140):
fcm mkpatch: improve handling of binary files. Re-enable use of patches with
binary files. Improve detection of binary files by using diff rather than
checking the `svn:mime-type` property (previous check was not safe since it did
not check the property for the old and new revisions).

[#139](https://github.com/metomi/fcm/pull/139):
fcm commit: fail a commit if it includes the `#commit_message#` file.

[#137](https://github.com/metomi/fcm/pull/137):
fcm merge: basic support for `kdiff3`.

[#129](https://github.com/metomi/fcm/pull/129):
`fcm commit`/`fcm branch-rm`: fix branch owner test to use correct user ID.

--------------------------------------------------------------------------------

## 2014.06.0 (2014-06-10)

### Highlighted Changes

-none-

### Noteworthy Changes

[#125](https://github.com/metomi/fcm/pull/125):
fcm make: build: handle adjacent cyclic dependency correctly.

[#128](https://github.com/metomi/fcm/pull/128):
Remove unnecessary `-r`, `-w` and `-x` tests to avoid ACL problems.
Use Perl's `filetest` pragma where necessary to correctly handle ACL.

--------------------------------------------------------------------------------

## 2014-04 (2014-04-23)

### Highlighted Changes

[#114](https://github.com/metomi/fcm/pull/#114),
[#117](https://github.com/metomi/fcm/pull/#117),
[#118](https://github.com/metomi/fcm/pull/#118):
fcm make: build: now recognises statements with Fortran
OpenMP sentinels that affect build dependencies.
These dependencies are normally ignored.
However, if a relevant `build.prop{fc.flag-omp}` property is specified, the
build system will treat these statements as normal dependency statements.

### Noteworthy Changes

[#121](https://github.com/metomi/fcm/pull/#121):
fcm make: extract via SSH: improve performance by using `find -printf`
instead of `find -exec stat`.

[#120](https://github.com/metomi/fcm/pull/#120):
fcm make: build will now correctly handle C source files that has camel
case names and `main` functions.

[#111](https://github.com/metomi/fcm/pull/#111):
fcm make: build in inherit mode: fix incorrect success in repeated
incremental mode.

[#105](https://github.com/metomi/fcm/pull/#105):
`FCM_CONF_PATH`: new environment variable that can be used to override
site/user configuration paths.

[#103](https://github.com/metomi/fcm/pull/#103):
fcm make: extract: detect diff trees that are the same as the base tree.

--------------------------------------------------------------------------------

## 2014-03 (2014-03-03)

### Highlighted Changes

[#96](https://github.com/metomi/fcm/pull/#96):
fcm make: arguments as extra configurations. This change allows the
`fcm make` command to accept command line arguments. Each argument will be
appended in order as a new line in the current `fcm-make.cfg`. This allows
users to override the configuration on the command line.

### Noteworthy Changes

[#101](https://github.com/metomi/fcm/pull/#101):
fcm make: do not inherit `steps` if it is already set in the current
configuration. This allows `steps=` to be declared before `use=`.

[#100](https://github.com/metomi/fcm/pull/#100):
fcm make: reduce memory usage in incremental mode. Invoking `fcm make`
with many steps was causing Perl to exit with SIGSEGV previously.

[#98](https://github.com/metomi/fcm/pull/#98):
fcm make: extract: fix ssh location efficiency.

[#93](https://github.com/metomi/fcm/pull/#93):
fcm make: fix `use=` properties override. This change allows `use=`
declarations to be placed anywhere in an `fcm-make.cfg` without interfering
other `*.prop` declarations.

[#92](https://github.com/metomi/fcm/pull/#92):
fcm branch-create/list: support alternate username using information in
users' `~/.subversion/servers` file.

[#91](https://github.com/metomi/fcm/pull/#91):
fcm make: remove config-on-success on failure.

--------------------------------------------------------------------------------

## 2014-02 (2014-02-03)

### Highlighted Changes

[#83](https://github.com/metomi/fcm/pull/#83):
fcm make: build: an initial attempt to support some Fortran 2K features.
* Recognise `iso_fortran_env` as an intrinsic module.
* Recognise `use, intrinsic ::` statements.
* Recognise `class`, `double complex` and `procedure` as types.
* Recognise new type declaration attributes.
* Recognise `abstract interface` blocks.
* Recognise `impure elemental` as a valid function or subroutine attribute.
* Recognise `submodule` blocks.

### Noteworthy Changes

[#89](https://github.com/metomi/fcm/pull/#89):
fcm merge, fcm switch, etc: Subversion 1.8 `svn upgrade` command may
not write a `.svn/entries` file at the working copy root. Several FCM wrappers
were failing because they were unable to determine the working copy root. This
is fixed by using the new entry available in Subversion 1.8 `svn info` to
determine the working copy root.

[#87](https://github.com/metomi/fcm/pull/#87):
fcm make: build: print sources to targets diagnostics on `-vv` mode and
in the log.

--------------------------------------------------------------------------------

## 2014-01 (2014-01-20)

### Highlighted Changes

-none-

### Noteworthy Changes

[#81](https://github.com/metomi/fcm/pull/#81):
fcm make: build: fix cyclic dependency logic.

[#80](https://github.com/metomi/fcm/pull/#80):
fcm make: extract: support `extract.location` declarations reset.

[#79](https://github.com/metomi/fcm/pull/#79):
fcm make: extract: SSH location: ignore dot files.

--------------------------------------------------------------------------------

## 2013-12 (2013-12-02)

### Highlighted Changes

-none-

### Noteworthy Changes

[#77](https://github.com/metomi/fcm/pull/#77):
fcm make: mirror and build: fix etc files install. This was broken by
[#65](https://github.com/metomi/fcm/pull/#65)
which causes etc files to be installed to `bin/`.

[#74](https://github.com/metomi/fcm/pull/#74):
Handle date in `svn log --xml`, which may have trailing spaces and lines.

--------------------------------------------------------------------------------

## 2013-11 (2013-11-22)

### Highlighted Changes

[#65](https://github.com/metomi/fcm/pull/#65):
fcm make: support declaration of class default properties using the
syntax e.g. `build.prop{class,fc}=my-fc`.

[#65](https://github.com/metomi/fcm/pull/#65):
fcm make: build: support target name as name-space for target properties,
e.g. `build.prop{fc}[myprog.exe]=my-fc`. N.B. Dependency properties are
regarded as source properties, and so are not supported by this change.

### Noteworthy Changes

[#73](https://github.com/metomi/fcm/pull/#73):
fcm mkpatch: use `/usr/bin/env bash` in generated scripts.

[#72](https://github.com/metomi/fcm/pull/#72):
fcm conflicts: fix incompatibility with SVN 1.8.

[#70](https://github.com/metomi/fcm/pull/#70):
fcm CLI: support new SVN 1.8 commands.

[#68](https://github.com/metomi/fcm/pull/#68):
sbin/fcm-backup-\*: hotcopy before verifying the hotcopy.

[#63](https://github.com/metomi/fcm/pull/#63):
fcm make: log file improvements. Print FCM version in beginning of log
file.

[#63](https://github.com/metomi/fcm/pull/#63):
fcm --version: new command to print FCM version.

[#63](https://github.com/metomi/fcm/pull/#63):
FCM is no longer dependent on the `HTTP::Date` Perl module.

--------------------------------------------------------------------------------

## 2013-10 (2013-10-30)

### Highlighted Changes

Changes that have significant impact on user experience.

[#52](https://github.com/metomi/fcm/pull/#52):
fcm make: build: new properties for C++ source files, separated from
C source files. File extension for C and C++ source files is rationalised to
follow what is documented in the GCC manual.

[#50](https://github.com/metomi/fcm/pull/#50),
[#54](https://github.com/metomi/fcm/pull/#54):
fcm make: build/preprocess.prop: include-paths/lib-paths/libs:
New build properties to specify a list of include paths for compile
tasks, and library paths and libraries for link tasks.

### Noteworthy Changes

Bug fixes and minor enhancements:

[#59](https://github.com/metomi/fcm/pull/#59):
fcm make: fix invalid cyclic dependency error when `build.prop{dep.o}` is
declared on the root name-space.

[#58](https://github.com/metomi/fcm/pull/#58):
fcm make: build: improve diagnostics for duplicated targets and bad values
in `build.prop{ns-dep.o}` declarations.

[#55](https://github.com/metomi/fcm/pull/#55):
fcm make: extract: can now extract from a location that is accessible via
`ssh` and `rsync`.

[#53](https://github.com/metomi/fcm/pull/#53):
fcm make: `.fcm-make/log` can now be accessed as `fcm-make.log`.

[#51](https://github.com/metomi/fcm/pull/#51):
FCM documentation: style updated using Bootstrap.

--------------------------------------------------------------------------------

## 2013-09 (2013-09-26)

### Highlighted Changes

Changes that have significant impact on user experience.

-None-

### Noteworthy Changes

Bug fixes and minor enhancements:

[#45](https://github.com/metomi/fcm/pull/#45):
An attempt to allow FCM to work under a case insensitive file system.

[#39](https://github.com/metomi/fcm/pull/#39),
[#40](https://github.com/metomi/fcm/pull/#40),
[#41](https://github.com/metomi/fcm/pull/#41):
CM commands are now tested under Subversion 1.8.

[#37](https://github.com/metomi/fcm/pull/#37):
fcm make: build: fixed hanging of `ext-iface` tasks when there is an
unbalanced quote or bracket in a relevant Fortran source file.

[#20](https://github.com/metomi/fcm/pull/#20):
fcm make: build: allow separate linker command and add ability to keep
the intermediate library archive while linking an executable.

[#19](https://github.com/metomi/fcm/pull/#19):
added test suite for code management commands to the distribution.

r4955: fcm extract: fix failure caused by the checking of latest version of a
deleted branch.

--------------------------------------------------------------------------------

## FCM-2-3-1 and Prior Releases

See <http://metomi.github.io/fcm/doc/release_notes/>.
