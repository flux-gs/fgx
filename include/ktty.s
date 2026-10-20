;==============================================================================
; ktty.s - Tty kernel bank ABI.  Shared by fgx.link.s and fgxtty.link.s.
;
; The tty bank is a THIRD statically linked kernel image, at live kernel bank
; + 2.  Geometry constants (FGX_KTTY_BANK/CODE/DATA) live in kernel.s; this
; file is the calling contract.  See docs/history/plans/tty-kernel-bank.md.
;
; STRUCTURALLY IDENTICAL TO include/kfar.s, deliberately.  The two banks are
; separate link units with separate ceilings, but the mechanism -- a JMP table
; at offset $0000, a core-side JSL whose bank byte is patched at boot, and a
; scraped-offset return path -- is the one the far bank has proven since
; 2026-08-01.  A reader who knows kfar.s knows this file; a reader who does not
; should read kfar.s's commentary, which is the long form of what follows.
;
;------------------------------------------------------------------------------
; THE EXPORT SLOTS ARE `JMP abs16`, NOT `JML`, AND ARE NEVER PATCHED.
;
; A core caller does `JSL <ttybank>:<slot>`.  That JSL sets PBR = tty bank
; BEFORE the slot executes, so a 16-bit JMP inside the slot already lands in
; the right bank.  Only the CALLER's JSL operand bank byte needs patching,
; core-side.
;------------------------------------------------------------------------------

KTTY_MAGIC          EQU     $544B           ; 'KT' -- validity marker
KTTY_ABI_VERSION    EQU     $0001

;------------------------------------------------------------------------------
; THE TABLE SITS AT OFFSET $0000, AND THAT IS FORCED BY THE LINKER.
;
; Merlin32 emits only real bytes: it does NOT pad the gap between two ORGs, so
; anything emitted before `ORG FGX_KTTY_CODE` in ttybank.s prepends itself to
; the image and shifts every slot while the EQUs below do not move.  The far
; bank has been bitten by exactly this once (see include/kfar.s), and the guard
; is the same: tools/check_kernel_ceiling.py asserts the built image OPENS with
; KTTY_MAGIC, because an `ERR` cannot see a file offset.
;------------------------------------------------------------------------------
KTTY_EXPORT_BASE    EQU     $0000           ; export table base (offset in bank)

KTTY_HDR_MAGIC      EQU     KTTY_EXPORT_BASE+$00    ; word: KTTY_MAGIC
KTTY_HDR_ABIVER     EQU     KTTY_EXPORT_BASE+$02    ; word: KTTY_ABI_VERSION
KTTY_HDR_RESERVED   EQU     KTTY_EXPORT_BASE+$04    ; word: reserved, 0

