;==============================================================================
; modules.s - FGX modules ABI constants.
;
; Declares the slot offsets for the core jump table at $00:032E (bank-0 JT
; gateway; was $02FE00), the ABI
; version monotone, and the VT_* vtable type tags modules use when
; registering with core.  See docs/superpowers/specs/2026-05-13-kernel-
; modules-design.md section 3.2.
;
; NOTE: The spec text shows slots 3 bytes apart, but 65816 JML is a 4-byte
; instruction ($5C + 24-bit address), so slots must be 4 bytes apart.
; Phase 1 implementation uses 4-byte spacing; the spec is the bug.
;
; This file emits zero binary bytes — pure EQU declarations.  PUT'd by
; src/kernel/main.s for the kernel side; future module sources will PUT
; the same file for slot-offset constants.
;==============================================================================

;------------------------------------------------------------------------------
; ABI version — bumped monotonically when the jump-table layout changes
; incompatibly (slot removal, renumbering, semantic break).  Adding slots
; at the tail is backward-compatible and does NOT bump the version.
;------------------------------------------------------------------------------
MOD_ABI_VERSION         EQU     $0002       ; v2: slot 24 reused for SYS_MODLOG

;------------------------------------------------------------------------------
; Jump-table base + slot offsets.  32 slots (0..31), each 4 bytes (JML
; opcode + 24-bit target).  Preceded by a 6-byte header.
;------------------------------------------------------------------------------
; RELOCATED 2026-06-11 from $02FE00 (top of the kernel bank, which moves under
; the relocatable-kernel campaign) to the bank-0 FGX_INTVEC gateway just past
; KFGX_ANCHOR.  Modules call FIXED bank-0 addresses (transparent to JSL/RTL);
; _JT_Init fills each cell's TARGET bank from the runtime kernel bank (PHK), so
; modules never need to know where the kernel landed.  The 114-byte region is
; reserved + ERR-guarded in include/memmap.s (DUM $000320, MOD_JT_GATEWAY).
; Every slot is MOD_JT_BASE-relative so a future move is a one-line change.
MOD_JT_BASE             EQU     $00032E     ; bank-0 gateway (was $02FE00)

MOD_JT_ABI_VER          EQU     MOD_JT_BASE+$00 ; word: ABI version
; Build identity of the RUNNING kernel, published by _JT_Init from
; _kernBuildId (src/kernel/kernel_build_id.s, GENERATED).  Every module's FGXM
; header carries the same word at +34, and Mod_Load refuses one that
; disagrees: the module baked kernel ADDRESSES at build time, so against
; another kernel build every one of them points at the wrong byte.  $0000 in a
; module header means NOT BUILD-LOCKED (it bakes no kernel addresses).
; See tools/gen_kernel_exports.py and tools/check_build_id.py.
MOD_JT_CORE_BUILD       EQU     MOD_JT_BASE+$02 ; word: core build identity
MOD_JT_RESERVED         EQU     MOD_JT_BASE+$04 ; word: reserved

; NAMES HERE ARE NOT PROMISES.  Three of the four slots below were declared
; for one service and repurposed for another, and the old names outlived the
; slots: SYS_KMALLOC/SYS_KFREE (slots 0/1) and SYS_BANKALLOC (slot 2) were
; never wired and now carry the block-cache pin bridge.  A module author who
; read this file in 2026-08 concluded that modules could allocate banks; they
; cannot.  The authority is src/kernel/jumptable.s's _JT_Targets -- a slot
; whose target is _Phase1_StubHalt is a RED BORDER AND A WEDGED MACHINE, not
; an unimplemented return.
;
; UNIMPLEMENTED, as of 2026-08-11 (targets are _Phase1_StubHalt): slot 8
; SYS_CONWRITEROW, slot 12 MOD_REGISTERFST, slot 13 MOD_REGISTERCONSOLE,
; slot 14 MOD_REGISTERINPUT, slot 15 MOD_REGISTERSOUND.
; (Slot 3 was SYS_BANKFREE, never implemented; it is SYS_KCALL now.)
SYS_BLKPIN              EQU     MOD_JT_BASE+$06 ; slot 0 (was SYS_KMALLOC):
                                                ;   A=blk, X.lo=dev ->
                                                ;   A=off, X.lo=bank, X.hi=idx
SYS_BLKUNPIN            EQU     MOD_JT_BASE+$0A ; slot 1 (was SYS_KFREE): A.lo=idx
SYS_BLKPINZ             EQU     MOD_JT_BASE+$0E ; slot 2 (was SYS_BANKALLOC):
                                                ;   pin a FRESH zeroed block.
                                                ;   prodos.s carries its own EQU
                                                ;   for this; modules do not PUT
                                                ;   this file
;------------------------------------------------------------------------------
; SYS_KCALL - slot 3 (was the never-implemented SYS_BANKFREE).  THE MULTIPLEXED
; SERVICE SLOT: one gateway cell carrying a SERVICE SELECTOR, dispatched
; kernel-side.
;
; The gateway is 32 fixed cells in 134 bytes of the firmware-free $0300-$03CF
; window, and IT CANNOT GROW -- everything after it is packed.  Symbol
; resolution does not help: modules already resolve kernel symbol OFFSETS at
; build time (kernel_exports.s), and what they cannot know is the kernel's
; BANK, which is exactly what the fixed bank-0 cells provide.  So the cap is
; real, and the answer is to make a slot CHEAP rather than unnecessary: new
; module->kernel services become SERVICE NUMBERS here, not new slots.  This is
; the single-entry-point-plus-command shape both SunOS's vddrv (`fcn`) and
; NetBSD's LKM (LKM_E_LOAD/UNLOAD/STAT) use in the other direction.
;
; The trade is one extra dispatch on the cold path.  Anything hot enough to
; notice still earns its own direct slot -- as net.mod's five did.
;
; ABI:  JSL SYS_KCALL with X = service number, A/Y = arguments.
;       Returns C=1 + service-specific results, or C=0 + A = errno.
;       An unknown service returns C=0 + A=ENOSYS.  It does NOT halt: this
;       slot is the one place a module can ask for something the running
;       kernel does not have, and a refusal it can log beats a red border.
;       MX %00 in and out.  Your DBR is saved and restored.
SYS_KCALL               EQU     MOD_JT_BASE+$12 ; slot 3 (was SYS_BANKFREE)

; SYS_KCALL service numbers.  APPEND ONLY -- a module image baked these at
; build time, and NOTHING WILL CATCH A RENUMBER.  The build identity does
; not cover it: a module that bakes no kernel ADDRESSES carries id $0000
; (not build-locked) and loads against any kernel, so hello.mod -- which
; hardcodes these numbers and M_ANON inline -- would silently call the
; wrong service.  Append-only discipline is the whole protection.
KSVC_KMALLOC            EQU     0   ; A = bytes, Y = M_* type (1..M_LAST-1)
                                    ;   -> C=1, A = offset, X = bank
                                    ;   -> C=0, A = errno (ENOMEM/EINVAL)
