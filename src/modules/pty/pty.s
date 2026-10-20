
;==============================================================================
; SPDX-License-Identifier: BSD-2-Clause
; SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
;
; FGX-Provenance: 2.11BSD pty(4)
;   Ported from usr/sys/sys/tty_pty.c, 2.11BSD (1.3 (2.11BSD GTE) 1997/5/2),
;   vendored at vendor/2.11BSD/usr/sys/sys/tty_pty.c: the routines follow
;   upstream's ptsopen, ptsread, ptswrite, ptsstart, ptcwakeup, ptcopen,
;   ptcclose, ptcread, ptcwrite, ptcselect and ptyioctl, and quote them.
;   Original work:
;   Copyright (c) 1986 Regents of the University of California.
;   All rights reserved.  The Berkeley software License Agreement
;   specifies the terms and conditions for redistribution.
;
; pty.s - FGXM module: the pseudo-terminal pair driver.
;
; A loadable module, not core-bank code; it reaches the kernel only through
; the five calls listed under "the seam".
;
; WHAT STAYED, and why it is not arbitrary:
;   - the pair table, both ring buffers and every scratch cell.  They are
;     kernel-bank statics, and the ops run at DBR = kernel bank, so every
;     DBR-relative access below reads them exactly as it did in-kernel.  That
;     is what let the bodies move verbatim.
;   - _Pty_Init, because it zeroes those statics and main.s calls it at boot,
;     long before Mod_LoadConf.  An initialiser for core-bank data belongs
;     with the data.
;   - _Tty_CookedDefaults, because it is tty state, not pty state: main.s
;     (tty[0]) and ttyv.s call it too.
;   - the two chardev ops tables and the four device names, because
;     _Chardev_InitBuiltins registers them at boot.  See "the call seam".
;
; THE CALL SEAM.  chardev.s dispatches an op by loading the table's 3-byte
; entry into a JSL trampoline operand -- so the ops were ALREADY JSL/RTL
; shaped, and moving them needed no shim at all.  _Pty_LoadOpsPtr rewrites the
; twelve entries with this module's real 24-bit addresses after Mod_LoadConf;
; until then they point at _Pty_NoDev, which fails ENXIO.  chardev.s and
; _Chardev_InitBuiltins are untouched.
;
; NOTHING NEEDS AN RTL ENTRY POINT ANY MORE.  `_Pty_InGetNB' was the last one
; -- syscall.s JSRed it through an inline self-modified JSL site, the ramdisk
; seam -- and it went with the in ring at T6 increment 4a.  Both directory
; entries that carried those seams are ZEROED, not closed up; see `pty_ops'.
;
; THE FIVE THAT GO BACK THE OTHER WAY, through SYS_KCALL:
;   _sleep _wakeup            a blocking chardev cannot exist without these --
;                             read(2) on an empty ring must sleep, not spin
;   _Tty_DeliverSig           in-band ^C/^\ -> the tty's foreground pgrp
;   _Se_TtyOpen               slave open claims the controlling terminal
;   _Tty_CookedDefaults       stayed behind (see above)
; Each is a JSL to the multiplexed service slot, so none costs a bank-0 cell.
;
; DBR DISCIPLINE: everything here runs at DBR = kernel bank and this module has
; NO data of its own -- which is the point.  tools/check_module_data_refs.py
; enforces that a module never reads its own data DBR-relatively (apple/fgx#93).
;==============================================================================

                MX      %11
                PUT     modplace.s
                ORG     MODP_ORG

;------------------------------------------------------------------------------
; Constants.  PUT from the kernel's own include tree rather than hand-copied:
; these files are EQU/DUM only (their two DS lines are inside DUM blocks and
; emit nothing), so the module sees byte-identical field offsets.  A
; hand-transcribed TTY_* or PTYR_* offset that drifted from the kernel's would
; be a silent corruption of a shared table, not a build error -- the exact
; failure mode this module's whole seam is built to avoid.
;------------------------------------------------------------------------------
                PUT     ../../../include/config.s       ; CFG_DP_KERNELC,
                                                ;   which FGX_DP_KERNELC
                                                ;   in kernel.s derives
                PUT     ../../../include/errno.s
                PUT     ../../../include/loader.s
                PUT     ../../../include/chardev.s
                PUT     ../../../include/modules.s      ; KSVC_* service numbers
                PUT     ../../../include/socket.s       ; FIONBIO
                PUT     ../../../include/fs.s
                PUT     ../../../include/kernel.s
                PUT     ../../../include/pty.s
                PUT     ../../../include/vfs_equ.s      ; VFS_IO_NDELAY
                ; DP soft-globals (_fcbPtr, _libcTmp2, _shTmp2).  One DUM
                ; block, so it emits nothing -- and unlike the hardcoded
                ; EQUs in bpf/serial/ramdisk, it cannot silently rot when
                ; the DP map moves.  It has, once.
                PUT     ../../../include/dpmap.s

;------------------------------------------------------------------------------
; Kernel statics this module reaches DBR-relatively (generated every build from
; the kernel's listing, so they cannot go stale).
;------------------------------------------------------------------------------
                PUT     kernel_exports.s

;------------------------------------------------------------------------------
; FGXM header v2 (40 bytes).
;------------------------------------------------------------------------------
pty_bss         EQU     0

pty_hdr         ASC     'FGXM'                          ; +0  magic
                DFB     <MODP_ORG                       ; +4  load lo
                DFB     >MODP_ORG                       ; +5  load mid
                DFB     ^MODP_ORG                       ; +6  load hi
                DFB     $02                             ; +7  header format v2
                DA      mod_init-$050000                ; +8  entry, bank-rel
                DA      pty_end-pty_text                ; +10 text bytes
                DA      pty_bss                         ; +12 bss bytes
                DA      pty_vtdir-pty_text              ; +14 vtdir offset
pty_modname     ASC     'pty'                           ; +16 module name
                DS      16-*+pty_modname                ;     NUL-pad to 16
                DA      $0000                           ; +32 module version
                DA      KERN_BUILD_ID                   ; +34 kernel build id
                DS      4                               ; +36 reserved

pty_text        EQU     *

;------------------------------------------------------------------------------
; VTDR: one VT_CHARDEV vtable -- a 4-entry DIRECTORY, not the ops tables.
;
; THE OPS TABLES THEMSELVES MUST LIVE HERE, IN THE MODULE, and this is not a
; preference: _Chardev_Dispatch deliberately IGNORES the bank byte stored in an
; ops table and JSLs using the bank the TABLE lives in (chardev.s, "Do NOT read
; the vtable's stored ^ bank byte" -- it is the build-time $02 and wrong under
; relocation).  So table and handlers must share a bank.  Leaving the tables in
; the core bank and patching them with module addresses assembles cleanly,
; boots cleanly, and then JSLs kernel_bank:module_offset on the first pty open
; -- a wild jump into the middle of the kernel.  Measured, 2026-08-11.
;
; What the kernel patches instead is each pty chardev ENTRY's CD_OpsLo/CD_OpsBank,
; repointing it at one of the two tables below.  Dispatch then works exactly as
; it does for any module chardev.
;------------------------------------------------------------------------------
pty_vtdir       ASC     'VTDR'
                DA      VT_CHARDEV
                DA      pty_ops-pty_text
                DA      VT_END

pty_ops         DA      _PtyMOpsMod-$050000             ; +0 master COPS table
                DA      _PtySOpsMod-$050000             ; +2 slave COPS table
                DA      0                               ; +4 RETIRED at T6 4a:
                                                        ;   was _Pty_InGetNB_RTL,
                                                        ;   the master->slave
                                                        ;   ring's get.  ZEROED
                                                        ;   for the reason +6
                                                        ;   states below, and
                                                        ;   _Pty_LoadOpsPtr no
                                                        ;   longer reads it.
                DA      0                               ; +6 RETIRED: was
                                                        ;   _Pty_OutPut_RTL, the
                                                        ;   slave->master ring's
                                                        ;   put.  ZEROED, NOT
                                                        ;   CLOSED UP: this
                                                        ;   directory is read by
                                                        ;   _Pty_LoadOpsPtr at
                                                        ;   FIXED OFFSETS, so
                                                        ;   removing an entry
                                                        ;   would slide every one
                                                        ;   above it -- the same
                                                        ;   rule the KTTY and
                                                        ;   KFAR slot tables
                                                        ;   state for the same
                                                        ;   reason.

;------------------------------------------------------------------------------
; The two chardev ops tables, in COPS_* order (open, close, read, write, ioctl,
; poll -- include/chardev.s).  The ^ bank bytes assemble as $05 and are NEVER
; READ: dispatch takes the bank from the chardev entry, which the kernel sets to
; this module's live bank.  They are written out in full anyway so the table is
; the ordinary 3-byte-per-entry shape the rest of the system expects.
;------------------------------------------------------------------------------
_PtyMOpsMod     DFB     <_PtyM_Open,>_PtyM_Open,^_PtyM_Open
                DFB     <_PtyM_Close,>_PtyM_Close,^_PtyM_Close
                DFB     <_PtyM_Read,>_PtyM_Read,^_PtyM_Read
                DFB     <_PtyM_Write,>_PtyM_Write,^_PtyM_Write
                DFB     <_PtyM_Ioctl,>_PtyM_Ioctl,^_PtyM_Ioctl
                DFB     <_PtyM_Poll,>_PtyM_Poll,^_PtyM_Poll
                DFB     <_PtyM_DRead,>_PtyM_DRead,^_PtyM_DRead  ; d_read: RECORD
                DFB     0,0,0                                   ; d_write: none -- per-byte
                DFB     0,0,0                                   ; d_stop: the MASTER is
                                                                ;   not a tty line, so
                                                                ;   nothing calls d_stop
                                                                ;   on it.  `ptsstop' is
                                                                ;   the SLAVE's, below

_PtySOpsMod     DFB     <_PtyS_Open,>_PtyS_Open,^_PtyS_Open
                DFB     <_PtyS_Close,>_PtyS_Close,^_PtyS_Close
                DFB     <_PtyS_Read,>_PtyS_Read,^_PtyS_Read
                DFB     <_PtyS_Write,>_PtyS_Write,^_PtyS_Write
                DFB     <_PtyS_Ioctl,>_PtyS_Ioctl,^_PtyS_Ioctl
                DFB     <_PtyS_Poll,>_PtyS_Poll,^_PtyS_Poll
                DFB     <_PtyS_DRead,>_PtyS_DRead,^_PtyS_DRead  ; d_read:  `ptsread'
                DFB     <_PtyS_DWrite,>_PtyS_DWrite,^_PtyS_DWrite ; d_write: `ptswrite'
                DFB     <_PtyS_Stop,>_PtyS_Stop,^_PtyS_Stop     ; d_stop: `ptsstop'

;==============================================================================
; mod_init - Mod_Load JSLs here with DBR = KERNEL bank and MX %00.
; Nothing to initialise: _Pty_Init already zeroed the pair state at boot, and
; this module owns no storage.  Registration is the kernel's job
; (_Pty_LoadOpsPtr patches the ops tables after Mod_LoadConf).
;==============================================================================
mod_init        MX      %00
                ; ONE THING TO INITIALISE SINCE T2.2b: find uiomove.  A bulk
                ; read op moves bytes into the caller's uio and uiomove is the
                ; only routine that knows how -- it is C, it lives in vfs.mod,
                ; and so its address is resolved at load rather than linked.
                ;
                ; ORDER IS ALREADY RIGHT: /etc/modload.conf loads vfs FIRST and
                ; pty LAST, so the vtable exists by the time this runs.  A
                ; failed resolve is NOT fatal: it leaves _ptyVfsBank zero and
                ; the bulk op refuses, which is the per-byte behaviour the
                ; /dev route had before this existed.
                JSR     _Pty_ResolveVfs
                SEC
                RTL

;==============================================================================
; _Pty_ResolveVfs - vfs.mod's bank and the address of its uiomove.
;
; Entered from mod_init with DBR = the KERNEL bank, which is where all three
; statics live and where every routine in this module runs.
;
; ONE ENTRY, NOT THE WHOLE VTABLE.  ufs.mod copies all VFSCORE_COUNT entries
; because it calls a dozen of them; this module calls exactly one.  The read is
; the same cross-bank shape ufs.mod's loop uses -- DBR to vfs.mod, read, DBR
; back, store -- because the source is in vfs.mod's bank, the destination is
; not, and a module has no direct page to put a long pointer in.
;
; DBR COMES BACK VIA PHB/PLB, NOT PHK/PLB.  ufs.mod can use PHK because the
; bank it wants back is its own program bank.  The bank THIS wants back is the
; KERNEL's; PHK would leave DBR on pty.mod, where every static below reads as
; whatever this module happens to hold at that offset.
;
; THE BANK IS STORED LAST, because it is the resolved FLAG.  Storing it first
; would advertise a resolve that the slot read had not yet completed.
;------------------------------------------------------------------------------
_Pty_ResolveVfs MX      %00
                LDA     #VT_VFSCORE
                LDX     #KSVC_FINDVTABLE
                JSL     SYS_KCALL
                BCS     @rv_have
                RTS                             ; no vfs.mod; the flag stays 0
@rv_have        ; A = the table's bank-relative address, X.lo = its bank.
                CLC
                ADC     #VFSCORE_Uiomove        ; the one slot we import
                TAY                             ; Y = its offset in that bank
                PHB                             ; the kernel bank, to come back
                SEP     #$20
                MX      %10
                TXA                             ; X.lo = vfs.mod's bank
                PHA
                PLB                             ; DBR = vfs.mod
                REP     #$30
                MX      %00
                LDA     |$0000,Y                ; uiomove's offset, from there.
                                                ;   `|' IS LOAD-BEARING: without
                                                ;   it Merlin shortens a $0000
                                                ;   operand to the DIRECT PAGE
                                                ;   form and reads fcc's
                                                ;   register file instead, with
                                                ;   no warning and a plausible
                                                ;   16-bit result.
                PLB                             ; DBR = the kernel bank again
                STA     |_ptyVfsUiomove
                TXA
                AND     #$00FF
                STA     |_ptyVfsBank            ; LAST: this is the flag
                RTS

;------------------------------------------------------------------------------
; _Pty_Uio1 - one uiomove(cp, n, uio) from this module's assembly.
;
; In:  A = cp OFFSET (always in the kernel bank -- the ring and the packet byte
;      are both kernel statics), Y = n, and the uio far pointer already staged
;      in _libcTmp2 by the caller.
; Out: A = uiomove's errno, 0 on success.  X, Y clobbered.
;
; NO ARGUMENT COPY, unlike ufs.mod's shims.  Those are entered from C, so the
; arguments they forward are already above their own return address and have to
; be re-pushed; this one BUILDS the frame, so it pile-calls what it just made.
;
; THE SAVED DBR AND D GO ON *BELOW* THE ARGUMENTS.  uiomove reads them at 4,S
; above its own return address, so one stray byte between the frame and the
; call shifts every argument.  Below the frame they are invisible to the callee
; and still there on the way out.  That is what makes the obvious PHD in the
; middle wrong.
;
; D BECOMES FGX_DP_KERNELC FOR THE CALL, and the switch happens AFTER the
; arguments are pushed: _libcTmp2 is a KERNEL direct-page cell and cannot be
; read once D names fcc's register file.  TCD moves no stack, so it can sit
; between the frame and the pile call where PHD cannot.
;------------------------------------------------------------------------------
_Pty_Uio1       MX      %00
                STA     |_ptyTmpB3              ; cp offset
                STY     |_ptyTmpB2              ; n
                PHB                             ; the kernel bank, for the exit
                PHD                             ; the kernel page, likewise

                ; --- the ten argument bytes, LAST argument first, so they land
                ;     arg1-lowest the way fcc pushes them --------------------
                LDA     _libcTmp2+2
                AND     #$00FF
                PHA                             ; uio bank
                LDA     _libcTmp2
                PHA                             ; uio offset
                LDA     |_ptyTmpB2
                PHA                             ; n
                SEP     #$20
                MX      %10
                PHB
                PLA                             ; A.lo = the kernel bank, where
                                                ;   cp points -- allocated at
                                                ;   boot, so nothing here can
                                                ;   name it as a constant
                REP     #$30
                MX      %00
                AND     #$00FF
                PHA                             ; cp bank
                LDA     |_ptyTmpB3
                PHA                             ; cp offset

                LDA     |_ptyVfsUiomove         ; the target, read while DBR is
                TAX                             ;   still ours
                LDA     #FGX_DP_KERNELC
                TCD                             ; fcc's register file, for C
                SEP     #$20
                MX      %10
                LDA     |_ptyVfsBank
                PHA
                PLB                             ; DBR = vfs.mod.  NET ZERO.
                REP     #$30
                MX      %00
                PHK                             ; ptyret_uio is in OUR bank
                PEA     ptyret_uio-1
                PHB                             ; target bank: DBR is vfs.mod's
                TXA
                DEC     A
                PHA                             ; target - 1
                RTL                             ; PILECALL
ptyret_uio      TAY                             ; park the errno
                TSC
                CLC
                ADC     #10                     ; drop the argument frame
                TCS
                PLD                             ; the kernel page back...
                PLB                             ; ...and the kernel bank
                TYA
                RTS

;==============================================================================
; `_Pty_InGetNB_RTL' STOOD HERE, T6 increment 4a.  It was the last of the RTL
; entry points syscall.s reached through the vtable directory; both rings are
; retired now and syscall.s asks this module for no byte at all.
;==============================================================================


;==============================================================================
; SYS_KCALL shims for the five kernel routines that stayed in the core bank.
; Each preserves the caller's register contract exactly as the in-kernel JSR
; did, so the bodies below did not change beyond the call target name.
;
; X is the SERVICE SELECTOR, so a routine that wants an argument in X gets it
; in Y and the kernel arm does TYX (include/modules.s).
;==============================================================================
; A = chan -> C=1 INTERRUPTED (abandon the wait, return EINTR), C=0 woken.
; The service reports in A (see include/modules.s) because the KCALL carry
; already means "service dispatched"; this thunk turns that back into the carry
; contract the in-kernel _sleep has always had, so the three wait loops below
; read the same as the kernel's own callers.  A is CLOBBERED, which none of
; them needs across the call (apple/fgx#28).
_PtyKC_Sleep    MX      %00
                LDX     #KSVC_SLEEP
                JSL     SYS_KCALL
                LSR     A                       ; A=1 -> C=1; A=0 -> C=0
                RTS

_PtyKC_Wakeup   MX      %00                     ; A = chan
                LDX     #KSVC_WAKEUP
                JSL     SYS_KCALL
                RTS

_PtyKC_DeliverSig MX    %00                     ; A = tty index, X = signal
                TXY
                LDX     #KSVC_TTYDELIVERSIG
                JSL     SYS_KCALL
                RTS

; _PtyKC_TtyOpen IS NO LONGER CALLED.  T4 increment 2 sends the slave open
; through the DISCIPLINE's l_open (_PtyKC_LineOpen below), which runs this same
; session-acquisition block on its way and then sets TS_ISOPEN, which this one
; never did and which is what a hangup is gated on.  Kept because the service
; number is kept: include/modules.s is append only.
_PtyKC_TtyOpen  MX      %00                     ; X = tty byte offset
                TXY
                LDX     #KSVC_TTYOPEN
                JSL     SYS_KCALL
                RTS

; THE DISCIPLINE'S OWN TWO, which is how 2.11BSD's pty driver talks to a line:
; `ptsopen' finishes at l_open (tty_pty.c:88) and `ptcopen'/`ptcclose' bracket
; the session with l_modem 1 and 0 (tty_pty.c:214, :228).  Both take the tty's
; BYTE OFFSET in A, like the four tty services above them -- PTYR_TtyOff is
; what a caller here holds -- and the flag rides in Y because X is the service
; number.
_PtyKC_LineOpen MX      %00                     ; A = tty byte offset -> A=errno
                LDX     #KSVC_TTYLOPEN
                JSL     SYS_KCALL
                RTS

_PtyKC_Modem    MX      %00                     ; A = tty byte offset, Y = flag
                LDX     #KSVC_TTYMODEM
                JSL     SYS_KCALL
                RTS

_PtyKC_LineClose MX     %00                     ; A = tty byte offset, Y = flag
                LDX     #KSVC_TTYLCLOSE
                JSL     SYS_KCALL
                RTS

; AND T4 INCREMENT 4's THREE, which are the pty driver's half of "the output
; queue is the discipline's and I am the device": install/clear `ptsstart' as
; the line's `t_oproc' (tty_pty.c:213, :231), ask what the queue holds without
; taking it (ptcread's wait condition, :271), and take runs into a uio (:277).
_PtyKC_PtyOproc MX      %00                     ; A = tty byte offset, Y = on
                LDX     #KSVC_TTYPTYOPROC
                JSL     SYS_KCALL
                RTS

_PtyKC_OutqAvail MX     %00                     ; A = tty byte offset -> A = cc
                LDX     #KSVC_TTYOUTQAVAIL
                JSL     SYS_KCALL
                RTS

_PtyKC_OutqUio  MX      %00                     ; A = uio offset,
                LDX     #KSVC_TTYOUTQUIO        ;   Y = (uio bank << 8) | tty idx
                JSL     SYS_KCALL
                RTS

_PtyKC_Stopped  MX      %00                     ; A = tty byte offset -> A = 1
                LDX     #KSVC_TTYSTOPPED        ;   if TS_TTSTOP, else 0
                JSL     SYS_KCALL
                RTS

_PtyKC_Carrier  MX      %00                     ; A = tty byte offset -> A = 1
                LDX     #KSVC_TTYCARRIER        ;   if TS_CARR_ON, else 0
                JSL     SYS_KCALL
                RTS

_PtyKC_Select   MX      %00                     ; A = tty byte offset, Y = rw
                LDX     #KSVC_TTYSELECT         ;   -> A = 1 ready / 0 not
                JSL     SYS_KCALL
                RTS

_PtyKC_CookedDef MX     %00                     ; X = tty byte offset
                TXY
                LDX     #KSVC_TTYCOOKEDDEF
                JSL     SYS_KCALL
                RTS

_PtyKC_TtyRead  MX      %00                     ; A = uio offset, Y = (uio bank
                LDX     #KSVC_TTYREAD           ;   << 8) | ndelay<<7 | tty IDX
                JSL     SYS_KCALL               ;   -> A = errno, 0 = success
                RTS

_PtyKC_TtyWrite MX      %00
                LDX     #KSVC_TTYWRITE
                JSL     SYS_KCALL
                RTS


;==============================================================================
; ---- the driver body, moved verbatim from src/kernel/pty.s ----
;==============================================================================

;------------------------------------------------------------------------------
; _Pty_PairFromMinor - Y.minor -> X = pair record offset; C=side (0=m,1=s).
; Internal.  MX %00, preserves A via _shTmp2.
;------------------------------------------------------------------------------
_Pty_PairFromMinor
                MX      %00
                STA     _shTmp2
                TYA
                AND     #$00FF
                LSR                             ; A = pair, C = side bit
                BEQ     @pf_p0
                LDX     #PTYR_SIZE              ; pair 1 (only 2 pairs)
                BRA     @pf_done
@pf_p0          LDX     #0
@pf_done        LDA     _shTmp2
                RTS

;------------------------------------------------------------------------------
; BOTH PTY BYTE RINGS ARE GONE.  `_Pty_RingSel', `_Pty_InPut' and
; `_Pty_InGetNB' stood here with the out half's `_Pty_OutPut'/`_Pty_OutGetNB',
; and the pair record's six cursors with them.
;
; THE OUT HALF WENT AT T4 INCREMENT 7.  Increment 4 made `t_outq' a pty's
; pending output -- `t_oproc' is `ptsstart', which moves no data, so the bytes
; wait in the DISCIPLINE'S queue until the master's read takes them -- and from
; that day nothing filled that ring and nothing read it.
;
; THE IN HALF GOES HERE, AT T6 INCREMENT 4a, for the mirror-image reason: the
; master's write feeds `ttyinput' directly now (`_PtyM_Write' ->
; KSVC_TTYPTCINPUT -> `kc_ptcinput'), so an arriving byte lands in the
; discipline's `t_rawq' at arrival time and `ttread' is what waits on it.
; `_Pty_InPut' lost its last caller with that flip; `_Pty_InGetNB' lost its
; only reachable route when the two far shims began answering **-2, "this line
; is not pumped"**, before entering `_Tty_GetByte'/`_Tty_PollByte'
; (far_shims.s:207).
;
; WHAT ANSWERS THE PUNCTURED PREMISE.  The retirement survey warned that "a pty
; line has a nonzero `TTY_Backend'" is not universally true, so the -2 gate
; cannot be leaned on alone.  It is narrower than the survey said: `TTY_Backend'
; has exactly TWO writers -- `_Pty_SlaveTtyInit' sets it and `_Pty_MaybeReset'
; clears it -- and the reset fires only when PTYF_MOPEN and PTYF_SOPEN are BOTH
; clear, i.e. when no fd exists on either end to read through.  (The survey
; named `_PtyS_Close' at pty.s:1669 for the clear; that is `_Pty_PktSend's
; comment block, and reading the tree is what corrected it.)  So a line reaches
; the core byte source with `TTY_Backend' zero only when it is a CONSOLE, and
; syscall.s keeps the test anyway rather than trusting the shim -- see the
; tombstone at `_Tty_GetByte'.
;
; A TOMBSTONE RATHER THAN A SILENT DELETION, which is this file's habit for a
; retired path -- `_PtyS_Write' below FAILS LOUD rather than appending to a
; buffer nobody drains, and says why.
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; _Pty_Wake - broadcast WCHAN_PTY + nudge select sleepers (mirrors the
; kbd/sock wake convention: only when someone is select-blocked).
;------------------------------------------------------------------------------
_Pty_Wake       MX      %00
                PHA
                PHX
                PHY
                LDA     #WCHAN_PTY
                JSR     _PtyKC_Wakeup
                LDA     _nSelSleepers
                BEQ     @pw_nosel
                LDA     #WCHAN_SELECT
                JSR     _PtyKC_Wakeup
@pw_nosel       PLY
                PLX
                PLA
                RTS

; scratch (kernel-bank; only used within single ops — no cross-sleep state)

;==============================================================================
; MASTER ops (ptypN).  Register convention (chardev.s dispatch): Y = minor,
; A = _cdArgByte (write).  RECORD-mode read: buf/len via _Sys_RdBufOff /
; _Sys_RdMax / _Sys_CallerBank, returns A = bytes (the bpf.s convention).
;==============================================================================

_PtyM_Open      MX      %00
                JSR     _Pty_PairFromMinor      ; X = pair off
                LDA     _ptyTable+PTYR_Flags,X
                AND     #PTYF_MOPEN
                BEQ     @mo_free
                LDA     #EBUSY                  ; exclusive master
                CLC
                RTL
@mo_free        ; THE PER-FD FLAG BYTE ARRIVES ZERO, so this no longer clears
                ; it.  The comment here used to claim "FCB scratch is NOT
                ; guaranteed zero -- the DS lesson, fd-table edition", and that
                ; is the DS lesson applied where it does not hold: an FCB is not
                ; a DS region, it is a Kmalloc'd block that _Fcb_Alloc
                ; ZERO-FILLS on every allocation (src/drivers/fs/fcb.s, @al_kok
                ; "Zero the new FCB"), and _Chardev_Open dispatches the driver's
                ; open on EVERY open, each with a fresh one.
                ;
                ; Removing it matters beyond the four instructions: it was a
                ; write through [_fcbPtr], an FCB this routine's signature never
                ; mentions and the WRONG one on the /dev route, where the namei
                ; walk lies between _Fcb_Alloc and the driver's open.  With it
                ; gone the pty open path touches no descriptor at all
                ; (apple/fgx#198).  If some future path ever hands a driver a
                ; reused FCB, the zeroing belongs THERE and not in each driver.
                ; claim + reset rings/state; install the slave tty's defaults
                ; (sgttyb/tchars mirror main.s tty[0] cooked boot state) and
                ; point its TTY_Backend at THIS pair record (nonzero = offset
                ; +1 so pair 0 is distinguishable from "console").
                LDA     _ptyTable+PTYR_Flags,X
                ORA     #PTYF_MOPEN
                AND     #PTYF_MOPEN+PTYF_SOPEN  ; drop stale PKT/STOPPED
                STA     _ptyTable+PTYR_Flags,X
                STZ     _ptyTable+PTYR_Send,X   ; `pti->pt_send = 0' (:217)
                                                ; THE THREE RING CURSORS THAT
                                                ; STOOD HERE ARE GONE (T6 4a).
                                                ; What a reopened pair has to
                                                ; start clean is the
                                                ; DISCIPLINE'S queues, and
                                                ; `ttyclose' -> `ttyflush(FREAD|
                                                ; FWRITE)' empties those on the
                                                ; slave's close -- ported at
                                                ; tty.c:853 from
                                                ; vendor/2.11BSD/usr/sys/sys/
                                                ; tty.c:695-702.
                JSR     _Pty_SlaveTtyInit
                ; CARRIER UP: THE CONTROLLER IS HERE.  `ptcopen' does
                ; `(void)(*linesw[tp->t_line].l_modem)(tp, 1)' (tty_pty.c:214)
                ; right after it claims the pair, and that is the whole of how
                ; a pty slave learns it has a far end.  The answer is discarded
                ; here as it is upstream -- 0 asks the driver to turn the line
                ; off, and there is nothing to turn off on a pty.
                ; X IS THE PAIR OFFSET AND EVERY KSVC DESTROYS IT -- X is the
                ; service number on the way in.  The tty offset is read ONCE,
                ; here, because the second call below indexed `_ptyTable,X'
                ; after the first had already overwritten X with 34, and the
                ; install then silently ran against a garbage line: ENXIO back,
                ; nothing changed, and the only symptom was five bytes still
                ; arriving in the ring.
                LDA     _ptyTable+PTYR_TtyOff,X
                STA    |_ptyTmpB2
                PHX
                LDA    |_ptyTmpB2
                LDY     #1                      ; carrier up
                JSR     _PtyKC_Modem
                ; AND THE LINE'S OUTPUT ROUTINE BECOMES `ptsstart', which is
                ; `ptcopen's other line (tty_pty.c:213).  Until now every bound
                ; line carried the generic `tty_oproc', which DRAINS `t_outq'
                ; into this driver's ring on every `ttstart'; `ptsstart' moves
                ; nothing and only wakes, so the bytes stay queued until the
                ; master's own read takes them -- which is the whole of T4
                ; increment 4.
                LDA    |_ptyTmpB2               ; the offset, read before the
                LDY     #1                      ;   first call took X
                JSR     _PtyKC_PtyOproc
                PLX
                ; RECORD MODE IS DECLARED AT REGISTRATION, not here.  This
                ; used to OR FCB_FL_RECORD into [_fcbPtr] -- an FCB this
                ; routine's signature never mentions, and on the /dev route the
                ; WRONG one, because the namei walk lies between _Fcb_Alloc and
                ; the driver's open (apple/fgx#198).  The master is registered
                ; with CDF_RECORD in _Chardev_InitBuiltins and _Sys_Read asks
                ; the registry, which is where Reno keeps the same fact
                ; (pt_ioctl[minor(dev)]) and why its ptcopen ignores the `flag'
                ; argument it is handed.
                SEC
                RTL

_PtyM_Close     MX      %00
                JSR     _Pty_PairFromMinor
                ; CARRIER LOST, AND IT GOES FIRST -- upstream's order in
                ; `ptcclose' (tty_pty.c:225-231), and load-bearing here for a
                ; reason upstream does not have: `_Pty_MaybeReset' below zeroes
                ; the line's foreground group once both sides are shut, and the
                ; group is exactly who `ttymodem' has to signal.  Dropping
                ; carrier afterwards would send SIGHUP to group 0.
                ;
                ; THIS IS WHAT A HANGUP IS.  `ttymodem's lost-carrier arm sends
                ; SIGHUP then SIGCONT to the line's foreground group and flushes
                ; both queues; the `@tgb_phup' arm in syscall.s only ever told a
                ; process that was already blocked in read(2), by handing it a
                ; `^D'.  A process that is not reading -- a shell computing, a
                ; stopped job -- was told nothing at all.  ptyhup is the witness.
                PHX
                LDA     _ptyTable+PTYR_TtyOff,X ; read ONCE: the KSVC below
                STA    |_ptyTmpB2               ;   destroys X (it is the
                LDA    |_ptyTmpB2               ;   service number on the way in)
                LDY     #0                      ; carrier lost
                JSR     _PtyKC_Modem
                ; ...and the output routine goes with it, `ptcclose's own
                ; `tp->t_oproc = 0' (tty_pty.c:231).  `ttstart' tests the field
                ; before calling through it -- upstream's comment there is
                ; "kludge for pty" -- so a line whose master has gone queues
                ; output and drains nothing, rather than jumping through a zero.
                LDA    |_ptyTmpB2
                LDY     #0                      ; clear
                JSR     _PtyKC_PtyOproc
                PLX
                LDA     _ptyTable+PTYR_Flags,X
                AND     #$FFFF-PTYF_MOPEN
                STA     _ptyTable+PTYR_Flags,X
                JSR     _Pty_MaybeReset         ; both sides closed -> reset
                JSR     _Pty_Wake               ; unblock slave sleepers
                SEC
                RTL

_PtyM_Read      MX      %00
                ; RECORD-mode master read.  T4 increment 4: the bytes come out
                ; of the DISCIPLINE'S `t_outq' now, not out of a ring this
                ; driver kept, and they are delivered through the uio the
                ; caller hands the d_read.
                ;
                ; A uio RATHER THAN THE THREE `_Sys_Rd*' STATICS, and packet
                ; mode is why.  `ptcread' writes its prefix with
                ; `ureadc(0, uio)' (2.11BSD tty_pty.c:275) -- one character into
                ; the SAME uio, whose cursor then carries both where the data
                ; goes and how much room is left.  A base and a length cannot
                ; express "start one byte in", which is what made this look like
                ; it needed a fourth argument.
                ;
                ; AND THE uio IS IN THE U-AREA, so it is per-task by
                ; construction: nothing here parks anything across the sleep
                ; below, where apple/fgx#231 had to.
                STX     _ptyNbFlag              ; X = the op's flag
                LDA    |_ptyVfsBank             ; did mod_init find uiomove?
                AND     #$00FF
                BNE     @mr_go
                LDA     #ENXIO                  ; no vfs.mod: cannot move bytes
                CLC
                RTL
@mr_go          JSR     _Pty_PairFromMinor      ; X = pair record offset

@mr_wait        SEI
                ; A PENDING STATUS BYTE OUTRANKS DATA, which is `ptcread's own
                ; order: its `pt_send' test comes before the queue test, inside
                ; the wait loop, and returns having delivered one byte.
                LDA     _ptyTable+PTYR_Flags,X
                AND     #PTYF_PKT
                BEQ     @mr_ask
                JSR     _Pty_PktSend            ; ptsstart's arm, then pt_send
                CMP     #0
                BEQ     @mr_ask
                STZ     _ptyTable+PTYR_Send,X   ; `pti->pt_send = 0' -- STZ does
                CLI                             ;   not touch A, which holds it
                STA    |_ptyPktByte
                JSR     _Pty_TaskUio            ; stage the per-task uio
                PHX
                LDA     #_ptyPktByte
                LDY     #1
                JSR     _Pty_Uio1
                PLX
                CMP     #0
                BNE     @mr_uerr
                LDA     #1                      ; the status byte, alone
                SEC
                RTL

@mr_ask         CLI
                ; `ptcread's wait condition, asked without consuming it:
                ; `tp->t_outq.c_cc && (tp->t_state&TS_TTSTOP) == 0'.
                PHX
                LDA     _ptyTable+PTYR_TtyOff,X
                JSR     _PtyKC_OutqAvail        ; A = bytes available now
                PLX
                CMP     #0
                BNE     @mr_have

                ; EOF IS THE CARRIER, NOT "IS A SLAVE OPEN RIGHT NOW".
                ; `ptcread' falls THROUGH its TS_ISOPEN block and then asks:
                ;
                ;     if ((tp->t_state&TS_CARR_ON) == 0)
                ;         return (0);          -- upstream calls this EOF
                ;         -- vendor/2.11BSD/usr/sys/sys/tty_pty.c:268
                ;
                ; so a master whose slave is not open at this instant SLEEPS.
                ; Carrier comes up when the MASTER opens (`ptcopen' :214, which
                ; _PtyM_Open already ports) and again when a slave opens onto a
                ; live master (`ptsopen' :77, ported in _PtyS_Open); it goes
                ; down when the slave closes, because `ttyclose' zeroes the
                ; whole of `t_state' (tty.c:853).
                ;
                ; ASKING PTYF_SOPEN HERE ANSWERED EOF IN A WINDOW WHERE UPSTREAM
                ; BLOCKS -- between the master's open and the first slave's --
                ; and telnetd carries a workaround for exactly that window
                ; rather than the divergence being fixed (apple/fgx#266).
                ;
                ; AND THE CARRIER, BESIDE IT AND OUTSIDE THE MASK.  This is a
                ; KTTY bracket crossing -- direct page, bank, JSL and back --
                ; and the SEI below is for ONE race: `_sleep' requires its
                ; caller to re-test the wait condition under the mask, or a
                ; slave-side write lands between the test and the sleep and the
                ; wakeup is lost (sched.s).  THE CARRIER IS NOT PART OF THAT
                ; RACE: it moves only in `_PtyM_Open', `_PtyS_Open',
                ; `_PtyM_Close' and `ttyclose', every one of them syscall
                ; context, never an interrupt.  A close that slips in between
                ; this read and the SEI costs nothing either -- `_Pty_Wake'
                ; wakes the sleeper, the loop re-enters @mr_wait, and it sees
                ; the carrier down then.
                ;
                ; INSIDE THE MASK IT WOULD SIT ON A HOT PATH: telnetd's relay
                ; spins on a non-blocking master read, so every poll that finds
                ; the queue dry would pay a cross-bank crossing with interrupts
                ; off -- and the heartbeat that window delays is what drives the
                ; keyboard, the input discipline and the scheduler tick.  The
                ; call above asks a question that IS part of the race and is
                ; still outside the mask; this one has less claim than it does.
                PHX
                LDA     _ptyTable+PTYR_TtyOff,X
                JSR     _PtyKC_Carrier          ; A = 1 carrier up / 0 down
                PLX
                CMP     #0
                BEQ     @mr_eof                 ; carrier down, queue dry -> EOF
                                                ;   (@mr_eof's CLI is harmless
                                                ;   with interrupts already on)

                SEI
                LDA     _ptyNbFlag
                AND     #VFS_IO_NDELAY
                BNE     @mr_again
                PHX                             ; X dies across the switch
                LDA     _ptyNbFlag              ; ...and so does this
                PHA
                LDA     #WCHAN_PTY
                JSR     _PtyKC_Sleep            ; C=1 = a signal wants us to stop
                REP     #$30                    ; _sleep may return 8-bit M/X;
                MX      %00                     ;   neither PLA/STA nor PLX
                PLA                             ;   touches the carry
                STA     _ptyNbFlag
                PLX
                BCS     @mr_intr                ; interrupted: do NOT re-wait
                BRA     @mr_wait
                ; Re-entering @mr_wait on a signal is apple/fgx#28: the sleep
                ; returns C=1 WITHOUT blocking while the signal stays pending,
                ; so the loop spins and the syscall that must return to let the
                ; handler run never does.
@mr_intr        LDA     #EINTR
                CLC
                RTL
@mr_again       CLI
                LDA     #EAGAIN
                CLC
                RTL
@mr_eof         CLI
                LDA     #0                      ; record-mode EOF: A=0 + C=0
                CLC
                RTL
@mr_uerr        CLC                             ; uiomove's errno, in A already
                RTL

@mr_have        JSR     _Pty_TaskUio            ; stage the per-task uio
                ; PKT MODE PREFIXES EVERY DATA READ WITH A ZERO BYTE --
                ; `ureadc(0, uio)', TIOCPKT_DATA being 0.
                LDA     _ptyTable+PTYR_Flags,X
                AND     #PTYF_PKT
                BEQ     @mr_drain
                STZ    |_ptyPktByte             ; TIOCPKT_DATA
                PHX
                LDA     #_ptyPktByte
                LDY     #1
                JSR     _Pty_Uio1
                PLX
                CMP     #0
                BNE     @mr_uerr

@mr_drain       ; The runs, into the same uio.  KSVC_TTYOUTQUIO takes the tty
                ; INDEX in Y's low byte and the uio's bank in its high -- see
                ; include/modules.s for why that one service breaks the
                ; byte-offset convention the others keep.
                LDA     _ptyTable+PTYR_TtyIdx,X
                STA    |_ptyTmpB2
                PHX
                LDA     _u+2
                AND     #$00FF
                XBA                             ; the u-area's bank, high byte
                ORA    |_ptyTmpB2               ; | the tty index
                TAY
                LDA     _u
                CLC
                ADC     #U_TtyUio               ; A = the uio's offset
                JSR     _PtyKC_OutqUio          ; A = errno
                PLX
                CMP     #0
                BNE     @mr_uerr
                ; THE COUNT IS uio_offset, which `ureadc' and `uiomove' advance
                ; per byte -- read out of the caller's OWN u-area, never
                ; `_Sys_RdMax - resid'.  syscall.s:4137 records what that
                ; subtraction cost when one operand was a singleton.
                LDY     #U_TtyUio+6
                LDA     [_u],Y
                SEC
                RTL

;------------------------------------------------------------------------------
; _Pty_TaskUio - stage the CURRENT TASK's read uio in _libcTmp2, where
; _Pty_Uio1 expects it.  MX %00.  Preserves X; clobbers A.
;
; `_Sys_UioOne' (syscall.s) built it in the u-area before the record op was
; dispatched, so this is arithmetic on `_u' rather than a cached pointer -- and
; that is the point: it is recomputed after every sleep for free, where a
; staged copy would be one task's answer handed to another.
;------------------------------------------------------------------------------
_Pty_TaskUio    MX      %00
                LDA     _u
                CLC
                ADC     #U_TtyUio
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _u+2                    ; the u-area's bank
                STA     _libcTmp2+2
                REP     #$30
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _PtyM_DRead - cdevsw's d_read for the pty MASTER.  apple/fgx#198's fix.
;
; WHAT THIS EXISTS TO STOP.  _PtyM_Read above is RECORD MODE: it fills the
; caller's buffer whole and returns a COUNT.  Without a d_read the /dev vnode
; route's spec_chread per-byte loop reads that count as one byte's VALUE --
; the buffer arrives filled, uio_resid drops by one, and the next call refills
; it from the top.  cdevsw's d_read is where a driver says "I move records",
; and this is that.
;
; In:  Y = minor, from the dispatcher.  A frame this routine reads directly:
;        9,S uio offset   11,S uio bank   13,S flag
;      Eight bytes of return address sit above it -- _Chardev_Bulk's JSR into
;      _Chardev_Dispatch (2), the dispatch's JSL through the bank-0 gateway
;      cell (3), and that cell's own JSL (3).
; Out: C=1 success, or C=0 + A = errno.
;
; THE FRAME IS RE-READ FROM THE STACK RATHER THAN CACHED, and that is the whole
; reason it travels on a stack at all: this op SLEEPS, and the stack it sleeps
; on is the task's own kernel stack, restored with S when it resumes.  A static
; would be one task's answer handed to another (apple/fgx#89).
;
; NON-BLOCKING COMES FROM `flag', NOT FROM [_fcbPtr] -- and as of T2.2b that
; is true of the PER-BYTE ops too, not just this one.  They used to read
; FCB_CdFlags through a pointer their signature never mentions, which was wrong
; twice: on the /dev route it is the WRONG FCB (the namei walk lies between
; _Fcb_Alloc and the driver's open), and all three read it INSIDE a wait loop,
; i.e. after _PtyKC_Sleep, where a shared direct-page cell names whichever
; descriptor another task resolved during the sleep.  The flag arrives in X now
; and is staged in _ptyNbFlag, which the sleep sites save.
;
; Reno takes it from the argument for the same reason:
; `if (flag & IO_NDELAY) return (EWOULDBLOCK)' (4.3BSD-Reno kern/tty_pty.c:303,
; and 2.11BSD tty_pty.c:271 identically).  IT IS REACHABLE THROUGH A VNODE NOW
; -- apple/fgx#310 gave FNDELAY a setter in vfs_ioctl and threaded the ioflag
; down through spec_read and the chardev seam, where it rides in the free bit 4
; of the index byte -- as well as through the syscall route, where the FIONBIO
; ioctl sets FCB_CDF_NONBLK and syscall.s translates it.  Both roads reach these
; arms, which is what the note above used to say only of the second.
;
; NO STAGING BUFFER.  Reno copies the clist into a `char buf[BUFSIZ]` because
; its outq is a clist and has no contiguous form; FGX's out ring already IS a
; contiguous kernel array, so the bytes go to uiomove where they lie -- one run
; from the tail to the end of the ring, and a second for the wrap if there is
; one.  That is 128 bytes of scarce kernel data not spent, and one fewer copy.
;
; THE BUDGET IS uio_resid AND IT IS READ FIRST.  uiomove clamps to resid and
; DISCARDS the excess (kern_subr.c:142), so a driver that dequeues more than
; the caller can take loses those bytes off the ring.  Reno bounds the same way
; (`cc = MIN(uio->uio_resid, sizeof(buf))`).
;------------------------------------------------------------------------------
_PtyM_DRead     MX      %00
                LDA     |_ptyVfsBank            ; did mod_init find uiomove?
                AND     #$00FF
                BNE     @dr_go
                LDA     #ENXIO                  ; no vfs.mod: cannot move bytes
                CLC
                RTL
@dr_go          JSR     _Pty_PairFromMinor      ; X = pair record offset

@dr_wait        ; `ptcread's wait condition, asked of the DISCIPLINE now:
                ; `tp->t_outq.c_cc && (tp->t_state&TS_TTSTOP) == 0'.  Outside
                ; the SEI, because the queue is kernel-C state that no interrupt
                ; touches -- what the mask below protects is PTYR_Flags, which
                ; another task can change.
                PHX
                LDA     _ptyTable+PTYR_TtyOff,X
                JSR     _PtyKC_OutqAvail        ; A = bytes available now
                PLX
                CMP     #0
                BNE     @dr_have
                SEI
                ; A PENDING STATUS BYTE IS SOMETHING TO READ, and it is asked
                ; BEFORE the queue because `ptcread' asks it there:
                ;
                ;     if (tp->t_state&TS_ISOPEN) {
                ;         if (pti->pt_flags&PF_PKT && pti->pt_send) {
                ;             error = ureadc((int)pti->pt_send, uio);
                ;             ...
                ;             return (0);
                ;         }
                ;         ...
                ;         if (tp->t_outq.c_cc && (tp->t_state&TS_TTSTOP) == 0)
                ;             break;
                ;     }
                ;
                ; -- vendor/2.11BSD/usr/sys/sys/tty_pty.c:246-262.  A flush, a
                ; stop or a start is precisely the case where the queue IS
                ; empty, so an order that reached the delivery arm only through
                ; `@dr_have' would answer EWOULDBLOCK with a status byte
                ; waiting.  `_PtyM_Read' asks in the same place; the two are one
                ; driver and must agree.
                ;
                ; `_Pty_PktSend' AND NOT A BARE `PTYR_Send' TEST.  It carries
                ; `ptsstart's arm as well: a line that was stopped and is
                ; running again has TIOCPKT_START minted at the ask, and the
                ; field alone reads zero for it.  Calling it twice is harmless
                ; -- the second call finds PF_STOPPED already clear and returns
                ; the field.
                ;
                ; UNDER THE MASK, where `_PtyM_Read' also asks it, because
                ; PTYR_Flags and PTYR_Send are what the mask is here to protect;
                ; the CLI comes before the delivery, which crosses banks.
                LDA     _ptyTable+PTYR_Flags,X
                AND     #PTYF_PKT
                BEQ     @dr_noPkt
                JSR     _Pty_PktSend            ; X preserved
                CMP     #0
                BEQ     @dr_noPkt
                CLI
                BRL     @dr_have                ; -> @dr_pkt delivers it alone
@dr_noPkt       LDA     _ptyTable+PTYR_Flags,X
                AND     #PTYF_SOPEN
                BEQ     @dr_eof                 ; no slave, queue dry -> EOF
                LDA     13,S                    ; the op's own `flag'
                AND     #VFS_IO_NDELAY
                BNE     @dr_again
                PHX                             ; X dies across the switch
                LDA     #WCHAN_PTY
                JSR     _PtyKC_Sleep
                REP     #$30                    ; _sleep may return 8-bit
                MX      %00
                PLX                             ; (neither touches the carry)
                BCS     @dr_intr
                BRA     @dr_wait
                ; Interrupted.  NOT re-entering @dr_wait is apple/fgx#28, the
                ; same reason _PtyM_Read spells this out: the sleep returns C=1
                ; WITHOUT blocking while the signal stays pending, so a loop
                ; here spins at full speed and the syscall that must return to
                ; let the handler run never does.
@dr_intr        LDA     #EINTR
                CLC
                RTL
@dr_again       CLI
                LDA     #EAGAIN
                CLC
                RTL
@dr_eof         CLI
                LDA     #0                      ; EOF is SUCCESS with nothing
                SEC                             ;   moved -- Reno returns 0 too
                RTL

@dr_have        ; --- stage the uio, once, for every uiomove below -----------
                LDA     9,S
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     11,S
                STA     _libcTmp2+2
                REP     #$30
                MX      %00

                ; --- THE FRAME ASSERTION.  Nothing had ever read 9/11/13,S
                ; before this routine, so the offsets were arithmetic over three
                ; call instructions rather than an observation.  A d_read is by
                ; definition handed a READ uio, so uio_rw names the frame: get
                ; the offsets wrong and _libcTmp2 is a wild pointer, which
                ; almost certainly does not read as 0 here.
                LDY     #UIO_RW
                LDA     [_libcTmp2],Y
                BEQ     @dr_budget
                LDA     #EINVAL
                CLC
                RTL

@dr_budget      LDY     #UIO_RESID
                LDA     [_libcTmp2],Y
                STA     |_ptyTmpN               ; what the caller can take
                BNE     @dr_pkt
                LDA     #0                      ; no room; nothing to do
                SEC
                RTL

                ; --- packet mode's prefix byte, which spends one of the budget
@dr_pkt         LDA     _ptyTable+PTYR_Flags,X
                AND     #PTYF_PKT
                BEQ     @dr_data
                JSR     _Pty_PktSend            ; ptsstart's arm, then pt_send
                CMP     #0
                BEQ     @dr_pkD
                STZ     _ptyTable+PTYR_Send,X   ; STZ preserves A
                STA     |_ptyPktByte
                JSR     @dr_pk1
                BNE     @dr_err
                LDA     #0                      ; A STATUS BYTE GOES ALONE, and
                SEC                             ;   this arm used to fall into
                RTL                             ;   the dequeue behind it.
                                                ;   `ptcread' RETURNS after its
                                                ;   `ureadc' (tty_pty.c:252-257)
                                                ;   so the data comes on the
                                                ;   NEXT read; the record path
                                                ;   has always done that and the
                                                ;   two must agree.
@dr_pkD         LDA     #TIOCPKT_DATA
                STA     |_ptyPktByte
                JSR     @dr_pk1
                BNE     @dr_err
                DEC     |_ptyTmpN               ; the prefix took one
                BNE     @dr_data
                LDA     #0                      ; ...and it was the whole budget
                SEC
                RTL
                ; One byte from _ptyPktByte into the caller's uio.  Returns with
                ; Z set on success (A = 0, no errno), X preserved.
@dr_pk1         PHX
                LDA     #_ptyPktByte
                LDY     #1
                JSR     _Pty_Uio1
                PLX
                CMP     #0
                RTS

@dr_data        ; The runs, into the caller's uio.  T4 increment 4: the same
                ; door `_PtyM_Read' uses, because the QUEUE is the same and only
                ; the destination ever differed -- and here the destination is
                ; already a uio, which is what `ptcread' takes.
                LDA     _ptyTable+PTYR_TtyIdx,X
                STA    |_ptyTmpB2
                PHX
                LDA     _libcTmp2+2
                AND     #$00FF
                XBA                             ; the uio's bank, high byte
                ORA    |_ptyTmpB2               ; | the tty index
                TAY
                LDA     _libcTmp2               ; A = the uio's offset
                JSR     _PtyKC_OutqUio          ; A = errno
                PLX
                CMP     #0
                BNE     @dr_err
@dr_done        JSR     _Pty_Wake               ; writers may be blocked on full
                LDA     #0
                SEC
                RTL
@dr_err         CLC                             ; uiomove's errno is in A
                RTL

                ; Consume _ptyDrRun bytes from the ring.  X = pair offset.
                ; `@dr_advance' STOOD HERE and went with the out ring, T4
                ; increment 7: it consumed a run from the ring's tail after
                ; `_PtyM_DRead' had copied it out.  That read has come from
                ; `t_outq' through `kc_ttoutq_uio' since increment 4, so
                ; nothing has called this since.

_PtyM_Write     MX      %00
                ; A = the byte (_cdArgByte via dispatch), X = flag.  EIO with
                ; no slave; refuses at TTYHOG once the slave's `t_rawq' is full
                ; (unless IO_NDELAY), which is where the InRing's backpressure
                ; went when the 4a flip fed `ttyinput' directly.
                STX     _ptyNbFlag              ; before _Pty_PairFromMinor
                AND     #$00FF                  ;   takes X for the pair index
                STA     _ptyTmpB2               ; the discipline below COMPARES
                                                ;   this; _Pty_InPut only ever
                                                ;   read the low byte, so the
                                                ;   high byte was never masked
                JSR     _Pty_PairFromMinor
                LDA     _ptyTable+PTYR_Flags,X
                AND     #PTYF_SOPEN
                BNE     @mw_go
                LDA     #EIO
                CLC
                RTL

                ; --- THE MASTER'S WRITE FEEDS THE DISCIPLINE (T6 4a) ---
                ;
                ; `vendor/2.11BSD/usr/sys/sys/tty_pty.c:439' is the whole of
                ; what a master write does with a byte:
                ;
                ;     (*linesw[tp->t_line].l_rint)(*cp++, tp);
                ;
                ; so that is what this does now, through KSVC_TTYPTCINPUT ->
                ; `kc_ptcinput' (KTTY slot 35), which carries upstream's TTYHOG
                ; guard with it.  There is no ring between the two halves of a
                ; pair any more.
                ;
                ; apple/fgx#57'S HAND-CODED INTR/QUIT TEST IS GONE FROM HERE,
                ; and it is SUBSUMED rather than dropped: it existed because
                ; the byte sat in a ring until something called read(2), so a
                ; spinning foreground process could not be stopped -- and
                ; `ttyinput' does that test itself, at arrival, which is where
                ; #57 wanted it.  It cost a KSVC crossing PER BYTE written to
                ; the master; this costs one too, and does the whole discipline
                ; for it rather than three characters' worth.
                ;
                ; SEI ACROSS THE TEST-AND-SLEEP, unchanged and still required:
                ; the answer is read and the sleep entered under one mask, or a
                ; slave read between them is a lost wakeup.  sched.s's `_sleep'
                ; asks its callers for exactly this and CLIs on wake.
@mw_go          SEI
                ; X is the pair row and EVERY KSVC DESTROYS IT, so the tty
                ; offset is read BEFORE the call and the row restored after --
                ; the trap T4 increment 4 spent a diagnosis on, where the oproc
                ; install ran against a garbage line and said nothing.
                PHX
                LDA     _ptyTable+PTYR_TtyOff,X ; A = the slave tty's offset
                LDY     _ptyTmpB2               ; Y = the byte
                LDX     #KSVC_TTYPTCINPUT
                JSL     SYS_KCALL               ; A = 1 fed / 0 hog / -1 no line
                PLX                             ; the pair row back
                CMP     #1
                BEQ     @mw_ok                  ; the discipline took it
                CMP     #0
                BEQ     @mw_hog                 ; at TTYHOG: block, as upstream
                CLI                             ; -1: the line went away
                LDA     #EIO
                CLC
                RTL
@mw_hog         ANOP
                LDA     _ptyNbFlag
                AND     #VFS_IO_NDELAY
                BNE     @mw_again
                PHX
                ; THE BYTE AND THE FLAG BOTH CROSS THE SWITCH, and neither
                ; survives it on its own: @mw_go re-reads _ptyTmpB2 on the way
                ; round, so another task's pty write during this sleep would
                ; hand ITS character to this task's line.  apple/fgx#89 with
                ; the byte instead of the count.
                LDA     _ptyTmpB2
                PHA
                LDA     _ptyNbFlag
                PHA
                LDA     #WCHAN_PTY
                JSR     _PtyKC_Sleep
                REP     #$30            ; _sleep may return 8-bit; restore
                PLA                     ; carry is @mw_intr's answer and none
                STA     _ptyNbFlag      ;   of these touch it
                PLA
                STA     _ptyTmpB2
                PLX
                BCS     @mw_intr        ; interrupted: do NOT re-wait (#28)
                BRA     @mw_go
@mw_intr        LDA     #EINTR          ; IRQs already on -- _sleep CLI'd
                CLC
                RTL
@mw_again       CLI
                LDA     #EAGAIN
                CLC
                RTL
@mw_ok          CLI
                LDA     #1                      ; one byte consumed
                SEC
                RTL

_PtyM_Ioctl     MX      %00
                JSR     _Pty_PairFromMinor
                LDA     _Sys_IoctlCmd
                CMP     #TIOCPKT
                BEQ     @mi_pkt
                CMP     #FIONBIO
                BEQ     @mi_nbio
                LDA     #ENOTTY
                CLC
                RTL
@mi_pkt         ; *arg != 0 -> PKT on, else off
                JSR     _Pty_ArgWord
                CMP     #0
                BEQ     @mi_pkOff
                LDA     _ptyTable+PTYR_Flags,X
                ORA     #PTYF_PKT
                BRA     @mi_pkStore
@mi_pkOff       LDA     _ptyTable+PTYR_Flags,X
                AND     #$FFFF-PTYF_PKT
@mi_pkStore     STA     _ptyTable+PTYR_Flags,X
                LDA     #0                      ; `return (0)' (tty_pty.c:490).
                SEC                             ;   This arm used to leave the
                RTL                             ;   flags word in A, so a caller
                                                ;   testing `!= 0' saw a failure
                                                ;   on a successful ioctl.
                ; `@mi_flush' STOOD HERE and went at apple/fgx#241.  It
                ; claimed TIOCFLUSH for the master and answered SUCCESS without
                ; touching a queue -- worse than refusing it, because a caller
                ; that asks a tty to discard its input had no way to learn that
                ; it did not.  (It once zeroed the in-ring's three cursors,
                ; which had been pinned at zero since the 4a flip, so the flush
                ; was already a no-op wearing three stores.)
                ;
                ; The command is routed to the SLAVE'S LINE before it reaches
                ; this vtable now (syscall.s `_Io_CdThenTty'), which is where
                ; upstream sends it: `ptyioctl' has no TIOCFLUSH arm at all and
                ; falls through to `ttioctl(tp, ...)' on the slave's tp
                ; (tty_pty.c:526).
                ;
                ; THE WAKE IS NOT LOST, AND IS NOT ALWAYS THERE EITHER.  For
                ; FWRITE `ttyflush' reaches `kc_cdstop' (tty.c:824) ->
                ; `_PtyS_Stop' -> `_Pty_Wake'.  For FREAD it does not, because
                ; upstream's `ttyflush' calls `d_stop' only under FWRITE
                ; (vendor tty.c:197) and its FREAD half calls `ttwakeup(tp)',
                ; which wakes the SLAVE'S readers rather than the master's
                ; WCHAN_PTY sleepers.  That is upstream's behaviour, kept.
@mi_nbio        JSR     _Pty_ArgWord
                JMP     _Pty_SetNB              ; shared with slave; RTLs

_PtyM_Poll      MX      %00
                JSR     _Pty_PairFromMinor
                LDA     #0
                STA     _ptyTmpB2
                ; READABLE IS THE DISCIPLINE'S ANSWER NOW, T4 increment 4, and
                ; it is `ptcselect's own test: `if (tp->t_outq.c_cc &&
                ; (tp->t_state&TS_TTSTOP) == 0) return (1)' (tty_pty.c:317).
                ; Asking PTYR_OutCount here would have been a silent regression
                ; -- the ring is not fed any more, so it answers 0 forever and
                ; select on a master would never report readable.  No fixture
                ; covers select on a pty master, so nothing would have said so.
                ; A PENDING STATUS BYTE IS READABLE TOO, and it is the first
                ; clause of `ptcselect's own test: `if (pti->pt_flags&PF_PKT &&
                ; pti->pt_send || ...)' (tty_pty.c:348).  It goes through the
                ; same door the reads use, so `ptsstart's arm is evaluated here
                ; as well and select cannot report a line unreadable that the
                ; next read(2) would answer at once.
                LDA     _ptyTable+PTYR_Flags,X
                AND     #PTYF_PKT
                BEQ     @mp_ask
                JSR     _Pty_PktSend
                CMP     #0
                BNE     @mp_rd
@mp_ask         PHX                             ; the KSVC takes X for its number
                LDA     _ptyTable+PTYR_TtyOff,X
                JSR     _PtyKC_OutqAvail        ; A = bytes available now
                PLX
                CMP     #0
                BNE     @mp_rd                  ; data -> readable
                LDA     _ptyTable+PTYR_Flags,X
                AND     #PTYF_SOPEN
                BNE     @mp_ckwr                ; no data, slave open -> not rd
@mp_rd          LDA     _ptyTmpB2
                ORA     #POLLIN                 ; data or hangup-EOF readable
                STA     _ptyTmpB2
@mp_ckwr        ; WRITABLE IS THE DISCIPLINE'S ANSWER.  This asked
                ; `PTYR_InCount < PTY_RING_SZ' -- and T6 increment 4a stopped
                ; feeding that ring, so the count is pinned at 0 and the answer
                ; became "always writable", while `_PtyM_Write' refuses at
                ; TTYHOG with EAGAIN.  A select that promises a write which then
                ; fails is the one answer select exists to prevent, and
                ; `_PtyS_Poll' says exactly that about the identical bug one
                ; increment earlier.
                ;
                ; KSVC_TTYPTCWRITABLE is `kc_ptcinput's EXACT COMPLEMENT
                ; (upstream's ptcselect FWRITE arm, tty_pty.c:395-402), so the
                ; two cannot disagree about the same queue.
                PHX                             ; the KSVC takes X for its number
                LDA     _ptyTable+PTYR_TtyOff,X
                LDX     #KSVC_TTYPTCWRITABLE
                JSL     SYS_KCALL               ; A = 1 writable / 0 not
                PLX
                CMP     #0
                BEQ     @mp_done
                LDA     _ptyTmpB2
                ORA     #POLLOUT
                STA     _ptyTmpB2
@mp_done        LDA     _ptyTmpB2
                SEC
                RTL

;==============================================================================
; SLAVE ops (ttypN).  Reads/sgtty-ioctls never reach these (routed in
; syscall.s to the shared discipline / @si_ttyX); open/close/write/poll live
; here.
;==============================================================================

_PtyS_Open      MX      %00
                JSR     _Pty_PairFromMinor
                LDA     _ptyTable+PTYR_Flags,X
                AND     #PTYF_MOPEN
                BNE     @so_ok
                LDA     #EIO                    ; no master -> no session
                CLC
                RTL
@so_ok          ; No clear of the per-fd flag byte here either -- see
                ; _PtyM_Open above for why it was never needed and why the
                ; write mattered.
                LDA     _ptyTable+PTYR_Flags,X
                ORA     #PTYF_SOPEN
                STA     _ptyTable+PTYR_Flags,X
                ; ACQUIRE THE LINE AS THE OPENER'S CONTROLLING TTY, and run
                ; 2.11BSD ttyopen()'s process-group half -- exactly what
                ; _Ttyv_Open does for a virtual console (apple/fgx#57).
                ;
                ; _PtyS_Open did NEITHER, and _Pty_SlaveTtyInit explicitly
                ; STZs TTY_FgPgrp, so a pty slave's foreground group stayed 0
                ; unless a job-control shell claimed the line with TIOCSPGRP --
                ; and only csh/tcsh issue that.  _Tty_DeliverSig no-ops on a
                ; line with no foreground group, so the in-band ^C discipline
                ; had nobody to signal: it looked implemented and could not
                ; fire.  Measured, not inferred -- ptyintr's child survived a
                ; ^C written to the master and waitpid returned 0.
                ;
                ; Same shape as #41 and #51: the console/VC path got the BSD
                ; behaviour and the pty path was left behind.  The helpers
                ; already resolve _kCttyTarget (the spawn file-actions case, so
                ; the CHILD claims the line rather than the spawner), which is
                ; precisely how a pty session is set up.
                ; THROUGH THE DISCIPLINE, not straight at the session block.
                ; `ptsopen' ends `error = (*linesw[tp->t_line].l_open)(dev, tp)'
                ; and that call is what sets TS_ISOPEN -- which nothing in this
                ; kernel had ever set, because no open path dispatched l_open.
                ; The hangup arm of `ttymodem' is gated on it, so without this
                ; the carrier work of T4 increment 2 would have had nobody to
                ; signal.  `ttyopen' reaches the session block this line used to
                ; call directly, through `kc_ttyopen', so nothing is lost.
                ; CARRIER FIRST, AND IT IS `ptsopen''s OWN LINE (apple/fgx#244):
                ;
                ;       if (tp->t_oproc)        /* Ctrlr still around. */
                ;               tp->t_state |= TS_CARR_ON;
                ;               -- vendor/2.11BSD/usr/sys/sys/tty_pty.c:77-78
                ;
                ; `PTYF_MOPEN', tested at the top of this routine, IS
                ; `tp->t_oproc' in this kernel's vocabulary -- the condition was
                ; already asked two instructions ago and the raise was simply
                ; missing.
                ;
                ; WHY IT MATTERS ONLY ON A REOPEN.  The master's open raises
                ; carrier through this same door (`ptcopen''s
                ; `l_modem(tp, 1)', tty_pty.c:214), so the FIRST session is
                ; fine.  `ttyclose' then does `tp->t_state = 0' -- verbatim
                ; upstream, tty.c:695-702 -- which takes the carrier down with
                ; everything else; and upstream is only safe there BECAUSE
                ; `ptsopen' puts it back.  Without this, the second session on
                ; a still-open pair opens a line whose carrier is down, and
                ; `ttread''s `if (!carrier && ISSET(tp->t_state, TS_ISOPEN))'
                ; arm answers EOF to every reader for as long as the pair
                ; lives.
                ;
                ; THE `while ((tp->t_state & TS_CARR_ON) == 0) sleep(...)' that
                ; follows it upstream has no counterpart here on purpose: this
                ; routine already answered EIO for a pair with no master, so
                ; the loop's only exit condition is the one case that cannot
                ; reach this line.  A blocking open is a wider change than
                ; #244, and BUGS in pty(4) records the divergence.
                ; X ACROSS THE KSVC ON THE STACK, which is `_PtyM_Open''s own
                ; idiom five hundred lines up: the service number goes in X on
                ; the way in, so the pair index does not survive.  The first
                ; cut of this restored it with `_Pty_PairFromMinor', which
                ; derives the pair from Y -- and Y is the carrier FLAG by then,
                ; so it recomputed pair 0 from a 1 and clobbered `_shTmp2' on
                ; the way.  It presented as `ptyhup' losing its SIGHUP.
                LDA     _ptyTable+PTYR_TtyOff,X
                STA    |_ptyTmpB2
                PHX
                LDA    |_ptyTmpB2
                LDY     #1                      ; carrier up
                JSR     _PtyKC_Modem
                PLX
                LDA     _ptyTable+PTYR_TtyOff,X
                JSR     _PtyKC_LineOpen
                SEC
                RTL

_PtyS_Close     MX      %00
                JSR     _Pty_PairFromMinor
                ; THE DISCIPLINE IS TOLD FIRST, which is `ptsclose' entire
                ; (tty_pty.c:88-96): l_close takes the discipline off the line,
                ; then `ttyclose' flushes both queues, clears the foreground
                ; group and clears the whole of t_state -- TS_ISOPEN with it.
                ; Both are behind one door, because a driver that made only one
                ; of the two calls would leave the line half shut either way.
                ;
                ; WITHOUT THIS A LINE WAS A RATCHET.  Whatever a session left
                ; unread in t_canq was what the next session's first read(2)
                ; returned, and TS_ISOPEN -- which increment 2 finally made
                ; real -- never came down again.  ptyflush is the witness.
                ;
                ; BEFORE THE FLAG GOES DOWN, so the line is still the one this
                ; session had while the discipline tears it down.
                PHX
                LDA     _ptyTable+PTYR_TtyOff,X
                LDY     #0                      ; flag: the ordinary, draining
                                                ;   close.  FNDELAY is the fd's
                                                ;   and the chardev close op is
                                                ;   handed a minor and nothing
                                                ;   else -- see include/ktty.s.
                JSR     _PtyKC_LineClose
                PLX
                LDA     _ptyTable+PTYR_Flags,X
                AND     #$FFFF-PTYF_SOPEN
                STA     _ptyTable+PTYR_Flags,X
                JSR     _Pty_MaybeReset
                JSR     _Pty_Wake               ; master read sees EOF after drain
                SEC
                RTL

_PtyS_Read      MX      %00
                ; THE PREMISE THAT STOOD HERE WAS FALSE, and apple/fgx#198 (3)
                ; is the record of it.  It read "unreachable: _Sys_Read detours
                ; slave fds into the shared discipline BEFORE the chardev read
                ; loop" -- true of the registry road, and the vnode route does not
                ; go through `_Sys_Read' at all.  `spec_chread' found no
                ; `d_read' on this line, fell to its per-byte loop, and every
                ; slave read through a device node arrived HERE and got EIO.
                ;
                ; `_PtyS_DRead' below is the slot that was empty.  This op is
                ; COPS_Getc, which is a different question -- FGX's per-byte
                ; device primitive, not `d_read' -- and with the bulk slot
                ; filled nothing reaches it by either road.
                ;
                ; IT STAYS, AND LOUD, which is this file's habit for a retired
                ; path: `_PtyS_Write's `@sw_go' says why.  Zeroing the slot
                ; would be worse than useless here -- COPS_Getc has no
                ; absent-slot test (`_Chardev_Read' dispatches straight through
                ; `_Chardev_Dispatch'), so an empty one is a JSL to offset 0 of
                ; the module's bank rather than a refusal.
                LDA     #EIO
                CLC
                RTL

;------------------------------------------------------------------------------
; _PtyS_DRead / _PtyS_DWrite - cdevsw's d_read and d_write for the pty SLAVE:
; `ptsread' and `ptswrite'.  apple/fgx#198 (3).
;
;     ptsread(dev, uio, flag)                ptswrite(dev, uio, flag)
;     {   ...                                {
;         } else                                 tp = &pt_tty[minor(dev)];
;             if (tp->t_oproc)                   if (tp->t_oproc == 0)
;                 error = (*linesw[tp->t_line]           return (EIO);
;                     .l_read)(tp, uio, flag);   return ((*linesw[tp->t_line]
;         ptcwakeup(tp, FWRITE);                     .l_write)(tp, uio, flag));
;         return (error);                    }
;     }
;
; -- vendor/2.11BSD/usr/sys/sys/tty_pty.c:100 and :146.
;
; `tp->t_oproc' IS PTYF_MOPEN HERE.  A slave line's `t_oproc' is `ptsstart',
; installed by `ptcopen' and cleared by `ptcclose' (KSVC_TTYPTYOPROC since T4
; increment 4), so "the master is open" and "the line has an oproc" are the
; same fact -- and the driver already keeps it as a flag, which `_PtyS_Write'
; and `_PtyM_DRead' both test.
;
; THE TWO DIRECTIONS DISAGREE ABOUT A CLOSED MASTER, and that is upstream's
; choice rather than one made here: a READ returns 0 -- `error' never left 0
; and nothing moved, which read(2) reports as END OF FILE -- while a WRITE
; returns EIO.  Reversing either would make a slave with no master hang or lose
; bytes in silence.
;
; PF_REMOTE IS NOT PORTED, which T4 increment 6 DECLARED rather than dropped
; (`279f64941'): remote mode needs a record boundary the write path does not
; have.  Its arm is the whole first half of `ptsread' and is absent with it.
;
; `ptcwakeup(tp, FWRITE)' IS `_Pty_Wake'.  The read drained `t_rawq', so a
; master parked at TTYHOG inside `_PtyM_Write' can go on -- and a master
; select()ing for write is waiting on the same answer.  It is on the READ side
; only, exactly as upstream has it.
;
; In:  Y = minor.  Frame: 9,S uio offset, 11,S uio bank, 13,S flag.
; Out: C=1 success, or C=0 + A = errno.
;------------------------------------------------------------------------------
_PtyS_DRead     MX      %00
                JSR     _Pty_PairFromMinor      ; X = pair record offset
                LDA     _ptyTable+PTYR_Flags,X
                AND     #PTYF_MOPEN
                BNE     @sdr_go
                LDA     #0                      ; no master: EOF -- success,
                SEC                             ;   nothing moved
                RTL
@sdr_go         LDY     #UIO_READ
                JSR     @sd_args                ; -> A = uio off, Y = packed
                BCC     @sd_err                 ;    A = EINVAL
                JSR     _PtyKC_TtyRead          ; A = errno
                PHA                             ; _Pty_Wake preserves A, but the
                JSR     _Pty_Wake               ;   errno is the return value and
                PLA                             ;   is not left to a convention
                BRA     @sd_done

_PtyS_DWrite    MX      %00
                JSR     _Pty_PairFromMinor
                LDA     _ptyTable+PTYR_Flags,X
                AND     #PTYF_MOPEN
                BNE     @sdw_go
                LDA     #EIO                    ; `if (tp->t_oproc == 0)'
                CLC
                RTL
@sdw_go         LDY     #UIO_WRITE
                JSR     @sd_args
                BCC     @sd_err
                JSR     _PtyKC_TtyWrite
@sd_done        CMP     #0                      ; an errno either side of the
                BNE     @sd_err                 ;   KSVC; a chardev op answers
                SEC                             ;   in the CARRY
                RTL
@sd_err         CLC
                RTL

;------------------------------------------------------------------------------
; @sd_args - the two ops' shared argument build: assert the frame, then pack it
; into the one A and one Y a KSVC has.
;
; In:  Y = the uio_rw this op is (UIO_READ / UIO_WRITE), X = pair record offset.
; Out: C=1, A = the uio's offset, Y = (uio bank << 8) | ndelay<<7 | tty index.
;      C=0 + A = EINVAL if the frame does not read as a uio in that direction.
;
; THE OFFSETS ARE COUNTED, NOT ASSUMED.  The op reads 9/11/13,S; this is JSR'd
; from it (+2) and pushes one word (+2), so it reads 13/15/17,S and drops back
; to 11,S for the last one.  include/chardev.s says the frame reaches an op
; through THREE call instructions, not one, and that a shim which guessed the
; depth is what its first cut got wrong.
;
; AND THE FRAME IS ASSERTED.  A d_read is handed a READ uio by definition, so
; `uio_rw' names the frame -- get the offsets wrong and the pointer handed
; across the KSVC is wild, and `ttread' would then move bytes into a stranger's
; bank.  `_PtyM_DRead's header records why the WEAK form of this proves
; nothing: a trial arm given the offset deliberately wrong by two stayed green,
; because the wild read returned zero and zero is UIO_READ.  Y carrying the
; direction is what makes the write half discriminate.
;------------------------------------------------------------------------------
@sd_args        PHY                             ; the expected uio_rw
                LDA     13,S                    ; the uio's offset
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     15,S                    ; the uio's bank.  8-BIT: the
                STA     _libcTmp2+2             ;   cell is THREE bytes wide
                REP     #$30
                MX      %00
                LDY     #UIO_RW
                LDA     [_libcTmp2],Y
                CMP     1,S
                BEQ     @sda_ok
                PLY
                LDA     #EINVAL
                CLC
                RTS

                ; --- the pack.  The tty travels as an INDEX because a
                ; TTY_SIZE-scaled offset does not fit beside the bank byte;
                ; include/modules.s states that at KSVC_TTYOUTQUIO, and the
                ; spare top bit carries the one flag there is.
@sda_ok         LDA     _ptyTable+PTYR_TtyIdx,X
                AND     #$007F
                STA     1,S                     ; reuse the pushed word
                LDA     17,S                    ; the op's `flag'
                AND     #VFS_IO_NDELAY
                BEQ     @sda_pack
                LDA     1,S
                ORA     #$0080
                STA     1,S
@sda_pack       LDA     15,S                    ; the uio's bank again
                AND     #$00FF
                XBA                             ; -> Y's high byte
                ORA     1,S
                TAY
                PLA                             ; drop the staged word
                LDA     11,S                    ; the uio's offset
                SEC
                RTS

_PtyS_Write     MX      %00
                ; A = byte, X = flag.  Slave output discipline: ONLCR per the
                ; slave tty's CRMOD (cooked LF -> CR+LF, ttyv's
                ; analog), then append the OutRing.  EIO once the master is
                ; gone.
                STX     _ptyNbFlag
                STA     _ptyTmpB2
                JSR     _Pty_PairFromMinor
                LDA     _ptyTable+PTYR_Flags,X
                AND     #PTYF_MOPEN
                BNE     @sw_go
                LDA     #EIO
                CLC
                RTL
                ; ONLCR IS THE DISCIPLINE'S NOW -- apple/fgx#108 T3 stage 3, and
                ; the same deletion `_Ttyv_Write' took for the same reason.  The
                ; slave's putc is driven only by `tty_oproc' draining `t_outq',
                ; and `ttyoutput' has already turned LF into CR+LF on the way
                ; in.  Mapping again here sent CR CR LF down the pty to
                ; telnetd, which is what `ttypeneg' saw as corrupted text.
@sw_go          ; UNREACHABLE SINCE T4 INCREMENT 4.  This op existed to be
                ; called by `tty_oproc' draining `t_outq' into the pair's out
                ; ring -- its own header above says the slave's putc is driven
                ; only by that.  A pty slave line's `t_oproc' is `ptsstart'
                ; now, which moves no data, so the discipline never hands this
                ; a run and the ring it fed is not read by anything.
                ;
                ; FAIL LOUD rather than delete, which is what `_PtyS_Read' does
                ; two hundred lines up and for the same reason: a path that
                ; quietly appends to a buffer nobody drains loses bytes and says
                ; nothing.  If something reaches here, it is a route this
                ; increment did not know about and the EIO names it.
                LDA     #EIO
                CLC
                RTL
                ; `@sw_putblk' STOOD HERE and went with the out ring, T4
                ; increment 7: it appended one byte to the slave->master ring
                ; and slept while it was full.  Its only caller was `@sw_go'
                ; above, which has failed loud since increment 4, so the wait
                ; and its three exits were unreachable with it.
                ;
                ; IT WAS ONE OF apple/fgx#28's THREE SLEEP SITES -- the slave
                ; write on a full out ring.  The other two are live and keep
                ; the fix: `_PtyM_Read's `@mr_wait' and `_PtyM_Write's
                ; `@mw_go'.  `ptyeintr' drives the master read; its `s' mode
                ; drove this one and is gone with it.

_PtyS_Ioctl     MX      %00
                ; sgtty/pgrp cmds were routed to @si_ttyX in syscall.s before
                ; the chardev dispatch; what reaches here: FIONBIO and
                ; TIOCGLTC/TIOCSLTC (store/return only — telnet mode()).
                ;
                ; TIOCFLUSH IS NOT ONE OF THEM ANY MORE, and upstream never
                ; answered it in the pty driver either: `ptyioctl's master
                ; switch has no arm for it, so it falls through to
                ; `ttioctl' -> `ttyflush(tp, rw)' -> `(*d_stop)(tp, rw)', which
                ; is where `pt_send' gets its flush bits.  The arm that used to
                ; be here dropped the pair's ring cursors and set a hand-rolled
                ; FLUSHPEND bit -- and since increment 4 the out ring is not fed
                ; at all, so it announced a flush that discarded nothing
                ; (apple/fgx#239).  Answering ENOTTY is what routes it: only
                ; ENOTTY falls through in `_Io_CdThenTty' (syscall.s).
                JSR     _Pty_PairFromMinor
                LDA     _Sys_IoctlCmd
                CMP     #FIONBIO
                BEQ     @si2_nbio
                CMP     #TIOCGLTC
                BEQ     @si2_gltc
                CMP     #TIOCSLTC
                BEQ     @si2_sltc
                LDA     #ENOTTY
                CLC
                RTL
@si2_nbio       JSR     _Pty_ArgWord
                JMP     _Pty_SetNB
@si2_gltc       ; ltchars round-trip: 6 bytes from the per-pair store
                JSR     _Pty_LtcPtr
                LDY     #0
@si2_gL         SEP     #$20
                MX      %10
                LDA     _ptyLtc,X
                STA     [_libcTmp2],Y
                REP     #$20
                MX      %00
                INX
                INY
                CPY     #6
                BCC     @si2_gL
                SEC
                RTL
@si2_sltc       JSR     _Pty_LtcPtr
                LDY     #0
@si2_sL         SEP     #$20
                MX      %10
                LDA     [_libcTmp2],Y
                STA     _ptyLtc,X
                REP     #$20
                MX      %00
                INX
                INY
                CPY     #6
                BCC     @si2_sL
                SEC
                RTL

_PtyS_Poll      MX      %00
                JSR     _Pty_PairFromMinor
                LDA     #0
                STA     _ptyTmpB2
                ; READABLE IS THE DISCIPLINE'S ANSWER TOO, and for the same
                ; reason the WRITABLE arm below already is.  This asked
                ; `PTYR_InCount' -- and T6 increment 4a stopped feeding that
                ; ring, so it reads 0 forever and POLLIN was NEVER set, while
                ; the master's bytes sat in `t_rawq' and a read(2) would have
                ; returned them at once.  A select-driven reader on a pty slave
                ; simply went deaf.
                ;
                ; THE EXACT DEFECT `_Ttyv_Poll' WAS WRITTEN TO CURE, one device
                ; over: "select could never report a VC readable -- and a
                ; program that reads ONLY when select says so therefore never
                ; read at all" (src/kernel/ttyv.s).  And the same shape the
                ; WRITABLE arm below had one increment earlier.  THREE TIMES
                ; NOW, always a poll op left reading a ring the increment
                ; underneath it stopped feeding.
                ;
                ; NO FIXTURE SAW IT: `ptyswsel' selects the slave for WRITE and
                ; nothing selected it for READ.  `ptysrsel' is that fixture.
                PHX                             ; the KSVC takes X for its number
                LDA     _ptyTable+PTYR_TtyOff,X
                LDY     #PTY_FREAD
                JSR     _PtyKC_Select           ; A = 1 ready / 0 not
                PLX
                CMP     #0
                BEQ     @sp_nord
                LDA     _ptyTmpB2
                ORA     #POLLIN
                STA     _ptyTmpB2
                BRA     @sp_ckwr
@sp_nord        LDA     _ptyTable+PTYR_Flags,X
                AND     #PTYF_MOPEN
                BNE     @sp_ckwr                ; no data, master alive -> not rd
                ; NO MASTER AND NO DATA IS EOF, and EOF IS READABLE -- a reader
                ; must be told to come and collect the zero.  Unchanged from the
                ; ring version, which reached here the same way.
                LDA     _ptyTmpB2
                ORA     #POLLIN
                STA     _ptyTmpB2
@sp_ckwr        ; WRITABLE IS THE DISCIPLINE'S ANSWER, not the ring's.  This
                ; asked `PTYR_OutCount < PTY_RING_SZ' -- and T4 increment 4
                ; stopped feeding that ring, so it read 0 forever and POLLOUT
                ; was set unconditionally while `ttwrite' still slept at the
                ; high watermark.  A select that promises a write which then
                ; blocks is the one thing select exists to prevent, and it said
                ; nothing.  `ttyselect's FWRITE arm is
                ; `t_outq.c_cc <= TTLOWAT(tp)' -- the queue that holds the
                ; bytes.  `ptyswsel' measured the old answer: 656 bytes queued,
                ; `ttwrite' refusing with EWOULDBLOCK, and select still saying
                ; writable.
                ;
                ; THE SAME SHAPE `_PtyM_Poll' HAD one increment ago, which is
                ; why the fix is the same door.
                PHX                             ; the KSVC takes X for its number
                LDA     _ptyTable+PTYR_TtyOff,X
                LDY     #PTY_FWRITE
                JSR     _PtyKC_Select           ; A = 1 ready / 0 not
                PLX
                CMP     #0
                BEQ     @sp_done
                LDA     _ptyTmpB2
                ORA     #POLLOUT
                STA     _ptyTmpB2
@sp_done        LDA     _ptyTmpB2
                SEC
                RTL

;------------------------------------------------------------------------------
; _PtyS_Stop - cdevsw's d_stop for a pty SLAVE line.  `ptsstop(tp, flush)',
; 2.11BSD usr/sys/sys/tty_pty.c:297-318.  T4 increment 5.
;
; In:  Y = minor, X = rw (the `flush' argument).  Out: C=1, always.
;
; THIS SLOT WAS ZERO UNTIL NOW and the comment beside it said why -- "a pty
; ring is not in flight".  That was true while `tty_oproc' drained `t_outq'
; into the pair's own ring on every `ttstart'.  INCREMENT 4 ENDED IT: `t_oproc'
; for a pty slave is `ptsstart', which moves no data, so the slave's output
; waits in the discipline's queue and the line has output in flight exactly as
; a serial line does.
;
; IT MOVES NO DATA EITHER, and that is upstream's shape rather than an
; omission: `ttyflush' has already cleared TS_TTSTOP and is about to drain
; `t_outq' itself (tty.c:179), so all this owes is the RECORD -- which of the
; TIOCPKT_* bits the master is now owed.
;
; `flush' IS THE FREAD/FWRITE MASK AND ITS BITS ARE THE PACKET BITS.  FREAD is
; 1 and TIOCPKT_FLUSHREAD is 1; FWRITE is 2 and TIOCPKT_FLUSHWRITE is 2, so the
; mask ORs straight in.  Upstream's own comment there is the deciding line:
;
;       /* note: FLUSHREAD and FLUSHWRITE already ok */
;
; and `flush == 0' is the other caller -- `ttstop' and `ttioctl's TIOCSTOP arm,
; which have set TS_TTSTOP and want the master TOLD.
;
; A PLAIN STOP DOES NOT WAKE THE MASTER, and that is upstream's arithmetic
; followed rather than an oversight.  The wake takes the flush mask with the
; two directions SWAPPED -- a flush of the slave's input is news for the
; master's write side -- and TIOCPKT_STOP is $04, which has neither bit, so
; `ptcwakeup(tp, 0)' does nothing.  A sleeping master learns of the stop on its
; next wake; `ptsstart' is what wakes it, because a restart is what it can act
; on.  FGX's `_Pty_Wake' is one channel for every pty waiter, so the swap
; collapses to "wake at all or not" -- the sleepers re-test either way.
;------------------------------------------------------------------------------
_PtyS_Stop      MX      %00
                PHX                             ; rw; _Pty_PairFromMinor takes X
                JSR     _Pty_PairFromMinor      ; X = pair record offset
                PLA                             ; A = `flush'
                CMP     #0                      ; upstream tests the WHOLE word,
                BNE     @ss_flush               ;   not a mask: `if (flush == 0)'
                LDA     _ptyTable+PTYR_Flags,X  ; `pt_flags |= PF_STOPPED'
                ORA     #PTYF_STOPPED
                STA     _ptyTable+PTYR_Flags,X
                LDA     #TIOCPKT_STOP           ; `flush = TIOCPKT_STOP'
                BRA     @ss_send
@ss_flush       PHA
                LDA     _ptyTable+PTYR_Flags,X  ; `pt_flags &= ~PF_STOPPED'
                AND     #$FFFF-PTYF_STOPPED
                STA     _ptyTable+PTYR_Flags,X
                PLA
@ss_send        PHA                             ; the LOCAL flush: the wake is
                ORA     _ptyTable+PTYR_Send,X   ;   computed from it and not
                STA     _ptyTable+PTYR_Send,X   ;   from what pt_send already
                PLA                             ;   carried.  `pt_send |= flush'
                AND     #TIOCPKT_FLUSHREAD+TIOCPKT_FLUSHWRITE
                BEQ     @ss_done                ; a plain stop wakes nobody
                JSR     _Pty_Wake
@ss_done        SEC
                RTL

; _Pty_ArgWord: A = *ioctl arg (16-bit read from caller bank).  Stages
; _libcTmp2 as a side effect (reused by ltc copy loops).  Clobbers Y.
_Pty_ArgWord    MX      %00
                PHA
                LDA     _Sys_IoctlArgLo
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_IoctlArgBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                PLA
                LDA     [_libcTmp2]
                RTS

; _Pty_LtcPtr: X = pair off -> X = ltc store offset (pair*6); also stages
; _libcTmp2 from the ioctl arg.  Clobbers A,Y.
_Pty_LtcPtr     MX      %00
                JSR     _Pty_ArgWord            ; stages _libcTmp2 (value unused)
                CPX     #0
                BEQ     @lp_p0
                LDX     #6
                RTS
@lp_p0          LDX     #0
                RTS

; _Pty_SetNB: A = *arg (0/nonzero) -> set/clear FCB_CDF_NONBLK on [_fcbPtr].
; RTLs (shared ioctl tail for both sides).
_Pty_SetNB      MX      %00
                CMP     #0                      ; A = *arg from _Pty_ArgWord
                BEQ     @nb_clr
                SEP     #$20
                MX      %10
                LDY     #FCB_CdFlags
                LDA     [_fcbPtr],Y
                ORA     #FCB_CDF_NONBLK
                STA     [_fcbPtr],Y
                REP     #$20
                MX      %00
                SEC
                RTL
@nb_clr         SEP     #$20
                MX      %10
                LDY     #FCB_CdFlags
                LDA     [_fcbPtr],Y
                AND     #$FF-FCB_CDF_NONBLK
                STA     [_fcbPtr],Y
                REP     #$20
                MX      %00
                SEC
                RTL

;------------------------------------------------------------------------------
; _Pty_PktSend - X = pair record offset -> A = `pt_send'.  X preserved.
;
; `ptsstart's PACKET-MODE ARM, EVALUATED HERE (T4 increment 5b):
;
;       if (pti->pt_flags & PF_STOPPED) {
;               pti->pt_flags &= ~PF_STOPPED;
;               pti->pt_send = TIOCPKT_START;
;       }
;
; Upstream runs it in `ptsstart' (tty_pty.c:163-175), the line's `t_oproc'.
; FGX's `ptsstart' is in the TTY BANK -- `t_oproc' is a pointer inside
; `struct tty' and a pointer cannot cross a bank -- and `pt_flags'/`pt_send'
; are here, so the two halves of that body are in different banks and the
; second one cannot follow the first.
;
; THE CONDITION IS THE SAME TWO FACTS, asked at the other end: PF_STOPPED,
; which `_PtyS_Stop' recorded when the line was stopped, AND TS_TTSTOP being
; clear, which is what `ptsstart' being CALLED means (`ttstart' clears it
; first).  `kc_ttstopped' carries that bit across.  `pt_send' has no consumer
; but this driver -- `ptcread' delivers it and `ptcselect' asks whether it is
; set -- so evaluating it at the ask rather than at the event is not observable
; anywhere, and the WAKE still happens eagerly: `ptsstart' calls `kc_ptywake',
; so a master parked in read(2) is woken by the restart exactly as upstream's
; `ptcwakeup(tp, FREAD)' wakes it, and finds the byte when it re-tests.
;
; THE ASSIGNMENT IS UPSTREAM'S, not an OR: a restart REPLACES a pending STOP,
; because the two describe the same line and the later one is true.
;
; EVERY KSVC DESTROYS X, so the pair offset is pushed around the call.  It cost
; a whole diagnosis on 2026-08-26 not to.
;------------------------------------------------------------------------------
_Pty_PktSend    MX      %00
                LDA     _ptyTable+PTYR_Flags,X
                AND     #PTYF_STOPPED
                BEQ     @pk_done                ; never stopped: nothing to arm
                PHX
                LDA     _ptyTable+PTYR_TtyOff,X
                JSR     _PtyKC_Stopped          ; A = 1 stopped / 0 running
                PLX
                CMP     #0
                BNE     @pk_done                ; still stopped: not yet
                LDA     _ptyTable+PTYR_Flags,X
                AND     #$FFFF-PTYF_STOPPED
                STA     _ptyTable+PTYR_Flags,X
                LDA     #TIOCPKT_START
                STA     _ptyTable+PTYR_Send,X
@pk_done        LDA     _ptyTable+PTYR_Send,X
                RTS

; `_Pty_FlushRings' STOOD HERE, T6 increment 4a.  With both rings retired it
; was three stores to cursors that no longer exist plus a wake, so its two
; callers keep the wake and drop the rest.

; _Pty_MaybeReset: X = pair off; when BOTH sides are closed, fully reset the
; pair (flags incl. PKT/FLUSHPEND) and detach the slave tty (Backend=0,
; FgPgrp=0) so a reopened pair starts clean.
_Pty_MaybeReset MX      %00
                LDA     _ptyTable+PTYR_Flags,X
                AND     #PTYF_MOPEN+PTYF_SOPEN
                BNE     @rz_no
                STZ     _ptyTable+PTYR_Flags,X
                STZ     _ptyTable+PTYR_Send,X
                JSR     _Pty_Wake               ; was `_Pty_FlushRings': the
                                                ;   rings are gone and the wake
                                                ;   is what is left of it
                PHX
                LDA     _ptyTable+PTYR_TtyOff,X
                TAX
                STZ     _ttyTable+TTY_Backend,X
                ; t_pgrp is in the TTY BANK since T3 stage 1c, and a module
                ; reaches the core through SYS_KCALL -- NOT by JSL to an
                ; exported address, which carries the assembly-time bank $02.
                ; The group travels in Y because X is the service number.
                TXA                             ; the tty's byte offset
                LDY     #0
                LDX     #KSVC_TTYSETPGRP
                JSL     SYS_KCALL
                PLX
@rz_no          RTS

; _Pty_SlaveTtyInit: X = pair off; install cooked defaults on the slave tty
; (mirrors main.s tty[0] boot values) and point TTY_Backend at this pair:
; Backend = pair record offset + 1 (nonzero sentinel; consumers subtract 1).
_Pty_SlaveTtyInit
                MX      %00
                PHX
                LDA     _ptyTable+PTYR_TtyOff,X
                TAY                             ; Y = tty entry offset
                TXA
                INC                             ; Backend = pair off + 1
                TYX                             ; X = tty entry offset
                STA     _ttyTable+TTY_Backend,X
                JSR     _PtyKC_CookedDef     ; full cooked tty defaults
                ; Window size (apple/fgx#150).  CookedDef seeds every line to
                ; the CONSOLE viewport, which is right for tty[0] and the VCs
                ; and wrong here: a pty's geometry belongs to whatever is on the
                ; far end.  Re-seed to the BSD 80x24 default so a client that
                ; never reports a size still gets the conventional one rather
                ; than the IIgs viewport's 25 rows; telnetd overwrites this from
                ; NAWS as soon as the client answers.
                ; IT IS IN THE TTY BANK since T3 stage 2c, so it comes through
                ; SYS_KCALL like t_pgrp below it -- rows and columns packed into
                ; Y because X carries the service number.  X (the tty offset) is
                ; the selector's casualty, so it goes on the stack and comes
                ; back as the next call's argument.
                PHX
                TXA                             ; the tty's byte offset
                LDY     #80*256+24              ; ws_col high, ws_row low
                LDX     #KSVC_TTYWINSZ
                JSL     SYS_KCALL
                PLA                             ; the tty's byte offset
                LDY     #0                      ; the group; X is the SELECTOR
                LDX     #KSVC_TTYSETPGRP
                JSL     SYS_KCALL
                PLX
                RTS

pty_end         EQU     *

;==============================================================================
; END pty.s (module)
;==============================================================================
