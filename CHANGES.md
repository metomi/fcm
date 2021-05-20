# FCM Changes

Go to https://github.com/metomi/fcm/milestones?state=closed
for a full listing of issues for each release.

--------------------------------------------------------------------------------

## 2021.05.0 (2021-05-20)

FCM release 43.

### Noteworthy Changes

[260](https://github.com/metomi/fcm/pull/260)
Fix bug where fcm would ignore modules that begin with function/subroutine.

--------------------------------------------------------------------------------

## 2019.09.0 (2019-09-30)

FCM release 42.

### Noteworthy Changes

[#256](https://github.com/metomi/fcm/pull/256):
fcm make: build: correctly support Fortran submodule. A submodule depends on
its parent module at compile time, but a parent module depends on its
submodules at link time. This change also ensures that other modern syntax
used in module/submodule definitions are handled correctly.

--------------------------------------------------------------------------------

## 2019.05.0 (2019-05-03)

FCM release 41.

### Noteworthy Changes

[#253](https://github.com/metomi/fcm/pull/253):
fcm make: build: fix handling of Fortran program unit tail comment. Fortran
dependency analysis was not handling tail comment of a program unit correctly.
This change fixes the issue.

--------------------------------------------------------------------------------

## 2017.10.0 (2017-10-03)

FCM release 40.

### Noteworthy Changes

[#247](https://github.com/metomi/fcm/pull/247):
fcm make: build: partially revert [#245](https://github.com/metomi/fcm/pull/245)
so the link task will, as before, create a temporary dependent object library
before linking the main object to it. However, users can now specify the
`build.prop{link-without-ar}` setting in the configuration to prevent it from
creating the temporary dependent object library, and put the full list of
dependent object files in the linker command line instead.

--------------------------------------------------------------------------------

## 2017.09.0 (2017-09-27)

FCM release 39.

### Noteworthy Changes

[#246](https://github.com/metomi/fcm/pull/246):
fcm make: new `description` setting to allow users to specify any string to
describe the current make.

[#245](https://github.com/metomi/fcm/pull/245):
fcm make: build: a link task for creating an executable will no longer create
an archive library with the `ar` command before calling the linker. The linker
command will contain the full list of object files instead.

--------------------------------------------------------------------------------

## 2017.02.0 (2017-02-24)

FCM release 38.

### Noteworthy Changes

[#243](https://github.com/metomi/fcm/pull/243):
fcm switch: fix Perl warning. This happened on an unexpected usage. A user has
checked out an entire project tree, and then run `fcm switch trunk` on it.
Clearly it did not work, but the added Perl warning was not helpful either.

--------------------------------------------------------------------------------

## 2016.12.0 (2016-12-06)

FCM release 37.

### Noteworthy Changes

[#241](https://github.com/metomi/fcm/pull/241):
fcm branch-delete: fix Perl warning on branches in a Rosie repository.

[#240](https://github.com/metomi/fcm/pull/240):
fcm make: fix implementation of `build.prop{ignore-missing-dep-ns}`.

--------------------------------------------------------------------------------

## 2016.10.0 (2016-10-07)

FCM release 36.

### Noteworthy Changes

[#239](https://github.com/metomi/fcm/pull/239):
fcm conflicts: handle tree conflict:
*local file edit, incoming file replace upon merge*.

[#238](https://github.com/metomi/fcm/pull/238):
fcm make: use `TMPDIR` (if defined in the environment) for temporary files on
load/dump of `ctx.gz`, instead of `/tmp/`.

--------------------------------------------------------------------------------

## 2016.09.0 (2016-09-19)

FCM release 35. Minor bug fix, and minor update to admin utilities.

### Noteworthy Changes

[#235](https://github.com/metomi/fcm/pull/235):
fcm make: build: fix `sprintf` redundant argument warning on Perl 5.22+.

--------------------------------------------------------------------------------

## 2016.05.1 (2016-05-19)

FCM release 34. Minor update to admin utilities, nothing noteworthy for users.

--------------------------------------------------------------------------------

## 2016.05.0 (2016-05-05)

FCM release 33. Minor bug fix and update.

### Noteworthy Changes

[#229](https://github.com/metomi/fcm/pull/229):
fcm commit, branch-create, branch-delete, etc: the default graphical editor for
commit message is modified from `gedit` to `gvim -f`, as `gedit` is not
reliable for running in the foreground.

[#227](https://github.com/metomi/fcm/pull/227):
fcm make: on gunzip of the context file, pass a file handle rather than a path
to the `gunzip` function to work around problems when files are made read-only
via ACL.

--------------------------------------------------------------------------------

## 2016.02.0 (2016-02-11)

FCM release 32. Minor bug fix and update.

### Noteworthy Changes

[#222](https://github.com/metomi/fcm/pull/222):
Configuration file: fix variable substitution of value 0. A (environment)
variable value of `0` was previously lost on substitution. This fixes the
problem.

[#219](https://github.com/metomi/fcm/pull/219):
fcm make: extract: fix target status on conflict. On conflict, the target
status was recorded incorrectly as unchanged. This caused incremental extracts
to succeed in error. This change fixes the problem.

[#215](https://github.com/metomi/fcm/pull/215):
Improvements to version related functionality:
* fcm version: now displays FCM_HOME location.
* fcm make: new `require-version=MIN-VERSION [MAX-VERSION]` declaration.
  If this declaration is specified and the current version is below
  `MIN-VERSION` or if a `MAX-VERSION` is specified and the current version is
  above it, the command will fail immediately.

--------------------------------------------------------------------------------

## 2015.12.0 (2015-12-09)

FCM release 31. Minor update.

### Noteworthy Changes

[#214](https://github.com/metomi/fcm/pull/214):
fcm make: `build.prop` declarations: modifiers such as `dep.include`, `dep.o`,
`no-dep.include` and `no-dep.o` are now supported with namespaces that are
target names.

--------------------------------------------------------------------------------

## 2015.11.0 (2015-11-17)

FCM release 30. Minor update.

### Noteworthy Changes

[#208](https://github.com/metomi/fcm/pull/208):
fcm make: build: now recognises more patterns as indicators of the existence of
a main program in a C source file.

[#207](https://github.com/metomi/rose/pull/207):
fcm test-battery: now runs correctly in the absence of site/user configuration
on recent Ubuntu distros.

--------------------------------------------------------------------------------

## 2015.10.0 (2015-10-15)

FCM release 29. Minor update.

### Noteworthy Changes

[#205](https://github.com/metomi/fcm/pull/205):
fcm make: build: new setting `build.prop{checksum-method}=md5|sha1|...` allows
users to choose MD5 or one of SHA algorithms in Perls' `Digest::SHA` to
calculate the checksums of source and target files.

[#204](https://github.com/metomi/fcm/pull/204):
fcm branch-create: allow `--bob` as a synonym of `--branch-of-branch`.

--------------------------------------------------------------------------------

## 2015.09.0 (2015-09-28)

FCM release 28. Minor update to admin utilities, nothing noteworthy for users.

--------------------------------------------------------------------------------

## 2015.08.0 (2015-08-19)

FCM release 27. Minor update to admin utilities, nothing noteworthy for users.

--------------------------------------------------------------------------------

## 2015.07.0 (2015-07-09)

FCM release 26.

### Noteworthy Changes

[#197](https://github.com/metomi/fcm/pull/197):
fcm make: build: fix target select modifier.
* The `category` modifier should now work.
* The `ns` modifier never worked, and is removed.
  Instead `task` and `category` selection can now be filtered by name-space.

[#196](https://github.com/metomi/fcm/pull/196):
pre/post commit: improve changeset size diagnostic
* pre-commit: log (but don't email) >1MB transactions
* post-commit: report pre-commit size threshold (normally 10MB) for any >1MB
  changesets

[#192](https://github.com/metomi/fcm/pull/192):
Primary location keyword: trailing slashes in values of primary location
keywords will now removed automatically.

[#191](https://github.com/metomi/fcm/pull/191):
fcm (branch-)diff --graphical: will now use the option
`--config-option config:working-copy:exclusive-locking-clients=` to prevent the
client from being locked.

--------------------------------------------------------------------------------

## 2015.05.0 (2015-05-28)

FCM release 25.

### Highlighted Changes

[#188](https://github.com/metomi/fcm/pull/188):
fcm make: allow multiple runs in same directory. A make can now be named, so
multiple non-overlapping makes can work in the same directory. It is worth
noting that once you have used this version of `fcm make` on a directory, older
version of FCM will no longer work in incremental mode on the same directory.
See also [metomi/rose#1604](https://github.com/metomi/rose/pull/1604).

### Noteworthy Changes

[#190](https://github.com/metomi/fcm/pull/190):
fcm make: new `--archive` option. If archive mode is specified, TAR-GZIP these
items by default:
* `.fcm-make/cache/extract/`
* `build/include/`
* `build/o/`

where `extract` and `build` are names of extract and build steps.
Users can configure what to TAR-GZIP under `build/`.

[#189](https://github.com/metomi/fcm/pull/189):
fcm make: correctly support relocation of a make.

--------------------------------------------------------------------------------

## 2015.03.0 (2015-03-26)

FCM release 24.

### Noteworthy Changes

[#183](https://github.com/metomi/fcm/pull/183):
Use of Subversion 1.6 with FCM is no longer recommended.

[#181](https://github.com/metomi/fcm/pull/181):
fcm make: source file find: ignore hidden paths only if paths are under
the source root directory, i.e. it is now OK for the source root directory to
be a hidden path itself.

[#178](https://github.com/metomi/fcm/pull/178):
fcm make: `.fcm-make/log` symbolic links are now relative. This should make it
easier to relocate a build.

--------------------------------------------------------------------------------

## 2015.02.0 (2015-02-10)

FCM release 23.

### Noteworthy Changes

[#176](https://github.com/metomi/fcm/pull/176):
fcm make: build: fix creation of Fortran interface files where procedure
arguments declared with `EXTERNAL` statements were incorrectly matched in
case-sensitive mode.

[#170](https://github.com/metomi/fcm/pull/170):
fcm commit: now works in a working copy with *externals*.

[#169](https://github.com/metomi/fcm/pull/169):
fcm branch-delete: now fails if bad arguments specified.

[#168](https://github.com/metomi/fcm/pull/168):
fcm branch-diff: `--trac` now works correctly. The `/intertrac/` syntax did not
appear to work any more. Use `/search?q=` syntax instead.

--------------------------------------------------------------------------------

## 2014.12.0 (2014-12-08)

FCM release 22.

### Noteworthy Changes

[#164](https://github.com/metomi/fcm/pull/164):
fcm build: fix fortran interface generation, broken by
[#156](https://github.com/metomi/fcm/pull/156).

[#163](https://github.com/metomi/fcm/pull/163):
fcm merge --reverse: improve logic. It now works with non-standard layout. The
`--revision=[M:]N` option is no longer compulsory. It now uses the last changed
revision of the working copy by default.

[#162](https://github.com/metomi/fcm/pull/162):
fcm-manage-trac-env-session: fix session logic. If a user already has some
entries in the `session_attribute` table, the old logic will not insert a new
`name` or `email` for the user. The new logic will only skip the `name` or
`email` attribute if already set correctly.

--------------------------------------------------------------------------------

## 2014.11.0 (2014-11-25)

FCM release 21.

### Noteworthy Changes

[#161](https://github.com/metomi/fcm/pull/161):
post-commit-bg-notify-who: use branch creator as branch owner if it cannot be
determined by the branch name.

[#159](https://github.com/metomi/fcm/pull/159),
[#160](https://github.com/metomi/fcm/pull/160):
FCM's Subversion wrappers: display error messages when `svn info` commands
fail.

[#158](https://github.com/metomi/fcm/pull/158):
fcm make: extract: improve checking of primary location in inherited mode.
Compare old value with normalised version of new value. E.g. use of location
keywords and extra slashes at the end of the path will no longer result in a
configuration conflict.

[#156](https://github.com/metomi/fcm/pull/156):
fcm extract and fcm build: fix warnings from Perl 5.12+ when parsing
configuration file.

[#155](https://github.com/metomi/fcm/pull/155):
fcm make: fix report of no such config file.

[#150](https://github.com/metomi/fcm/pull/150):
fcm-manage-trac-env-session: improve removal logic.

[#149](https://github.com/metomi/fcm/pull/149):
svnperms.py: fix bug, alter message override, and add tests.

[#148](https://github.com/metomi/fcm/pull/148):
Reverse `commit.conf` logic. To verify branch owner, specify
`verify-branch-owner`.  To notify branch owner, specify `notify-owner`.
`post-commit-bg` now supports owner notification on trunk commit.

[#147](https://github.com/metomi/fcm/pull/147):
Use `dd conv=fsync` to create backup and dump to ensure that backup and dump
data is written to disk before returning a good status.

[#146](https://github.com/metomi/fcm/pull/146):
fcm merge: basic support for `meld`.

--------------------------------------------------------------------------------

## 2014.09.0 (2014-09-17)

FCM release 20.

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

[#129](https://github.com/metomi/fcm/pull/129),
[#136](https://github.com/metomi/fcm/pull/136),
[#143](https://github.com/metomi/fcm/pull/143),
[#144](https://github.com/metomi/fcm/pull/144):
Major improvements to the admin sub-system:
* Improve hook installation.
  Write, store and housekeep hook logs at `$REPOS/log/`.
  Clean options for hook installation.
  Install `svnperms.conf` from repository root.
  `TZ=UTC` for all hook scripts.
* Improve diagnostics for hooks.
  Custom configuations per repositories.
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
* `pre-commit`: optionally block branch create with bad owner.
* `post-commit-bg`: rename repository dump.
* `post-commit-bg`: optionally notify branch owner if author is not owner.
* `post-*` hooks: configurable notification `From:` field.
* Test batteries for hooks, and selected admin utilities.

### Noteworthy Changes

[#140](https://github.com/metomi/fcm/pull/140):
fcm mkpatch: Changes required for use with svn 1.8 + other minor bug fixes.

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