KSVC_KFREE              EQU     1   ; A = offset, Y = bank -> C=1
; Log helpers.  Every driver migrated out of the core bank needs these -- the
; kernel's Kern_Log* have no gateway slot, and giving each one a slot would
; spend the scarce bank-0 gateway on cold boot-time logging.  As services they
; cost a compare each.  LOGSTRNE reads the string from the CALLER's bank, so
; its arm restores the caller's DBR first (the same contract SYS_KERNLOG has).
KSVC_LOGSTRNE           EQU     2   ; A = bank-rel string ptr, no EOL
KSVC_LOGDEC16           EQU     3   ; A = value, logged as decimal
KSVC_LOGHEX8            EQU     4   ; A.lo = byte, logged as 2 hex digits
KSVC_LOGEOL             EQU     5   ; end the line
; Scheduler + tty callbacks, for pty.mod (the pty driver left the core bank
; 2026-08-11).  A module that implements a BLOCKING character device needs the
; scheduler, and there is no way around that: read(2) on an empty pty ring must
; sleep, not spin.  Services rather than gateway slots because none of these is
; hot enough to earn one of the 32 bank-0 cells.
;
; THE X REGISTER IS THE SELECTOR, so a kernel routine that takes an argument in
; X takes it in Y here and the kernel arm does TYX.  Getting that backwards
; passes the SERVICE NUMBER as the argument, which for TTYDELIVERSIG would post
; a signal number picked from a table index.
KSVC_SLEEP              EQU     6   ; A = wait channel (blocks; may switch)
                                    ;   -> A = 1 INTERRUPTED (a signal is
                                    ;      actionable; the caller must abandon
                                    ;      the wait and return EINTR, or it
                                    ;      spins -- apple/fgx#28)
                                    ;      A = 0 slept and was woken normally.
                                    ;   The verdict is in A and NOT in the
                                    ;   carry, because C=1/C=0 already means
                                    ;   "service dispatched"/"no such service
                                    ;   (A = ENOSYS)" for every arm.
KSVC_WAKEUP             EQU     7   ; A = wait channel
KSVC_TTYDELIVERSIG      EQU     8   ; A = tty index, Y = signal
KSVC_TTYOPEN            EQU     9   ; Y = tty byte offset (_Se_TtyOpen)
KSVC_TTYCOOKEDDEF       EQU     10  ; Y = tty byte offset (_Tty_CookedDefaults)
; For net.mod after net_loop.s + pipe.s moved into it (2026-08-11).  Same X-is-
; the-selector rule: a kernel routine wanting an argument in X takes it in Y.
KSVC_TASKLOOKUP         EQU     11  ; A = pid -> C=1 + X = TCB offset
KSVC_FCBFREE            EQU     12  ; A = fd
KSVC_FCBLOOKUPPTR       EQU     13  ; A.lo = fd -> C=1 + _fcbPtr / C=0 + A=EBADF
KSVC_SIGRAISE           EQU     14  ; A = signal, posted to _curTask
; For vfs.mod: the VFS's kc_sys seam, which is the far bank's _FarSh_BlkIo and
; _FarSh_BlkReads with the same contracts and no scraped kernel addresses.
;
; BLKIO IS NOT SYS_BLKREAD/SYS_BLKWRITE, and the difference is the reason it
; exists.  Those two take their parameters entirely from direct page cells the
; caller has already written, which a module CAN do -- but the caller's buffer
; BANK is not one of them.  _blkBufBank is a core-bank static (direct page
; $10-$1F is full), so setting it needs DBR on the kernel bank, and a module
; that could name it would be baking a kernel address.  The bank therefore
; crosses the gateway in a register, exactly as it crosses _FarSh_BlkIo.
;
; It also states _blkSrcPool = 0 for the same reason that shim does: a stale
; "the bytes are in a cache pool entry" flag left by an errored write would
; send this transfer to the pool's bank and silently move the wrong 512 bytes.
KSVC_BLKIO              EQU     15  ; A = buffer BANK, Y = nonzero to READ.
                                    ;   _blkNum/_blkNumHi/_blkBuf/_fsCurDevIdx
                                    ;   already set by the caller (all DP, so
                                    ;   it needs only the kernel's D).
                                    ;   -> C=1 ok / C=0 + A = errno
KSVC_BLKREADS           EQU     16  ; -> A = _kBlkReadCount, low word.  C=1.
; THE UNINTERRUPTIBLE SLEEP, and it is a SEPARATE SERVICE rather than a flag on
; KSVC_SLEEP because the two have different callers with opposite needs.
;
; KSVC_SLEEP routes to _sleep, which returns C=1 WITHOUT BLOCKING when the task
; has an actionable signal pending.  That is right for pty.mod: a read(2) on an
; empty ring must abandon the wait so the signal can be delivered.  It is wrong
; for a buffer wait, which re-tests and loops and has no error path to take --
; there, "a signal is pending, I did not sleep" makes the loop spin at full
; speed for as long as the signal stays pending.
;
; 2.11BSD and Reno both sleep at PRIBIO for buffers, and PRIBIO is below PZERO,
; so it is not interruptible there either.  This is that priority, not a new
; idea.  sched.s keeps the distinction in the PROGRAM COUNTER (two entry points
; around one body) rather than in a flag byte, because a flag set before a
; switch is read on the far side of one -- the shape of apple/fgx#41.
KSVC_SLEEPUN            EQU     17  ; A = wait channel (blocks; may switch)
; WHICH PROCESS AM I.  The VFS needs this to index per-process storage -- its
; nameidata slots and their pathname buffers (UFS 1.2) -- which is how namei
; stops needing the caller to lend it a buffer without becoming a singleton
; that crosses a sleep.
;
; It is a SERVICE rather than a direct read, and the reason is the DIRECT PAGE
; rather than the bank.  _curTask is a DP cell ($9E, include/dpmap.s), so it is
; free to any module code running on the KERNEL's page -- but kernel C does not
; run on that page.  It runs on FGX_DP_KERNELC, where $9E is a slot in fcc's
; register file, and a read there returns a compiler temporary that looks
; exactly like a plausible pid.  The KSVC bracket switches D, so the arm reads
; the real cell; C cannot.
;
; It must also be READ FRESH at every use.  A pid latched before a sleep is
; read on the far side of a context switch, when it names some other process
; -- apple/fgx#41's shape, and here it would cross-index another process's
; nameidata slot.
KSVC_CURPID             EQU     18  ; -> A = _curTask (1..NPROC).  C=1.

; KSVC_FINDVTABLE - resolve another module's exported vtable.  THE FIRST
; SERVICE THAT LETS ONE MODULE REACH ANOTHER, and it exists because UFS moved
; into a module of its own (apple/fgx#169) and has to reach vfs.mod's buffer
; cache.
;
; Mod_FindVtable is the kernel's own registry walk and has always been there;
; what did not exist was a way to ASK for it from outside the kernel bank. Every
; caller until now (fst_dispatch, net_dispatch, pty) is kernel code that can
; JSR it directly.  A module cannot: it does not know the kernel's bank.
;
; It is safe to expose precisely because apple/fgx#32 made Mod_FindVtable
; BANK-INDEPENDENT BY CONSTRUCTION.  Before that it routed its walk through
; DBR-relative scratch and required `DBR = kernel bank` of its callers -- the
; arrangement whose sibling failure (apple/fgx#29) wrote two words into a
; freshly loaded module image and turned four bytes of _fop_rename into BRKs.
; Publishing it as a service then would have handed every module a footgun.
;
; RESOLVE ONCE, AT mod_init, AND CACHE THE RESULT.  The walk is a linear scan of
; the registry, and the importing module's hot path is every block read.
KSVC_FINDVTABLE         EQU     19  ; A = VT_* tag -> C=1 + A = voffset,
                                    ;   X.lo = bank; C=0 + A = ENOENT if the
                                    ;   exporting module is not loaded.

; KSVC_RTCFRAME (20) - RETIRED.  It read the battery clock's raw frame for
; kernel C's own clock; kernel C reads the kernel clock through KSVC_TIME now.
; The number stays reserved, and the dispatcher answers it ENOSYS.
KSVC_RTCFRAME           EQU     20  ; retired: ENOSYS
; THE 60 Hz TICK COUNTER, all 32 bits, because the low word alone is not enough
; for the caller this exists for (apple/fgx#182).
;
; The low word wraps every 65536 ticks = 18.2 MINUTES, and `kern_time`'s callers
; are `ufs_itimes` and `ufs_sbupdate` -- filesystem writes, which on an idle
; system are hours apart.  A 16-bit delta cannot tell "no time passed" from
; "18.2 minutes passed", and the reading that says no time passed produces a
; file timestamp quietly stale by eighteen minutes.  So the service is 32-bit
; and the arm pays a PHP/SEI to read the halves together.
;
; X carries the high word; see the arm in jumptable.s for why that is documented
; rather than assumed.
KSVC_TICKS              EQU     21  ; -> A = _kSystemTicks lo16, X = hi16.  C=1.
                                    ;   apple/fgx#182: kern_time's clock was a
                                    ;   3.6 ms firmware excursion PER CALL,
                                    ;   measured, where BSD reads a global.
;------------------------------------------------------------------------------
; THE CHARACTER DEVICE SWITCH, as kernel C sees it.  UFS 1.13b.
;
; Reno dispatches a device operation through cdevsw[major(dev)]; FGX has one
; major and reaches a character device by INDEX into the chardev registry
; (src/kernel/chardev.s), which is kernel assembly with no vnode path at all
; until now.  These five are that path: spec_vnops.c's VCHR arms, which have
; been a panic naming 1.13 since 1.7b, dispatch through them.
;
; PER BYTE, WHICH IS THE REGISTRY'S OWN SHAPE and not a simplification chosen
; here: _Chardev_Read returns one byte and _Chardev_Write takes one, and
; spec_read and spec_write loop over a uio with them.  A block-at-a-time seam would have to be
; invented at the driver end first, and there is nothing to gain from
; inventing it before a driver that could use it exists.
;
; IOCTL AND SELECT ARE NOT HERE and their arms still panic.  ioctl's argument
; is a pointer into the CALLER's bank and select's is a per-process wait
; record; both need a marshalling decision that read and write do not, and
; making it before a caller exists is how a knob nothing sets gets built.
KSVC_CDLOOKUP           EQU     22  ; A = name offset, Y = name bank (a
                                    ;   NUL-terminated name in the MODULE's
                                    ;   bank) -> C=1 + A.lo = chardev idx,
                                    ;   C=0 + A = ENOENT.  A registry index is
                                    ;   assigned by registration ORDER, so it
                                    ;   is not a constant a caller may bake --
                                    ;   this is how a caller finds one.
KSVC_CDOPEN             EQU     23  ; A.lo = idx -> C=1, or C=0 + A = errno
KSVC_CDCLOSE            EQU     24  ; A.lo = idx -> C=1, or C=0 + A = errno
KSVC_CDREAD             EQU     25  ; A.lo = idx -> C=1 + A.lo = the byte;
                                    ;   C=0 + A = 0 means END OF FILE and
                                    ;   C=0 + A = nonzero is an errno.  Zero is
                                    ;   not a valid errno, which is what lets
                                    ;   one carry carry both answers.
KSVC_CDWRITE            EQU     26  ; A.lo = idx, Y.lo = the byte -> C=1, or
                                    ;   C=0 + A = errno
KSVC_CDDREAD            EQU     27  ; cdevsw d_read.  A = uio OFFSET,
                                    ;   Y = (uio BANK << 8) | chardev idx.
                                    ;   -> C=1, A = (status << 8) | value:
                                    ;      0 = the op ran, low byte its errno
                                    ;      1 = device has NO bulk op; the
                                    ;          caller uses its own per-byte loop
                                    ;      2 = bad index, low byte ENODEV
                                    ;
                                    ; A uio POINTER FITS THE REGISTER ABI:
                                    ; offset (16) + bank (8) + index (8) is
                                    ; A + Y, the way KSVC_RTCFRAME and
                                    ; KSVC_BLKIO already pack.  An earlier cut
                                    ; believed it did not and exported a
                                    ; scraped shim for the module to dispatch
                                    ; through; that put the dispatch on the
                                    ; module's DIRECT PAGE, where the registry
                                    ; pointer reads fcc's register file.
                                    ;
                                    ; A STATUS BYTE, NOT AN errno SENTINEL.
                                    ; ENODEV cannot mean "no bulk op": nodev()
                                    ; in the line-discipline switch returns it,
                                    ; and that switch is where tty bulk reads
                                    ; will route.
KSVC_CDDWRITE           EQU     28  ; cdevsw d_write.  Same shape as CDDREAD.
; KSVC_TTYPGRP / KSVC_TTYSETPGRP - a line's FOREGROUND PROCESS GROUP.
;
; apple/fgx#108 T3 stage 1c moved t_pgrp out of the core kernel's _ttyTable and
; into the TTY BANK's `ttys[]'.  pty.mod writes it (_Pty_SlaveTtyInit and
; _Pty_MaybeReset) and net.mod's pipe.s reads tty[0]'s, and a MODULE CANNOT JSL
; A gen_kernel_exports.py ADDRESS to get at it: those EQUs carry the
; assembly-time bank $02 and the kernel does not run there.  net.s:91 records
; that mistake already made and fixed once.  So it comes through here.
;
; THE ARGUMENT IS THE OLD BYTE OFFSET, not an index, because that is what the
; callers hold -- pty.mod keeps PTYR_TtyOff and pipe.s speaks of tty[0] as
; offset zero.  The core side converts with _Se_TtyOffToIdx.  When PTYR_TtyOff
; becomes an index these lose the conversion and the ABI is unchanged.
;
; THE VALUE TRAVELS IN Y, NOT X: X carries the service number.
KSVC_TTYPGRP            EQU     29  ; A = tty byte offset -> C=1 + A = its
                                    ;   foreground group (0 = none)
KSVC_TTYSETPGRP         EQU     30  ; A = tty byte offset, Y = the group.  C=1.
; KSVC_TTYINTRQUIT - a line's INTERRUPT and QUIT characters, which moved to the
; tty bank with the rest of `t_chars' at T3 stage 2b.  Same argument convention
; as the pair above: A is the old byte offset, because PTYR_TtyOff is what the
; caller holds.  BOTH come back from ONE call because pty.mod's @mw_disc tests
; a byte against both before it enters the ring, and it does that PER BYTE
; WRITTEN TO A PTY MASTER -- a second crossing there is paid per character.
; IT ALSO HANDS BACK THE MODE WORD since stage 2d, in X, and for the same
; reason it hands back both characters at once: `@mw_disc' tests SG_RAW BEFORE
; it tests either character, so a separate flags service would have doubled the
; crossings on the very path this one call exists to keep to one.
KSVC_TTYINTRQUIT        EQU     31  ; A = tty byte offset -> C=1 + A = t_intrc,
                                    ;   Y = t_quitc (both zero-extended),
                                    ;   X = sg_flags
; KSVC_TTYWINSZ - a line's WINDOW SIZE, which moved to the tty bank with the
; rest of `t_winsize' at T3 stage 2c.  Same argument convention as the three
; above: A is the old byte offset, because PTYR_TtyOff is what the caller holds.
;
; ROWS AND COLUMNS TRAVEL PACKED IN ONE REGISTER -- ws_col in the high byte,
; ws_row in the low -- because X carries the service number and A carries the
; line, which leaves Y and nothing else.  That caps what this call can SEED at
; 255 either way; it does not cap the size a line can be SET to, because
; TIOCSWINSZ carries a whole `struct winsize' through `ttioctl' and never comes
; this way.  The one caller seeds the BSD 80x24 default.
KSVC_TTYWINSZ           EQU     32  ; A = tty byte offset,
                                    ;   Y = ws_col << 8 | ws_row.  C=1.
; KSVC_TTYLOPEN / KSVC_TTYMODEM - the LINE DISCIPLINE's `l_open' and `l_modem',
; which a driver in a module has no other way to reach.  T4 increment 2, and
; they are the two calls 2.11BSD's pty driver makes into the discipline around
; a session: `ptsopen' ends with l_open (tty_pty.c:88) and `ptcopen'/`ptcclose'
; bracket it with l_modem 1 and 0 (tty_pty.c:214, :228).
;
; KSVC_TTYLOPEN REPLACES KSVC_TTYOPEN AT ITS ONE CALLER rather than joining it.
; KSVC_TTYOPEN is the session-acquisition block alone; `ttyopen' runs that same
; block through `kc_ttyopen' and then does the rest of the open -- TS_ISOPEN
; above all, which nothing in this kernel had ever set because no open path
; dispatched l_open.  That leaves KSVC_TTYOPEN with NO CALLER -- pty.mod was
; its only one, the virtual consoles reach `_Se_TtyOpen' directly because they
; are core code -- and it stays declared anyway: this file is APPEND ONLY and a
; service number is never reused or renumbered.
KSVC_TTYLOPEN           EQU     33  ; A = tty byte offset -> C=1 + A = errno,
                                    ;   0 = opened.
KSVC_TTYMODEM           EQU     34  ; A = tty byte offset, Y = flag (1 = carrier
                                    ;   up, 0 = carrier lost) -> C=1 + A = 0 if
                                    ;   the line should be turned off.
; KSVC_TTYLCLOSE - the discipline's `l_close' AND `ttyclose', which is the pair
; `ptsclose' calls (tty_pty.c:94-95) and not two ways of spelling one thing.
; T4 increment 3.  Y carries FNDELAY, which FGX's chardev close op has no way
; to know, so its one caller passes 0 -- the ordinary, draining close.
KSVC_TTYLCLOSE          EQU     35  ; A = tty byte offset, Y = flag (FNDELAY)
                                    ;   -> C=1 + A = errno.
; KSVC_TTYPTYOPROC / KSVC_TTYOUTQREAD - T4 increment 4, the pty master's two
; halves of "the output queue is the discipline's, and I am the device".
;
; PTYOPROC is `ptcopen'/`ptcclose's `tp->t_oproc = ptsstart' and `= 0'
; (tty_pty.c:213, :231).  The value is a function IN THE TTY BANK, so only that
; bank can name it.
;
; OUTQREAD is `ptcread's dequeue: it takes runs out of `t_outq' with the same
; `ndqb'/`ndflush' pair `tty_oproc' uses to push them at a device, and MVNs each
; into the caller's buffer.  THE DESTINATION IS NOT AN ARGUMENT because there is
; only one it could be -- `_Sys_CallerBank' and `_Sys_RdBufOff', which is where
; `_Sys_Read' leaves a CDF_RECORD read's buffer and what `_PtyM_Read' parks
; across its sleep (apple/fgx#231).
KSVC_TTYPTYOPROC        EQU     36  ; A = tty byte offset, Y = 1 install / 0
                                    ;   clear.  C=1 + A = errno.
KSVC_TTYOUTQREAD        EQU     37  ; A = tty byte offset, Y = max bytes
                                    ;   -> C=1 + A = bytes delivered.
; KSVC_TTYOUTQUIO - the same dequeue, delivered through a uio, for cdevsw's
; d_read on the /dev vnode route (apple/fgx#198).
;
; ITS ARGUMENTS BREAK THIS BLOCK'S CONVENTION AND THE REASON IS ARITHMETIC.
; The other six tty services take the tty's BYTE OFFSET in A, because
; PTYR_TtyOff is what a caller holds.  This one needs THREE values -- tty, uio
; offset, uio bank -- and a KSVC has A and Y, X being the service number.  A
; tty INDEX is 0..4 and fits in Y's spare byte where a TTY_SIZE-scaled offset
; (up to 1,192) does not, and pty.mod already caches both: PTYR_TtyIdx sits
; beside PTYR_TtyOff in the pair record.
KSVC_TTYOUTQUIO         EQU     38  ; A = uio offset,
                                    ;   Y = (uio bank << 8) | tty INDEX
                                    ;   -> C=1 + A = errno.
; KSVC_TTYOUTQAVAIL - how much the master could take right now, taking nothing.
;
; `ptcread's own wait condition, which is a QUERY and not a dequeue:
; `if (tp->t_outq.c_cc && (tp->t_state&TS_TTSTOP) == 0) break' (tty_pty.c:271).
; The driver needs it separately because the packet-mode prefix is written only
; when there IS data to prefix, so "is there any" has to be answerable without
; consuming the answer.  `ndqb' behind it has no side effect.
KSVC_TTYOUTQAVAIL       EQU     39  ; A = tty byte offset -> C=1 + A = bytes
                                    ;   available now, 0 = none.
; KSVC_TTYSTOPPED - is that line's output stopped?  T4 increment 5b.
;
; `(tp->t_state & TS_TTSTOP) != 0'.  `ptcread' reads the bit off the shared
; `struct tty' (tty_pty.c:271); FGX's driver is a bank away from that struct and
; asks.  It is the OTHER HALF of `ptsstart's packet-mode arm: the driver records
; PF_STOPPED in `ptsstop' and needs "and is it running again?" to turn that into
; the TIOCPKT_START byte.
;
; SEPARATE FROM KSVC_TTYOUTQAVAIL, which tests the same bit: that one answers
; zero for a stopped line AND for an empty one, deliberately, because its caller
; is asking "may I take bytes now".  Merging the two answers cannot serve a
; caller that has to tell them apart, and packing a flag into the count is
; apple/fgx#234's shape.
KSVC_TTYSTOPPED         EQU     40  ; A = tty byte offset -> C=1 + A = 1 stopped
                                    ;   / 0 running.
; KSVC_TTYSELECT - the DISCIPLINE's readiness answer, for a driver's poll op.
;
; `ttyselect(tp, rw)': FWRITE is `t_outq.c_cc <= TTLOWAT(tp)', FREAD is
; `ttnread(tp) > 0'.  `_PtyS_Poll' had been answering POLLOUT from the pty's own
; ring, which T4 increment 4 stopped feeding -- so it said "writable" forever
; while `ttwrite' still slept at the high watermark, which is exactly the
; promise select exists not to break.  A driver asks the queue that holds the
; bytes instead of keeping a second opinion about it.
KSVC_TTYSELECT          EQU     41  ; A = tty byte offset, Y = rw
                                    ;   -> C=1 + A = 1 ready / 0 not.
; KSVC_TTYPTCINPUT - `ptcwrite's inner loop for ONE byte.  T6 increment 4a.
;
; A = the tty BYTE OFFSET (PTYR_TtyOff, what every other tty KSVC takes),
; Y = the byte -> C=1 and A = 1 given to the discipline / 0 the caller must
; block because the queue is at TTYHOG / -1 no such line.
;
; IT REPLACES `_Pty_InPut', not merely wraps it: the master's write feeds the
; line discipline directly now, as vendor/2.11BSD/usr/sys/sys/tty_pty.c:439
; does, so there is no ring between the two halves of a pair.  THE CALLER
; BLOCKS on a 0 -- sleeping in the tty bank would be C asleep inside a module's
; write, and `ttread' is the routine that owns waiting on that queue.
KSVC_TTYPTCINPUT        EQU     42  ; A = tty byte offset, Y = the byte
; KSVC_TTYPTCWRITABLE - would a master's write block?  T6 increment 4a.
;
; A = the tty BYTE OFFSET -> C=1 and A = 1 writable / 0 not.  The exact
; complement of KSVC_TTYPTCINPUT, so `_PtyM_Poll' and `_PtyM_Write' cannot
; disagree about the same queue -- which is what happened when poll read a ring
; write had stopped filling.
KSVC_TTYPTCWRITABLE     EQU     43  ; A = tty byte offset -> C=1 + A = 1/0
; KSVC_TTYREAD / KSVC_TTYWRITE - the DISCIPLINE's `l_read' and `l_write',
; through a uio, for a driver that lives in a MODULE.  apple/fgx#198 (3).
;
; The caller is `ptsread'/`ptswrite', and upstream is one line each:
; `(*linesw[tp->t_line].l_read)(tp, uio, flag)'
; (vendor/2.11BSD/usr/sys/sys/tty_pty.c:136, :156).  The kernel has had that
; door since T3 stage 4 -- `_Tty_Read'/`_Tty_Write' -> `kc_ttread'/`kc_ttwrite'
; -- and what was missing is a way for a module to reach it, which is all these
; two are.  Until they existed a pty slave read through a `/dev' node found no
; `d_read', fell to `spec_chread's PER-BYTE loop, and met no discipline at all.
;
; THE ARGUMENTS ARE KSVC_TTYOUTQUIO'S, PLUS ONE BIT.  A uio needs three values
; -- tty, offset, bank -- and a KSVC has A and Y, X being the service number;
; the tty travels as an INDEX rather than a byte offset for exactly the reason
; stated at KSVC_TTYOUTQUIO.  `flag' is a FOURTH value and there is no fourth
; register, so the one bit of it that exists rides in the index byte's top bit:
; NTTY is 5, so bits 3..7 of that byte are spare, and the arm turns bit 7 back
; into VFS_IO_NDELAY before calling.
;
; PACKING IT BEATS THE ALTERNATIVE, which is for the module to write
; `_Sys_CdFlag' -- a CORE-BANK SINGLETON -- and have the arm read it back.
; `ttread' sleeps, and apple/fgx#89 is what a kernel singleton costs when
; another task reaches it during that sleep.  A value that travels in a register
; is on the caller's own stack before anything can sleep.
KSVC_TTYREAD            EQU     44  ; A = uio offset,
                                    ;   Y = (uio bank << 8)
                                    ;       | (IO_NDELAY ? $80 : 0) | tty INDEX
                                    ;   -> C=1 + A = errno.
KSVC_TTYWRITE           EQU     45  ; the same, for `l_write'.

; KSVC_CDSETTTYIDX - "this chardev IS tty[n]", for a driver in a MODULE.
;
; apple/fgx#108 T7.  `_Chardev_SetTtyOff' is FGX's `cdevsw[].d_ttys' -- BSD
; reaches a tty driver's `struct tty *' through `&cdevsw[major].d_ttys[minor]'
; (2.11BSD conf.c), and with one major and a runtime registry FGX keeps the
; same fact in the registry entry.  `tty_devinit' asks the registry and records
; nothing of its own, so a device the registry does not call a tty gets no
; `struct tty' and `tty_byidx' answers NULL for it forever.
;
; EVERY EXISTING TTY LINE IS REGISTERED BY THE KERNEL, which is why this did
; not exist: the console, both virtual consoles AND both pty slaves go through
; `_Chardev_RegisterInternal' (chardev.s:1197-1249) with the kernel supplying
; the offset -- pty.mod supplies ops, not a registration.  serial.mod registers
; ITSELF, through MOD_REGISTERCHARDEV, so it is the first driver that has to
; say this for itself.  `_Chardev_SetTtyOff's header called this out in
; advance: "the day a MODULE registers a tty chardev, adding the service then
; costs exactly what it costs now" (chardev.s:590-592).
;
; IT TAKES AN INDEX AND NOT AN OFFSET, deliberately.  TTY_SIZE is computed by a
; DUM block, and `_Chardev_TtyIdx' already keeps the matching division on this
; side for that exact reason -- "THE DIVISION, WHICH IS WHERE TTY_SIZE STAYS"
; (chardev.s:699) -- because a caller that restates the stride goes wrong the
; first time a field is added to the entry.  A module cannot include an
; assembly header at all, so it would be restating a number it cannot see.
;
; IT ANSWERS WITH THE BYTE OFFSET, which is not decoration: `KSVC_TTYSELECT'
; and `KSVC_TTYCOOKEDDEF' take a tty BYTE OFFSET, and a module must not compute
; one -- that is the same TTY_SIZE argument this service's own index-not-offset
; input rests on.  pty.mod gets its offset from `PTYR_TtyOff', which the KERNEL
; wrote at registration; a self-registering driver gets it from here.
;
; In:  A = chardev index (as MOD_REGISTERCHARDEV returned it), Y = tty index.
; Out: C=1 + A = the line's `_ttyTable' BYTE OFFSET; C=0 + A = EINVAL if the tty
;      index is out of range.
KSVC_CDSETTTYIDX        EQU     46  ; A = chardev idx, Y = tty index.

; KSVC_TTYIRQINPUT - one ARRIVED character into the line discipline, from a
; driver's RECEIVE INTERRUPT.  apple/fgx#108 T7.
;
; This is 2.11BSD's `(*linesw[tp->t_line].l_rint)(c, tp);' -- dzrint,
; vendor/2.11BSD/usr/sys/pdpuba/dz.c:259 -- reached from a module.
;
; IT IS A KSVC AND NOT AN EXPORTED ADDRESS, and that is not a style choice.
; `gen_kernel_exports.py's `abs24' form emits `$02XXXX': the ASSEMBLY ORG bank,
; not the bank the kernel was relocated into.  Exporting the routine and JSL-ing
; it sent serial.mod into bank $02 -- the machine reached its prompt, nothing
; ever arrived in `t_rawq', and with a reader on the line it took down an
; in-flight `_Chardev_Dispatch'.  The bank-0 gateway is relocation-invariant,
; which is the whole reason it exists.
;
; In:  Y = (tty index << 8) | character.  MX %00.
; Out: C=1 always; A = $FFFF the discipline did not take it (no tty bank, or an
;      unbound line), 1 something was deferred, 0 taken with nothing marked.
KSVC_TTYIRQINPUT        EQU     47  ; Y = (tty idx << 8) | c.
; KSVC_TTYCARRIER - is the CARRIER up on that line?  apple/fgx#266.
;
; A = the tty BYTE OFFSET -> C=1 + A = 1 carrier up / 0 down.  `ptcread' tests
; TS_CARR_ON to decide end of file (vendor/2.11BSD/usr/sys/sys/tty_pty.c:268),
; and a pty master that asked "is a slave open right now" instead reported EOF
; in the window before the first slave open -- where upstream sleeps.
KSVC_TTYCARRIER         EQU     48  ; A = tty byte offset -> C=1 + A = 1/0
; KSVC_CDIOCTL / KSVC_CDPOLL - the character-device switch's d_ioctl and
; d_select, for a MODULE's kernel C.  UFS 1.7d I4.
;
; THE SWITCH ALREADY EXISTED; WHAT WAS MISSING WAS THIS DOOR.  `_Chardev_Ioctl'
; and `_Chardev_Poll' (src/kernel/chardev.s) have dispatched COPS_Ioctl and
; COPS_Poll since T2.  The TTY bank reaches d_ioctl through `_FarSh_CdIoctl'.
; A MODULE could reach neither -- `kc_chardev.s's note says why: a scraped
; kernel address dispatches on the MODULE's direct page, where `_cdTablePtr' is
; fcc's register file and not a table pointer.  So vfs.mod's `spec_ioctl' and
; `spec_select' had nothing to call and panicked instead.
;
; ONLY THE INDEX TRAVELS, AND THAT IS THE ABI RATHER THAN AN OMISSION.
; `_Chardev_Dispatch' passes the op only Y (= minor); cmd and arg reach the op
; through the kernel singletons `_Sys_IoctlCmd', `_Sys_IoctlArgLo' and
; `_Sys_IoctlArgBank', which `_Sys_Ioctl' stages in its FIRST FOUR
; INSTRUCTIONS (syscall.s:3323) -- before the descriptor is classified, so they
; are already this ioctl's cmd and arg by the time any road reaches the op.
; `_Io_CdThenTty' relies on exactly that and re-stages nothing.
;
; THAT IS A DIVERGENCE FROM RENO, WHICH PASSES THEM AS ARGUMENTS:
; `(*cdevsw[major(dev)].d_ioctl)(dev, com, data, fflag)'
; (vendor/4.3BSD-Reno/kern/spec_vnops.c:319).  The upgrade is to widen the
; chardev ioctl ABI to carry cmd/arg on the stack the way COPS_DRead carries
; its uio -- which `far_shims.s' already argues for and which rewrites the
; ioctl entry of pty, serial, tty_tty and null.  Not this increment's.
;
; POLL ANSWERS A MASK, NOT A BOOLEAN.  Reno's d_select takes `which' and
; answers yes/no for that one direction (spec_vnops.c:350); FGX's COPS_Poll
; answers POLLIN|POLLOUT for both in one dispatch, and the caller picks its
; bit.  One dispatch for two questions is the cheaper shape on this machine and
; `spec_select' already reads it that way.
;
; THE INDEX IS STAGED IN `_selCdIdx' BEFORE THE DISPATCH, because at least one
; op reads it rather than taking it from the dispatch: `_Ttyv_Poll' asks which
; line it is polling at ttyv.s:455.  @kc_cdwrite has the same note for
; `_Sys_WrCdIdx' and the same reason -- an op that is not told which device it
; is serving answers for whichever one the last caller named.
KSVC_CDIOCTL            EQU     49  ; A.lo = chardev idx -> C=1, or
                                    ;   C=0 + A = errno.  cmd/arg come from
                                    ;   the _Sys_Ioctl* staging, above.
KSVC_CDPOLL             EQU     50  ; A.lo = chardev idx -> C=1 + A = POLL*
                                    ;   mask (POLLIN and/or POLLOUT)
; THE CALLER'S CREDENTIALS, for the permission checks of UFS campaign 2.6.
; TWO SERVICES RATHER THAN ONE RETURNING A PAIR: `kc_curpid' is the shape these
; follow and it answers in A, and a Y return would need a convention fcc does
; not have on this path.  Two dispatches are cheap and the call sites are few.
;
; EFFECTIVE, NOT REAL.  BSD's access control is on the effective ids; the real
; ones are what access(2) swaps in around its own check (2.11BSD saccess(),
; usr/sys/sys/ufs_syscalls.c:383), which is that syscall's job and not this
; seam's.  A boot-context caller (no u-area) answers 0, exactly as
; `_Sys_GetUid' does for the same case.
;
; DO NOT CACHE THE ANSWER IN A C STATIC, for kc_curpid's reason one screen up
; and one of its own: a uid read before a sleep names a different process
; after one, and setuid(2) can move it under a task that never slept at all.
KSVC_CURUID             EQU     51  ; -> A = effective uid.  C=1.
KSVC_CURGID             EQU     52  ; -> A = effective gid.  C=1.
KSVC_CONBACKEND         EQU     53  ; A = table offset, Y = table bank: the
                                    ;   module's console renderer, five 3-byte
                                    ;   entries (src/kernel/far/console/
                                    ;   console_backend.s).  C=1.
KSVC_UNPNAME            EQU     54  ; an AF_UNIX socket's NAME, bound or looked
                                    ; up.  A = the sockaddr's offset in the
                                    ; caller's bank; _unpNameOp holds UNP_OP_BIND
                                    ; or UNP_OP_LOOKUP and _unpSlot carries the
                                    ; descriptor slot -- in for a bind, out for a
                                    ; lookup.  -> C=1, or C=0 + A = errno.
                                    ;
                                    ; IT IS ONE SERVICE AND NOT TWO because bind
                                    ; and lookup differ only in the walk they ask
                                    ; for; a second slot would be a slot spent on
                                    ; a switch.  The arm copies the path into
                                    ; _Sys_PathBuf and far-calls slot 74, because
                                    ; namei is in vfs.mod, the C that calls it is
                                    ; in the far bank, and a module can reach
                                    ; neither directly.
KSVC_TIME               EQU     55  ; Y = 0 for UTC, 1 for local time -> the
                                    ;   kernel clock's seconds, A = low word,
                                    ;   X = high.  C=1.  The clock itself is
                                    ;   src/kernel/tty/kern_time.c; local is
                                    ;   UTC less resettodr's offset.
KSVC_BANKGRANT          EQU     56  ; -> C=1 + A = a pool bank in no TCB
                                    ;   (Bank_Alloc), which only its holder
                                    ;   frees; C=0 + A = ENOMEM.  ld.mod's
                                    ;   library banks (shared libc SP4).
KSVC_BANKFREE           EQU     57  ; A = a bank KSVC_BANKGRANT gave -> C=1
KSVC_COUNT              EQU     58
SYS_BLKREAD             EQU     MOD_JT_BASE+$16
SYS_BLKWRITE            EQU     MOD_JT_BASE+$1A
SYS_BLKSTATUS           EQU     MOD_JT_BASE+$1E
SYS_CONPUTCHAR          EQU     MOD_JT_BASE+$22 ; A=char
SYS_CONWRITEROW         EQU     MOD_JT_BASE+$26 ; slot 8: UNIMPLEMENTED (halts)
SYS_PATHRESOLVE         EQU     MOD_JT_BASE+$2A ; slot 9:  RETIRED (halts)
SYS_FCBALLOC            EQU     MOD_JT_BASE+$2E ; slot 10: RETIRED (halts)
SYS_FCBFREE             EQU     MOD_JT_BASE+$32 ; slot 11: RETIRED (halts)
MOD_REGISTERFST         EQU     MOD_JT_BASE+$36
MOD_REGISTERCONSOLE     EQU     MOD_JT_BASE+$3A
MOD_REGISTERINPUT       EQU     MOD_JT_BASE+$3E
MOD_REGISTERSOUND       EQU     MOD_JT_BASE+$42
SYS_KERNLOG             EQU     MOD_JT_BASE+$46
SYS_PANIC               EQU     MOD_JT_BASE+$4A
SYS_BMENSUREVOL         EQU     MOD_JT_BASE+$4E ; slot 18: RETIRED (halts)
SYS_FSDIRENTRY2STAT     EQU     MOD_JT_BASE+$52 ; slot 19: RETIRED (halts)
SYS_FSFILLMOUNTSLOT     EQU     MOD_JT_BASE+$56 ; slot 20: RETIRED (halts)
SYS_BMFREE              EQU     MOD_JT_BASE+$5A ; slot 21: RETIRED (halts)
SYS_BMALLOC             EQU     MOD_JT_BASE+$5E ; slot 22: RETIRED (halts)
; THE SEVEN `RETIRED' ROWS ABOVE, plus slot 8, are the ProDOS filesystem ABI.
; Each named a thin kernel wrapper that a module JSL'd into the driver behind;
; prodos.mod was the only caller of any of them and it is gone (apple/fgx#344).
; The EQUs stay because the slot NUMBERS are the ABI -- closing a gap would
; renumber every slot after it -- and each now reaches _Phase1_StubHalt, so a
; stale caller halts with a red border instead of running the wrong routine.
MOD_REGISTERCHARDEV     EQU     MOD_JT_BASE+$62 ; chardev registry -- see
                                            ;   src/kernel/jumptable.s.  Entry:
                                            ;   MX %00; A = name ptr, X = COPS
                                            ;   ptr, both relative to the
                                            ;   caller's PROGRAM bank;
                                            ;   Y.lo = minor, Y.hi = CDF_* flags.
                                            ;   Returns C=1 + A = chardev idx;
                                            ;   C=0 + A = ENOSPC if registry full.
SYS_MODLOG              EQU     MOD_JT_BASE+$66 ; slot 24 (reused retired
                                            ; SYS_INSTALL_SCC_IRQ tombstone):
                                            ; X = bank-rel detail string ptr;
                                            ; kernel emits "<curmod>: <detail>".

; --- SIM (Serial Interrupt Manager) — see src/kernel/sim.s, spec
; docs/superpowers/specs/2026-05-27-fgx-sim-kernel-lift-design.md ---
SYS_SIM_INSTALL         EQU     MOD_JT_BASE+$6A ; slot 25: install SCC IRQ handler
SYS_SIM_REMOVE          EQU     MOD_JT_BASE+$6E ; slot 26: remove SCC IRQ handler

; --- slots 27-31: net.mod direct kernel-call wrappers.  Was baked-$02
; `JSL _Net_KCall_*` in net.s/net_xport.s; routed through bank-0 JT slots for
; the relocatable kernel.  Targets = RTL wrappers in net_dispatch.s. ---
SYS_NETKC_W5WRITEIP     EQU     MOD_JT_BASE+$72 ; slot 27
SYS_NETKC_FCBALLOC      EQU     MOD_JT_BASE+$76 ; slot 28
SYS_NETKC_SOCKFDTODESC  EQU     MOD_JT_BASE+$7A ; slot 29
SYS_NETKC_CONPOLLKEY    EQU     MOD_JT_BASE+$7E ; slot 30
SYS_NETKC_SLEEP         EQU     MOD_JT_BASE+$82 ; slot 31

; Errno values for SIM install/remove (returned in A on C=0).
ESIM_DUP                EQU     1           ; mask collides with existing entry
ESIM_FULL               EQU     2           ; handler table full
ESIM_ATALK              EQU     3           ; AppleTalk owns this port
ESIM_ROMUNSUPPORTED     EQU     4           ; ROM 0 — not supported
ESIM_NOENT              EQU     5           ; remove: no matching entry
ESIM_GONE               EQU     6           ; SYS_INSTALL_SCC_IRQ tombstone

;------------------------------------------------------------------------------
; Vtable type tags — used by modules' vtable directory + by core's
; _Mod_Register* dispatch.  Phase 1 declares them; Phase 2+ wires them up.
;------------------------------------------------------------------------------
VT_END                  EQU     $0000       ; directory terminator
VT_FST                  EQU     $0001
VT_CONSOLE              EQU     $0002
VT_INPUT                EQU     $0003
VT_SOUND                EQU     $0004
VT_BLOCKDEV             EQU     $0005
VT_HELLO                EQU     $0006       ; Phase 2a HELLO test module
VT_CHARDEV              EQU     $0007       ; character device (serial, tty, …) —
                                            ; module exports CharDev_Ops vtable;
                                            ; see include/chardev.s.
VT_NET                  EQU     $0008       ; networking stack (net.mod) — module
                                            ; exports a net_op_table (3-byte FOP-
                                            ; style long-ptrs); kernel dispatches
                                            ; via _Net_Dispatch (net_dispatch.s).
VT_PDCORE               EQU     $000B       ; prodos.mod's C entry points, for
                                            ;   prodosw.mod, the write half
                                            ;   (ProDOS FST P6) -- PDCORE_* below
VT_UFSCORE              EQU     $000A       ; ufs.mod's C entry points, for
                                            ;   ufsprobe.mod (UFS 1.12c) -- see
                                            ;   UFSCORE_* below
VT_VFSCORE              EQU     $0009       ; vfs.mod's C entry points, for
                                            ; ANOTHER MODULE rather than for the
                                            ; kernel -- the first vtable used in
                                            ; that direction (apple/fgx#169).
                                            ; The table is VFSCORE_* below: plain
                                            ; 16-bit offsets into vfs.mod's bank,
                                            ; not FOP-style long pointers,
                                            ; because the bank comes back from
                                            ; Mod_FindVtable and repeating it per
                                            ; entry is a second copy that can
                                            ; drift.

;------------------------------------------------------------------------------
; VFSCORE table offsets (byte offsets into vfs.mod's vfscore_ops, 2 apiece).
;
; THESE ARE fcc ENTRY POINTS AND ARE CALLED WITH fcc's CONVENTION -- arguments
; pushed on the stack, RTL-terminated, DBR = vfs.mod's bank.  The importing
; module's shims are what establish that; see src/modules/ufs/vfs_import.s,
; which is the only caller and documents the whole seam.
;
; The set is deliberately SMALL and is the actual dependency of the UFS code,
; measured by reading its externs rather than guessed: the buffer cache four,
; plus the two vnode helpers the on-target probe needs.  Adding to it is adding
; to an ABI two modules agree on, so it wants the same care as a syscall.
;------------------------------------------------------------------------------
VFSCORE_Bread           EQU     0           ; bread(vp, blkno, bpp) -> errno
VFSCORE_Bwrite          EQU     2           ; bwrite(bp) -> errno
VFSCORE_Brelse          EQU     4           ; brelse(bp)
VFSCORE_Getblk          EQU     6           ; getblk(vp, blkno) -> struct buf *
VFSCORE_Bdevvp          EQU     8           ; bdevvp(dev, vpp) -> errno
VFSCORE_Vrele           EQU     10          ; vrele(vp)
VFSCORE_Getnewvnode     EQU     14          ; getnewvnode(tag, mp, vops, vpp)
                                            ; -- added at 1.11a with iget
VFSCORE_Vget            EQU     16          ; vget(vp) -- likewise
VFSCORE_Vref            EQU     12          ; vref(vp) -- added at 1.8a: a mount
                                            ; holds its own reference on the
                                            ; device vnode, so ufs_unmount's
                                            ; vrele has one of its own to drop
VFSCORE_Uiomove         EQU     18          ; uiomove(cp, n, uio) -> errno --
                                            ; added at 1.11b: ufs_read is the
                                            ; first thing in ufs.mod that moves
                                            ; bytes, and kern_subr.c is vfs.mod's
VFSCORE_Biodone         EQU     20          ; biodone(bp) -- likewise, and only
                                            ; for the HOLE: ufs_strategy issues
                                            ; no I/O for an unallocated block, so
                                            ; it has to complete the buffer
                                            ; itself or bread's biowait never
                                            ; sees B_DONE
VFSCORE_Vinvalbuf       EQU     22          ; vinvalbuf(vp, save) -- added at
                                            ;   UFS 1.12b.  itrunc frees blocks
                                            ;   the buffer cache may still hold
                                            ;   under the FILE's logical
                                            ;   numbers; leaving them would let
                                            ;   a read after a truncate-then-
                                            ;   grow hit a cached buffer whose
                                            ;   block now belongs to another
                                            ;   file.  Reno's itrunc calls it in
                                            ;   the same place.
VFSCORE_Vgone           EQU     24          ; vgone(vp) -- added at UFS 1.12b.
                                            ;   ufs_inactive frees an inode
                                            ;   whose link count reached zero
                                            ;   and must then get the vnode off
                                            ;   the inode hash IMMEDIATELY:
                                            ;   left there with i_mode 0 it is
                                            ;   what ufs_ihashget hands back
                                            ;   when the number is reallocated.
                                            ;   Reno's ufs_inactive calls it in
                                            ;   the same two places.
; THE WALK ITSELF, added when namei learned to follow symlinks: the UFS probe
; drives a real path resolution over a real symlink, and namei and its slot
; allocator both live here.  ndslot returns a POINTER, which the shims carry
; the same way getblk's already does.
VFSCORE_Namei           EQU     26          ; namei(ndp) -> errno
VFSCORE_Ndslot          EQU     28          ; ndslot(pid, which) -> nameidata *
; THE DEVICE SWITCH AS THE FILESYSTEM SEES IT, added at UFS 1.13a.  A device
; file has an INODE and a DEVICE, and neither module owns both: the inode
; operations are ufsdir.mod's and the device operations are vfs.mod's, so the
; vnodeops vector a device file wears -- spec_inodeops -- is built in ufsdir.mod
; out of its own entries and these.  4.3BSD-Reno spells the same split with the
; same table (ufs/ufs_vnops.c:125) and for the same reason; there it costs
; nothing because both halves are one link.
;
; TEN AT ONCE IS MORE THAN THIS TABLE HAS EVER GROWN, and the alternative was
; worse: building spec_inodeops in vfs.mod instead needs ELEVEN entries going
; the other way, and there is no other way -- nothing crosses from vfs.mod into
; ufsdir.mod today, so it would mean a second vtable, a second resolver and a
; direction the bank split was measured to avoid.
VFSCORE_Checkalias      EQU     30          ; checkalias(nvp, rdev, mp) ->
                                            ;   struct vnode * -- iget's, and
                                            ;   the only one of these ufs.mod
                                            ;   rather than ufsdir.mod imports
VFSCORE_SpecLookup      EQU     32          ; spec_lookup(vp, ndp)
VFSCORE_SpecOpen        EQU     34          ; spec_open(vp, mode, cred)
VFSCORE_SpecClose       EQU     36          ; spec_close(vp, flag, cred)
VFSCORE_SpecRead        EQU     38          ; spec_read(vp, uio, ioflag, cred)
VFSCORE_SpecWrite       EQU     40          ; spec_write(vp, uio, ioflag, cred)
VFSCORE_SpecIoctl       EQU     42          ; spec_ioctl(vp, com, data, fflag,
                                            ;   cred)
VFSCORE_SpecSelect      EQU     44          ; spec_select(vp, which, fflags,
                                            ;   cred)
VFSCORE_SpecBmap        EQU     46          ; spec_bmap(vp, bn, vpp, bnp)
VFSCORE_SpecStrategy    EQU     48          ; spec_strategy(bp)
VFSCORE_Vcount          EQU     52          ; vcount(vp) -> int -- how many
                                            ;   references exist to the
                                            ;   DEVICE, summed across every
                                            ;   vnode naming it.  1.13a's probe
                                            ;   asserts it; spec_close has used
                                            ;   it since 1.7b
VFSCORE_SpecBadop       EQU     50          ; spec_badop() -- the slot filler
                                            ;   for an operation that is
                                            ;   MEANINGLESS on a device, and it
                                            ;   is imported rather than
                                            ;   open-coded because it PANICS:
                                            ;   spec_vnops.c's header is
                                            ;   careful that badop, ebadf and
                                            ;   nullop are three different
                                            ;   answers, and a local stand-in
                                            ;   would make the two spec tables
                                            ;   disagree about which one this
                                            ;   is
; THE FILE/VNODE GLUE, added at UFS 1.7c.  These are what a syscall layer calls
; and what 1.7c's probe drives from ufsprobe.mod.  vn_open needs namei, which is
; already here, and the rest need a `struct file` -- which the probe builds on
; its own stack rather than importing falloc, because 1.7c is about the glue and
; 1.7d is what makes the allocator part of the path.
VFSCORE_VnOpen          EQU     54          ; vn_open(ndp, fmode, cmode) -> errno
VFSCORE_VnRead          EQU     56          ; vn_read(fp, uio) -> errno
VFSCORE_VnWrite         EQU     58          ; vn_write(fp, uio) -> errno
VFSCORE_VnClose         EQU     60          ; vn_close(fp) -> errno
VFSCORE_VnRdwr          EQU     62          ; vn_rdwr(rw, vp, base, len, offset,
                                            ;   segflg, ioflg, cred, aresid)
VFSCORE_VnWritechk      EQU     64          ; vn_writechk(vp) -> errno -- the
                                            ;   probe drives it directly
                                            ;   because vn_open reaches only
                                            ;   its permitted arm
; THE LAST TWO vnops TARGETS -- UFS 1.7d I2b.  The descriptor layer that used
; to be exported here (vfs_open/read/write/lseek, falloc, ufalloc, getf,
; closef, fdrelease, fdbase) IS NOT IN vfs.mod ANY MORE: Mod_LoadConf opens
; files through _Fcb_Alloc and Mod_LoadConf is what loads vfs.mod, so the file
; table moved to the far kernel bank where it exists before any module does.
; Nothing crosses for it now, so nothing is exported for it.
;
; What remains is the vnode layer, which really is the filesystem's.  `vnops`
; lives in the far bank with the code that dispatches through it, and these two
; complete the five targets its entries name.
VFSCORE_VnIoctl         EQU     66          ; vn_ioctl(fp, com, data) -> errno
VFSCORE_VnSelect        EQU     68          ; vn_select(fp, which) -> errno
; vn_open is the syscall layer's way in; vn_getattr is VOP_GETATTR performed on
; THIS side, by vfs_vnops.c's rule that a VOP_ is dispatched in the module that
; owns the vnode layer.
VFSCORE_VnGetattr       EQU     70          ; vn_getattr(vp, vap) -> errno
; THE /dev MOUNT'S ROOT, HELD UNLOCKED -- UFS 1.7d I3.
;
; It is vfs.mod's job and not the far bank's: VFS_ROOT and VOP_UNLOCK are
; dispatched beside the vput its refusal arm needs, and the far bank hands the
; mount over.
VFSCORE_DevRoot         EQU     72          ; vfs_devroot(mp) -> errno; holds
                                            ;   the mount's root UNLOCKED for
                                            ;   namei's ni_rdir
; ureadc(c, uio) -> errno.  apple/fgx#108 T3's ttread, and T4's tty_pty.c,
; which calls it four times.  IT LIVES HERE RATHER THAN IN THE TTY BANK for
; that second reason and for the one kern_subr.c already gave when it reserved
; the spot: BSD puts ureadc in kern_subr.c beside uiomove, and a line
; discipline in one bank plus a pty driver in a module both need it.
VFSCORE_Ureadc          EQU     74          ; ureadc(c, uio) -> errno
; UNMOUNT'S TWO HALVES, and they are exported to DIFFERENT callers.  UFS
; 1.8b-3c.
;
; vflush goes to ufs.mod, because that is where 4.3BSD-Reno calls it from:
; `ufs_unmount' opens with `if (error = vflush(mp, NULLVP, flags)) return
; (error);', so the FILESYSTEM decides whether its vnodes may be taken away.
; Moving it up into vfs_dounmount would have been free -- both live in vfs.mod
; -- and would have made flush policy the VFS's for every filesystem, which is
; not upstream's shape and not a decision one filesystem should settle.
;
; vfs_dounmount goes to the FAR BANK, because what follows the check is this
; module's: cache_purgevfs's table, vrele of the covered vnode, and the
; VFS_UNMOUNT beside them.  unmount(2) resolves the path and checks it named a
; mount root; the module does the rest.
VFSCORE_Vflush          EQU     76          ; vflush(mp, skipvp, flags) -> errno
VFSCORE_Dounmount       EQU     78          ; vfs_dounmount(mp, flags) -> errno
; THE ROOT OF THE NAMESPACE, UFS campaign 2.4b.  `rootdir' is vfs.mod's DATA
; (vfs_lookup.c), so the far bank could not store the answer.  The far bank
; mounts the boot volume and hands the mount over; vfs.mod finds its root,
; unlocks it, and keeps it.
VFSCORE_SetRoot         EQU     80          ; vfs_setroot(mp) -> errno
; listdir(2)'s WHOLE BODY.  namei, ndslot and vrele are all this module's and
; VOP_READDIR is dispatched here, so a body in the far bank would cross the seam
; once per directory BLOCK; here it crosses once, on the way in.  Measured, too:
; in the far bank it was 1,353 bytes against 697 free.
VFSCORE_VfsListdir      EQU     82          ; vfs_listdir(pid, path, buf, size)
                                            ;   -> bytes written, or -errno
; THE PROCESS'S WORKING DIRECTORY, as a VNODE.  UFS campaign, the cwd port --
; Reno's u.u_cdir, which namei's relative arm has always read (`dp =
; ndp->ni_cdir') and nothing in this tree ever set.  It lives in vfs.mod beside
; `rootdir' and namei; the far bank ASKS rather than keeping a copy, which is
; the distinction root_mount.c:185 draws when it declines to copy rootdir
; across the seam (apple/fgx#114).
VFSCORE_Cdir            EQU     84          ; vfs_cdir(pid) -> struct vnode *
                                            ;   (rootdir when nothing chosen)
VFSCORE_Chdir           EQU     86          ; vfs_chdir(pid, path) -> 0 or errno
VFSCORE_Cdirinit        EQU     88          ; vfs_cdirinit() -- zero the table
; vput BESIDE vrele, added when the far bank's namei callers started asking for
; LOCKLEAF (apple/fgx#294).  It is not a convenience over the vrele two entries
; up: vput is VOP_UNLOCK followed by vrele, the release upstream makes, and a
; far-bank caller that holds a LOCKED vnode lets go of it through this slot.
; The alternative is not asking for the lock -- which is the defect.
VFSCORE_Vput            EQU     90          ; vput(vp) -- VOP_UNLOCK + vrele
; The cwd's other two lifetime events, which chdir alone cannot cover: a child
; must take a reference on what it inherits and a dying process must give its
; own back.  Reno does both in the u-area (kern_fork.c:272, kern_exit.c:139);
; this table is pid-indexed, so each has to be told which slots.
VFSCORE_CdirFork        EQU     92          ; vfs_cdirfork(ppid, cpid)
VFSCORE_CdirExit        EQU     94          ; vfs_cdirexit(pid)
; apple/fgx#318's second half: the namespace operations the legacy resolver
; used to own.  They are vfs.mod's because their walks are namei, ndslot, vput
; and vrele, and VOP_REMOVE/MKDIR/RMDIR are dispatched beside them.
VFSCORE_Unlink          EQU     96          ; vfs_unlink(pid, dvp, path) -> errno
VFSCORE_Mkdir           EQU     98          ; vfs_mkdir(pid, dvp, path, mode)
VFSCORE_Rmdir           EQU     100         ; vfs_rmdir(pid, dvp, path) -> errno
; APPENDED, never inserted: a slot number is ABI and the ten dead Spec slots
; above are dead precisely so nothing below them moved.  ufsdir.mod hands the
; device-vnode ops table over from its mod_init now that spec_vnops.c lives
; there; vfs_subr.c's bdevvp and checkalias refuse until it has.
VFSCORE_Setspecops      EQU     102         ; vfs_setspecops(vnodeops *)
; ...and the four the DEVICE VNODE OPS need now that spec_vnops.c is ufsdir's.
; They were same-bank calls while it lived here; they are the seam now, and
; they are APPENDED for the reason the ten dead Spec slots above were kept.
VFSCORE_Bawrite         EQU     104         ; bawrite(bp) -> errno
VFSCORE_Bdwrite         EQU     106         ; bdwrite(bp)
VFSCORE_Vflushbuf       EQU     108         ; vflushbuf(vp, flags)
VFSCORE_BioStrategy     EQU     110         ; bio_strategy(bp)
; rename(2)'s body -- ported at last, the bank having had 267 bytes free and
; rename needing 783.  APPENDED, like everything since the Spec slots died.
VFSCORE_Rename          EQU     112         ; vfs_rename(pid,fdvp,from,tdvp,to)
; symlink(2).  APPENDED, like everything since the Spec slots died.
; readlink's slot came back the day after it came out: the wrapper that failed
; took a VNODE across the seam; this one is vfs_listdir's shape exactly.
VFSCORE_Symlink         EQU     114         ; vfs_symlink(pid,dvp,path,target,mode)
VFSCORE_Readlink        EQU     116         ; vfs_readlink(pid,path,buf,count)
; statfs(2) and the half getfsstat(2) shares with it (apple/fgx#329).  BOTH are
; vfs.mod's: statfs walks with namei, ndslot and vrele, and both copy out with
; uio_copy.  The mount-list WALK stays in the far bank beside the list; only the
; per-mount half crosses.  APPENDED, like everything since the Spec slots.
VFSCORE_Statfs1         EQU     118         ; vfs_statfs1(mp, sbp) -> errno
VFSCORE_Statfs          EQU     120         ; vfs_statfs(pid, path, sbp) -> errno
; chmod(2) and chown(2), UFS 2.6.  ONE SLOT FOR BOTH, because Reno's two
; syscalls are the same seven lines with a different vattr field set -- see
; vfs_setattr's header.  It is here rather than in the far bank because its
; walk is namei, ndslot and vrele and its fill is vattr_null, all this module's.
; APPENDED, like everything since the Spec slots -- a slot number is ABI.
VFSCORE_Setattr         EQU     122         ; vfs_setattr(pid,path,follow,
                                            ;             mode,uid,gid) -> errno
; link(2), UFS 2.6.  Here for its two walks -- namei, ndslot, vrele -- and the
; VOP_LINK dispatched beside them.  APPENDED.
VFSCORE_Link            EQU     124         ; vfs_link(pid,target,linkname)
; sync(2), apple/fgx#332.  The per-mount VFS_SYNC is this module's and the
; WALK stays in the far bank beside the mount list -- getfsstat's split
; exactly.  APPENDED.
VFSCORE_Sync1           EQU     126         ; vfs_sync1(mp) -> errno
; ftruncate(2), UFS 2.7.  VOP_SETATTR performed on this side, by
; VFSCORE_VnGetattr's rule.  It takes a SIZE rather than a vattr because `vattr_null' is this
; module's, beside the structure it fills; see vn_setsize.  APPENDED.
VFSCORE_VnSetsize       EQU     128         ; vn_setsize(vp, length) -> errno
; fchdir(2), UFS 2.7.  Here because `cdir_vp' is vfs.mod's data and
; vref/vrele are its functions -- chdir(2)'s reason exactly.  The far bank
; owns the descriptor half and hands the vnode over.  APPENDED.
VFSCORE_Fchdir          EQU     130         ; vfs_fchdir(pid, vp) -> errno
; vn_access(vp, fmode) -> errno.  UFS 2.6, access(2)'s per-bit half.  It lives
; in vfs.mod because it needs the VOP_ACCESS dispatch AND vn_writechk, both of
; which are there; the far bank resolves the name and calls in.
;
; THE FIRST ENTRY PAST THE ORIGINAL 66, so the count grows with it.  That costs
; two bytes in each of _ufsImp, _upVImp and _udVImp (all `DS VFSCORE_COUNT*2')
; and shifts nothing else: the offsets are absolute and every consumer is
; rebuilt from this header.
VFSCORE_VnAccess        EQU     132
; vfs_setcacheops(cacheops *).  The name cache's handover, and it points the
; way vfs_setspecops does -- INTO this module, from ufsdir.mod, which owns the
; cache since it was wired into ufs_lookup.  vfs.mod keeps the two rare callers
; (getnewvnode mints a capability number, unmount drops a filesystem's entries)
; and neither can name a function in another bank, so ufs_dirinit hands over a
; table of the two and vfs_subr.c dispatches through it.  APPENDED.
VFSCORE_Setcacheops     EQU     134
; THE securelevel TRIO, apple/fgx#410.  The variable lives in vfs_subr.c
; because both of its customers already import from here and neither can reach
; the other: spec_open is ufsdir.mod's (it is the only place that sees a device
; vnode, a write mode and a device number together), and sysctl(2)'s body is
; the FAR KERNEL BANK's.  APPENDED.
;
; spec_securechr ANSWERS THE WHOLE QUESTION rather than handing back the level,
; so the level itself never crosses a bank on the hot path -- an open of any
; character device asks once and gets an errno.
VFSCORE_SpecSecurechr   EQU     136         ; spec_securechr(dev) -> 0 or errno
VFSCORE_GetSecurelevel  EQU     138         ; vfs_getsecurelevel() -> int
VFSCORE_SetSecurelevel  EQU     140         ; vfs_setsecurelevel(level) -> 0 or
                                            ;   errno
; bflush(dev), apple/fgx#398.  ufs_sync's last act, where 4.3BSD-Reno flushes
; the mount's device vnode: this tree has no per-mount vnode list, so the
; delayed writes are found by DEVICE in the buffer pool instead.  APPENDED.
VFSCORE_Bflush          EQU     142         ; bflush(dev)
; exec(2)'s two permission tests, UFS 2.6/apple/fgx#416.  It returns an ERRNO
; and takes no vattr, which is VFSCORE_VnSetsize's rule above and is here for a
; measured reason as well: VOP_GETATTR reached from Load_Binary's context with
; a far-bank vattr corrupts a live pty session (apple/fgx#417), while
; VOP_ACCESS from the same place is safe any number of times.  Keeping both
; tests -- and the structure they fill -- on vfs.mod's side of the seam costs
; one slot and hands the far bank a single int.
VFSCORE_VnExecchk       EQU     144
; ...and whose credentials it runs with, one id per call (0 = uid, 1 = gid),
; answering -1 for "no change".  An int and not a pair, for VFSCORE_VnExecchk's
; reason one line up.
VFSCORE_VnExecsugid     EQU     146
; mount(2)'s TYPE SWITCH, Reno's `vfssw[]'.  The table is here because its
; writers are modules and a module cannot reach the far bank: each filesystem's
; mod_init hands its row to vfs_setvfsops, vfs_setspecops's shape, and the far
; bank's vfs_mountat reads one with vfs_getvfsops and dispatches VFS_MOUNT
; itself.  APPENDED.
VFSCORE_Getvfsops       EQU     148         ; vfs_getvfsops(type) -> vfsops *
VFSCORE_Setvfsops       EQU     150         ; vfs_setvfsops(type, ops) -> errno
; vattr_null(vap), Reno's VATTR_NULL.  ufs.mod's fchmod(2)/fchown(2) half,
; kern_fsetattr.c, fills a vattr for VOP_SETATTR, and the fill must reach every field, so it is
; the one here rather than a copy.  APPENDED.
VFSCORE_VattrNull       EQU     152         ; vattr_null(vap)

VFSCORE_COUNT           EQU     77

; UFSCORE_* -- ufs.mod's exported C entry points, indexed into the table
; ufsprobe.mod copies out of VT_UFSCORE.  Added at UFS 1.12c.
;
; THE PROBES LEFT THE MODULE THEY TEST, and this table is what lets them.
; ufs.mod's shipping code reached 50,992 bytes of a 65,536-byte bank at 1.12c
; and two of the three probe gates stopped fitting beside it; splitting a gate
; again would have bought one increment.  So the probes went to their own bank
; and reach back through here, which is the arrangement vfs.mod and ufs.mod
; already have and which stops test code competing with shipping code for
; good.
;
; CHOSEN BY READING THE PROBES' externs, not by guessing what a filesystem
; ought to export -- the same rule vfs.mod's table records for itself.  Every
; VOP_ and VFS_ call the probes make goes through a vector instead, whose
; entries carry the callee's bank since apple/fgx#178, so none of them needs
; an entry here.
UFSCORE_Iget            EQU     0           ; iget(mp, ino, ipp) -> errno
UFSCORE_Iput            EQU     2           ; iput(ip)
UFSCORE_Balloc          EQU     4           ; ufs_balloc(devvp, sb, resultbno) -> errno
UFSCORE_Bfree           EQU     6           ; ufs_bfree(devvp, sb, bno) -> errno
UFSCORE_Bmap            EQU     8           ; ufs_bmap(devvp, addr, lbn, resultbno)
UFSCORE_Dget32          EQU     10          ; ufs_dget32(b, off) -> long
UFSCORE_Ialloc          EQU     12          ; ufs_ialloc(devvp, sb, resultino)
UFSCORE_Ifind           EQU     14          ; ufs_ifind(dev, ino) -> struct inode *
UFSCORE_Ifree           EQU     16          ; ufs_ifree(sb, ino)
UFSCORE_Itrunc          EQU     18          ; ufs_itrunc(oip, length, flags, countp)
UFSCORE_Mountfs         EQU     20          ; ufs_mountfs(devvp, mp, ump)
UFSCORE_Sbdecode        EQU     22          ; ufs_sbdecode(b, sb)
UFSCORE_Sbencode        EQU     24          ; ufs_sbencode(sb, b)
UFSCORE_Sbread          EQU     26          ; ufs_sbread(devvp, sb, blk)
UFSCORE_Sbupdate        EQU     28          ; ufs_sbupdate(devvp, sb)
UFSCORE_Sbvalid         EQU     30          ; ufs_sbvalid(sb, volblocks)
UFSCORE_KernTime        EQU     32          ; kern_time() -> long
; THE UFS BANK SPLIT.  ufs.mod's shipping code reached 60,211 bytes of
; its 65,536 with 1.13 and 2.6 still ahead, so the filesystem's own two halves
; separated: the BLOCK layer (inodes, the superblock, the allocators, bmap)
; stayed, and the NAME layer (the vnode ops and the directory scan) became
; ufsdir.mod.  These six entries are what the name half calls back.  The seam
; was chosen by measuring the call graph, not by subject: 42 call sites cross
; it in this direction and ZERO in the other.
UFSCORE_Clrbuf          EQU     34          ; clrbuf(bp)
UFSCORE_Iupdat          EQU     36          ; iupdat(ip, waitfor) -> errno
UFSCORE_Bmapx           EQU     38          ; ufs_bmapx(...7 args...) -> errno
UFSCORE_Ifmttovt        EQU     40          ; ufs_ifmttovt(mode) -> enum vtype
UFSCORE_Itimes          EQU     42          ; ufs_itimes(ip)
; ...and this one goes the other way in spirit: the NAME half owns the vnodeops
; table, and hands it over once at its own mod_init.  iget refuses until it
; has, because a null table is dispatched through on the first VOP_ call.
UFSCORE_Setvnodeops     EQU     44          ; ufs_setvnodeops(vnodeops *)
; ...and one entry that exists for a DATA cell rather than a call site.  The
; vnodeops table is in the name half and every slot in it must be a symbol that
; half can name; ufs_reclaim is inode lifecycle and stayed with the inodes.  The
; generated shim carries the name, so the table's cell points at the shim and
; the shim pile-calls across -- which is what a vector entry does anyway.
UFSCORE_Reclaim         EQU     46          ; ufs_reclaim(vp) -> errno
; THE DEVICE NUMBER OF A SPECIAL FILE, added at UFS 1.13a.  It lives in
; di_addr[0] -- inode.h derives exactly where, from both upstream sources --
; and these two are the only code that knows it.  They are exported rather than
; open-coded on the far side precisely so that stays true: the block half owns
; the on-disk representation (ufs_idecode and ufs_iencode are there), and a
; second copy of the derivation in the name half is a second place to get the
; PDP-11 word order wrong.
UFSCORE_Getrdev         EQU     48          ; ufs_getrdev(ip) -> dev_t
UFSCORE_Setrdev         EQU     50          ; ufs_setrdev(ip, dev)
UFSCORE_Setspecops      EQU     52          ; ufs_setspecops(vnodeops *)
; ufs_mount(mp, path, data, ndp) -> errno.  NO IMPORTER: mount(2) reaches
; ufs_mount through vfssw[] and VFS_MOUNT instead.  The slot stays
; because a slot number is ABI and UFSCORE_Fsync follows it.
UFSCORE_Mount           EQU     54          ; ufs_mount(mp, path, data, ndp)
; fsync(2)'s one descriptor, UFS 2.8 / apple/fgx#355.  `sync(2)' has reached
; the inodes since apple/fgx#332 -- vfs_sync -> vfs_sync1 -> VFS_SYNC ->
; ufs_sync -> ufs_iflushall -- but there was no path to ONE of them, so
; fsync(2) answered EIO out of the ProDOS FST and forced nothing.  The far
; bank calls the ported `ufs_fsync' rather than repeating its three lines,
; and reaches it through ufs.mod's one-line ufs_fsyncvp, because ufsdir.mod,
; where ufs_fsync lives, exports nothing by design.
UFSCORE_Fsync           EQU     56          ; ufs_fsync(vp, fflags, cred, waitfor)
; flock(2), kern_flock.c, in this bank because vfs.mod is full.  The far bank
; calls vn_flock from vfs_flock, and vn_unlock from closef to drop a lock with
; a file's last reference (2.11BSD kern_descrip.c:359).
UFSCORE_VnFlock         EQU     58          ; vn_flock(fp, how) -> errno
UFSCORE_VnUnlock        EQU     60          ; vn_unlock(fp, kind) -> 0
; fchmod(2) and fchown(2) past the descriptor lookup, kern_fsetattr.c, here
; for flock's reason.
UFSCORE_VnFsetattr      EQU     62          ; vn_fsetattr(fp, mode, uid, gid)
                                            ;   -> errno
UFSCORE_COUNT           EQU     32

;------------------------------------------------------------------------------
; PDCORE_* -- prodos.mod's exported C entry points, indexed into the table
; prodosw.mod copies out of VT_PDCORE.  ProDOS FST P6, when the write half
; left for a bank of its own: every one is a node-layer function the write
; half calls, and pd_setwriteops is how the write half's entry points reach
; prodos.mod's vector.  Plain 16-bit offsets, VT_UFSCORE's form.
;------------------------------------------------------------------------------
PDCORE_Pdget            EQU     0           ; pdget(pmp, dirblk, idx, pdpp) -> errno
PDCORE_Fork             EQU     2           ; pd_fork(pd) -> errno
PDCORE_Entsync          EQU     4           ; pd_entsync(pd)
PDCORE_Twin             EQU     6           ; pd_twin(pd) -> struct pdnode *
PDCORE_Rekey            EQU     8           ; pd_rekey(pd, blk, idx)
PDCORE_Bmap             EQU     10          ; pd_bmap(pd, lbn, blkp) -> errno
PDCORE_Unlock           EQU     12          ; pd_unlock(vp)
PDCORE_Setwriteops      EQU     14          ; pd_setwriteops(struct pdwops *)
PDCORE_COUNT            EQU     8


;------------------------------------------------------------------------------
; NET op-table offsets (byte offsets into net.mod's net_op_table, multiples of
; 3 like FST FOPs).  The kernel's syscall thunks pass these to _Net_Dispatch.
; net.mod's net_op_table MUST list its ops in this order.  (Module side mirrors
; these — keep in sync, like the FOP_* set in include/fst.s.)
;------------------------------------------------------------------------------
NETOP_Ifconfig          EQU     0           ; SYS_IFCONFIG (#70)
NETOP_Socket            EQU     3           ; SYS_SOCKET (#71)
NETOP_Bind              EQU     6           ; SYS_BIND (#72)
NETOP_Sendto            EQU     9           ; SYS_SENDTO (#73)
NETOP_Recvfrom          EQU     12          ; SYS_RECVFROM (#74)
NETOP_Setsockopt        EQU     15          ; SYS_SETSOCKOPT (#75)
NETOP_Connect           EQU     18          ; SYS_CONNECT (#76)
NETOP_Send              EQU     21          ; SYS_SEND (#77)
NETOP_Recv              EQU     24          ; SYS_RECV (#78)
NETOP_Listen            EQU     27          ; SYS_LISTEN (#84)
NETOP_Accept            EQU     30          ; SYS_ACCEPT (#85)
; Internal dispatches (not syscalls): the read/write seam + Fs_Close teardown
; route into net.mod's transport here (Phase 3 moved the transport in).
NETOP_SoWrite           EQU     33          ; write(2) on a socket: sorw -> sosend
NETOP_SoRead            EQU     36          ; read(2) on a socket: sorw -> soreceive
NETOP_SockTeardown      EQU     39          ; Fs_Close FCB_FL_SOCKET -> _Sock_Teardown
NETOP_SockStatus        EQU     42          ; select(2): non-blocking readiness poll
NETOP_Shutdown          EQU     45          ; SYS_SHUTDOWN: TCP half-close (CR_DISCON)
; net_loop.s + pipe.s moved into net.mod 2026-08-11.  Their entry points are
; ordinary NETOPs, so they cross on the EXISTING _NetThunkExec -- which already
; answers ENOSYS when net.mod is absent, and needs no new patch machinery.
; APPEND ONLY, like the KSVC block above.
NETOP_LoopBind          EQU     48
NETOP_LoopConnect       EQU     51
NETOP_LoopListen        EQU     54
NETOP_LoopAccept        EQU     57
NETOP_LoopSend          EQU     60          ; RETIRED: sockets go through sosend/
NETOP_LoopRecv          EQU     63          ;   soreceive, which pick the transport;
NETOP_LoopRead          EQU     66          ;   the slots stay so the numbers after
NETOP_LoopWrite         EQU     69          ;   them do not move, and answer EINVAL
NETOP_LoopStatus        EQU     72
NETOP_LoopClose         EQU     75
NETOP_PipeRead          EQU     78          ; fd staged in _pipeThunkFd (A is
NETOP_PipeWrite         EQU     81          ;   clobbered by _Net_Dispatch)
NETOP_PipeTeardown      EQU     84
NETOP_SysPipe           EQU     87          ; the pipe(2) syscall-table entry
NETOP_GetPeerName       EQU     90          ; SYS_GETPEERNAME (#108)
NETOP_GetSockName       EQU     93          ; SYS_GETSOCKNAME (#109)
NETOP_IfIoctl           EQU     96          ; ioctl(2) SIOCGIF* on a socket

;------------------------------------------------------------------------------
; Module vtable registry — per-entry layout.  Mod_Load appends one entry
; per non-VT_END tuple in a module's VTDR directory; Mod_FindVtable walks
; the table to dispatch (Phase 3+).  Each entry is 6 bytes; the table
; lives in a Kmalloc'd heap soft-global (_modRegPtr; see below).
;------------------------------------------------------------------------------
MOD_REG_MAX             EQU     16          ; max simultaneous vtables
MOD_REG_E_VTYPE         EQU     0           ; 2 B
MOD_REG_E_VOFFSET       EQU     2           ; 2 B
MOD_REG_E_BANK          EQU     4           ; 1 B
MOD_REG_E_PAD           EQU     5           ; 1 B reserved
MOD_REG_E_SIZE          EQU     6
; The registry is a Kmalloc'd soft-global reached via the DP long-pointer
; _modRegPtr (dpmap.s); allocated by _AllocModReg at boot.  Was a 96-byte
; static _modReg in memmap.s.
MOD_REG_BLK_SIZE        EQU     MOD_REG_MAX*MOD_REG_E_SIZE   ; 96
