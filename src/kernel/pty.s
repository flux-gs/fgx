;==============================================================================
; pty.s - what the pty pair driver leaves in the CORE BANK.
;
; THE DRIVER ITSELF IS src/modules/pty/pty.s, an FGXM module.  It moved out of
; the core bank 2026-08-11, taking ~1.4 KB with it.  Its header carries the
; behavioural documentation; this file is the seam.
;
; WHAT STAYS HERE, and why each one has to:
;   - the pair table, both rings and the scratch cells.  They are kernel-bank
;     statics and the module's ops run at DBR = kernel bank, so every
;     DBR-relative access over there reads them exactly as it did in-kernel --
;     which is what let the bodies move verbatim.
;   - _Pty_Init, because main.s calls it at boot, long before Mod_LoadConf.
;     An initialiser for core-bank data belongs with the data.
;   - _Tty_CookedDefaults: tty state, not pty state.  main.s (tty[0]) and
;     ttyv.s call it, so it cannot live in a module that may not be loaded.
;   - the two chardev ops tables and the four names, because
;     _Chardev_InitBuiltins registers them at boot, before any module exists.
;
; HOW THE CALL CROSSES.  chardev.s dispatches an op by loading the table's
; 3-byte entry into a JSL trampoline operand -- so the twelve ops were ALREADY
; JSL/RTL shaped and needed no stub.  _Pty_LoadOpsPtr simply rewrites the
; twelve entries with the module's real 24-bit addresses.  chardev.s and
; _Chardev_InitBuiltins are untouched by the migration.
;
; NO ROUTINE NEEDS A STUB ANY MORE.  `_Pty_InGetNB' and `_Pty_OutPut' were the
; two syscall.s JSRed through inline self-modified JSL sites here (the ramdisk
; seam -- an inline JSL needs no bank-0 vector, so no gateway space is spent),
; and both went with their rings, at T6 increment 4a and T4 increment 7.
;
; WITH NO pty.mod the tables still point at _Pty_NoDev: opening a pty gives
; ENXIO, which is what a machine with no pty driver should say.  Nothing else
; in the system degrades.
;
; State is EXPLICITLY zeroed at boot by _Pty_Init: DS regions are NOT
; guaranteed zero in RAM (the P1b lesson).
;==============================================================================

