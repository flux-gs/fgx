# Changelog

All notable changes to FGX, a port of 2.11BSD to the Apple IIgs.  Format:
[Keep a Changelog](https://keepachangelog.com); versions:
[SemVer](https://semver.org).  See docs/VERSIONING.md.

## [2.1.0] - 2026-10-20

### Build

- A zone written into .fgx_tz after the first build is used
  gen.py named .fgx_tz as a regen input only when the file existed when it
  ran, so a .fgx_tz created after the first build was never read: the
  image kept a UTC /etc/localtime until gen.py was re-run by hand.  gen.py
  now creates an empty .fgx_tz when there is none -- empty is UTC, as
  absent was -- and always names it as an input, so writing a zone into it
  regenerates build.ninja.

- /etc/version no longer reads dirty on a clean tree
  make_ufsboot.sh appends `+' to /etc/version when git sees untracked
  files, and it runs inside ninja, which holds .ninja_lock in the source
  root for the whole build.  .ninja_lock was not ignored, so every image
  was stamped dirty -- the published fgx-2.0.0.fs says `v2.0.0+'.  It is
  ignored now; a fresh clone's image reads v2.0.0-18-ge0760c4.


### Changed

- kernel: the IIgs clock is not written back unless asked
  machdep.disable_rtc_set is 1 by default.  FreeBSD 2.2.8 declares it
  `int disable_rtc_set;' (sys/i386/isa/clock.c:101), so 0, and resettodr()
  (clock.c:776) writes the battery clock from settimeofday(2) and from a
  write to machdep.adjkerntz.  On a IIgs that clock belongs to the machine
  and GS/OS reads it too: with an image in the wrong zone, a time set by
  ntpd or date(1) was written into it hours out, and adjkerntz -i wrote it
  at every boot.  Clearing the variable restores FreeBSD's write-back.
  
  At a daylight saving change, adjkerntz -a now moves the kernel's offset
  and leaves the IIgs clock as it was; adjkerntz(8), date(1) and
  settimeofday(2) state the divergence.

- boot: hardware modules, inetd and ntpd are turned on in /etc/rc.local
  /etc/rc loads what every machine needs -- ld, net (sockets and pipe(2)),
  ramdisk (it finds the Control Panel's RAM disk itself), pty, klog, fpsim
  -- and sources /etc/rc.local last, as 2.11BSD's rc ends with
  `/etc/rc.local' (usr/etc/rc).  rc.local ships with serial, bpf, sscon,
  cda, inetd and ntpd commented out, as 2.11BSD's usr/etc/rc.local ships
  `#timed'; removing the `#' turns one on at the next boot.  It is sourced
  rather than run, so it sees $INET from /etc/netstart without an export.
  inetd, which served telnet as root from /testbin on every image, now
  starts only from rc.local and only with a network.
  
  When /etc/localtime is UTC and /etc/wall_cmos_clock exists, rc says the
  zone is not set and that the IIgs clock is being read as UTC.
  
  modload.conf lists the same defaults, with the optional modules named in
  comments.  check_modload_lists.py reads rc.in followed by rc.local, as rc
  runs them, so an rc.local line turned on without its modload.conf entry
  fails the build.
  
  The suite tests the optional devices and daemons, so run.py stages
  tools/mame_test/rc.local, which turns all of them on, over /etc/rc.local
  before every test's own stage_files, and hashes it into the verdict key.
  modimage_check.py takes the modules that file loads into its roster, so
  the loaded-image comparison covers the same ten modules as before.

- ramdisk: the formatter's writes set the block latches Blk_Write would
  _RamDisk_WriteDirBuf enters _RamWrBody directly rather than through
  Blk_Write, and the body reads _blkCurHi and _blkCurBufBank, which
  Blk_Read and Blk_Write latch per call and leave set.  A UFS read before
  the module loaded had left the vfs_bio arena's bank latched, so the
  directory was copied from that bank instead of _fsDirBuf: the format
  reported success, set FormatFlag, and left block 2 all zeros, which
  mount_prodos then refused as "not a ProDOS volume".  The writes now
  clear _blkCurHi, _blkCurBufBank and _blkSrcPool first, as Blk_Write does
  for a 16-bit block in the kernel bank.

- ramdisk: battery RAM decides; the ROM's own MakeDisk on an 8 MB ROM 03
  ramdisk.mod allocated a 1 MB buffer of its own on every boot, whatever
  the Control Panel said: it read rdMinRam and then clamped to a 1 MB
  floor, so a machine with no RAM disk configured got one anyway.  It now
  follows GS/OS 6.0.1:
  
  - adopt the buffer at the bank-$E1 rendezvous (ram5.aii Startup:
    "see if there is a RAMdisk installed or not");
  - if there is none, have the ROM make it where ProBoot.src's CreateRAM5
    does -- ROM 3, no RAM5 handle, MaxDiskParm ($E102F7) non-zero and
    NumBanks ($E11624) >= $80, "a ROM 3 bug that fails to create RAM5 if
    you have 8 Megs of RAM" -- by its entry: A = $81, B = $E1, a 32-byte
    DP frame, JML $FC/14D1 with a pushed RTL and $00BC-1 for MakeDisk's
    RTS.  CreateRAM5 then resets the machine; this carries on and adopts;
  - mark an empty Pascal RAM5 unformatted (ram5.aii NukeIfEmptyPascal:
    block 2 word 0 = 0, +$006 = $5204, +$010 file count = 0);
  - otherwise log `ramdisk: none' and make nothing.
  
  The disk is formatted by RamDisk_Format, not by the ROM.  ram5.aii's
  FormatIfNeeded calls $FC/159D from inside GS/OS; called from FGX it
  writes an empty Pascal volume (measured: block 2 reads
  00 00 06 00 00 00 04 'RAM5', FormatFlag $FFFF).
  
  Measured on MAME's 8 MB ROM 03 with BRAM $36/$37 = 8: `ramdisk: 512
  blocks @ bank $38 (made)', 256 KB as asked.  With BRAM $36/$37 = 0:
  `ramdisk: none'.
  
  The disk registers at device row 8, the first row no /dev/sdN node
  names, so /dev/ram0 always names it.  Not the last row: a mount on rows
  29..31 crashes the machine (rows 1, 7, 8, 15, 16, 23, 24, 27 and 28
  mount; 29, 30 and 31 jump to $00:0000), which is a block-layer defect of
  its own.
  
  RamDisk_Create and the 1 MB floor are gone; ROMVersion joins the
  module's kernel exports and _kFgxUserID leaves them.

- boot: the RAM disk is mounted writable on /ram5 as /dev/ram0
  gen.py mints `b /dev/ram0 8', the row ramdisk.mod registers in, and the
  image carries the mount point /ram5.  /etc/rc runs
  `mount_prodos -o write /dev/ram0 /ram5' after the modules load, and says
  `ram5: /dev/ram0 mounted on /ram5' when it does; on a machine with no
  RAM disk the device row is empty, the mount fails, and nothing is said.
  mount_prodos loads prodos and prodosw itself.  CONFIGURING.md describes
  the RAM disk; modules.md gives the module's behaviour.

- ramdisk: the rows-29..31 note names its issue, flux-gs/fgx#4
- mount: the listing names each filesystem's type
  mount(8) with no arguments now prints the type first inside the
  parentheses, as the 4.4BSD-Lite2 descendants (FreeBSD, macOS) do:
  
      /dev/sd0 on / (ufs)
      /dev/sd1 on /mnt (prodos, read-only)
  
  2.11BSD's prmount (vendor/2.11BSD/usr/sbin/mount/mount.c) prints only
  the flags, which left a ProDOS mount looking like a UFS one; Reno's and
  netbsd-0-9's do the same.  The name is f_type from getmntinfo(3) through
  upstream's own INITMOUNTNAMES table, which badvfstype already used.
  mount -v prints the same line.
  
  ufsmount's needles now carry `(ufs', and pdmount lists its read-only
  ProDOS mount.

- rc: comments at 2.11BSD's density
  /etc/rc keeps every command and drops the essays, so it reads like
  2.11BSD's usr/etc/rc: a header, upstream's own fsck warning, and a
  one-line note where a step is not self-explanatory.  229 lines to 93.
  
  What the removed comments said, for the record:
  - ld.mod and ldload run first because every program but the static set
    (init, getty, login, sh, fsck, mount, ifconfig, modload, ldload,
    test, echo, hostname, mv, tar, ln) is dynamic.  ldload exiting 1 (a
    listed library failed) lets the boot go on; any other status stops rc
    before fsck, and init starts the static console shell regardless.
  - fsck runs without upstream's -t /_FSCK_TMP_FILE: that names a scratch
    file on the root, which setup() refuses, and the maps for a
    32000-block root fit in memory.
  - The root is mounted read-only by the kernel (ufs_mountroot), so the
    remount follows the check.  utmp is emptied here, as 4.3BSD-Reno's rc
    does, because 2.11BSD's init cannot do it on a read-only root.
  - rc runs with "/" as its descriptors (2.11BSD init.c runcom), so each
    visible line names /dev/console.
  - rc waits up to 15 s for /var/run/syslog.pid so syslogd's replay of the
    boot log is not delivered to the console shell a second time.

- etc: rc.local, modload.conf and netstart at 2.11BSD's density
  The same trim as /etc/rc: every command and every commented-out
  command stays, the explanations go to a line or none.
  
  What the removed comments said, for the record:
  - modload.conf is read by /etc/rc, not the kernel: Mod_LoadConf reads
    through Fs_ReadN, which answers EBADF for a root descriptor.
    tools/check_modload_lists.py holds rc's two modload lines and
    rc.local's enabled ones equal to it.  ufsprobe is last because it
    runs its cases from mod_init and some need pty.mod; the image carries
    it only in a probe build.
  - klog is /dev/klog, the kernel log ring syslogd reads; fpsim is fcc's
    soft double as one shared copy, without which a double operation
    raises SIGILL.
  - rc.local is sourced, so it sees $INET from netstart; FGX never writes
    the IIgs clock back (machdep.disable_rtc_set is 1).
  - netstart's INET mirrors 2.11BSD's; dhclient exits nonzero without a
    lease, and renewing means running dhclient again.

- ci: every push to main publishes its image on a rolling pre-release
  The build now also runs on pushes to main, and a third job publishes the
  image as fgx-main-<sha>.fs on the `main-latest' pre-release.  It moves
  that tag to the commit, and deletes all but the newest three images
  (MAIN_KEEP).  Release assets are stored outside git, so this does not
  grow the repository.  The vX.Y.Z releases are unchanged, and a
  pre-release is never GitHub's Latest, so the newest version stays the
  default download.
  
  Checkout fetches full history, so /etc/version in a main image is
  `git describe' against the v* tags (v2.0.0-5-g712de08) rather than a
  bare hash.
  
  The README links the pre-release; RELEASING.md and BUILDING.md describe it.


### Documentation

- Configuring a machine -- the clock and time zone, devices, services
  docs/CONFIGURING.md covers what a running machine starts and how to
  change it: choosing a time zone (/etc/localtime from
  /usr/share/zoneinfo), why the IIgs clock is read as UTC until then, the
  battery-clock policy and daylight saving, turning on ntpd; the serial,
  bpf, sscon and cda modules and how to load them from /etc/rc.local; and
  inetd.  The README points first-boot users at it, and BUILDING describes
  .fgx_tz and FGX_TZ for building an image with a zone already set.

- Support terms, the community channel, and a bug report form
  The README says no support is offered or implied, that questions get an
  answer where possible and contributions are welcome, and points to #fgx
  on the Apple II Infinitum Slack for discussion and to GitHub Issues for
  bugs.  A new "Reporting bugs" section lists what a report needs.
  
  .github/ISSUE_TEMPLATE/bug_report.yml is a GitHub issue form asking for
  the FGX version (image file and uname -r), where it happens, the full
  hardware description or emulator settings, a detailed explanation, the
  steps to reproduce it in Ample or MAME, and screenshots.  config.yml
  keeps blank issues and links questions to the Slack.
  
  CONTRIBUTING.md points to the form and the channel, and no longer says
  CI builds only releases: it builds release tags and main.

- The README's acknowledgements
  FGX's own code was written from scratch, almost entirely with Claude
  Code, with feedback from ChatGPT.  The section thanks those who published
  Apple IIgs source as reference material, above all the GNO Consortium;
  the developers and maintainers of 2.11BSD; the BSD heritage of
  4.3BSD-Reno and NetBSD; SunOS 4.1.3, whose shared library model FGX
  adopted; and the [cCc] crew and extended family.

- The issue templates name the Slack channel without linking its signup page
  The bug form's note says to ask questions in #fgx on the Apple II Infinitum Slack as plain text, and config.yml drops its contact link, which GitHub cannot show without a URL.

- The README and CONTRIBUTING name the Slack channel without linking its signup page

### Tests

- Per-test battery RAM, and a test for the Control Panel RAM disk
  A manifest's "bram" key sets battery-RAM parameters ({"36": 8, ...},
  the Toolbox Reference's numbers) in the test's copy of the BRAM and
  rewrites the checksum the ROM checks: the 16-bit sum of bytes 0..251,
  then the sum ^ $AAAA, as gsport's clk_calculate_bram_checksum computes
  it.  The self-test reproduces the checksum stored in a real BRAM, and
  fails when the loop steps by two.
  
  ramdisk asks for a 256 KB RAM disk and checks that it is made, mounted
  on /ram5 as /dev/ram0, and written: the staged rc.local writes /ram5/b1
  during the boot.  It does not cover keeping the disk across a soft
  reboot; a warm_reset_frame run made the disk again and stalled at the
  system logger, and that is unmeasured here.


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
