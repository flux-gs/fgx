# Classic desk accessories: `loadcda`, `cda.mod`, and DocVue

Status: C1, C2 and C3 landed 2026-09-15.  ROADMAP
item: Kernel / memory, "Classic desk accessories".

## 1. What is decided

- Classic desk accessories (CDAs, ProDOS type $B9) run from the ROM's
  Ctrl-OA-Esc menu under FGX.  The menu itself already works (measured
  2026-09-15: Quit, and a Control Panel visit then Quit, return to a working
  shell).
- THE TARGET CDA IS DocVue 2.0 (freeware, Brian Ballweber 1993-94), used to
  watch the Ensoniq DOC while `ntpplay` plays.  It runs UNMODIFIED.
- CDAs that need GS/OS are not in scope in general, but the calls DocVue makes
  are, provided DocVue needs no change (the maintainer, 2026-09-15).
- The GS/OS os_kind flag ($E1/00BC) is set only as part of providing GS/OS
  calls; whether other CDAs need it is open.
- CDAs are loaded by a PRIVILEGED USERLAND COMMAND, `loadcda FILE`, which
  registers one CDA per run, so several can be loaded (the maintainer, 2026-09-15).
- The CDAs under `examples/mentzer/` are reference only; their provenance is
  unknown.

## 2. The shape, and where it comes from

BSD's counterpart is loadable kernel modules: modload(8) is a userland command
that talks to the kernel through a root-only pseudo-device, `/dev/lkm`
(`examples/netbsd-0-9/sys/kern/kern_lkm.c`, advisory source only).  Its
protocol is the one a relocatable load needs: LMRESERV reserves memory and
returns its address, the userland command relocates the image for that
address, LMLOADBUF copies it in, LMREADY makes it live, and a close before
LMREADY discards the reservation.  Every ioctl requires the device to be open
for writing.

FGX's own modload(8) moved the file read to userland and kept allocation and
relocation in the kernel behind SYS_MODLOAD (`src/userland/modload/modload.c`,
`docs/history/plans/2026-09-01-userland-modload.md`).  CDAs differ from FGX
modules in one way that decides the split: the code that must stay resident
(the GS/OS and Loader stubs, the Desk Manager hooks) is FGX's, and the CDA is
someone else's OMF file.  So:

- **`cda.mod`**, a kernel module loaded by `/etc/rc` like `bpf`, holds
  everything resident and registers a character device `/dev/cda`, as
  `bpf.mod` registers `/dev/bpf0` in its mod_init.  The node is root-only.
- **`loadcda`** (userland, C) opens `/dev/cda` for writing, parses and
  relocates the OMF file, and uses ioctls in LKM's order.

No core-bank syscall slot is needed, and the OMF parser stays in userland C.

## 3. `loadcda FILE`

1. Read FILE's OMF load segments.  Accept static code and data segments that
   fit one bank, with LCONST/CONST/DS bodies and RELOC, cRELOC, INTERSEG,
   cINTERSEG and SUPER (RELOC2, RELOC3, INTERSEG1) records.  Skip
   ~ExpressLoad.  Refuse dynamic segments, jump tables and anything else by
   name, rather than loading something half-relocated.
2. `CDAIOCRESERVE { size }`: the module allocates a desk-accessory user ID
   (Miscellaneous Tool Set GetNewID; the type value to be read from Toolbox
   Reference vol 1 ch. 14, not assumed) and a locked, fixed NewHandle of
   `size` bytes under it, aux ID 0, and returns the handle's address.
3. Relocate every segment for its place in that block.
4. `CDAIOCLOAD { buf, len, offset }` copies it in, chunked like modload.
5. Read FILE's resource fork if it has one: `._FILE` beside it, the AppleDouble
   form FGX's ProDOS filesystem already presents (mount_prodos(8), FORKED
   FILES), which a copy onto UFS keeps.  `CDAIOCFORK { buf, len, offset }`
   copies it into a second handle the module owns.
6. `CDAIOCINSTALL { path, header offset }`: the module records the user ID,
   the absolute pathname and the fork, then calls InstallCDA ($0F05) with a
   handle to the CDA header.  A close before this frees everything.

Why the CDA's ID matters: DocVue calls MMStartUp for its ID and allocates only
under aux IDs +$100 (a copy of the SHR screen) and +$200 (its fork data), and
DisposeAll touches only those; the code handle at aux 0 survives its shutdown
routine.

## 4. `cda.mod`, resident