;------------------------------------------------------------------------------
; storage (kernel-bank statics; zeroed by _Pty_Init)
;------------------------------------------------------------------------------
_ptyTable       DS      PTY_NPAIR*PTYR_SIZE
; BOTH RING BUFFERS STOOD HERE -- `_ptyInRings' and `_ptyOutRings', 256 BYTES
; OF THE CORE BANK EACH -- and both are gone: the out half at T4 increment 7,
; the in half at T6 increment 4a.  A pty's bytes are the discipline's now in
; both directions, `t_outq' since increment 4 and `t_rawq' since the 4a flip
; fed `ttyinput' at arrival.

;------------------------------------------------------------------------------
; _Pty_Init - boot init: zero ALL pty state (DS regions are not zero in RAM)
; and bake the per-pair tty linkage.  Called from FGX_Entry after the tty
; table zeroing.  MX %00.
;------------------------------------------------------------------------------
_Pty_Init       ENT
                MX      %00
                LDX     #PTY_NPAIR*PTYR_SIZE-2
@pi_zt          STZ     _ptyTable,X
                DEX
                DEX
                BPL     @pi_zt
                ; pair 0 -> tty[1], pair 1 -> tty[2]
                LDA     #1
                STA     _ptyTable+PTYR_TtyIdx
                LDA     #TTY_SIZE
                STA     _ptyTable+PTYR_TtyOff
                LDA     #2
                STA     _ptyTable+PTYR_SIZE+PTYR_TtyIdx
                LDA     #TTY_SIZE*2
                STA     _ptyTable+PTYR_SIZE+PTYR_TtyOff
                ; The bulk-read statics.  _ptyVfsBank in particular: it is the
                ; "vfs.mod resolved" flag the bulk op tests before it calls
                ; through _ptyVfsUiomove, and a DS region is not zero in RAM.
                STZ     _ptyVfsBank
                STZ     _ptyVfsUiomove
                STZ     _ptyPktByte
                STZ     _ptyDrN
                STZ     _ptyDrRun
                RTS

_ptyTmpB        DS      2
_ptyTmpR        DS      2


;------------------------------------------------------------------------------
; shared internals
;------------------------------------------------------------------------------
_ptyTmpB2       DS      2
_ptyTmpB3       DS      2
_ptyTmpN        DS      2

;------------------------------------------------------------------------------
; The BULK READ path's statics (apple/fgx#198, TTY campaign T2.2b).
;
; KERNEL STATICS, NOT MODULE DATA, and that is forced rather than chosen:
; pty.mod has no data of its own and runs at DBR = the kernel bank, which the
; head of src/modules/pty/pty.s states and tools/check_module_data_refs.py
; enforces (apple/fgx#93).  Every other byte of pty state is here for the same
; reason.
;
; ONE IMPORTED ENTRY, NOT A VFSCORE_COUNT TABLE.  ufs.mod copies the whole
; VFSCORE vtable into a VFSCORE_COUNT*2 destination because it calls a dozen of
; them; this module calls exactly ONE, uiomove, so it stores exactly one
; address and 74 bytes of a scarce kernel-data region stay unspent.  DO NOT
; "fix" this into a subset-sized copy of the whole vtable: a partial
; destination fed to a whole-table copy loop is a measured overrun.  A
; single-entry resolve reads the slot it wants and stores that.
;
; _ptyVfsBank IS THE RESOLVED FLAG.  Zero means the resolve never ran or
; failed, and the bulk op refuses rather than JSLing into bank zero.  _Pty_Init
; zeroes it explicitly, because a DS region is not zero in RAM -- the P1b
; lesson this file's own header states.
_ptyVfsBank     DS      2               ; low byte = vfs.mod's live bank
_ptyVfsUiomove  DS      2               ; uiomove's offset within that bank
; The packet-mode prefix byte, as a one-byte REGION.  uiomove takes an address
; and a byte in a register does not have one, so the prefix needs somewhere to
; live for the length of one call.  Not live across a sleep: it is written and
; consumed inside the delivery, after the wait has already ended.
_ptyPktByte     DS      2
; The bulk read's own scratch: the byte count it settled on, and the
; length of the run it is currently handing to uiomove.  DEDICATED rather
; than borrowed from _ptyTmpB/_ptyTmpR, which the ring helpers own, and
; from _ptyTmpB2/_ptyTmpB3, which _Pty_Uio1 uses to stage its arguments.
; Neither is live across a sleep: the wait has already ended by the time
; either is written.
_ptyDrN         DS      2
_ptyDrRun       DS      2
; _ptyNbFlag -- the per-byte op's `flag' argument (VFS_IO_NDELAY), staged from
; X at op entry because _Pty_PairFromMinor wants X for the pair index.
;
; IT REPLACES A READ OF [_fcbPtr], and that read was wrong twice over
; (apple/fgx#198).  It named an FCB the op's signature never mentions -- the
; WRONG one on the /dev route, where the namei walk lies between _Fcb_Alloc and
; the driver's open -- and it happened AFTER a sleep, so on the syscall route it
; could see whatever descriptor another task's syscall had just resolved into
; that shared direct-page cell.
;
; SAVED AND RESTORED ACROSS EVERY SLEEP that can reach it, like _ptyTmpB2/B3
; beside it: a static staged before a wait and read after one is apple/fgx#89
; whatever it holds.
_ptyNbFlag      DS      2
; MASTER chardev idxs, same $FFFF-until-registered discipline (apple/fgx#150).
; Only the WINDOW SIZE pair is routed from a master to its slave's tty entry.
; In BSD the two ends share one `struct tty`, so telnetd's ioctl(pty,
; TIOCSWINSZ) on the master IS a set on the line the child reads; here they are
; separate chardevs, and without this the size a client reports over NAWS has
; nowhere to land -- telnetd holds the master and never the slave.
; Deliberately NOT the whole sgtty set: widening the master's ioctl surface is
; a behaviour change nothing has asked for, and these two are what NAWS needs.
_ptyMasterIdx0  ENT
                DS      2
_ptyMasterIdx1  ENT
                DS      2
_ptyLtc         DS      PTY_NPAIR*6             ; ltchars store (round-trip only)


; _Tty_CookedDefaults: X = tty entry byte offset.  The FULL boot/cooked tty
; default state, shared by main.s (tty[0], X=0) and the pty slave init above
; (code-size dedup 2026-07-27 -- the kernel bank is at its ceiling): sgttyb
; (B9600, erase DEL, kill ^U, ECHO|CRMOD), the 6 tchars, the 6 PACKED ltchars
; bytes (fcc packs char struct members at 1 byte, two per 16-bit store), the
; local-mode word (the CRT bits describe what the cooked discipline already
; does: BS-space-BS erase/kill), and an empty canonical line buffer.
_Tty_CookedDefaults ENT
                MX      %00
                ; The tchars and ltchars images live in the TTY BANK now
                ; (apple/fgx#108 T3 stage 2b): nine stores here became one call,
                ; and the values are upstream's `ttydefaults' (tty.c:216) rather
                ; than a second transcription of them.  X survives -- _Tty_Chars
                ; is register-transparent, which this routine requires.
                ; ONLY ONCE THE BANK IS UP, and the guard is not belt-and-
                ; braces: main.s calls this routine for tty[0] at boot FORTY
                ; LINES BEFORE Tty_Init, so an unguarded JSL here keeps the
                ; assembler's bank byte and lands in ROM with a blank screen --
                ; which is the defect main.s's own Far_Init comment records
                ; having already been fixed once, on the far bank.  main.s
                ; seeds tty[0]'s characters itself the moment Tty_Init returns,
                ; so nothing is skipped: this arm is dead for exactly one call
                ; and that call is covered at the other end.
                ;
                ; The WINDOW SIZE joins them at stage 2c, under the same guard
                ; and for the same reason -- and it takes the same INDEX, so
                ; the conversion is done once for both.  _Tty_SetWinSz
                ; preserves A, which is what lets _Tty_Chars follow it.
                ; The MODE WORD and the SPEEDS follow at stage 2d, and with
                ; them the last of `_ttyTable''s sgtty image.  `t_flags' is ONE
                ; LONG in the bank whose low word is sg_flags and whose high
                ; word is the local mode word -- `ioctl.h:175-189' spells every
                ; L* bit `((int)(BIT>>16))' -- so the two seeds that used to be
                ; six stores apart are one call.  The speeds go with the
                ; characters, in `kc_ttychars', because `tty_pty.c:72-73' puts
                ; them there.
                LDA     _kTtyReady
                BEQ     @tcd_noBank
                PHX
                TXA                             ; the OFFSET, which the flags
                LDX     #SG_ECHO+SG_CRMOD       ;   accessor takes and gives
                LDY     #L_CRTBS+L_CRTERA+L_CRTKIL
                JSR     _Tty_SetFlagsAt         ;   back -- it preserves A
                JSR     _Se_TtyOffToIdx         ; ...and the other two take the
                LDX     #CON_VIS_ROWS
                LDY     #CON_VIS_COLS
                JSR     _Tty_SetWinSz
_ktp077         JSL     KTTY_KC_TTYCHARS        ; slot 13, on _KTty_Chars
                ; NO FLUSH AT OPEN.  2.11BSD's ttyopen() flushes a line that is
                ; opened for the first time only when it is NOT on the new
                ; discipline (`if (tp->t_line != NTTYDISC) ttywflush(tp)',
                ; usr/sys/sys/tty.c), and every FGX line is NTTYDISC
                ; (tty_devinit).  ptsopen() flushes nothing either
                ; (sys/tty_pty.c).  FGX's ported ttyopen (tty/tty.c) already
                ; carries that test, and a line's queues are emptied when it
                ; closes (ttyclose).
                PLX
@tcd_noBank
                RTS

;------------------------------------------------------------------------------
; vtables + names (registered by _Chardev_InitBuiltins).
;
; Every entry starts pointing at _Pty_NoDev and is rewritten by
; _Pty_LoadOpsPtr once pty.mod is loaded.  They must stay HERE, in the core
; bank, because _Chardev_InitBuiltins runs at boot -- long before any module
; exists -- and because a 24-bit pointer into a module cannot be assembled:
; the module's bank is not known until the loader places it.
;------------------------------------------------------------------------------
_PtyMChardev_Ops ENT
                DFB     <_Pty_NoDev,>_Pty_NoDev,^_Pty_NoDev     ; open
                DFB     <_Pty_NoDev,>_Pty_NoDev,^_Pty_NoDev     ; close
                DFB     <_Pty_NoDev,>_Pty_NoDev,^_Pty_NoDev     ; read
                DFB     <_Pty_NoDev,>_Pty_NoDev,^_Pty_NoDev     ; write
                DFB     <_Pty_NoDev,>_Pty_NoDev,^_Pty_NoDev     ; ioctl
                DFB     <_Pty_NoDev,>_Pty_NoDev,^_Pty_NoDev     ; poll
                ; ZERO HERE DOES NOT MEAN "per-byte", because the MASTER is
                ; registered CDF_RECORD (chardev.s:1064).  _Chardev_Bulk
                ; refuses a record device with no d_read rather than telling
                ; the caller to loop, so a bulk read in this window -- before
                ; _Pty_LoadOpsPtr fills the slot from pty.mod -- answers EIO,
                ; not the ENXIO the per-byte stubs above give.  Both are
                ; errors and neither is reachable from userland; said because
                ; the two lines look identical to the slave's below and are
                ; not.
                DFB     0,0,0                                   ; d_read:  until the module lands
                DFB     0,0,0                                   ; d_write: none -- per-byte
                DFB     0,0,0                                   ; d_stop:  nothing in flight

_PtySChardev_Ops ENT
                DFB     <_Pty_NoDev,>_Pty_NoDev,^_Pty_NoDev     ; open
                DFB     <_Pty_NoDev,>_Pty_NoDev,^_Pty_NoDev     ; close
                DFB     <_Pty_NoDev,>_Pty_NoDev,^_Pty_NoDev     ; read
                DFB     <_Pty_NoDev,>_Pty_NoDev,^_Pty_NoDev     ; write
                DFB     <_Pty_NoDev,>_Pty_NoDev,^_Pty_NoDev     ; ioctl
                DFB     <_Pty_NoDev,>_Pty_NoDev,^_Pty_NoDev     ; poll
                DFB     0,0,0                                   ; d_read:  none -- per-byte
                DFB     0,0,0                                   ; d_write: none -- per-byte
                DFB     0,0,0                                   ; d_stop:  until the module
                                                                ;   lands.  ALL NINE SLOTS,
                                                                ;   COPS_SIZE bytes: a table
                                                                ;   one slot short gives
                                                                ;   _Chardev_Stop the next
                                                                ;   label's bytes -- 'pt' of
                                                                ;   'ptyp0' -- as a routine

_PtyName_M0     ENT
                ASC     'ptyp0',00
_PtyName_S0     ENT
                ASC     'ttyp0',00
_PtyName_M1     ENT
                ASC     'ptyp1',00
_PtyName_S1     ENT
                ASC     'ttyp1',00

;==============================================================================
; END pty.s
;==============================================================================

;==============================================================================
; THE SEAM: table patching + the two syscall.s stubs.
;==============================================================================

; `_ptyOpsOK' STOOD HERE and went with the in ring at T6 increment 4a.  It was
; "0 until _Pty_LoadOpsPtr has patched everything" -- a whole byte rather than
; testing an operand, because $000000 is a legal-looking address and "not yet
; resolved" must not be a guess -- and its ONLY readers were the two stub
; routines that guarded their patched JSL sites with it, `_Pty_InGetNB' and
; `_Pty_OutPut'.  Both are retired, so the flag was write-only: set on every
; boot and asked by nothing.  FOUND BY GREPPING FOR THE READER, which is this
; campaign's standing rule and found it in the reverse direction for once --
; deleting the last reader is what leaves a writer dead.
;
; "NO pty.mod" IS STILL ANSWERED, and never needed this cell: the twelve ops
; entries point at `_Pty_NoDev' until the module loads, so opening a pty gives
; ENXIO on its own.

;------------------------------------------------------------------------------
; _Pty_NoDev - what all twelve ops table entries point at until the module
; loads.  ENXIO: the device is registered but has no driver behind it.
; Reached by the chardev JSL trampoline, so it RTLs.
;------------------------------------------------------------------------------
_Pty_NoDev      MX      %00
                LDA     #ENXIO
                CLC
                RTL

;==============================================================================
; _Pty_LoadOpsPtr - resolve pty.mod's VT_CHARDEV vtable, rewrite the twelve
;                   chardev ops entries with real 24-bit addresses, and patch
;                   the two inline JSL sites.  Called once from main.s after
;                   Mod_LoadConf.
;
; In:  none.  MX %00.  DBR = kernel bank.
; Out: C=1 patched, C=0 no VT_CHARDEV module.  A/X/Y, _libcTmp2 clobbered.
;
; The vtable is 16-BIT bank-relative offsets; the bank comes from the registry,
; so the module never self-patches its own table.  Entry order IS the ABI --
; it must match pty_ops in src/modules/pty/pty.s.
;==============================================================================
_Pty_LoadOpsPtr ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                LDA     #VT_CHARDEV
                JSR     Mod_FindVtable          ; C=1: A=voffset, X.lo=bank
                BCC     @plo_none
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                TXA
                STA     _libcTmp2+2             ; module bank
                REP     #$30
                MX      %00
                ; --- read the directory: master ops off, slave ops off ---
                LDY     #0
                LDA     [_libcTmp2],Y
                STA     _ptyTmpB                ; module-relative master COPS
                LDY     #2
                LDA     [_libcTmp2],Y
                STA     _ptyTmpR                ; module-relative slave COPS
                ; --- repoint every chardev entry that was registered with one
                ;     of our stub tables at the module's real table.
                ;
                ; FOUND BY SCANNING, not by remembering indices: the entry whose
                ; ops pointer is _PtyMChardev_Ops IS a pty master, by
                ; construction, and nothing else can carry that value.  A
                ; remembered index would have to be kept in step with
                ; _Chardev_InitBuiltins' registration order forever, and would
                ; go wrong silently.
                ;
                ; CD_OpsBank is what dispatch JSLs through -- it does NOT use
                ; the bank byte inside the ops table -- so this is the ONLY
                ; place the module's bank has to land. ---
                LDX     #0                      ; X = chardev index
@plo_scan       TXA
                ASL     A
                ASL     A
                ASL     A
                STA     _ptyTmpB2               ; idx*8
                ASL     A
                CLC
                ADC     _ptyTmpB2               ; idx*24 = CD_REC_STRIDE
                CLC
                ADC     #CD_OpsLo
                TAY                             ; Y = entry_off + CD_OpsLo
                LDA     [_cdTablePtr],Y
                CMP     #_PtyMChardev_Ops
                BEQ     @plo_master
                CMP     #_PtySChardev_Ops
                BNE     @plo_next
                LDA     _ptyTmpR                ; slave
                BRA     @plo_set
@plo_master     LDA     _ptyTmpB
@plo_set        STA     [_cdTablePtr],Y         ; CD_OpsLo = module-relative
                INY
                INY                             ; Y = entry_off + CD_OpsBank
                SEP     #$20
                MX      %10
                LDA     _libcTmp2+2
                STA     [_cdTablePtr],Y         ; CD_OpsBank = the module's bank
                REP     #$30
                MX      %00
@plo_next       INX
                CPX     #CHARDEV_MAX
                BCC     @plo_scan
                ; --- NO STUB SITES LEFT TO PATCH.  Directory entries +4 and
                ;     +6 are both RETIRED -- +6 carried `_Pty_OutPut_RTL' (T4
                ;     increment 7), +4 carried `_Pty_InGetNB_RTL' (T6 increment
                ;     4a) -- and the module still ships ZEROS in both rather
                ;     than closing the gap.  BE HONEST ABOUT WHAT THAT BUYS
                ;     TODAY: this reader takes its entries at FIXED OFFSETS, but
                ;     +4 and +6 are the LAST two, so removing them would slide
                ;     nothing now.  The zeros keep the rule true for the next
                ;     entry appended at +8, which WOULD slide.  They are the
                ;     convention, not the load-bearing part. ---
                REP     #$30
                MX      %00
                PLP
                SEC
                RTS
@plo_none       PLP
                CLC
                RTS

;==============================================================================
; `_Pty_InGetNB' AND `_ptyInGetSite' STOOD HERE, T6 increment 4a -- as
; `_Pty_OutPut' and its own patched JSL site did until T4 increment 7.  They
; were the core's two doors into the module's ring helpers, self-modified by
; `_Pty_LoadOpsPtr' from the vtable directory's +4 and +6 entries.  Both rings
; are retired, both directory entries are ZEROED (not closed up), and the
; loader reads neither.
;==============================================================================