; Slot 42: tty_devbind (C) -- the BINDING half of tty_devinit, run again after
; a module registers a chardev.  /dev/tty01's driver is a module and modules
; load from /etc/rc, long after main.s's one tty_devinit; without this the
; serial line never binds.  Only the binding half is exposed: re-running the
; reset half would clear a live console's discipline.
KTTY_KC_TTYDEVBIND  EQU     KTTY_SLOT0+4*42
; Slots 43 on are the kernel clock's (kern_time.c), a tenant of this bank for
; its room rather than its subject -- docs/history/plans/tty-kernel-bank.md.
; Slot 43: tod_init (C) -- inittodr: the clock from the root's fs_time, then
; the battery clock.  No arguments; called inside KTTY_KC_ENTER/LEAVE, once,
; right after the root is mounted.
KTTY_TOD_INIT       EQU     KTTY_SLOT0+4*43
; Slot 44: _KTty_Gtod -- gettimeofday(2).  A = the argument block's offset,
; X = its bank (the caller's) -> C=1 A=0, or C=0 A=errno.  Sets its own DBR and
; D, as _KTty_Carrier does, so the core calls it bare.
KTTY_TOD_GTOD       EQU     KTTY_SLOT0+4*44
; Slot 45: _KTty_Adj -- adjtime(2), slot 44's shape.  The caller has already
; asked _Suser.
KTTY_TOD_ADJ        EQU     KTTY_SLOT0+4*45
; Slot 46: _KTty_Stod -- settimeofday(2), slot 44's shape: A = the block's
; offset, X = its bank -> C=1 A=0, or C=0 A=errno.  The caller has already
; asked _Suser.
KTTY_TOD_STOD       EQU     KTTY_SLOT0+4*46
; Slot 47: _KTty_Sysctl -- sysctl(2) for a CTL_MACHDEP name, slot 44's shape.
; The C asks the uid itself.
KTTY_TOD_SYSCTL     EQU     KTTY_SLOT0+4*47
; Slot 48: _KTty_Now -- KSVC_TIME's: Y = 0 for UTC, 1 for local -> the
; clock's seconds, A = low word, X = high.  Sets its own DBR and D.
KTTY_TOD_NOW        EQU     KTTY_SLOT0+4*48
; Slots 49-54: shared-library residency (shared libc SP4, ld_hooks.s).  Bare:
; immediates and JSL LD_TRAMP only, no DBR or D of their own.
; Slot 49: SYS_LDCTL's body.  A = service, X/Y = block offset/bank.
KTTY_LD_CTL         EQU     KTTY_SLOT0+4*49
; Slots 50-53: the exit, fork, exec and slot-allocation hooks.  A = the pid;
; X/Y preserved.
KTTY_LD_EXIT        EQU     KTTY_SLOT0+4*50
KTTY_LD_FORK        EQU     KTTY_SLOT0+4*51
KTTY_LD_EXEC        EQU     KTTY_SLOT0+4*52
KTTY_LD_TALLOC      EQU     KTTY_SLOT0+4*53
; Slot 54: reclaim -> C=1 a bank went back to the pool; preserves Y.
KTTY_LD_RECLAIM     EQU     KTTY_SLOT0+4*54
; Slot 55: _KTty_SigHold -- A = a pending signal -> C=1 if it stays pending (a
; stop while the running task still holds its parent).  D = the kernel's real
; page.  Clobbers A, Y.
KTTY_SIG_HOLD       EQU     KTTY_SLOT0+4*55
; Slots 56-62: the shared-text table (src/kernel/tty/text.s), entered by JSL,
; MX %00; each sets its own DBR.
; Slot 56: A = key offset, X = its bank, Y = 16-byte list offset (same bank)
; -> C=1 A = text index, reference taken, banks then pages copied; C=0 not
; loaded.
KTTY_TEXT_FIND      EQU     KTTY_SLOT0+4*56
; Slot 57: A = key offset, X = its bank -> C=1 A = a new entry's index, one
; reference, no segments yet; C=0 (changed this second, or the table is full
; of running texts).
KTTY_TEXT_CLAIM     EQU     KTTY_SLOT0+4*57
; Slot 58: free the least recently used unused text -> C=1 freed, C=0 none.
KTTY_TEXT_RECLAIM   EQU     KTTY_SLOT0+4*58
; Slot 59: A = text index (0 = none): drop one reference.
KTTY_TEXT_UNREF     EQU     KTTY_SLOT0+4*59
; Slot 60: A = parent pid, X = child pid: the child shares and counts the text.
KTTY_TEXT_FORK      EQU     KTTY_SLOT0+4*60
; Slot 61: A = pid, X = its text now (0 = none); the old one is dropped.
KTTY_TEXT_SET       EQU     KTTY_SLOT0+4*61
; Slot 62: A = a claimed index, X = list bank, Y = list offset: 24 bytes, the
; banks, first pages and page counts of its segments.
KTTY_TEXT_FILL      EQU     KTTY_SLOT0+4*62
; Slot 63: vmtotal()'s text sums, in pages -> A = t_vmtxt (= t_rmtxt),
; X = t_avmtxt, Y = t_armtxt.
KTTY_TEXT_TOTAL     EQU     KTTY_SLOT0+4*63
KTTY_SLOT_COUNT     EQU     72              ; reserved from the start, so adding
                                            ;   an export is never a layout change.
                                            ;   32 -> 40 on 2026-08-26 when slot
                                            ;   32 was assigned: the reservation
                                            ;   is not ABI, only the SLOT
                                            ;   ADDRESSES are, and those are
                                            ;   KTTY_SLOT0 + 4n with KTTY_SLOT0
                                            ;   fixed -- so growing it moves
                                            ;   where this bank's CODE starts
                                            ;   and renumbers nothing.  Eight at
                                            ;   a time so the next one is not
                                            ;   another edit here.
KTTY_SLOT0          EQU     KTTY_EXPORT_BASE+$06
KTTY_TABLE_SZ       EQU     $06+4*KTTY_SLOT_COUNT   ; $126 -- code starts above this

;------------------------------------------------------------------------------
; Export slots.  Slot n = KTTY_SLOT0 + 4n.  Unassigned slots JMP to a red-border
; halt (_Ktty_StubHalt): an accidental call must fail loudly, not fall through.
;
; SLOT 0 IS THE INIT ENTRY, for the same reason it is in kfar.s: slots are JMP
; abs16 and are never patched, so the table is correct the moment it is
; assembled and there is no bootstrap ordering problem.
;
; THE TABLE'S SHAPE IS ABI.  Slot addresses are EQUs the core kernel bakes into
; its JSL operands, so a retired export is STUBBED, never removed -- closing a
; gap renumbers every slot above it and a stale caller then lands on a
; different routine instead of on the halt.
;------------------------------------------------------------------------------
KTTY_INIT           EQU     KTTY_SLOT0+4*0  ; slot 0: Tty_BankInit
KTTY_LOG_STATE      EQU     KTTY_SLOT0+4*1  ; slot 1: Tty_LogState

; --- kernel C, slots 2-3 ---
; The slot JMPs STRAIGHT AT the C function, with no wrapper: fcc functions end
; in RTL and read arguments at n,S off a 3-byte return frame, which is exactly
; what the caller's JSL leaves.  A PHB/PHK/PLB shim would insert four bytes
; between the arguments and the callee, so DBR is switched on the CALLING side
; instead -- see KTTY_KC_ENTER in include/kernelc.s.
KTTY_KC_CINIT       EQU     KTTY_SLOT0+4*2  ; slot 2: cinit (C) -- build the
                                            ;   cblock free chain.  No argument:
                                            ;   the pool is a global in the bank.
; slot 3: RETIRED -- held the tty bank's clist probe until
;   2026-09-07.  The slot itself remains, stubbed to
;   _Ktty_StubHalt in ttybank.s: a slot's ADDRESS is its
;   identity, so reusing this number renumbers the table.
KTTY_KC_TTYDEVINIT  EQU     KTTY_SLOT0+4*6  ; slot 6: tty_devinit (C) -- BINDS
                                    ;   every tty device to its struct
                                    ;   tty.  PRODUCTION INIT, not a
                                    ;   probe: it lived inside tty_probe
                                    ;   until the probes were gated and
                                    ;   the default kernel came up with
                                    ;   nothing bound
; slot 5: RETIRED -- held the tty bank's tty probe until
;   2026-09-07.  The slot itself remains, stubbed to
;   _Ktty_StubHalt in ttybank.s: a slot's ADDRESS is its
;   identity, so reusing this number renumbers the table.
; slot 7: RETIRED -- held the tty bank's tty probe until
;   2026-09-07.  The slot itself remains, stubbed to
;   _Ktty_StubHalt in ttybank.s: a slot's ADDRESS is its
;   identity, so reusing this number renumbers the table.
; Half D took the first FREE slot rather than one beside its siblings: slots
; 4, 5 and 7 were assigned when there were three halves, and a slot address is
; baked into the core's JSL operands, so renumbering to keep the family tidy
; would be an ABI change for cosmetics.
; slot 18: RETIRED -- held the tty bank's tty probe until
;   2026-09-07.  The slot itself remains, stubbed to
;   _Ktty_StubHalt in ttybank.s: a slot's ADDRESS is its
;   identity, so reusing this number renumbers the table.

; --- slot 19: the discipline's READ half (T3 stage 4) ---
; Slot 17's twin, and everything its note says applies unchanged: kernel C,
; because a read(2) arrives from a syscall where no second C context can be
; live, and through `linesw[t_line]' rather than straight at ttread.
;
; HOW MUCH WAS READ COMES OFF THE uio, AND THAT IS NOT COSMETIC.  `uio_offset'
; starts at 0 and `ureadc' advances it once per delivered byte, so the count
; lives in the caller's own per-task u-area for the whole call.  The obvious
; alternative -- subtracting `uio_resid' from `_Sys_RdMax' afterwards -- reads a
; core-bank singleton that `_Tty_GetByte' does NOT park across its sleep, so a
; task that yielded inside the pump would subtract from whatever another task's
; read(2) left there.  The write half reads its count off the uio for the same
; reason; the read half additionally cannot use the subtraction at all.
KTTY_KC_TTREAD      EQU     KTTY_SLOT0+4*19 ; slot 19: kc_ttread (C) -- errno
                                            ;   back, 0 = success.  How much
                                            ;   moved is uio_offset.
; slot 4: RETIRED -- held the tty bank's tty probe until
;   2026-09-07.  The slot itself remains, stubbed to
;   _Ktty_StubHalt in ttybank.s: a slot's ADDRESS is its
;   identity, so reusing this number renumbers the table.

; --- slots 8-11: the core bank's window onto struct tty (T3 stage 1) ---
; ASSEMBLY entries, not kernel C, and that is the whole reason they exist as
; slots rather than as another kc_ pair: toolbox.s reads the foreground group
; at 60 Hz AT INTERRUPT TIME, and include/kernelc.s makes kernel C a SINGLETON
; -- a second live C context shares its register file and corrupts it.
KTTY_PGRP_GET       EQU     KTTY_SLOT0+4*8  ; slot 8:  A=idx -> A=t_pgrp,  C=1
KTTY_PGRP_SET       EQU     KTTY_SLOT0+4*9  ; slot 9:  A=idx X=pgrp,       C=1
KTTY_FLAGS_GET      EQU     KTTY_SLOT0+4*10 ; slot 10: A=idx -> A=lo X=hi, C=1
KTTY_FLAGS_SET      EQU     KTTY_SLOT0+4*11 ; slot 11: A=idx X=lo Y=hi,    C=1

; --- slot 12: the ioctl (T3 stage 2) ---
; KERNEL C, not assembly, and the split from slots 8-11 is the singleton rule
; again rather than taste: an ioctl arrives from a SYSCALL, where a second live
; C context cannot exist, so this one may be C.  Slots 8-11 are read by
; toolbox.s at interrupt time and may not.
KTTY_KC_TTIOCTL     EQU     KTTY_SLOT0+4*12 ; slot 12: kc_ttioctl (C) -- the
                                            ;   core's door into ttioctl.
                                            ;   0 = handled, -1 = not mine,
                                            ;   >0 = errno

; --- slot 13: the special characters (T3 stage 2b) ---
; `ttychars(tp)' is `tp->t_chars = ttydefaults' and nothing else, so this is
; the tty bank taking over the nine stores `_Tty_CookedDefaults' used to make
; into `_ttyTable'.  Kernel C rather than assembly: every caller of
; _Tty_CookedDefaults is a boot or syscall path, none is interrupt time.
KTTY_KC_TTYCHARS    EQU     KTTY_SLOT0+4*13 ; slot 13: kc_ttychars (C) -- A line
                                            ;   gets the default tchars and
                                            ;   ltchars.  No return value.

; --- slot 14: the interrupt and quit characters (T3 stage 2b) ---
; ASSEMBLY, like slots 8-11 and for a different reason than theirs: this one is
; read PER BYTE WRITTEN TO A PTY MASTER (pty.mod's @mw_disc tests each byte
; against t_intrc and t_quitc before it enters the ring), and a kernel-C
; bracket plus an fcc frame on that path would be paid for every character.
; IT ALSO HANDS BACK THE MODE WORD since stage 2d, in Y, for that same reason:
; `@mw_disc' tests RAW before it tests either character, and Y was the register
; the slot was not already using.
KTTY_INTRQUIT       EQU     KTTY_SLOT0+4*14 ; slot 14: A=idx -> A=t_intrc,
                                            ;   X=t_quitc, Y=sg_flags, C=1.
                                            ;   C=0 on a bad index.

; --- slot 15: the window size (T3 stage 2c) ---
; ASSEMBLY, and the reason is neither of the two above: it is a TWO-WORD STORE,
; so a KTTY_KC_ENTER bracket and an fcc frame would be most of the call.
;
; A SETTER AND NO GETTER, which is the shape of the stage rather than an
; omission.  `t_winsize' has exactly one reader once TIOCGWINSZ belongs to
; `ttioctl', and that reader is ttioctl itself, in this bank.  What still has to
; cross is the SEED: `_Tty_CookedDefaults' gives every line the console
; viewport, and pty.mod re-seeds a slave to the BSD 80x24 default.
KTTY_WINSZ_SET      EQU     KTTY_SLOT0+4*15 ; slot 15: A=idx X=ws_row Y=ws_col,
                                            ;   C=1.  C=0 on a bad index; the
                                            ;   PIXEL fields are not touched.

; --- slot 16: the erase and kill characters (T3 stage 2d) ---
; ASSEMBLY, and per-keystroke like slot 14: the core's canonical line editor
; compares every key against both before it decides the key is data.  ONE call
; for the pair, and the pair comes back in A and Y rather than A and X because
; at that call site X IS THE CALLER'S BUFFER OFFSET -- apple/fgx#224's register.
KTTY_ERASEKILL      EQU     KTTY_SLOT0+4*16 ; slot 16: A=idx -> A=t_erase,
                                            ;   Y=t_kill, C=1.  C=0 on a bad
                                            ;   index.
                                            ;
                                            ; STILL LIVE, and increment 8b
                                            ; nearly retired it by mistake.
                                            ; Its CORE WRAPPER
                                            ; `_Tty_EraseKillAt' really did die
                                            ; with the cooked gather -- but
                                            ; main.s calls THE SLOT directly
                                            ; from `_TtySlotProbe' (`_ktp029'),
                                            ; where it pins `_Tty_Chars' and is
                                            ; the only coverage the erase path
                                            ; has: no fixture sends the Delete
                                            ; key (apple/fgx#229).  Grepping
                                            ; the wrapper's name finds none of
                                            ; that.  GREP THE SLOT.

; --- slot 17: the discipline's WRITE half (T3 stage 3) ---
; KERNEL C, for slot 12's reason exactly: a write(2) arrives from a SYSCALL,
; where no second C context can be live.  It goes through `linesw[t_line]'
; rather than straight at ttwrite, so the switch T2.1 built is load-bearing at
; last.
KTTY_KC_TTWRITE     EQU     KTTY_SLOT0+4*17 ; slot 17: kc_ttwrite (C) -- errno
                                            ;   back, 0 = success.  How much
                                            ;   moved is read off the uio.