### 4.1 Desk Manager hooks

GNO/ME's approach (`examples/gno/kern/gno/patch.c:42-43`, `kern.asm:605-750`,
`kern/drivers/conpatch.asm`): replace the Desk Manager's SaveAll ($0B05) and
RestAll ($0C05) entries, which bracket the CDA menu, and call the originals.

Both tables are in ROM on a bare ROM 03 (measured: the Tool Locator's
pointer table at $FE/0139, the Desk Manager's at $FE/C57B), so GNO's in-place
write cannot work here.  The module gives SetTSPtr a function pointer table of
its own, as Technical Note #101 describes -- BootInit patched to return no
error, and userOrSystem $0001, which ROM 3 requires for tool set 5.  With that
table installed, one menu visit calls SaveAll once and RestAll once (measured).

- SaveAll: save the border ($C034 low nibble) and text colours ($C022), which
  the Desk Manager does not restore (measured: 2 to 5 and F2 to F4); from C3,
  set os_kind to 1 when the GS/OS stub is present (section 4.2).
- RestAll: put the colours back, and from C3 os_kind.  A head patch is
  enough: the original RestAll does not touch the colours (measured).
- A CDA that takes IRQ.VBL, as DocVue does, stops `_kSystemTicks` for as long
  as it runs (measured: 5698 before and after 120 frames inside DocVue).  NO
  CLOCK RESYNC IS NEEDED: `gettimeofday` reads the battery clock on every call
  (`toolchain/lib/libc_c/gettimeofday.c:50-58`, SYS_RTCREAD), and the
  filesystems' `kern_time` rereads it every 3600 ticks
  (`src/kernel/vfs/kern_time.c`).  Adding the missed ticks would instead fire
  every sleep, select and alarm deadline at once.  What stalls is only what
  stalls for any application under GS/OS while a CDA runs.
- A console repaint IS needed: DocVue leaves SCB 0 and palette 0 zero and its
  own pixels in the frame buffer (measured), so the shell kept running with
  its text invisible.  The ROM menu turns SHR off, so DocVue sees a text screen
  and has nothing of the console's to save.  RestAll sets the kernel's
  `_kConRestoreReq`; `_Con_DrainRestore` (ttyv.s), called where
  `_Vc_DrainSwitch` is, runs SYS_SCREEN_CTL's release sequence -- SCBs,
  palettes, `Con_RenderAll` -- at the next safe point, and not while a task
  owns the screen.

### 4.2 The GS/OS stub

DocVue's only GS/OS use, on first activation: Open ($2010) of its own resource
fork (pcount 4, request access read, resourceNumber 1), SetMark ($2016) to
1024, Read ($2012) of 44,777 bytes, Close ($2014).

Those calls come INSIDE the CDA, with every FGX task stopped, where the VFS
cannot run.  So the stub never touches a disk: it serves the fork `loadcda`
registered.  It installs a JML at the GS/OS entry $E1/00A8 and handles, for a
pathname a registered CDA owns and resourceNumber 1: Open (one refNum per
open), SetMark, Read, Close, GetEOF if a CDA needs it.  Every other call or
pathname returns a GS/OS error ($0001 bad call number; $0046 file not found)
rather than pretending.

### 4.3 The Loader stub

LGetPathname2 ($2211) is a System Loader call, tool set $11, which is not in
ROM (the Loader is in P16 on disk).  The module installs a tool set $11 table
through SetTSPtr whose LGetPathname2 returns, for a registered CDA's user ID
and file number 1, a class 1 GS/OS string of its pathname, and whose other
entries return the tool set's error.

### 4.4 os_kind

DocVue refuses to run when os_kind ($E1/00BC) is 0.  Set it only while a CDA
is active (SaveAll to RestAll) and only when the GS/OS stub is installed: FGX
itself never runs with GS/OS, and ROM or toolbox code outside a CDA must not be
told otherwise.

## 5. Increments

- **C1: `cda.mod` with the SaveAll/RestAll hooks** -- colours restored.
  Check: a MAME run that opens the menu, visits the Control Panel and quits
  reads $C034 and $C022 back at FGX's values.  LANDED 2026-09-15: both round
  trips read $42/$F2 where they had read $45/$F4, and the shell answers after
  each.
- **C2: `/dev/cda` and `loadcda`** for CDAs that need no GS/OS.  Check: DocVue
  loads, appears in the menu, and, with os_kind 0, shows its own error screen
  and returns to the menu -- the documented failure path, which proves
  loading, relocation, installation, entry and exit.  LANDED 2026-09-15:
  `loadcda /root/docvu.cda' exits 0; DOCVu is listed between Alternate Display
  Mode and Quit; selecting it runs DocVue from its reserved block (bank $12)
  into the key wait at the end of its os_kind refusal; a key returns to the
  menu, Quit to a shell that answers.  The boot log says `/dev/cda is device
  19', the index the root's node carries.  The relocation was also checked on
  the host: loadcda's relocator and a separate Python one produce the same
  19,824-byte image.
  - FOUND: the refusal's text did not reach the screen, and THE CAUSE IS AN
    fcc DEFECT IN loadcda.  loadcda's patch() takes the relocated value as an
    unsigned long parameter and shifts it in place; fcc caches that parameter
    in its register cells and loads only the low word at entry (_fcc_img2),
    never the high word (_fcc_img3).  Every cRELOC and INTERSEG record goes
    through patch(), so on the machine each relocated bank byte came out 0:
    DocVue's WriteLine string pointers (cRELOC, shift -16) named bank $00, and
    a test CDA whose header pointers are cRELOC entered $00:0011 and dropped
    into the Monitor.  DocVue's own header pointers are SUPER RELOC3, added
    in a long local, and were right -- which is why it ran at all.  The host
    build of the relocator (clang) was correct, so the host check passed.
    FIXED in fcc: the entry seed now writes both words of a promoted long
    parameter.  Measured after the fix: TEXTTEST's installed header reads
    start $12:0011 and shutdown $12:003E, its WriteLine prints `HELLO FROM
    FGX TEXT TOOLS', and DocVue draws "DOCVu Error: DOCVu cannot operate
    under ProDOS 8.  <hit any key>" legibly.
  - Ruled out on the way, each by measurement: Text Tools initialisation,
    the bank-0 language card (a harness dump that read the $C080-$C08F
    switches made it look guilty), the output masks and device (AND $FF,
    OR $80, BASIC slot 3), and the direct page register.
- **C3: the GS/OS and Loader stubs, fork registration, os_kind, and the clock
  resync (and a console repaint if one proves needed).**  Check:
  with `ntpplay` playing, DocVue shows the oscillators, the music keeps
  playing (ntpplay reads $E1/00CC since d0b450f64), and Quit returns to a
  shell whose clock was resynced.  LANDED 2026-09-15, measured headless:
  - on a bare ROM 03 $E1/00A8 is `00 00 00 00`, a BRK, and tool set $11 is a
    placeholder at $FE/0265; with os_kind forced to 1 and no stubs, DocVue's
    LGetPathname2 returned garbage and its Open dropped into the Monitor;
  - DocVue's MMStartUp ID is $5001, the ID loadcda reserved, so the stubs key
    on the CDA's own ID;
  - with the stubs, the boot log says `cda: GS/OS and Loader stubs
    installed', `loadcda /root/docvu.cda' (with `/root/._docvu.cda') exits 0,
    DocVue's Open returns refNum 1, and it draws its full display from the
    fork; os_kind reads 1 in the menu and 0 after Quit;
  - with `ntpplay /root/m.ntp' playing, DocVue shows live oscillators --
    waveforms, OSC ENABLE $36 then $3E, frequencies moving between two
    snapshots 300 frames apart, its CPU meter at 10% -- and ntpplay's
    IRQ.SOUND handler is back in place after Quit;
  - after Esc and Quit the console's SCB, palette and pixels read back as
    they were before the menu, and `ls /` runs.
  The clock resync was not needed (section 4.1).
- Later: the busy flag ($E1/00FF) around kernel sections the menu must not
  interrupt; RemoveCDA ($2105) for an unload.

## 6. Open

- DECIDED (the maintainer, 2026-09-15): CDAs live in `/usr/fgx/cda`, each beside its
  `._` resource fork, and `/etc/rc` runs loadcda on every file there after
  modload, as GS/OS installs */System/Desk.Accs at boot.  DocVue ships there,
  vendored in `vendor/docvu2/` (freeware, "distribute freely, but do not
  sell").  Measured: a fresh boot lists DOCVu in the menu with nothing typed,
  and it runs from the shipped fork.
- Whether any other CDA needs os_kind or more GS/OS calls.  The stubs serve a
  CDA's own resource fork for reading and nothing else.
- The desk-accessory user ID type value, to be read from the manual.
