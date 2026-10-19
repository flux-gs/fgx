# Changelog

All notable changes to FGX, a port of 2.11BSD to the Apple IIgs.  Format:
[Keep a Changelog](https://keepachangelog.com); versions:
[SemVer](https://semver.org).  See docs/VERSIONING.md.

## [2.0.1] - 2026-10-19

### Changed

- gitignore: the disk_src staging rules name the directories as they are spelt
  The rules for staged binaries, man cat pages, modules and fixture staging
  named disk_src/SBIN, TESTBIN, USR/MAN/CAT[1-8] and the rest in upper case,
  the ProDOS-era spelling; the directories are lower case.  They matched only
  where git folds case, so a clone without core.ignorecase -- a case-sensitive
  checkout, or a fresh macOS clone -- showed 219 build outputs as untracked
  after one build.  That also moved the tree hash release.sh compares against
  the gate receipt.  The comment that said these rules covered case-sensitive
  layouts is gone with the problem.


## [2.0.0] - 2026-10-15

The first release from the GitHub repository, whose history starts here.
Earlier history is archived; references of the form `apple/fgx#N` in the tree
name issues in that earlier tracker.

### Changed

- **Breaking:** binaries and disk images from 1.x do not run unchanged.  The
  syscall ABI and the on-disk layout changed in this series; rebuild from
  source and boot `fgx-2.0.0.po`.
- The root filesystem is 2.11BSD's UFS, mounted through 4.3BSD-Reno's VFS,
  buffer cache and name cache, and checked by `fsck` at boot.
- Programs share their code, and the C library and libfgx are shared
  libraries loaded once at boot; libcurses, libtermlib and libutil load when
  a program first needs them.
- Up to 32 processes; job control and the full BSD signal set; TCP, UDP and
  Unix-domain sockets; syslogd, cron and inetd (telnet logins) start at boot.
- A Second Sight card adds a fourth virtual console (Option-4).