; --- slots 20-21: what increment 8b needed before `TTY_CanonBuf' could go ---
; The core kept its own canonical line buffer and four routines flushed a line
; by zeroing its cursor.  The discipline owns the queue now, so those sites ask
; the bank instead.
;
; KERNEL C for both, and each is safe for slot 12's reason: every caller arrives
; from a SYSCALL -- close(2), the pty open, select(2) -- where no second
; kernel-C context can be live.
;
; THE SIGNAL-DELIVERY FLUSH IS NOT ONE OF THEM AND HAS NO SLOT.
; `_Tty_DeliverSig' reaches `_Tty_DrainSigPend', whose header says kernel-DP
; contexts only, and sched.s calls it from the SWITCH path -- kernel C there
; would share its register file with whatever task was interrupted.  That site
; posts `_kTtyFlushPend' and the pump does the flush, which is the machinery
; increment 5 built for the heartbeat's ^C.
KTTY_KC_TTFLUSH     EQU     KTTY_SLOT0+4*20 ; slot 20: kc_ttflush (C) -- A=idx,
                                            ;   X=rw (TTYIO_FREAD/FWRITE).
                                            ;   -> A = errno, 0 = flushed.
KTTY_KC_TTNREAD     EQU     KTTY_SLOT0+4*21 ; slot 21: kc_ttnread (C) -- A=idx
                                            ;   -> A = bytes a read would
                                            ;   return now, 0 = would block.

; SLOTS 22 AND 23 ARE T4 INCREMENT 2's PAIR, and they arrive together because
; carrier without an open signals nobody.  `ttymodem's lost-carrier arm is
; gated on TS_ISOPEN, TS_ISOPEN is set by `ttyopen', and `ttyopen' is `l_open'
; -- which no FGX open path had ever dispatched.  So the bit could not be 1 on
; any line in this kernel, and slot 23 alone would have been a call that
; changed nothing observable.
;
; UPSTREAM CALLS BOTH FROM THE PTY DRIVER: `ptsopen' ends at `l_open'
; (tty_pty.c:88) and `ptcopen'/`ptcclose' bracket the session with `l_modem'
; 1 and 0 (tty_pty.c:214, :228).
KTTY_KC_TTOPEN      EQU     KTTY_SLOT0+4*22 ; slot 22: kc_ttopen (C) -- A=idx
                                            ;   -> A = errno, 0 = opened.
