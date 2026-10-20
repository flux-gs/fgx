# Changelog

All notable changes to FGX, a port of 2.11BSD to the Apple IIgs.  Format:
[Keep a Changelog](https://keepachangelog.com); versions:
[SemVer](https://semver.org).  See docs/VERSIONING.md.

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
