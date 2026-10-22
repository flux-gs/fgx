# Changelog

All notable changes to FGX, a port of 2.11BSD to the Apple IIgs.  Format:
[Keep a Changelog](https://keepachangelog.com); versions:
[SemVer](https://semver.org).  See docs/VERSIONING.md.

## [2.2.0] - 2026-10-22

### Build

- The provenance check has its own stamp, over the files it reads
  check_provenance ran inside the kernel checks, whose stamp's inputs are
  the kernel listings.  A change to a userland source alone never re-ran
  it, so a new port went unregistered through a green build until the
  kernel next changed.
  
  The check now names its own inputs (--inputs: the registry, every file a
  row names, every tracked .c under the ported directories, the cited
  sources and the vendored files rows claim), and build/.provenance_checked
  is built from that list as part of `all`.  docs/PROVENANCE.md is an input
  to build.ninja, so a new row regenerates the list.


### Changed

- kernel: block devices take 2.11BSD's major and minor, through a bdevsw
  A block dev_t is now a major and a minor (2.11BSD usr/sys/h/types.h:17-23,
  in src/kernel/vfs/fsparam.h), and bio_strategy dispatches on the major
  through bdevsw[], the call 2.11BSD's bread makes (usr/sys/sys/ufs_bio.c:38).
  The SmartPort disks are major 0, so /dev/sd0-sd7 keep their numbers; the
  RAM disk is major 1, and /dev/ram0 is minted as 256.  The minor is the
  driver's unit.
  
  Every block driver reaches the disk through kc_blkio, so a bdevsw entry
  carries the driver's slice of the kernel device table -- its first row and
  unit count, include/fs.s's BDEV_* -- where upstream's carries d_strategy and
  the rest; vfs.mod's bank has 65 bytes left and no room for a strategy
  routine per driver.  A major past the table is ENXIO in bio_strategy, in
  spec_open and in getmdev, which carries Reno's check again (2.11BSD
  ufs_mount.c:346); a unit past the driver's count is ENXIO in bio_strategy.
  
  Dev_Init attaches at most BDEV_NSD (8) SmartPort disks, one per /dev/sd
  node, and the RAM disk takes row BDEV_RAM_ROW (8) outright.  It had scanned
  upward from row 8 for a free row while /dev/ram0 named row 8 alone, so a
  machine with more than eight SmartPort units put it where its node did not
  reach.
  
  ufs_devname names a mounted device by its major, so df and mount print
  /dev/ram0 for a UFS RAM disk rather than /dev/sd8.

- kernel: the boot log names each disk and bus as BSD's attach lines do
  The SmartPort scan's lines follow NetBSD's autoconfiguration shape
  (sys/scsi/cd.c: "cd%d at %s%d targ %d lun %d: %s"): the device first, then
  where it was found, then what it is.  A SmartPort bus is spN, after the
  order Dev_Init registers them; boot bus first.
  
      sp0 at slot 7
      sd0 at sp0 unit 1: 63999 blocks (31999KB)
      sp1 at slot 5
      sd1 at sp0 unit 2: 40960 blocks (20480KB)
  
  They replace "blk: dev 01: s7,d2 (attaching sd1) ..." and "bus 1: slot 5
  entry=$C50D", which led with the kernel's device-table index and named the
  unit by slot and drive.

- kernel: a SmartPort CD-ROM attaches as /dev/cd0, read-only
  The SmartPort scan reads each unit's device information block (status code
  $03, Apple IIGS Firmware Reference p.123) and attaches one whose device type
  is $05, "SCSI CD-ROM" (SmartPort Technical Note #4), as a cd unit rather
  than an sd one, as BSD attaches by the device's own type.  A unit that does
  not implement code $03 is asked code $00 and attaches as a disk, as before.
  
  cd is block major 2, its units rows 9-12 of the device table (BDEV_CD_ROW0,
  BDEV_NCD), and /dev/cd0-cd3 are minted 400.  Its bdevsw entry is read-only:
  a write is EROFS, NetBSD 0.9's cdstrategy answer (sys/scsi/cd.c).  A drive
  with no disc -- the general status byte's "disk in drive" bit clear -- is
  attached offline and logged
  
      cd0 at sp0 unit 2: empty
  
  rather than with the block count the card reports for it, 17352 on MAME's
  Apple SCSI CD-ROM.  With a disc it is logged with its size.  The Apple II
  SCSI Card presents the disc's ProDOS partition as 512-byte blocks, so a
  ProDOS CD mounts with mount_prodos -o ro /dev/cd0; ISO 9660 does not mount
  yet.
  
  mame-hd.sh -cdrom FILE loads a disc into MAME's drive on the SCSI card.

- kernel: a CD-ROM with 2048-byte sectors reads as 512-byte blocks
  The Apple II SCSI Card presents a disc with no ProDOS partition whole, in
  the drive's 2048-byte sectors, and its ReadBlock then returns the first 512
  bytes of SECTOR b rather than block b -- the card reads the whole sector
  and discards the rest (its ROM, bank 1 $CEBB).  SmartPort Technical Note #5:
  "For devices with a block size other than 512 bytes, use the SmartPort Read
  and Write calls."
  
  At attach a CD-ROM unit is asked the card's STATUS $06, the unit's block
  size (big-endian; ROM STATUS table at offset $11E1).  A 2048-byte unit is
  marked DEV_FLAG_SEC2K and its size given in 512-byte blocks, and Blk_Read
  serves it through the block cache's read-ahead with a run of one sector:
  one extended Read of 2048 bytes, addressed by sector (block >> 2, which the
  card puts into the SCSI READ unconverted), fills the four cache slots of
  blocks 4s..4s+3.  Every layer above still sees 512-byte blocks, as SunOS
  4.1.3's sr.c divides its block number by 4 (sys/sundev/sr.c:974).  A read
  the read-ahead cannot do fails with EIO rather than fall back to ReadBlock.
  
  The size is read once, at attach; an empty drive does not answer and is
  taken as 512.  The CD attach moves into its own routine, _dev_attachCd.

- kernel: isofs, the ISO 9660 filesystem type, and mount_isofs(8)
  isofs.mod mounts an ISO 9660 volume read-only: a CD on /dev/cd0, or an
  image on any block device.  It is netbsd-0-9's sys/isofs in FGX's VFS terms,
  in prodos.mod's shape -- its own module bank, vfs.mod reached through
  generated import shims, vfssw[MOUNT_ISOFS] filled at load -- with 4.4BSD-Lite2
  cd9660's node numbering, name handling and recording dates.  Both trees are
  vendored.
  
      mount_isofs /dev/cd0 /mnt
  
  Names are handed up as Lite2 hands them, "README.TXT;1" as readme.txt, and
  lookup takes either case and an optional ;version.  Every node is root's,
  mode 0555.  mount_isofs loads isofs.mod with modload when mount(2) answers
  ENODEV, as mount_prodos does.
  
  Upstream defects not carried: netbsd-0-9 numbered every node by its extent,
  so empty files were one node (Lite2's isodirino numbers a file by its
  directory record); its lookup passed iso_iget a pointer into a buffer it had
  released for `..'; it read an interleaved file's gaps as data (refused here
  with EIO); and Lite2 read a recording date's zone offset unsigned, so zones
  west of Greenwich were never applied.  Every block number, size and offset
  is a long, upstream's being int.
  
  readdir renders each 128 bytes of directory into one DIRBLKSIZ block, since
  FGX's getdirentries needs block-aligned offsets; a directory's stat size is
  that rendered length.  The module loader's bank table grows to eight
  ordinals for isofs.mod's bank.  Rock Ridge is not yet read.

- isofs: Rock Ridge names, modes, owners, times and symbolic links
  A volume whose root "." record opens with SP and carries an ER field naming
  Rock Ridge is read through its System Use fields: NM names, PX modes,
  owners and link counts, TF times, and SL symbolic links, which readlink
  returns.  A directory relocated past ISO 9660's eight levels is found where
  its CL field points, and its ".." follows PL to the parent it really has, so
  pwd climbs out of it.  CE continuation areas are followed.  This is
  4.4BSD-Lite2's cd9660_rrip.c; netbsd-0-9's read only the first NM field,
  ignored CE and assumed Rock Ridge on every volume.
  
  ER accepts RRIP 1.12's IEEE_P1282 and IEEE_1282 as well as RRIP 1.09's
  RRIP_1991A, the only identifier Lite2 knew; current mastering tools write
  the newer ones.  A Rock Ridge name longer than MAXNAMLEN (63) falls back to
  the ISO 9660 name, Lite2's own fallback for a name too long for its buffer.
  A Rock Ridge name is matched exactly, case and all.

- tools: the kernel listing parser reads the label column after the address
  parse_listing took the text after a line's LAST '|' as its label column.
  Merlin's absolute-address prefix puts a '|' in the operand, so
  `LDA |_Sys_IoctlCmd' read as a definition of _Sys_IoctlCmd at the LDA's
  address.  The first such line in listing order won: every module that bakes
  the symbol would have been given the wrong address, and the build identity
  the two generators compute disagreed ($E3F5 against the kernel's $F8A8).
  
  The label is now the first token of the column after the address, and a
  line whose column starts with white space carries no label.  A self-test
  holds both cases and runs with the other generators' self-tests.

- fcc: a scalar's initializer may sit in braces
  K&R A8.7: "The initializer for a pointer or an object of arithmetic type
  is a single expression, perhaps in braces."  fcc refused the braces at
  file scope ("brace-initializer requires int[N], ...") and failed to parse
  them in a block or as a static local.  SunOS eject.c's
  `char *default_dev = { "/dev/rfd0c" };' is the shape.
  
  All three declaration sites now take the braces off, parse the expression
  as before, and accept the trailing comma A8.7's grammar allows in a list.
  Fixture M37/bracescalar covers each site and reads the values back at run
  time.

- kernel: a CD-ROM takes another disc once it is unmounted, and ejects
  A CD-ROM row is marked DEV_FLAG_STALE when nothing holds the drive, and
  the next Blk_Read probes it again before trusting what attach recorded:
  the card is asked to rescan (CONTROL $1F, so its own partition and block
  size tables are rebuilt), then the sector size (STATUS $06) and the DIB,
  as at attach.  A drive found empty stays stale, so the read after a disc
  goes in probes once more; a drive empty at boot starts stale.  This is
  netbsd-0-9's cdopen (sys/scsi/cd.c), which checks the unit and loads its
  parameters on every open, done on the first read after the medium may
  have changed.
  
  What marks it is the block device's close.  spec_close's VBLK arm calls
  the bdevsw d_close Reno names there; netbsd-0-9's cdclose releases the
  drive (cd_prevent_unit(unit, PR_ALLOW, ...)), and FGX's half is
  KSVC_BLKSTALE, which marks the row and drops the block cache.  isofs and
  ProDOS unmounts now close their device first, as 4.4BSD-Lite2's
  cd9660_unmount and Reno's ufs_unmount do, which also drops the old disc's
  buffers.
  
  spec_ioctl gains Reno's block arm, `(*bdevsw[major(dev)].d_ioctl)', by
  the staged road kc_cdioctl uses: KSVC_BLKIOCTL carries netbsd-0-9's
  CDIOCEJECT (cdioctl, _IO('c', 24) less the size bits) to the card's
  CONTROL $04 and marks the row stale.  Anything else is ENOTTY.  A mounted
  disc cannot be ejected this way because it cannot be opened: spec_open
  answers EBUSY through mountedon.
  
  _dev_rawStatus/_dev_status gain _dev_call, the command in X, for the
  CONTROL calls.  kc_blkstale/kc_blkioctl live in modules/common/kc_blkdev.s,
  PUT by ufsdir.mod alone.
  
  The renumbering of units a rescan can cause, when a new disc has more
  ProDOS partitions than the last, is not handled.

- eject(1), from SunOS 4.1.3
  vendor/SunOS-4.1.3/usr.bin/eject.c, with its man page.  The devices are
  /dev/cd0 to /dev/cd3 (nicknames cd, cdrom, cd0-cd3) and the ioctl is
  CDIOCEJECT from a new <sys/cdio.h>.  FGX has no raw CD-ROM device, so the
  block device is opened, and try_unmount runs before the open because a
  block device with a filesystem mounted on it cannot be opened.  The mount
  table comes from getmntinfo(3) and the unmount is 2.11BSD's umount(2) on
  the special file.  -q reads the first block, since an empty drive opens
  here.  -f cannot eject a disc that will not unmount, which the man page's
  BUGS section says.

- block: an offline drive does not downgrade its bus
  A failed extended read cleared the bus's extended and multi-block flags
  for the rest of the boot, on any error, because a standard-only device
  that does not answer an unknown command times out with a bus or I/O error
  rather than BADCMD.  An empty CD-ROM answers a read with OFFLINE, so one
  read of an empty drive downgraded the card: the drive stayed unreadable
  after a disc went in, its 2048-byte sectors having no standard-call path,
  and every other device on the card fell back to single-block reads.
  
  OFFLINE ($2F, "The device is off line or no disk is in drive") and DISKSW
  ($2E, "Media has been swapped (extended calls only)") are answers only a
  device that took the call can give (Firmware Reference Table 7-6, p.156).
  Both _SP_ReadBlock's extended arm and _SP_ReadBlockN now return them as
  the read's EIO and leave the bus as it is; every other error downgrades
  it as before.

- eject(1) is registered in the provenance table
  A third-party row for src/userland/eject/eject.c, from SunOS 4.1.3
  vendor/SunOS-4.1.3/usr.bin/eject.c, and the SPDX marker the row names.

- block: an extended read that answers DISKSW is asked again
  DISKSW ($2E, "Media has been swapped (extended calls only)", Firmware
  Reference Table 7-6, p.156) reports a medium change to the first extended
  call that can see it.  The boot program reads with standard calls, so the
  kernel's first extended read -- the root mount's -- is that call.  Since
  OFFLINE and DISKSW became the read's EIO, a card giving that notice failed
  the root mount, and the boot ended with `init load failed: errno=$06'.
  Before, any extended error downgraded the bus and the standard retry read
  the block.
  
  _SP_ReadBlock now reissues an extended read that answers DISKSW, once; a
  second DISKSW in a row is taken as any other error and downgrades the bus.
  OFFLINE is the read's EIO only for a CD-ROM, whose empty drive answers it
  and whose 2048-byte sectors have no standard-call path; a disk's OFFLINE
  downgrades the bus, as every other error does.

- login(1): the login PATH carries /usr/fgx/bin
  login set PATH=:/bin:/usr/bin:/sbin, while init seeds the same default
  with /usr/fgx/bin, the system tool directory (dmesg, vmstat, slotscan,
  font, color and the rest).  A shell started by init found those tools by
  name; one started by login(1) did not, so dmesg was "not found" after a
  console login.
  
  2.11BSD's login sets PATH from _PATH_DEFPATH (usr/bin/login/pathnames.h:22,
  "/bin:/usr/ucb:/usr/bin:/usr/games:"), which names the system's own tool
  directory, /usr/ucb, beside /bin and /usr/bin.  login's PATH is now
  init's.

- rtcread: the battery clock's frame, as the kernel reads it at boot
  /testbin/rtcread prints the six bytes SYS_RTCREAD returns (Misc Tools
  ReadTimeHex): seconds, minutes, hours, the year less 1900, and the day and
  month counted from zero.  tod_init rejects a frame outside 1970-2099 with
  "Invalid time in real time clock", and this shows the frame it rejected.

- kernel: the DOC is quieted before interrupts are enabled
  The firmware's sound-interrupt vector ($E1002C) starts out at a system
  failure, $08FF unclaimedSndIntErr, until something claims it.  Sound_Init
  halted the DOC's oscillators only after the CLI in Toolbox_InstallHB, so an
  oscillator left with its interrupt enabled by whatever ran before the
  kernel could interrupt in between and stop the machine.  The boot failed
  that way intermittently on a IIgs with a TransWarp GS.
  
  Sound_Init now runs before the CLI, and after halting every oscillator,
  which clears its interrupt enable, it drains the Oscillator Interrupt
  register: an oscillator that had already reached the end of its
  wavetable keeps IRQ asserted until $E0 is read (Apple IIgs Hardware
  Reference pp.106-107, Table 5-3).

- boot: stage 1 quiets the DOC before anything can take an interrupt
  The firmware's sound-interrupt vector ($E1002C) starts out at a system
  failure, $08FF unclaimedSndIntErr.  A IIgs with a TransWarp GS stopped
  that way intermittently before the kernel was up, straight after the
  accelerator's power-on splash; a warm restart then booted normally.
  Stage 1 masks interrupts, but the firmware and Toolbox calls between it
  and the kernel run with whatever interrupt state they choose.
  
  Straight after its SEI, stage 1 now halts all 32 oscillators, which
  clears their interrupt enables, and reads the Oscillator Interrupt
  register until bit 7 says none is pending, discarding the first read as
  the DOC's one-cycle read lag requires (Apple IIgs Hardware Reference
  pp.106-107).  The Sound Control register's volume bits are kept.

- kernel: the super hi-res page is black before it is shown
  _ConfigureHardware turned on super hi-res and left the console to clear
  it at _BootScreen, so in between the display showed whatever the frame
  buffer, SCBs and palettes held.  On an unaccelerated IIgs that gap lasts
  seconds.  The page, SCBs and palettes ($E1:2000-$9FFF) are now zeroed
  first, which is black.

- dev: every SmartPort bus decides extended calls from its own card
  Blk_DetectCaps asked $CnFB and the devices' DIB subtypes of the boot bus
  alone, and _dev_registerBus left every other bus's flags at zero, so a
  second card was driven with standard calls whatever it supported.  A
  CD-ROM with 2048-byte sectors has no standard-call path, so on any card
  but the boot one it could not be read; a IIgs can hold an extended card
  and a standard one at once.
  
  _dev_enumBus now decides it for each further bus from the DIBs the walk
  reads anyway: the card's $CnFB bit 7, then every answering device's DIB
  subtype bit 7 (Firmware Reference p.142), with at least one answering
  and none lacking a DIB -- Blk_DetectCaps's rule.  A bus that qualifies
  gets BS_FLAG_EXT and BS_FLAG_MB and says so in the boot log, "spN:
  extended SmartPort".
  
  A CD-ROM's attach no longer asks for the DIB a second time: the first
  four bytes of the enumeration's DIB are kept across the block-size
  STATUS.  A card may take seconds over each STATUS to an empty drive.

- kernel: the console comes up before the storage probe
  The console started after Blk_Init and Dev_Init, so the attach lines
  reached the screen only in the ring replay, and a card that is slow to
  answer STATUS -- an empty CD-ROM drive behind an Apple High-Speed SCSI
  Card, for half a minute -- showed as a blank screen with nothing said.
  _BootScreen and the RAM floor check now run straight after the hardware
  summary, once the heap, the far bank and the boot program's font are in
  place, and each attach line appears as its device is found, as BSD's
  autoconfiguration prints them.

- kernel: the CPU speed is measured with interrupts enabled
  A TransWarp GS with its AppleTalk/IRQ option on "will slow down to the
  appropriate speed whenever the interrupts are disabled (the IRQ Disable
  flag is set)" (TransWarp GS User's Manual p.14).  _MeasureCPUSpeed ran
  under the boot SEI, so on such a card the boot line reported 2.5 MHz
  while user code, which runs with interrupts enabled, ran at 15.4; with
  the option off it read 15.4.
  
  The probe now enables interrupts for its two VBL periods and restores
  the boot's P after.  Nothing of FGX's is on the IRQ vector yet and stage
  1 has quieted the DOC; a firmware VBL interrupt, if one is armed, costs
  the count a few hundred cycles of the ~33 ms it spans.

- kernel: /dev/null reads and writes in bulk, as 2.11BSD's mmrw does
  /dev/null's chardev vtable had no d_read or d_write, so spec_chwrite
  moved every discarded byte through its own one-byte uiomove and a
  kc_cdwrite seam crossing, and a read found end of file the same way.
  Output to /dev/null cost more than output to a file: `od -c' of a 7.7 KB
  file took 27.1 s to /dev/null and 16.8 s to the root (#22).
  
  The bulk ops are 2.11BSD's mmrw minor 2 (usr/sys/pdp/mem.c:58-67): a
  read is end of file at once, and a write consumes every region whole --
  iov_base += c, iov_len -= c, uio_offset += c, uio_resid -= c -- stepping
  over an emptied region as mmrw's loop does.  A uio that runs out of
  regions with bytes still owed, mmrw's panic, is EIO.  include/chardev.s
  gains the uio_iov, uio_iovcnt and struct iovec offsets the walk reads.
  
  The same `od -c' now takes 15.8 s to /dev/null, and `cat' of the file
  0.3 s, from 3.0.

- dev: the boot log names every SmartPort device and each bus's call set
  Each attach line now carries the device's own ID string and type from its
  device information block (Firmware Reference p.123; type names from
  SmartPort Technical Note #4), as NetBSD 0.9's scsi_probe
  (sys/scsi/scsiconf.c) prints a target's inquiry strings and type:
  
      sp0 at slot 7
      sd0 at sp0 unit 1: <SEAGATEST225N1> hard disk, 63999 blocks (31999KB)
      cd0 at sp0 unit 2: <SONYCD-ROMCDU-80> CD-ROM, empty
      sp0: 2 units, extended SmartPort, multi-block reads
  
  Each bus prints its line before its units and a capability line after
  them: the unit count its port reports, and whether the block driver makes
  extended or standard calls to it. That line replaces the boot bus's
  "blk: extended SmartPort - multi-block read path" line, which only ever
  described the boot bus.
  
  A unit that answers but is not attached says why rather than vanishing:
  "sp1 unit 1: <DISK 3.5> 3.5-inch disk, no media", or "not attached,
  every unit number in use" past sd7 or cd3.
  
  The boot bus is enumerated like every other one, from unit 1; its unit 1
  is the boot disk Blk_Init registered as row 0. Blk_DetectCaps, its DIB
  walk and Blk_LogBootDev are gone, and the boot bus's extended-call
  decision is the same per-bus rule the others use.

- console: a write's full-screen scrolls move the pixels once (#27)
  Every newline at the bottom row moved the whole screen, about 30 KB of
  pixels, so output that scrolled cost one full-screen move per line.
  
  While a write(2) to the console is open (_Vc_WriteEnter, Con_WriteArm),
  a full-screen scroll now advances the cell ring and clears the new row
  as before but only counts the pixel move. Rendering skips the pixels and
  records the topmost row it would have drawn. When the write ends
  (_Vc_WriteLeave, Con_WriteDone), _Con_FlushPending moves the rows still
  on screen up by the count with one MVN and renders every row from the
  topmost exposed or dirty row down; a screenful or more renders the whole
  viewport. The other pixel writers, Con_Clear, a partial-region scroll
  and Con_ScrollRegionDown, flush first. A console with a module renderer,
  and one a task has claimed with SYS_SCREEN_CTL, are not armed.
  
  cat of a 1,100-line file takes 17.6 s in MAME instead of 68.7 s. A
  writer that sends one line per write(2) still pays a move per line.
  
  The conscroll test compares the framebuffer with the cell buffer after
  a scrolling cat, and fails when the flush moves the pixels without
  rendering the rows it exposed.

- console: a pending scroll outlives the write and is drawn 100 ms on (#27)
  A program that writes one line per write(2) -- anything on line-buffered
  stdio, which is every filter writing to a terminal -- still moved the
  whole screen once per line, because each write drew what it owed when it
  ended.
  
  Con_WriteDone now leaves a pending scroll pending, and the next write's
  scrolls add to it. _Vc_WriteLeave starts a clock the first time it sees
  one (_Con_StampScroll, _kConPendTick), and _Con_DrainScroll, called
  beside _Tty_DrainOutPend at every syscall return and in swtch's idle
  loop, draws it through the new Con_DrainPending once it is
  CON_SCROLL_TICKS (6) old. The screen is current within 100 ms of the
  last write with nothing reading the console; any other render state
  stops the clock.
  
  sed -n 1,400p of a man page takes 25.2 s in MAME instead of 40.0 s, and
  cat of 1,100 lines 16.1 s instead of 17.6 s.
  
  conscroll and conpaint both fail with the drain disabled.

- more(1): the page goes out through stdio, not a write(2) per byte
  putch() wrote every byte of the page with its own write(1, &c, 1), so a
  page cost one system call per character. It is putchar() now, as 2.11BSD
  more's putch() is (usr/ucb/more/more.c), the --More-- prompt goes through
  fputs(), and stdout is flushed before the key is read, as upstream's
  prompt() does. One 784-byte page went from 4.0 s to 1.1 s in MAME, 0.7 s of
  which is starting more and clearing the screen.

- console: erasing the whole screen does not repaint blank cells
  ESC[2J cleared the super hi-res page to the background color and then
  rendered every cell, all of them blank. A blank cell draws only its
  background unless inverse or underline marks it, so the repaint now runs
  only for those attributes, or when a module's renderer owns the screen.
  A clear(1) takes 0.2 s instead of 0.3 s in MAME.


### Documentation

- The root and fgx accounts' default password, fgx
  CONFIGURING.md gains a "Logins and passwords" section: the console is a root shell, the other consoles and telnet ask for a login, and both root and fgx have the password fgx; change them with passwd(1) before networking or telnet.  The README's first-boot note names the password.

- Mount_isofs(8), and CD-ROMs mount as ISO 9660
  mount_isofs(8) describes the command, name translation, Rock Ridge and what
  is not read: Joliet names, a disc's later sessions and interleaved files.
  CONFIGURING.md's CD-ROM paragraph says an ISO 9660 disc mounts with it, and
  modules.md lists isofs.mod in bank ordinal 7.

- The scanline console's phases 2-4 are deferred; the scroll batching is in (#27)

### Tests

- testdata: colours.ans, an 80x25 chart of every colour pair the card shows
  /testdata/colours.ans fills the Second Sight card's console with the 16 x 16
  matrix of colour pairs, each cell labelled with its VGA attribute byte
  bg<<4|fg, written as ANSI.SYS art writes them: 30-37 and 40-47, bold for a
  bright foreground and blink for a bright background (iCE colour).  Beside
  each row is its colour as a foreground in code page 437 blocks; below are the
  shade ramp in all sixteen colours, samples of SGR 7, 4, 38;5, 48;2 and
  90-107, single-line box drawing, half blocks and the high glyphs, inside a
  double-line box.
  
  Lines end in CR LF, since ansicat sets LLITOUT, and none reaches column 80;
  the last row has no line end, so the screen does not scroll.  A ^Z and a
  SAUCE record (80x25, iCE colour) follow.  tools/mkcolours_ans.py writes it.
  
      ansicat /testdata/colours.ans > /dev/ttyv3
  
  ansi.ans stays as ssansi's fixture: its rows are built so each lands on one
  attribute byte the check script can read.

- testdata: the color chart leaves the last row to the prompt and shows the graphics block
  colours.ans now ends after row 23 with a line end, so the shell's prompt
  lands on row 24 and the screen does not scroll; it had ended on row 24
  with none, the prompt began at column 79, and the title bar scrolled off.
  
  The box's second row is code page 437's whole graphics block, $B0-$DF,
  then $F0-$FE, in place of the accented letters and Greek.  The SGR samples
  are labelled in words (256-color, 24-bit, aixterm fg/bg) rather than by
  their parameters, which read as unparsed sequences.  Black's name in the
  right-hand column is shown in white, since black on black cannot be read.

- tests: isofs mounts a Rock Ridge volume and reads it
  tests/isofs mounts tools/testdata/isofs/rrtest.hdv on /dev/sd1 with
  mount_isofs and checks Rock Ridge names, a name past MAXNAMLEN falling back
  to its ISO 9660 name, a PX mode, an SL link, a directory of several blocks,
  a file across seven sectors, and a directory Rock Ridge relocated past eight
  levels, in and out again with pwd.  With Rock Ridge detection turned off,
  seven of its arms go red.
  
  The volume is written by pycdlib, an independent writer, and committed with
  the script that regenerates it.  It is padded with 16 zero sectors, as
  mkisofs and xorriso pad: a volume's last sector reads as an I/O error on
  MAME's Apple SCSI CD-ROM.

- tests: specops holds the block switch's close and ioctl to their driver
  spec_close's VBLK arm now ends in the driver close, kc_blkstale, and
  spec_ioctl's in kc_blkioctl.  The fixture stubs both with call counters:
  a last close reaches the driver with its own dev (160, 161), a close while
  an alias still holds the device does not (166), and an ioctl returns the
  driver's answer, 0 or ENOTTY, so no constant passes both (162-165).
  Section 7's note that the last-close branch was unobservable goes, now
  that the branch has a driver to call.

- tests: exit_on_prompt can settle before the final dump (#27)
  The console draws a pending scroll up to 100 ms after the last write, so
  a check that reads the framebuffer at exit could find the sentinel in
  the CharBuf before the pixels caught up. exit_on_prompt takes
  settle_frames, the frames to run on after the count is reached before
  the final dump; conscroll settles 30.


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