KTTY_KC_TTMODEM     EQU     KTTY_SLOT0+4*23 ; slot 23: kc_ttmodem (C) -- A=idx,
                                            ;   X=flag (1 = carrier up, 0 =
                                            ;   carrier lost).  -> A = 0 if the
                                            ;   line should be turned off.

; SLOT 24 IS SLOT 22's OTHER END.  `ptsclose' calls l_close AND `ttyclose'
; (tty_pty.c:94-95), which are not alternatives: the first takes the discipline
; off the line, the second cleans the line.  Without it TS_ISOPEN never comes
; down and t_canq keeps one session's unread input for the next one.
;
; THE FLAG IS 0, NOT THE FD'S.  FNDELAY decides drain-or-discard in
; `ttylclose', and FGX's chardev close op is handed a minor and nothing else.
KTTY_KC_TTCLOSE     EQU     KTTY_SLOT0+4*24 ; slot 24: kc_ttclose (C) -- A=idx,
                                            ;   X=flag (FNDELAY).  -> A = errno.

; SLOTS 25-28 ARE T4 INCREMENT 4, and they are one mechanism in four pieces:
; the pty's pending output stops being drained into the driver's ring and stays
; in `t_outq' until the master's read pulls it, which is upstream's arrangement
; (`ptsstart' moves no data; `ptcread' does the dequeue).
;
; 26/27/28 ARE `ndqb', `c_cf' AND `ndflush' -- the same three `tty_oproc' uses
; to push a run at a device.  Increment 4 reverses who calls them, so there is
; ONE answer to "what may leave the queue next" rather than two that can drift.
; The offset is a second CALL rather than a second return value: fcc returns a
; long in A and `_fcc_long_hi', and one crossing per RUN is cheaper than a long
; shift on the path (apple/fgx#209 is why that is not a free abstraction).
KTTY_KC_PTYOPROC    EQU     KTTY_SLOT0+4*25 ; slot 25: kc_ptyoproc (C) -- A=idx,
                                            ;   X=on (1 install ptsstart, 0
                                            ;   clear).  -> A = errno.
KTTY_KC_TTOUTQRUN   EQU     KTTY_SLOT0+4*26 ; slot 26: kc_ttoutq_run (C) -- A=idx
                                            ;   -> A = contiguous bytes
                                            ;   available now, 0 = none.
KTTY_KC_TTOUTQCF    EQU     KTTY_SLOT0+4*27 ; slot 27: kc_ttoutq_cf (C) -- A=idx
                                            ;   -> A = that run's offset IN THE
                                            ;   TTY BANK.
KTTY_KC_TTOUTQFLUSH EQU     KTTY_SLOT0+4*28 ; slot 28: kc_ttoutq_flush (C) --
                                            ;   A=idx, X=cc.  -> A = errno.

; SLOT 29 IS THE SAME DEQUEUE, DELIVERED DIFFERENTLY.  FGX has two master-read
; paths: `_PtyM_Read' is the RECORD-mode syscall op and writes to
; `_Sys_CallerBank:_Sys_RdBufOff' (the core's `_Tty_OutqRead' MVNs it), while
; `_PtyM_DRead' is cdevsw's d_read for the /dev vnode route and writes through a
; uio (apple/fgx#198).  The QUEUE work is not duplicated -- both go through
; slots 26 and 28 -- only the delivery does.
KTTY_KC_TTOUTQUIO   EQU     KTTY_SLOT0+4*29 ; slot 29: kc_ttoutq_uio (C) --
                                            ;   A=idx, uio far pointer.
                                            ;   -> A = errno.
; slot 30: RETIRED -- held the tty bank's tty probe until
;   2026-09-07.  The slot itself remains, stubbed to
;   _Ktty_StubHalt in ttybank.s: a slot's ADDRESS is its
;   identity, so reusing this number renumbers the table.

; SLOT 31 WAS THE LAST OF THE ORIGINAL THIRTY-TWO, and slot 32 below is what
; grew the reservation to forty.  That moves KTTY_TABLE_SZ and therefore where
; this bank's code starts -- it does NOT renumber any slot, because slot n is
; KTTY_SLOT0 + 4n and KTTY_SLOT0 is fixed.  A rebuild, not an ABI break; the
; header above says the count was reserved from the start for exactly this.
KTTY_KC_TTSTOPPED   EQU     KTTY_SLOT0+4*31 ; slot 31: kc_ttstopped (C) -- A=idx
                                            ;   -> A = 1 if TS_TTSTOP is set on
                                            ;   that line, 0 otherwise.  The
                                            ;   half of `ptsstart's PKT arm the
                                            ;   tty bank can answer; the driver
                                            ;   holds the other (PF_STOPPED).
KTTY_KC_TTDRAIN     EQU     KTTY_SLOT0+4*39 ; slot 39: kc_ttdrain (C) -- no
                                        ; arguments -> A = how many lines had

;------------------------------------------------------------------------------
; KTTY_KC_TTGETRAW - slot 40: kc_ttgetraw(idx, nonblock) -> one RAW byte from
; line `idx', or -1 when there is none, or -2 when a signal interrupted the
; wait.  T6 increment 4b.
;
; MODE-INDEPENDENT ON PURPOSE, and that is the whole reason this is not
; `kc_ttread'.  SYS_GETKEY's contract is "one RAW key" -- `more's pager key,
; `worm' and `robots' steering, `ping's interrupt check -- so it cannot wait
; for a line terminator the way a cooked read must.  Upstream has no such
; syscall at all: a program that wants raw keys sets CBREAK and reads, and this
; is that pair expressed as one call for callers that have no fd to set modes
; on.
;
; IT CONSUMES FROM `t_rawq', WHICH IS THE POINT.  Until T6 4b these syscalls
; dequeued a SECOND copy of the keystroke from `_kKbdRing', so a pager key was
; also still in the shell's line -- one byte with two owners, which is what
; `ptykey' measures as a program on a pty eating the physical console's keys.
; One queue, one owner.
;------------------------------------------------------------------------------
KTTY_KC_TTGETRAW    EQU     KTTY_SLOT0+4*40 ; slot 40: kc_ttgetraw (C)
KTTY_KC_TTCARRIER   EQU     KTTY_SLOT0+4*41 ; slot 41: kc_ttcarrier (C) -- A=idx
                                            ;   -> A = 1 carrier up / 0 down.
                                            ;   `ptcread's EOF test is the
                                            ;   CARRIER (tty_pty.c:268), not
                                            ;   whether a slave is open this
                                            ;   instant; apple/fgx#266.
                                        ; deferred output restarted.  THE SOFT
                                        ; HALF OF THE OUTPUT RAIL, T6 4b: the
                                        ; ISR's `ttyinput' fills `t_outq' and
                                        ; marks TS_TIMEOUT because a chardev
                                        ; dispatch cannot run at interrupt
                                        ; time; this calls `ttrstrt' for each
                                        ; marked line, in TASK context.
                                        ; **SLOT 39 IS THE LAST OF THE RESERVED
                                        ; FORTY.**  A fortieth grows
                                        ; KTTY_SLOT_COUNT, which moves where
                                        ; the bank's code starts and renumbers
                                        ; NOTHING (slot n is KTTY_SLOT0 + 4n).
KTTY_KC_TTYINPUT    EQU     KTTY_SLOT0+4*38 ; slot 38: kc_ttyinput (C) --
                                        ; TWO STACK ARGUMENTS, idx then c,
                                        ; pushed right-to-left as fcc reads
                                        ; them (see _Tty_PtcInput, ttyv.s, for
                                        ; the shape) -> A = 0, or -1 for an
                                        ; index that names no line.
                                        ; THE RECEIVE INTERRUPT'S DOOR, T6 4b:
                                        ; 2.11BSD's `dzrint' binds a character
                                        ; to its line and calls `l_rint' before
                                        ; the discipline knows an interrupt
                                        ; happened, and this is that call.
                                        ; ENTERED THROUGH KTTY_KC_ENTER_IRQ,
                                        ; never the ordinary bracket -- it is
                                        ; the second register file that makes
                                        ; C-at-interrupt legal.
KTTY_KC_PTCWRITABLE EQU     KTTY_SLOT0+4*37 ; slot 37: kc_ptcwritable (C) --
                                            ;   A=idx -> A = 1 if a master
                                            ;   write would not block.  The
                                            ;   exact complement of slot 35, so
                                            ;   select and write cannot
                                            ;   disagree.  T6 increment 4a.
; slot 36: RETIRED -- held the tty bank's tty probe until
;   2026-09-07.  The slot itself remains, stubbed to
;   _Ktty_StubHalt in ttybank.s: a slot's ADDRESS is its
;   identity, so reusing this number renumbers the table.
KTTY_KC_PTCINPUT    EQU     KTTY_SLOT0+4*35 ; slot 35: kc_ptcinput (C) --
                                            ;   A=idx, X=byte.  `ptcwrite's
                                            ;   inner loop for ONE byte:
                                            ;   -> A = 1 given to the
                                            ;   discipline, 0 the caller must
                                            ;   block (TTYHOG), -1 no such
                                            ;   line.  T6 increment 4a.
KTTY_KC_IRQPROBE    EQU     KTTY_SLOT0+4*33 ; slot 33: kc_irqprobe (C) -- A=seed
                                            ;   -> A = seed*4+6.  The callee of
                                            ;   _KcIrqProbe (main.s), reached
                                            ;   through KTTY_KC_ENTER_IRQ: the
                                            ;   only thing that exercises the
                                            ;   second register file until the
                                            ;   heartbeat does (T6, #108).
KTTY_KC_SPLPROBE    EQU     KTTY_SLOT0+4*34 ; slot 34: kc_splprobe (C) -- no
                                            ;   arguments -> A = 44 when
                                            ;   spltty()/splx() are the real
                                            ;   bracket, 0 when they are the
                                            ;   empty macros they were before
                                            ;   T6 increment 2.
KTTY_KC_TTSELECT    EQU     KTTY_SLOT0+4*32 ; slot 32: kc_ttselect (C) -- A=idx,
                                            ;   X=rw (FREAD/FWRITE).  -> A = 1
                                            ;   ready / 0 not.  `ttyselect', so
                                            ;   a driver stops hand-rolling a
                                            ;   readiness answer out of state
                                            ;   the discipline owns.

; ttioctl's `flag' argument, from `usr/sys/h/file.h'.  MUST match the FREAD /
; FWRITE in src/kernel/tty/tty.h:316-317, which is the copy the C side compiles
; against -- these two are the same constant on either side of a bank.
;
; NOT SPELLED `KTTY_': tools/check_far_calls.py evaluates EVERY `KTTY_*' EQU in
; this file as a slot ADDRESS and builds its name map from the ones that land in
; the export region.  A `KTTY_FREAD EQU 1' is a valid expression, so it would
; not fail -- it would quietly name offset 1 as an export.  That is the same
; trap the TTYC_ offsets are named around, one screen down.
TTYIO_FREAD         EQU     1
TTYIO_FWRITE        EQU     2

;------------------------------------------------------------------------------
; `struct tty' FIELD OFFSETS, for the core bank's assembly.
;
; T3's cutover gives the four fields that outlive the old discipline one home
; in this bank's `ttys[]' (docs/history/plans/tty-kernel-bank.md section 10).  The core bank
; reaches them through assembly export slots -- assembly rather than kernel C
; because toolbox.s reads the foreground group at 60 Hz AT INTERRUPT TIME and
; include/kernelc.s makes kernel C a singleton, so a second live C context
; would share its register file.
;
; A DUM BLOCK RATHER THAN A LIST OF NUMBERS, which is the idiom include/
; kernel.s already uses for `_ttyTable': Merlin computes every offset from the
; DS chain, so the layout is expressed as a shape and the offsets fall out.
;
; fcc DECIDES THIS LAYOUT, so the chain is a TRANSCRIPTION and it is pinned in
; two independent ways rather than trusted:
;
;   - the ERR below fails the BUILD if the chain stops totalling 92;
;   - tty_probe.c asserts `sizeof (struct tty)' and the two offsets the
;     accessors use ON THE MACHINE, so a layout change goes red there.
;
; That is gen_vfs_equ.py's discipline (its struct sizes are literals pinned by
; toolchain/tests/M37/vfslayout.c) in this bank's own idiom.  Merlin sees no C,
; so the transcription has to exist; what must not exist is an UNCHECKED one.
;
; SIZES: fcc gives int/short 2, char 1 PACKED, long 4, every pointer 4 (far).
; `struct clist' is 10 (c_cc 2 + c_cf 4 + c_cl 4) and `dev_t' is `unsigned
; short' (ttyparam.h).  Both measured out of fcc, not assumed.
;------------------------------------------------------------------------------
                DUM     0
TTYC_NU       DS      20              ; union: {t_rawq,t_canq} vs
                                        ;   {T_bufp,T_cp,T_inbuf,T_rec} = 12
TTYC_OUTQ     DS      10              ; struct clist
TTYC_OPROC    DS      4               ; int (*)()
TTYC_RSEL     DS      4               ; struct proc *
TTYC_WSEL     DS      4
TTYC_LINEP    DS      4               ; caddr_t T_LINEP
TTYC_ADDR     DS      4               ; caddr_t
TTYC_DEV      DS      2               ; dev_t
TTYC_FLAGS    DS      4               ; long.  The sgtty mode bits -- and its
                                        ;   HIGH WORD IS THE LOCAL MODE WORD:
                                        ;   ioctl.h:174 defines the L* bits as
                                        ;   `((int)(CRTBS>>16))', so LTOSTOP
                                        ;   $0040 IS TOSTOP $00400000 >> 16.
                                        ;   T3 stage 2d deleted _ttyTable's
                                        ;   separate copy of these bits.
TTYC_STATE    DS      4               ; long
TTYC_PGRP     DS      2               ; short -- the foreground process group
TTYC_DELCT    DS      1               ; char
TTYC_LINE     DS      1               ; char -- the line DISCIPLINE number
TTYC_COL      DS      1               ; char
TTYC_ISPEED   DS      1               ; char
TTYC_OSPEED   DS      1               ; char
TTYC_ROCOUNT  DS      1               ; char
TTYC_ROCOL    DS      1               ; char
; THE PAD IS IN THE MIDDLE, NOT AT THE END, and that was MEASURED rather than
; reasoned: this chain said t_chars was at 69 and fcc puts it at 70, because it
; aligns a struct member to an even offset and the seven chars above end on an
; odd one.  tty_probe case 164 is what said so.  With the pad here the tail
; totals exactly 70 + 14 + 8 = 92 and nothing is left over -- which is the
; question the note that used to sit here could not answer.
TTYC_MIDPAD   DS      1               ; fcc's alignment pad, BEFORE t_chars
TTYC_CHARS    DS      14              ; struct ttychars -- tc_erase, tc_kill,
                                        ;   tc_intrc, tc_quitc, tc_startc,
                                        ;   tc_stopc, tc_eofc, tc_brkc,
                                        ;   tc_suspc, tc_dsuspc, tc_rprntc,
                                        ;   tc_flushc, tc_werasc, tc_lnextc,
                                        ;   one byte each (fcc packs char
                                        ;   members).  `struct tchars' is the
                                        ;   first six from tc_intrc; `struct
                                        ;   ltchars' the last six from tc_suspc.
TTYC_WINSIZE  DS      8               ; struct winsize {row, col, xpixel, ypixel}
                DEND
; Pinned by tty_probe cases 164-166 ON THE MACHINE, the way TTYC_SIZE,
; TTYC_FLAGS and TTYC_PGRP are pinned by 160-163.
TTYC_INTRC      EQU     TTYC_CHARS+2    ; t_intrc  -- pty.mod's ^C test
TTYC_QUITC      EQU     TTYC_CHARS+3    ; t_quitc  -- and its ^\ test
; NOT `EQU *': check_far_calls.py evaluates every EQU in this file and Merlin's
; location counter is not arithmetic it can read.  TTYC_TAIL is the running
; total Merlin computed from the DS chain above, so the ERR still checks the
; SHAPE against the literal rather than the literal against itself.
TTYC_SIZE       EQU     92              ; fcc's sizeof (struct tty)
                ERR     TTYC_WINSIZE+8-TTYC_SIZE
