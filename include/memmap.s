;==============================================================================
; memmap.s - Authoritative kernel memory map for bank $02.
;
; Single source of truth for every static kernel allocation inside FGX_DATA
; ($028000..$02AFFF).  Every claim goes through the DUM/DEND block below.
; Merlin32 computes offsets automatically; compile-time ERR guards catch
; overflow into the filesystem buffer region.
;
; Discipline:
;   - Every region has a usable area, an `_end` label marking one past last
;     usable byte, and a 1-byte canary immediately after the `_end`.
;   - Owners zero-fill their region at Init time via _ZeroBankRegion
;     (see include/macros.s).  The zero-fill stops at `_end`, so canary
;     bytes are preserved across init.
;   - At boot, _KMem_WriteCanaries writes $A5 to every canary byte.
;     _KMem_CheckCanaries (called every shell prompt) reads them back;
;     any byte != $A5 means a previous subsystem overran its region.
;   - No MMU, so we can only detect overruns that reach the canary.
;     Middle-of-region stray writes remain invisible — still catches
;     the most common off-by-one-at-end-of-buffer class.
;
; Design: docs/superpowers/specs/2026-04-22-fgx-kernel-memory-discipline-design.md
;==============================================================================

                DUM     FGX_DATA                ; $02EF50 today -- DERIVED, and
                                                ; the literal here is a comment,
                                                ; not the source.  It said $02E000
                                                ; long after the base moved, and a
                                                ; test poking that address hit dead
                                                ; memory and reported a false pass
                                                ; (apple/fgx#120).  Take addresses
                                                ; from the build listing.

;------------------------------------------------------------------------------
; Kernel globals.  Owner: main.s.  Zero-init: _KMem_ClearGlobals (FGX_Entry).
;------------------------------------------------------------------------------
LastExitStatus  DS      2                       ; status from last user _exit (slice-1)
_taskAllocCur   DS      2                       ; Task_Alloc round-robin cursor:
                                                ; next slot index to try (0..NPROC-1).
                                                ; Prevents INSTANT pid reuse -- BSD
                                                ; job control (tcsh pchild/pfind)
                                                ; aliases two pipeline children that
                                                ; get the same pid (2026-07-27).
                                                ; Zero-init => first alloc = slot 0
                                                ; (init must be pid 1).
DetectedROM     DS      2                       ; Raw ROM ID byte
ROMVersion      DS      2                       ; ROM version (0, 1, 3)
DetectedSpeed   DS      2                       ; Raw CYAREG value
CPUSpeedMHz     DS      2                       ; Measured speed × 10
RawIters        DS      2                       ; VBL cycle-count iterations
IterRise        DS      2                       ; Phase 1 iters (to rising edge)
IterFall        DS      2                       ; Phase 2 iters (to falling edge)
RAMBanks        DS      2                       ; 64 KB bank count
RAMSizeKB       DS      2                       ; RAM in KB
RAMSizeMB       DS      2                       ; RAM in MB (approx)
_PdValStorage   DS      2                       ; _PutDec work value
_ioCdIdx        DS      2                       ; _Io_CdThenTty holds the
                                        ;   chardev index across the device's
                                        ;   own ioctl op, so that an ENOTTY can
                                        ;   be retried against the tty
                                        ;   discipline.  The op is arbitrary
                                        ;   device code and preserves nothing,
                                        ;   and A carries the result back, so
                                        ;   the index cannot stay in either.
                                        ;   LINE's foreground group here while
                                        ;   the READER's is fetched -- the
                                        ;   accessor answers in A, so the two
                                        ;   cannot both live there.  NOT an
                                        ;   _shTmp: syscall.s:5254 states as a
                                        ;   standing assumption that nothing on
                                        ;   this path touches _shTmp0.

; _TtyStateProbe's scratch (apple/fgx#108 T3 stage 1).  _ttyStSave holds every
; line's real t_pgrp across the test, because a probe that left its own pattern
; behind would be production state written by a test.
;
; NOT gated on TTYANY, though the probe that uses it is: this file is PUT ahead
; of include/kernelc.s, where TTYANY is defined, and Merlin resolves DO in
; source order -- it fails with "can't be translated as a numeric expression".
; Twenty bytes of FGX_DATA, which is not the resource the tty campaign is short
; of; the CODE is gated and that is where the 65 KB ceilings are.
_ttyStVerdict   DS      2                       ; 0 = pass, else the case
_ttyStIdx       DS      2                       ; loop cursor
_ttyStTmp       DS      2
_ttyStSaveLo    DS      2                       ; line 0's t_flags, both halves
_ttyStSaveHi    DS      2
_ttyStSave      DS      2*NTTY                  ; every line's saved t_pgrp
_PdNzStorage    DS      2                       ; _PutDec leading-zero flag

; Boot-screen mount-table formatter scratch (used only inside _BootScreen
; during boot; zero-init via _KMem_ClearGlobals).  Six 16-bit cells.
_pmtCol         DS      2                       ; current output column
_pmtSlot        DS      2                       ; current mount slot offset
_pmtPad         DS      2                       ; pad-to-col target
_pmtSize        DS      2                       ; mount size in KB
_pmtDigits      DS      2                       ; digit count of size
_pmtDigCnt      DS      2                       ; _CountDigits temp
_pmtTmp         DS      2                       ; _CountDigits scratch

; Wall-clock time captured at FGX_Entry, served back to userland by
; SYS_UPTIME so a user-mode `uptime` can compute time-since-boot.  Layout
; matches Misc Toolset ReadTimeHex result:
;   [0]=second [1]=minute [2]=hour [3]=year [4]=day [5]=month
; _kBootTime moved to the FAR kernel bank with the RTC (2026-08-01): it is
; written by _KCaptureBootTime and read by _Sys_Uptime, both of which live
; there now, so it never crosses a bank.

; 60 Hz tick counter, incremented by the heartbeat task body in
; src/kernel/toolbox.s::_HBTickTask. Read by SYS_TICKS via _Sys_Ticks
; (also in toolbox.s). Zero-init: _KMem_ClearGlobals.
_kSystemTicks   DS      4

; Kernel keyboard ring buffer.  The heartbeat (src/kernel/toolbox.s
; _HBTickTask) polls $E0C000 at every VBL and enqueues the latest keystroke
; into _kKbdRing[head]; Con_PollKey dequeues from _kKbdRing[tail].
; Decouples key reads from foreground CPU load so the one-deep Mega-II
; hardware buffer can't drop keys when the kernel is busy (e.g. mid-scroll).
; Indices are stored as 2-byte fields so 16-bit X-register access from the
; heartbeat (LDX/STX) reads them cleanly under MX %10 without mode flips.
; Zero-init: _KMem_ClearGlobals.
KBD_RING_SZ     EQU     16
_kKbdRing       DS      KBD_RING_SZ
_kKbdRingHead   DS      2                   ; producer index (0..KBD_RING_SZ-1)
_kKbdRingTail   DS      2                   ; consumer index (0..KBD_RING_SZ-1)
_kKbdRingCount  DS      2                   ; 0..KBD_RING_SZ

; Test-only raw-key injection (vt100 keyboard net).  The ADB key latch is not
; pokeable in MAME (a $E0C000 write hits the 80STORE soft switch), so fgxdebug
; writes a pre-translation ADB byte here and the heartbeat feeds it through the
; SAME vt100 translation as a real strobe.  Encoding: low byte = 7-bit key,
; bit 8 = Ctrl-held; 0 = no injection (the normal case).  Zero-init +
; self-clearing (heartbeat consumes it).  Inert in production (nobody writes it).
_kKbdInjectRaw  DS      2

; T6 increment 4b: what `@hb_kbdEmit' (toolbox.s) made of the last keystroke.
; -1 = the discipline could not take it.  Zero-init: _KMem_ClearGlobals.
_kTtyEmitRet    DS      2

; Vestigial diagnostic cells from the retired Irq_Init path. Still read
; by src/userland/vbldiag/vbldiag.s, so kept in place to preserve the
; layout offsets it depends on. Currently always zero.
_kIrqIntenAfter DS      1
_kIrqPad        DS      1

; Diagnostic block-read counter, incremented at every Blk_Read entry.
; Read by SYS_KSTAT.  Owner: src/drivers/block/block.s.  Zero-init:
; _KMem_ClearGlobals (falls within the kernel-globals region).
_kBlkReadCount  DS      4

; Multi-block ($48) read-ahead request, written by _BlkCache_ReadAhead and read
; by _SP_ReadBlockN.  The destination is a LONG pointer because the whole point
; of an extended call is that the transfer lands in another bank (the cache
; pool's heap bank), which a bank-0 staging buffer could never reach.
; Zero-init: _KMem_ClearGlobals.
_blkRaDstOff    DS      2               ; destination offset
_blkRaDstBank   DS      1               ; destination bank
_blkRaCount     DS      2               ; BYTE count for the call (K*512)
; Read-ahead scratch.  NOT _libcTmp2: that is THREE bytes ($54..$56), so a
; 16-bit store at _libcTmp2+2 runs into the next DP cell.
_blkRaSlot      DS      2               ; first slot index of the run
_blkRaBlk       DS      2               ; running block number while marking
; Read-ahead outcome counters.  A read-ahead that FAILS and falls back to the
; single-block path is indistinguishable from a slow firmware unless you
; count it -- both just look like 'multi-block is slower'.
_blkRaOk        DS      2               ; runs filled by one $48
_blkRaFail      DS      2               ; $48 calls that returned an error
_blkRaErr       DS      2               ; SmartPort errno from the last failed
                                        ; $48 -- the CODE distinguishes 'this
                                        ; card cannot' from 'this EMULATION
                                        ; does not route the command'
_blkExtErr      DS      2               ; and the same for the last failed $41,
                                        ; latched before the trampoline cleanup
                                        ; overwrites A (apple/fgx#119)
_blkDibSubtype  DS      1               ; boot device's DIB subtype byte, $FF if
                                        ; no unit answered.  Read/written
                                        ; DBR-relative, like _busTable
; HIGH word of the block number for the operation in flight.  Blk_Read and
; Blk_Write latch _blkNumHi into this on entry and zero the DP cell in the same
; breath; from that point the device layer, the cache and read-ahead all read
; the block number as _blkCurHi:_blkNum.  Keeping the authoritative copy OUT of
; direct page is what makes the self-clean work -- the DP cell is a one-shot
; caller input, this is the value the operation actually runs on.
_blkCurHi       DS      2
; BANK of the caller's buffer, and the same one-shot discipline _blkNumHi uses.
;
; _blkBuf is a 16-bit OFFSET; its bank was the live kernel bank, baked into
; every MVN and every extended-call parameter list.  That was true while the
; only callers were the legacy FS layer, which lives there.  The vfs_bio buffer
; arena does not and cannot: 16 KB will not fit in a core bank with ~1 KB free.
;
; _blkBufBank is therefore CALLER INPUT AND IT SELF-CLEANS, exactly like
; _blkNumHi: Blk_Read/Blk_Write latch it into _blkCurBufBank and zero it in the
; same breath, so it reads 0 at all times except inside one caller's own
; store-then-call window.  ZERO MEANS THE LIVE KERNEL BANK.  That is what lets
; the ~60 existing callers that never heard of it stay correct by construction
; instead of being swept -- the same reason the 32-bit block key cost no audit.
;
; _blkCurBufBank, not this cell, is what the device and cache layers read.
; Both live OUT of direct page because $10-$1F is full, and because keeping the
; authoritative copy outside DP is what makes the self-clean sound.
_blkBufBank     DS      2
_blkCurBufBank  DS      2
; Nonzero when the device in flight carries DEV_FLAG_VFSOWNED, so the legacy
; block cache must be skipped entirely (UFS 1.3c).  Derived once per operation
; from the device record, right after _devPtr is resolved, because the flag is
; read at four different points and re-reading it through a long pointer at
; each would cost more than the byte.  Only the low byte is ever written or
; read; see DEV_FLAG_VFSOWNED in include/fs.s for what it enforces and why.
_blkNoCache     DS      2
; _bufArenaBase, _vfsPoolBase, _vfsProbeDev and _vfsProbeCand REMOVED
; 2026-08-12 -- 10 bytes.  They held where the kernel had put the VFS's two
; heap arenas, and which device its wiring probe had chosen, back when main.s
; allocated on the VFS's behalf and handed the bases down through the far
; bank's export table.  vfs.mod allocates its own through KSVC_KMALLOC and
; keeps the answers in module storage, so the kernel no longer knows or needs
; to know where either arena is.
;
; _blkNoCache above STAYS, and the difference is the point: that one is the
; BLOCK LAYER's view of a flag the VFS sets, read on the kernel's own I/O path.
; These four were only ever the kernel remembering something on the VFS's
; behalf.
_blkRaLast      DS      2               ; previous block REQUESTED (hit or miss)
_blkRaSeq       DS      2               ; nonzero when this request continues
                                        ; the last one -- read-ahead is for
                                        ; STREAMING only.  Firing it on the
                                        ; index/dir blocks that interleave a
                                        ; file read made every request a
                                        ; 4 KB transfer: 2,166 read-aheads
                                        ; for 2,190 requests, 3x SLOWER.

;------------------------------------------------------------------------------
; The raw disk`s working set (apple/fgx#330, src/drivers/block/rawdisk.s).
;
; ONE STAGING SECTOR FOR ALL EIGHT UNITS.  Reno hands physio a per-unit buffer
; (`&sdbuf[unit]', sd.c:677) because physio SLEEPS waiting for B_DONE and
; B_BUSY on that buffer is what keeps a second raw transfer out of it across
; the sleep.  FGX has no such window -- bio_strategy transfers and calls
; biodone before returning, kc_blkio is sleep-free, uiomove is a banked copy --
; so nothing can run between one transfer and the next.  That is the invariant
; the legacy FS layer`s singletons already rest on, and rawdisk.s is listed in
; check_fs_sleep_invariant.py`s FS_LAYER so it is enforced rather than assumed.
; Zero-init: _KMem_ClearGlobals.
;------------------------------------------------------------------------------
_rsdSector      DS      512             ; one device block, staged
_rsdUio         DS      4               ; the uio, parked across Blk_*
_rsdNBlk        DS      4               ; the unit`s block count, 32-bit
_rsdBn          DS      4               ; block number of the current sector
_rsdEnd         DS      4               ; bn + sz, for the range check
_rsdTmp         DS      4               ; 32-bit scratch (the howmany)
_rsdTmp2        DS      2               ; cp offset, across the frame build
_rsdCount       DS      2               ; n, across the frame build
_rsdBoff        DS      2               ; byte offset inside the sector
_rsdResid       DS      2               ; bytes still wanted
_rsdN           DS      2               ; bytes this turn
_rsdRw          DS      2               ; UIO_READ / UIO_WRITE
_rsdUnit        DS      2               ; the minor, = the device index
_rsdRegU        DS      2               ; registration loop counter

; Name of the module currently in mod_init - set by modload.s (both load
; paths) before the mod_init JSL; read by _Mod_LogImpl (SYS_MODLOG) to prefix
; detail lines, and by the kernel-owned 'mod: <name> loaded' announce.
; 16 B NUL-padded (matches the FGXM name field).  Zero-init: _KMem_ClearGlobals.
_curModName     DS      16

; SYS_KSTAT scratch — 24-bit accumulator for cross-arena field sums.
; Lives long enough only for one syscall invocation; no other consumer.
_ksSum          DS      4

; SYS_DMESG scratch — copy-loop state for the log-ring → caller-buf path.
_dmesgMaxBytes  DS      2
_dmesgCopied    DS      2
_dmesgSrcIdx    DS      2

; SYS_MEMINFO scratch — per-call state for the diagnostic memory readout.
; Owner: src/kernel/syscall.s _Sys_MemInfo.  Zero-init: _KMem_ClearGlobals.
; Only valid during one SYS_MEMINFO invocation; the syscall is reentrant-safe
; only at the dispatch level (concurrent SYS_MEMINFO would corrupt this state,
; but the kernel is single-threaded today).
_mi_subcmd      DS      2       ; subcmd (0..4)
_mi_dstOff      DS      2       ; running write cursor offset in caller bank
_mi_dstOff0     DS      2       ; original offset (unused today; kept for symmetry)
_mi_bufRem      DS      2       ; bytes remaining in caller buf
_mi_written     DS      2       ; total bytes emitted so far
_mi_thisCnt     DS      2       ; bytes for current _MI_Emit call
_mi_auditOnly   DS      2       ; subcmd-4 flag: emit only corrupt chunks
_mi_bank        DS      2       ; current arena bank (chunk walker)
_mi_off         DS      2       ; current chunk header offset within bank
_mi_chSize      DS      2       ; cached CH_SIZE of current chunk
_mi_chType      DS      2       ; cached CH_TYPE
_mi_chNext      DS      2       ; cached CH_NEXT
_mi_chFlags     DS      2       ; record flags (bit 0 free, bit 1 guard bad)
_mi_rec         DS      16      ; staging buffer for emitted record

; Module vtable registry — Mod_Load appends one entry per VTDR tuple.
; The 96-byte table MOVED TO THE HEAP (soft-global, 2026-06-05): _AllocModReg
; Kmalloc's it and reaches it via the DP long-pointer _modRegPtr (dpmap.s);
; modload.s accesses it with [_modRegPtr],Y.  _modRegCount stays static (a
; scalar).  See include/modules.s for layout constants (MOD_REG_E_*).
_modRegCount    DS      2

; Toolbox state (set at boot by src/kernel/toolbox.s).
; Owner: toolbox.s. Zero-init: _KMem_ClearGlobals.
_kFgxUserID     DS      2       ; from _GetNewID; written by Toolbox_Init
_kClaimIdx      DS      2       ; loop index used by Toolbox_PreClaim
_kClaimHeapIdx  DS      2       ; heap-bank-claim loop index (Fix #3)
_kFgxToolErr    DS      2       ; last tool errno from a failed JSL (halt path)

; Process credentials MOVED (2026-07-28, credentials campaign P1).  _kProcUid /
; _kProcGid were machine-wide globals — one credential set for every task,
; which fork could not express.  They now live PER TASK in the u-area
; (U_Ruid/U_Uid/U_Rgid/U_Gid/U_Svuid/U_Svgid, include/kernel.s), reached via
; _Uarea_Cur / _Uarea_FromTCB in task.s.  The TCB and the SE_ sched entry are
; both physically full, which is why the u-area is the home; see
; docs/history/plans/2026-07-28-userland-credentials-plan.md §2.1.
;
; A task's creds start zeroed (root) because Task_AllocUarea zeroes the block --
; and the same routine then copies the CURRENT task's whole u-area over the top,
; so on fork/vfork/spawn a child inherits its parent's.  Only the boot task,
; allocated while _curTask is still 0, keeps the zeros.

; Kernel direct-page allocation (Commit A: kernel DP via MM).  Toolbox_AllocKernelDP
; calls _NewHandle for a 256-B bank-0 page-aligned locked block, copies the
; current DP image into it, then TCDs.  Subsequent DP-relative accesses hit
; the MM-tracked page so firmware/MM scratching bank-0 zero-page can't
; corrupt kernel state.  The dispatcher swaps to this page on every syscall
; entry; user tasks keep their own DP (TCB.DirectPage).
; THE RUNNING TASK'S PID, ABSOLUTE.  _curTask is a DIRECT-PAGE cell, and the
; dispatcher needs the pid BEFORE the TCD that selects a per-task kernel direct
; page -- so it cannot come from the page being selected.  This is that pid,
; in the kernel bank, reachable whatever D happens to be.
;
; It is NOT a duplicate of _curTask, it is the other half of a split.  _curTask
; is now a PER-PAGE IDENTITY: page N's copy holds N, seeded once when the page
; is allocated.  That is what keeps ~170 "which task am I" reads correct with
; no edit -- including the ones in modules, where the direct page is the only
; addressing mode that is free.  _kCurPid answers the different question, "who
; is running", for the two places that must ask it from outside a page: the
; syscall dispatcher and swtch.
_kCurPid        DS      2       ; running pid, kernel-bank absolute
_bootTcbSave    DS      2       ; boot's TCB offset, parked across Mod_Load /
                                ;   _BootScreen / Sound_* / Mod_LoadConf, which
                                ;   all clobber X.
                                ;
                                ;   IT USED TO BE PARKED IN _curTask, and that
                                ;   cell means CURRENT PID -- so from main.s's
                                ;   park until its STZ, every reader of the pid
                                ;   got a TCB offset instead.  kc_curpid is one
                                ;   of those readers (jumptable.s @kc_curpid
                                ;   reads _curTask), and Mod_LoadConf runs
                                ;   inside that window: any kernel C asking who
                                ;   it was during module load was answered with
                                ;   a structure offset.  Two bytes to stop one
                                ;   cell meaning two things.
_fcbFreeFd      DS      2       ; the fd _Fcb_Free is closing.  Kept because
                                ;   _shTmp0 is overwritten with fd*3 two
                                ;   instructions in, and kdesc_free needs the
                                ;   fd ITSELF, not the table offset.
; The round-robin cursor.  GLOBAL by nature: pick_next scans starting just after
; the last slot scheduled, so a per-task copy is not a cursor, it is N cursors
; that each see one switch in N.  It was a direct-page cell until the kernel DP
; became per-task, at which point it silently stopped being shared -- swtch runs
; on the OUTGOING task's page, so every switch advanced a different copy.
_schedLastSlot  DS      2       ; last slot scheduled (round-robin fairness)

; THE VOLUME BITMAP'S SCALARS.  Size, and the dirty span awaiting sync.  They
; were direct-page cells until the kernel direct page became per-task, at which
; point each task quietly got its own copy of state that belongs to the disk.
;
; Safe at the time only by an invariant nobody had written down: every mutating
; FS operation syncs the bitmap inside the same syscall, so a dirty range never
; outlived the task that set it, and the root volume is mounted at boot so the
; boot template carried a correct _bm_size to every page.  Both of those are
; assumptions about how the FS happens to be driven today, not properties of
; the data -- a DEFERRED or batched bitmap sync would have left task A's dirty
; range on task A's page while task B synced from its own and read clean, and a
; volume mounted after boot sets _bm_size on the mounting task's page alone.
;
; The first is silent on-disk bitmap divergence.  Being statics, neither can
; happen: there is one copy because there is one volume.
_bm_size        DS      2       ; bitmap size in bytes
_bm_dirty_lo    DS      1       ; first dirty bitmap-block index ($FF = clean)
_bm_dirty_hi    DS      1       ; one-past-last dirty bitmap-block index
_kFgxDPKernel   DS      2       ; bank-0 lo-word address of kernel DP page
_kFgxDPHandle   DS      4       ; MM handle for kernel DP block (long ptr)
_restBaseBank   DS      1       ; runtime rest-of-OS base bank (seeded at boot from
                                ;   KFGX_REST_ANCHOR; == REST_BASE_DEFAULT at $02 build)
; Phase 2B: cached rest-of-OS region banks = _restBaseBank + REST_*_OFF, derived
; once at boot (main.s) so per-region code loads the dynamic bank instead of a
; baked fixed bank.  Word each (bank in low byte, high byte 0).
_kFontsBank     DS      2       ; pre-expanded console fonts (was fixed $04)
_kUserFirstBank DS      2       ; user-task bank pool floor (was fixed $0A); bank.s
_kConsoleBank   DS      2       ; console CharBuf/AttrBuf/FgBuf/BgBuf framebuffers
                                ;   (was fixed $03); = _restBaseBank + REST_CONSOLE_BANK_OFF(0).
                                ;   The 75 baked-$03 operand bank bytes (STAL/LDAL CON_*BUF +
                                ;   MVN $03,$03) are self-modded to this at Con_Init via the
                                ;   generated _ConBankPatchTbl (console_bankpatch.s).

; --- Virtual console registry (slice D).  CORE bank on purpose: the console
; --- switch runs in the far bank but Bank_Alloc, the tty write path and the
; --- keyboard enqueue are all core, and they are the frequent readers.  The far
; --- side reaches these with a _cfp-marked LDAL, exactly as it does
; --- _kConsoleBank.  6 + 4 bytes against ~7.4 KB free.
;
; _kVcBank[i] is VC i's framebuffer bank, or 0 for "not allocated yet".  VC 0's
; entry is seeded from _kConsoleBank at boot, so it is never 0 and the console
; needs no special case.  Allocation is LAZY and happens on FIRST WRITE, not
; first switch (2026-08-05): once /etc/ttys turns the ttyv lines `on`,
; each getty writes its prompt within seconds of boot, long before anyone
; switches -- so first-switch would allocate at boot anyway and buy nothing,
; while pretending to be lazy.  First-write is the honest trigger and still
; costs nothing for a line left `off`.
_kVcBank        DS      2*4     ; NVC entries; keep in step with NVC in far.s
_kVcActive      DS      2       ; index of the VC on the IIgs screen: the one
                                ;   whose state the console engine holds
                                ;   between writes
_kVcFocus       DS      2       ; index of the VC that has the keyboard.  The
                                ;   same as _kVcActive until Option-4 hands
                                ;   the keys to the card's console (VC_CARD),
                                ;   which has a display of its own and so
                                ;   never needs the SHR switched to it
_kVcCard        DS      2       ; VC_CARD + 1 once sscon.mod has registered a
                                ;   card for that console; 0 = no card, and
                                ;   then VC_CARD switches onto the SHR like
                                ;   the others

_fdDupSrc       DS      2       ; _Fd_Dup's SOURCE fd, UFS 1.7d I2c.
                                ;   _Fd_Dup has always taken the source as a
                                ;   resolved FCB pointer and the target as an
                                ;   fd, which is all the fd table needs.  The
                                ;   file table is indexed by DESCRIPTOR, so the
                                ;   mirror needs the number the FCB came from.
                                ;   A cell rather than a register because the
                                ;   routine's contract preserves X and its
                                ;   callers rely on that.
_fdOpSlot       DS      2       ; _Fcb_OpEntry's op offset (FO_*), kept
                                ;   across the struct-file resolution.
_fdOpsFar       DS      2       ; _Fcb_OpEntry's THIRD answer, UFS 1.7d I3:
                                ;   nonzero when the descriptor's f_ops point
                                ;   OUTSIDE this bank.  C=0 alone cannot say
                                ;   it -- "no vector" and "a vector this bank
                                ;   must not jump to" want opposite handling,
                                ;   EBADF for the first and route-to-the-far-
                                ;   bank for the second, and a descriptor
                                ;   opened under /dev names vnops in the far
                                ;   bank.  Written on EVERY call, before it can
                                ;   be read, so a stale one cannot route a
                                ;   legacy descriptor over the seam.
_kOfilePool     DS      4       ; 24-bit base of the far bank's per-process
                                ;   descriptor arrays (ofile_pool), published
                                ;   by _Vfs_FileInit at boot.  UFS 1.7d I2c.
                                ;   The FS layer reads `struct file' through
                                ;   this with the offsets in include/vfs_equ.s,
                                ;   because a far call per read(2) would be a
                                ;   bank round trip on the hottest path there
                                ;   is.  0 = no far bank; see _kFarReady.
_fdDupDst       DS      2       ; _Fd_Dup's TARGET fd, kept for the same
                                ;   reason _fcbFreeFd is: _shTmp0 holds fd*3
                                ;   two instructions in.
_fdOwnerPid     DS      2       ; pid whose fd table _fd_table_ptr currently
                                ;   points at, or 0 = "the current task".
                                ;
                                ;   THE SAME HAZARD _kCttyTarget BELOW EXISTS
                                ;   FOR, one layer down, and found the same way.
                                ;   _Sys_ApplyFdActions repoints _fd_table_ptr
                                ;   at the CHILD's table and runs inside the
                                ;   PARENT's spawn syscall, so _curTask is the
                                ;   parent for the whole of it.  Every other
                                ;   writer of _fd_table_ptr derives it from
                                ;   _curTask, so the two agree everywhere else.
                                ;
                                ;   It matters because UFS 1.7d I2b gave the FS
                                ;   layer a SECOND table indexed BY PID: the fd
                                ;   table is reached through a pointer, but
                                ;   kdesc_alloc/free/dup take a pid.  Reading
                                ;   _curTask there would clear the PARENT's
                                ;   descriptor while clearing the CHILD's fd
                                ;   slot -- the two tables silently disagreeing
                                ;   for the one process whose descriptors a
                                ;   spawn is in the middle of building.
                                ;
                                ;   Read through _Fcb_OwnerPid, never directly.
_kCttyTarget    DS      2       ; pid whose controlling terminal a tty OPEN
                                ;   should set, or 0 = "the current task".
                                ;
                                ; Needed because init opens a line's device via
                                ; spawnx FILE ACTIONS, and _Sys_ApplyFdActions
                                ; runs inside INIT's spawn syscall -- _curTask is
                                ; still the parent there (process.s:320).  So the
                                ; obvious "_Ttyv_Open records _curTask's ctty"
                                ; bound the LINE TO INIT and left the shell that
                                ; actually runs on it with no controlling tty at
                                ; all.  The fd-based gate in _Tty_GetByte still
                                ; held, but the SYS_GETKEY gate did not bind,
                                ; which is half of apple/fgx#41's protection.
                                ;
                                ; Set around the file-actions walk and cleared
                                ; after, so an ordinary userland open() (target 0)
                                ; keeps binding to the caller, as BSD does.
_kKbdOptHeld    DS      2       ; 1 while the Option (Closed-Apple) key is down
                                ;   for the keystroke being translated.  A
                                ;   SECOND modifier flag was needed because the
                                ;   heartbeat already carries Ctrl in X and
                                ;   alt-N has to be distinguished from a bare
                                ;   digit; it lives here rather than in a
                                ;   register because @hb_kbdXlate is reached
                                ;   from two paths with different register use.
_kVcWrBracket   DS      2       ; 0 = no bracket open, else bracketed VC + 1.
                                ;   Set by _Vc_WriteEnter for the duration of
                                ;   ONE write(2) to a non-active VC and cleared
                                ;   by _Vc_WriteLeave.  Safe to keep as a single
                                ;   static rather than per-task because the
                                ;   heartbeat never preempts kernel code
                                ;   (toolbox.s:324, "Model A"): it only sets
                                ;   _kYieldReq and the dispatcher honors it
                                ;   BETWEEN syscalls, so a write loop always runs
                                ;   to completion and two brackets can never be
                                ;   open at once.
_kVcWrCurs      DS      2       ; 1 = _Vc_WriteEnter hid the block cursor for this
                                ;   write(2) and _Vc_WriteLeave owes a re-show.
                                ;   SEPARATE from _kVcWrBracket because the two
                                ;   cover different sets: the bank bracket is
                                ;   skipped when the target VC is already on
                                ;   screen, but the cursor must be hidden for
                                ;   EVERY ttyv write -- most of all the on-screen
                                ;   one, which is the cursor the user is looking
                                ;   at.  Same single-static reasoning as above.
_kVcEchoFrom    DS      2       ; 0 = the engine points where _FarSh_CdWrite
                                ;   found it, else the VC it pointed at before
                                ;   _Vc_EchoEnter moved it to the written line's
                                ;   console, + 1.  The discipline's own output
                                ;   (the echo) is the one writer whose line can
                                ;   be a console other than the engine's: the
                                ;   keyboard can be on the card's console while
                                ;   the SHR screen shows another.  Same single-
                                ;   static reasoning as _kVcWrBracket.
_kVcSwitchReq   DS      2       ; 0 = none, else target VC index + 1.  Set where
                                ;   the switch is DETECTED (an ISR), drained
                                ;   where it is SAFE -- never executed at the
                                ;   detection point.  Same shape as _kTtySigPend
                                ;   above it, and for the same reason: the
                                ;   switch rewrites the console engine's bank
                                ;   operands, so a task preempted mid-switch
                                ;   would resume with half of them retargeted
                                ;   (the wrong-bank smear of #20/!58).
_kConRestoreReq DS      2       ; nonzero = repaint the console at the next safe
                                ;   point.  cda.mod's RestAll hook sets it as the
                                ;   Ctrl-OA-Esc menu closes, inside an interrupt;
                                ;   _Con_DrainRestore (ttyv.s) consumes it where
                                ;   _Vc_DrainSwitch runs, for the same reason.

; Far kernel bank (docs/history/plans/far-kernel-bank.md).  Only a READY flag lives here: the
; far bank NUMBER is not stored, because it is always the live kernel bank + 1
; (the kernel handle's headroom bank), which Far_Init derives from _BANKK.  A
; stored copy would be one more thing to keep in sync for no gain.
_kFarReady      DS      2       ; 0 = far bank absent or unverified, 1 = patched
                                ;   and callable.  Every core->far call site must
                                ;   test this: with the bank absent the JSL operands
                                ;   keep the assembler's FGX_KFAR_BANK ($08) and
                                ;   would jump into an unrelated bank.

; Tty kernel bank (docs/history/plans/tty-kernel-bank.md).  Same shape and same reasoning one
; bank further on: the tty bank is always the live kernel bank + 2, so only the
; READY flag is stored.
_kTtyReady      DS      2       ; 0 = tty bank absent or unverified, 1 = patched
                                ;   and callable.  Every core->tty call site must
                                ;   test this, for the same reason _kFarReady
                                ;   exists: with the bank absent the JSL operands
                                ;   keep the assembler's FGX_KTTY_BANK ($09).
_clistVerdict   DS      2       ; T1's clist probe result: 0 = pass, else the
                                ;   failing case.  A STATIC and not a register,
                                ;   because Kern_LogStr returns Y holding the
                                ;   length of the string it just walked.
_ttyVerdict     DS      2       ; T2.1's linesw/tty-lookup probe result, same
                                ;   shape and same reason as _clistVerdict.

; (Sound state used to live here when we went through the Sound Tool Set;
; that approach was abandoned in favour of direct DOC programming, which is
; stateless from the kernel's perspective — see src/kernel/sound.s.)

;------------------------------------------------------------------------------
; Console statics moved to the FAR KERNEL BANK with the driver (2026-08-01):
;   _conMode, CON_VT_STATE, CON_EXPAND, CON_FONT_HDR_BUF, CON_ALT_SAVE.
; They are console-owned -- only CON_VT_STATE is read from the core kernel at
; all (14 sites in syscall.s, the deferred-flush timestamp and the hi-res
; profiling block), and those reach it by patched LDAL.  See
; src/kernel/far/far.s and docs/history/plans/far-kernel-bank.md.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Kernel log ring buffer.  Owner: kernel log facility.
; Zero-init: _KMem_ClearGlobals (the region falls within KMem_KGlobals).
; Writers append null-terminated lines + $0A; readers walk oldest->newest.
;------------------------------------------------------------------------------
; KMEM_LOGBUF_SIZE IS IN include/kernel.s, which is PUT before this file, so
; that klog.mod can share the one declaration -- it wraps its read cursor on the
; same number the writer wraps its index on, and Merlin32 does not nest PUT.
; RAISED $0700 -> $1000 (1792 -> 4096 B) on 2026-08-07, when the THIRD console
; landed (apple/fgx#43).  Each extra task adds its own stkhwm churn, and at 1792
; the ring wrapped fast enough to CLIP a line that had already been written:
; srcdepth_loud's `GUARD stkhwm 7 3994/4096` came back as `UARD stkhwm ...`, so
; the assertion missed an event the kernel had correctly reported.  A diagnostic
; ring that silently eats the diagnosis is worth less than the 2304 bytes of
; kernel heap this costs -- and 8 of the 23 klog probes were ALREADY asking for
; 4096, reading 2304 bytes of adjacent heap past the end of the old ring.
; The 1792-B ring buffer moved to the heap (Kmalloc M_KERN in _AllocLogBuf at
; boot; reached via the _kLogBufPtr DP long-ptr).  Bank-reclaim P0.1: this is
; the single biggest static FGX_DATA item; moving it lets FGX_DATA's anchor
; rise (P0.3) and raises the kernel code ceiling.  Only the small ring-state
; words stay static below.  (KMem_kernLog_end/_canary kept as a guard byte.)
KMem_kernLog_end        EQU *
KMem_kernLog_canary     DS  1
_kernLogHead            DS  2               ; next-write offset 0..KMEM_LOGBUF_SIZE-1
_kernLogWrap            DS  1               ; 1 iff buf has wrapped at least once
_kernLogMirror          DS  1               ; 1 iff _kernLogPutByte also mirrors
; /dev/klog's cursor over the ring above, and the copy counters its read uses.
; Owner: klog.mod (src/modules/klog/klog.s), which imports these addresses
; through its generated kernel_exports.s.
;
; THEY LIVE HERE AND NOT IN THE MODULE'S OWN BANK because a chardev op is entered
; with DBR = the kernel bank and never the module's (include/chardev.s), so here
; they are plain absolutes in every op -- the arrangement pty.mod's _ptyNbFlag
; has.  DUM space, so they cost FGX_DATA addresses and no image bytes.
;
; The ring itself has no read pointer: dmesg(1) copies the whole thing out
; without consuming it, so a second reader that DOES consume needs a position of
; its own, and the writer is left alone.
; There is no saved non-blocking flag and no copy-loop state here on purpose.
; The bulk read is handed its `flag' on the stack and RE-READS it rather than
; caching it, which is what makes it safe across the sleep -- the stack is the
; task's own kernel stack, restored with S when it resumes, where a static would
; be one task's answer handed to another (apple/fgx#89).  And the bytes are moved
; by uiomove, so there is nothing to count.
_klogRd                 DS  2               ; read cursor, 0..KMEM_LOGBUF_SIZE-1
_klogOpen               DS  1               ; 1 iff /dev/klog is open (one reader)
_klogVfsUiomove         DS  2               ; vfs.mod's uiomove, resolved at load
_klogVfsBank            DS  1               ; its bank; LAST, it is the flag
; 1 iff the registration in flight is a PRE-STAGED bank (vfs, ufs, ufsdir),
; which the boot loader placed before the kernel ran.  Mod_RegisterPreLoaded
; tail-calls Mod_RegisterStreamed, so both arrive at ONE announce and this is
; the only thing that can tell them apart.
_modPreStaged           DS  1

                                            ; each byte to Con_PutChar.  Flipped
                                            ; by _BootScreen once SHR console is
                                            ; up; pre-splash logs go to ring only.

;------------------------------------------------------------------------------
; Keyboard driver state.  Owner: console_kbd.  Zero-init: _KMem_ClearGlobals.
;   _conKbdLastKey  = ASCII of last key returned by Con_PollKey (0 if none).
;   _conKbdRepeat   = 0 before initial delay expires, 1 while auto-repeating.
;   _conKbdTick     = 16-bit Con_PollKey call counter, saturating at $FFFF,
;                     reset at each accepted key.  Used to gate same-key
;                     repeats against initial-delay / repeat-rate thresholds.
;------------------------------------------------------------------------------
_conKbdLastKey          DS  1
_conKbdRepeat           DS  1
_conKbdTick             DS  2

;------------------------------------------------------------------------------
; Console current-font name slot.  Owner: console driver.
; Zero-init: _KMem_ClearGlobals (falls within kernel globals region).
;
; The active-font long pointer lives in DP at cur_font_long_ptr (see dpmap.s);
; the 760-byte glyph block is heap-allocated at Con_Init via Kmalloc(M_FONT)
; and addressed through cur_font_data_ptr.
;
;   CurrentFontName - up to 16 bytes of the loaded .FNT file's name
;                     (no path, no extension, lowercased).  Empty (first
;                     byte = 0) when the built-in default is active.
;------------------------------------------------------------------------------
CurrentFontName         DS  16
KMem_CurFontName_canary DS  1

;------------------------------------------------------------------------------
; libc-core typed allocator state.  Owner: libc/alloc.s.
; Zero-init: _KMem_ClearGlobals (falls within kernel globals region).
;   Kmem_ArenaCount - number of populated arena records (0..KMEM_MAX_ARENAS).
;   Kmem_Arenas     - fixed table; each record 16 bytes.  Fields declared
;                     via ARENA_* offsets in alloc_state.s.
;   Kmem_TypeStats  - fixed 8 × 8-byte table; fields TS_INUSE/COUNT/CALLS/PEAK.
;------------------------------------------------------------------------------
KMEM_MAX_ARENAS         EQU  16              ; slot count in the arena table.
KMALLOC_BIG_THRESH      EQU  $F000           ; sizes >= this (or any 32-bit size with a
                                             ;   nonzero hi word) bypass the byte-grain
                                             ;   arenas for a DEDICATED MM block (train-2
                                             ;   M-4; kind=4 block-table row)
MM_CLAIM_MAX_BANKS      EQU  $20             ; single-claim ceiling for _MM_ClaimBanksToRow
                                             ;   (2 MB — sanity bound, not a design limit)
                                              ;  At boot, only KMEM_BOOT_ARENAS
                                              ;  of these are populated (the
                                              ;  rest-of-OS heap banks).  Slots
                                              ;  beyond that fill on demand
                                              ;  from _Kmem_GrowOneArena: when
                                              ;  Kmalloc would return ENOMEM, it
                                              ;  asks Bank_Alloc for a free
                                              ;  user-pool bank and turns it
                                              ;  into a fresh arena.  A grown
                                              ;  arena is not given back.
KMEM_BOOT_ARENAS        EQU  2                ; banks $08-$09 — populated at
                                              ;  Kmem_Init time before any user
                                              ;  task spawns.  Must not eat
                                              ;  user-pool banks at boot.
KMEM_ARENA_SIZE         EQU  16
KMEM_TYPE_COUNT         EQU  8
KMEM_TYPE_REC_SIZE      EQU  8

Kmem_ArenaCount         DS      2
; Phase 2B: the heap's first bank under reloc = _restBaseBank + REST_HEAP_FIRST_OFF
; (== $07 at the $02 build).  Computed once in Kmem_Init; replaces the fixed
; KMEM_HEAP_FIRST_BANK in the boot arena-count cap + _SoftGlob_ValidatePtr so the
; "in heap?" bounds track the dynamic rest-of-OS handle, not a stale $07.  Word:
; bank in low byte, high byte 0 (16-bit SBC/CMP safe).
_kHeapFirstBank         DS      2
Kmem_Arenas             DS      KMEM_MAX_ARENAS*KMEM_ARENA_SIZE
KMem_Arenas_canary      DS      1
Kmem_TypeStats          DS      KMEM_TYPE_COUNT*KMEM_TYPE_REC_SIZE
KMem_TypeStats_canary   DS      1

;------------------------------------------------------------------------------
; libc-core printf arg slots (8 × 16-bit).  In bank-$02 static memory (not
; DP) because we read via `LDA _kprintfArgs,Y` which needs abs,Y — there's
; no DP,Y mode on the 65816.  Owner: printf.s.  Zero-init: ClearGlobals.
;------------------------------------------------------------------------------
_kprintfArgs            DS      16
KMem_PfArgs_canary      DS      1

;------------------------------------------------------------------------------
; Per-task signal handler offsets (vi-port slice 3).  Each table is 16 * 2
; bytes -- indexed by (pid - 1).  Value:
;   $0000 = SIG_DFL (delivery falls back to _SigDefAction)
;   $0001 = SIG_IGN
;   else  = handler offset in the task's code bank.  TCB_CodeBank gives
;           the bank byte at delivery time.
;
; MIGRATED to heap soft-global (2026-06-05): the tables live in ONE
; Kmalloc'd (M_KERN) block reached via the DP long-pointer _sigHndPtr
; (dpmap.s); signal.s accesses them with [_sigHndPtr],Y by the field offsets
; below.  _AllocSigHnd (main.s) allocates+zeros it at boot (SIG_DFL = 0).
; Kernel-PRIVATE + syscall-context only: SYS_SIGNAL (set) and _Sys_CheckSignal
; (delivery, runs with kernel DP before the dispatcher's TCD to user DP) — NOT
; touched by the heartbeat (only _kAlarmTicks is), so [dp],Y is reachable.
; Reclaimed 65 static bytes of KGlobals.  Pointer-validity guarded by
; _SoftGlob_ValidatePtr (replaces the old canary).
; NB the tables size for 16 tasks (32 B each), matching the historical static
; DS 32 — NOT MAX_TASKS (=32); preserved verbatim as a faithful no-op.
; The mask/IGN tables below are 4 B per task and are sized for 16 TASKS, like
; everything else here.  They were sized for 8 (32 B each) while NPROC was 8,
; and NPROC became 10 on 2026-08-05 WITHOUT them being resized -- see the ERR
; below, which now makes that impossible to repeat.
;
; ONE ENTRY POINT AND THREE PER-TASK MASKS -- this is BSD's shape, and it is
; SMALLER than the five per-signal handler tables it replaces (apple/fgx#58).
;
; 2.11BSD keeps the DISPOSITIONS in the per-process u-area (u_signal[NSIG])
; and only three things in the kernel's proc struct: p_sigignore, p_sigcatch
; and p_sigmask.  FGX had it the other way round -- five per-signal tables of
; per-task handler OFFSETS -- which capped the catchable set at five signals
; and cost 160 bytes to do it.
;
; The five tables were also REDUNDANT.  libc's signal() passes the SAME value
; for every signal: _sig_tramp_off, crt0's adapter (see libc_c/signal.c).  The
; per-signal dispatch happens in the trampoline, out of the process's own
; handler table, where BSD keeps it too.  So the kernel needs exactly one entry
; offset per task, plus one bit per signal saying whether to use it -- which is
; p_sigcatch.
;
; The three masks are CONTIGUOUS AND EQUAL-STRIDE (64 B) on purpose: fork's
; inheritance walks them as one loop (process.s @vf_sigML) rather than three
; hand-written copies.  Add a fourth per-task mask INSIDE that run and bump the
; loop count; one appended after CATCH would be silently skipped, which is the
; trap the five handler tables used to carry.
;------------------------------------------------------------------------------
SIGHND_ENTRY_OFF        EQU     0           ; per-task signal ENTRY point, the
                                            ; (pid-1)*2 offset of crt0's
                                            ; trampoline in the task's CODE
                                            ; bank.  16 x 2 = 32 B.  One per
                                            ; task, not one per signal: the
                                            ; signum reaches the trampoline in
                                            ; A and it dispatches from there.
SIGHND_MASK_OFF         EQU     64          ; per-task 32-bit BSD signal masks,
                                            ; (pid-1)*4.  USER bit convention:
                                            ; bit (s-1) blocks signal s (the
                                            ; sigmask() shape callers compute),
                                            ; NOT the kernel pending layout.
                                            ; Set via SYS_SIGSETMASK (#102);
                                            ; _Sys_CheckSignal leaves masked
                                            ; signals PENDING.  Heap-resident
                                            ; on purpose: the kernel bank and
                                            ; the KMem data region are both at
                                            ; their ceilings (2026-07-27).
SIGHND_IGN_OFF          EQU     192         ; per-task 32-bit SIG_IGN masks,
                                            ; (pid-1)*4, bit (s-1).  A set bit
                                            ; means signal s is IGNORED: the
                                            ; pending bit is cleared and NO
                                            ; action runs.  Honors
                                            ; signal(sig, SIG_IGN/SIG_DFL) for
                                            ; EVERY signal -- shells ignore
                                            ; SIGTSTP/TTIN/TTOU to protect
                                            ; themselves, and dropping that
                                            ; install stopped tcsh dead on ^Z
                                            ; at its own prompt (2026-07-27).
                                            ; BSD's p_sigignore.
SIGHND_CATCH_OFF        EQU     320         ; per-task 32-bit CATCH masks,
                                            ; (pid-1)*4, bit (s-1).  A set bit
                                            ; means a user handler is installed
                                            ; for signal s, so delivery uses
                                            ; SIGHND_ENTRY_OFF instead of the
                                            ; default action.  BSD's p_sigcatch.
                                            ; This is what makes all 31 signals
                                            ; catchable rather than five.
SIGHND_BLK_SIZE         EQU     448         ; total block (heap Kmalloc).
                                            ; = CATCH_OFF + 64.  Highest byte
                                            ; any access reaches is
                                            ; CATCH_OFF + (NPROC-1)*4 + 3.
                                            ; Was 288 with the five tables.
;
; THESE TWO TABLES WERE SIZED FOR 8 TASKS WHILE NPROC WAS 10, and the damage was
; silent and severe.  THE OFFSETS BELOW ARE THE PRE-#58 ONES (MASK at 160, IGN
; at 224, block 288) -- kept verbatim because they are what the incident
; actually happened to; the arithmetic, not the addresses, is the lesson.
; Every access is base + (pid-1)*4, so with 32-byte tables:
;
;   pid 9  MASK -> 160+32 = 192 = pid 1's IGN word   (aliased)
;   pid 10 MASK -> 196            = pid 2's IGN word   (aliased)
;   pid 9/10 IGN -> 224..231      = PAST THE END of the 224-byte Kmalloc block
;
; So a pid-10 shell's SIGCHLD block-mask lived in pid 2's IGN word -- and pid 2
; is exactly the slot the wrapping allocator hands that shell's first child, so
; Task_Alloc's per-pid scrub erased the block mid-fork.  SIGCHLD then dispatched
; INSIDE the window tcsh blocks it for, pchild reaped a child palloc had not yet
; recorded, and the shell waited forever for a death that had already happened:
; a hang at the first foreground external command.  It only became reachable
; when a third console pushed the login shell from pid 9 to pid 10 -- pid 9's
; alias lands on init's IGN word, and init is never re-allocated.  See
; apple/fgx#43.  Plus 4 bytes of the NEXT heap object zeroed on every pid 9/10
; allocation.
;
; The ERR below is the actual fix: sizing and NPROC can no longer drift apart
; silently, which is what turned a one-word config change into a hang.
; Enforced by tools/check_bank0_geometry.py, which already reads NPROC and
; already guards the other per-pid table (the DP block).  Merlin's ERR fires on
; any NON-ZERO expression and has no ">" , so it cannot express "fits" -- it
; would have to be an exact-size assertion, which would then fail every time the
; block was deliberately given slack.

;------------------------------------------------------------------------------
; The time of day, UTC, as 32.32 fixed-point seconds since the epoch -- NTP's
; own format.  The heartbeat adds `_kTickFrac' (one VBL in 2^-32 s) to it every
; tick: 4.3BSD-Reno kern_clock.c:223's `BUMPTIME(&time, tick)' in a binary
; fraction.  Everything else about the clock -- inittodr, gettimeofday, the
; tick itself -- is C in the tty bank (src/kernel/tty/kern_time.c), which reads
; and writes these through its accessors under SEI so a tick cannot tear them.
; `_kRootFsTime' is the root superblock's fs_time, set by root_mount.c for
; inittodr's base (2.11BSD init_main.c:197).  Zero-init: _KMem_ClearGlobals,
; so a heartbeat before inittodr adds nothing.
;------------------------------------------------------------------------------
_kTodSec                DS      4           ; UTC seconds
_kTodFrac               DS      4           ; and 2^-32 of one
_kTickFrac              DS      4           ; one VBL in 2^-32 s
_kRootFsTime            DS      4           ; the root's fs_time, for inittodr

;------------------------------------------------------------------------------
; Per-task alarm tick counter (vi-port slice 3).  4 bytes per task (32-bit
; tick countdown).  Heartbeat decrements non-zero entries each VBL tick;
; when an entry reaches zero, SIGALRM is OR'd into that task's
; TCB_PendingSig.  Set via SYS_ALARM (#64).  Zero = no alarm pending.
; Zero-init: _KMem_ClearGlobals.
;------------------------------------------------------------------------------
_kAlarmTicks            DS      128         ; NPROC (32) x 4 bytes
KMem_AlarmTicks_canary  DS      1

;------------------------------------------------------------------------------
; Per-task ITIMER_REAL RELOAD -- setitimer(2)'s interval, in TICKS, TWO bytes
; per task at (pid-1)*2 against the counter's four above.
;
; `_Sys_AlarmTickAll' copies it into `_kAlarmTicks' whenever that counter reaches
; zero, and copies it UNCONDITIONALLY, which is the whole of upstream's
; repeating timer and not a shortcut:
;
;     if (p->p_realtimer.it_value && !--p->p_realtimer.it_value) {
;             psignal(p, SIGALRM);
;             p->p_realtimer.it_value = p->p_realtimer.it_interval;
;     }
;                       -- vendor/2.11BSD/usr/sys/sys/kern_synch.c:48-51
;
; A zero reload therefore leaves the one-shot that alarm(2) already was, so no
; arm has to ask whether a timer repeats.  alarm(2) zeroes it, which is what
; upstream's alarm(3) does with `timerclear(&itp->it_interval)'
; (examples/2.11BSD/usr/lib/libc/gen/alarm.c) before calling setitimer.
;
; 16-BIT, and the width is arithmetic rather than thrift: seconds become ticks
; as s*64 - s*4, so the INTERMEDIATE binds at 1023 s (ITIMER_MAX_INTERVAL,
; include/loader.s) and a longer interval is refused EINVAL in the far-bank arm
; rather than stored truncated.  Two bytes also let the whole table fit the room
; this region has -- measured 2026-09-21 at 87 bytes under the $02FE00 ERR.
;
; HERE rather than in signal.s beside the routine that arms it, because the
; FAR-BANK arm names it too and src/kernel/far/far.s PUTs this file and not that
; one.  Zero-init: _KMem_ClearGlobals, the same sweep the counter above relies
; on; the pid-reuse scrub is Task_Alloc's (apple/fgx#474).
;------------------------------------------------------------------------------
_kAlarmReload           DS      64          ; NPROC (32) x 2 bytes, ticks
KMem_AlarmReload_canary DS      1

;------------------------------------------------------------------------------
; Alarm EXPIRY hand-off, heartbeat -> swtch (apple/fgx#152).
;
; The heartbeat used to post SIGALRM itself when a counter hit zero, and stop
; there.  That left a task asleep on WCHAN_KBD with an empty ring holding a
; pending signal nothing would ever act on -- its own comment assumed "the next
; syscall exit will deliver", but a blocked task has no next syscall exit, and a
; timeout is by definition the case where the awaited event never arrives.
;
; It cannot simply call _Kill_PostOne instead: _Sys_AlarmTickAll runs at
; INTERRUPT time (toolbox.s, the firmware heartbeat), and posting walks the
; scheduler table, which a syscall may be part-way through.  So the ISR only
; RECORDS the expiry here and swtch does the post-and-wake in scheduler
; context -- the same shape _kSockWakePending already uses for the W5100 ISR.
;
; _kAlarmFired[idx] = 1 when that slot's counter reached zero; consumed (and
; cleared) by _Sig_AlarmDeliver.  _kAlarmFiredAny is the cheap gate so the
; common no-alarm switch stays one LDA+BEQ.
; Zero-init: _KMem_ClearGlobals (this is inside its LastExitStatus..
; KMem_KGlobals_end range -- see apple/fgx#120 for why that matters).
;------------------------------------------------------------------------------
_kAlarmFired            DS      32          ; NPROC (32) x 1 byte
_kAlarmFiredAny         DS      2           ; 0 = nothing expired since last scan

;------------------------------------------------------------------------------
; FST FOP table pointer — 3 bytes (lo, mid, bank).  Lives in bank-$02 static
; memory rather than DP.  (Historical note: the original rationale claimed the
; kernel DP page at $00:BF00 was "the ProDOS Global Page" and that DP $58-$77
; aliased ProDOS DEVADR vectors.  That was a MISATTRIBUTION — FGX runs no
; ProDOS, so $00:BF00 is just the MM-allocated kernel DP page: plain RAM in the
; net.mod's net_op_table location (bank:voffset), resolved once at boot by
; _Net_LoadOpsPtr (net_dispatch.s).  bank byte 0 ⇒ net.mod not loaded (the
; syscall thunks then return ENOSYS).
_net_ops_save           DS      3
KMem_NetOps_canary      DS      1

;------------------------------------------------------------------------------
; printf digit scratch (up to 5 ASCII chars + slack).  In bank-\$02 for same
; reason as _kprintfArgs: writes use X-index + Y-index, and abs,Y mode needs
; the label in bank-\$02 to match DBR.
;------------------------------------------------------------------------------
_pf_numBuf              DS      12          ; up to 10 digits (%lu max) + slack
KMem_PfNumBuf_canary    DS      1

;------------------------------------------------------------------------------
; Filesystem buffers.  Owner: fs driver.  Zero-init: Fs_Init.
;
; Each buffer gets a trailing 1-byte canary.  Buffer sizes are preserved
; exactly (disk-block / ProDOS layout) — canaries live in the gap byte
; between buffers, not inside them.  Every buffer now has its own
; overrun-detection boundary, not just the fs region as a whole.
;------------------------------------------------------------------------------
_fsDirBuf               DS  $0200       ; one dir block
KMem_fsDirBuf_canary    DS  1
; (P3.3-iv: _fsFileState/_fsDirState singletons + canaries retired.)
_fsStatBuf              DS  $0034       ; stat result -- FIFTY-TWO BYTES since
                                        ; the STX_ cutover (2026-09-05).  It
                                        ; held the 15-byte ProDOS-shaped ST_
                                        ; image; it holds 2.11BSD's struct stat
                                        ; exactly (usr/sys/h/stat.h:14-31),
                                        ; spares included, so libc copies it
                                        ; instead of translating it and a BSD
                                        ; port that reads any field compiles.
KMem_fsStatBuf_canary   DS  1
_fsStatNoFollow         DS  1           ; Fs_Lstat sets it, the root hook reads
                                        ; it, nothing else touches it.  Not live
                                        ; across a sleep -- the FS layer does not
                                        ; sleep, which check_fs_sleep_invariant
                                        ; holds and every other _fs* singleton
                                        ; here already leans on.
_fsLastDirInfo          DS  $0004       ; transient kernel channel from
                                        ; Fs_Stat -> Fs_Open: dir block (2 B)
                                        ; + entry offset (2 B). Previously
                                        ; squatted at _fsStatBuf+11..14;
                                        ; moved out so userland can see
                                        ; mtime at those offsets.
KMem_fsLastDirInfo_canary DS 1
                                        ; (_fsCwd retired: the cwd is now per-task,
                                        ; held in the heap cwd table reached via the
                                        ; DP long-ptr _fsCwdPtr — see project per-task
                                        ; cwd.  This reclaims 80 B of bank $02.)
KMem_fsCwd_canary       DS  1
; Landing pad for a path arriving from the far kernel bank.  Fs_Open and
; everything under it (Path_Resolve, _Sys_PathResolveImpl, prodos.mod's FOP
; path) reach the string DBR-relative with DBR forced to the kernel bank, so a
; far-bank path has to be copied here first -- see src/kernel/far_shims.s.
; Sized to the resolver's own staging limit (112) plus the NUL, rounded up.
FS_FARPATH_MAX          EQU 127         ; chars; buffer holds MAX+1 with the NUL
; No canary: the copy loop is length-bounded by FS_FARPATH_MAX, so there is no
; overrun for one to catch.
_fsFarPathBuf           DS  $0080
; (P3.3-iv: _fsCurOwnerFcb + canary retired — no owner machine.)

;------------------------------------------------------------------------------
; Write-path globals (single-buffer write model — only one open file may be
; in write mode at a time).  Relocated from write.s 2026-05-15 so prodos.mod
; can bake stable addresses; previously their position drifted with kernel
; code growth and bit slice 5g's FOP_Open migration.
; Set by Fs_Open/Fs_Create; consumed by Fs_Write and _Fs_FlushOnClose.
;------------------------------------------------------------------------------
; (P3.1 2026-07-18: _fwDirBlock / _fwDirEntryOff / _fwDataBlk / _fwIdxBlk /
;  _fwBlocksUsed retired — that per-file state lives in the FCB now
;  (FCB_DirBlock / FCB_FwDirEntryOff / FCB_DataBlk / FCB_IdxBlk /
;  FCB_BlocksUsed).  What remains below is BUFFER state — residency +
;  dirtiness of the shared 512 B buffers — which P3.3 retires with the
;  buffers themselves.)
; (P3.3-iv: the _fw* dirty/idx singletons retired — per-FCB
; FCB_WDirty/FCB_WBlkIdx replaced them.)
_blkSrcPool             DS  1           ; P3.3-iii-B: 1 = the NEXT Blk_Write
                                        ; sources from the F2 POOL bank (the
                                        ; _blkBuf offset is a pool-entry
                                        ; offset) and the entry stays VALID
                                        ; (it IS the freshest copy — WrInval
                                        ; skips the invalidate).  Self-
                                        ; clearing: Blk_Write zeroes it on
                                        ; every exit (success and error).
                                        ;   Tree master block == _fsFS_KeyBlk;
                                        ;   current sub-index == _fwIdxBlk;
                                        ;   "sub N resident?" == master[N]==_fwIdxBlk.
                                        ;   Reset on switch-away flush, so not
                                        ;   persisted per-FCB.
_ulSapRec               DS  3           ; P3.3-iv: unlink freeSap transient pin
                                        ; record {off16, idx8} (module scratch;
                                        ; always written before read)
_ulMasterRec            DS  3           ; P3.3-iv: unlink freeTree master pin
                                        ; record {off16, idx8}
KMem_fw_canary          DS  1
; P3.3-ii: found-dir-entry staging — readdir pins its block in the F2 pool
; and COPIES the winning 39-byte entry here, so the kernel-bank X-pointer
; ABI to readdir consumers survives the death of _fsDirBuf.  Also holds the
; vroot//MNT synthetic entries.  OVERLAYS _fsDirBuf's tail (bank $02 is at
; its $02FE00 ceiling): safe because the staging is written AFTER all
; pinning/chaining in a readdir call and consumed by the same syscall
; before any other FS op can rewrite the buffer (Model A atomicity).
_fsDirEnt               EQU _fsDirBuf+464
; P3.3-iii: FOP_Bmap -> kernel bulk-engine pin handoff (the kernel ReadN
; loop owns all three _fsTmp cells as scratch, so the resolver's pin record
; is republished here).  Overlays _fsDirEnt+40..43 = _fsDirBuf+504..507 —
; written AFTER any pin-miss bounce, consumed by the same syscall's copy.
; Both zero = sparse block (no pin; kernel zero-fills).
_blkPinOff              EQU _fsDirEnt+40    ; pinned buffer offset (2 B)
_blkPinRec              EQU _fsDirEnt+42    ; heap bank (lo) | slot idx (hi)

;------------------------------------------------------------------------------
; Fs_Lseek scratch (slice 4b, 2026-05-16).  Relocated from fs.s in-line DS
; so prodos.mod's FOP_Lseek can bake stable bank-$02 addresses (KAD_ EQUs).
; Kernel Fs_Lseek thunk captures args here before dispatching FOP_Lseek;
; module reads them and computes the new position.
;------------------------------------------------------------------------------
_flsOff                 DS  4           ; offset bits 0..31 (signed off_t)
_flsNew                 DS  4           ; computed new position (+pad)
_flsBase                DS  4           ; whence-derived base for the add
_flsFd                  DS  2           ; saved fd (low byte)
_fsLsWhence             DS  2           ; whence (SEEK_SET/CUR/END low byte)
KMem_fls_canary         DS  1

;------------------------------------------------------------------------------
; Fs_ReadN scratch (bulk file read primitive — used by program loader).
; State persists across nested helper calls (Blk_Read, _Fs_EnsureBlock)
; that clobber _fsTmp* / _shTmp*.  Owner: fs driver.  Zero-init: Fs_Init.
;------------------------------------------------------------------------------
_frnDstBank             DS  1           ; destination bank (low byte)
_frnPad0                DS  1           ; alignment slack
_frnDstOff              DS  2           ; destination offset (running cursor)
_frnRemaining           DS  2           ; bytes still to copy
_frnTotal               DS  2           ; bytes copied so far (returned in Y)
_frnFd                  DS  1           ; saved fd
_frnPad1                DS  1
KMem_frn_canary         DS  1

;------------------------------------------------------------------------------
; Fs_WriteN scratch (bulk file write primitive — mirror of Fs_ReadN).  ALIASED
; onto the _frn* storage above: a syscall is either a read or a write, and the
; cooperative scheduler runs each I/O primitive to completion (yields happen
; only at the syscall boundary, where this scratch is quiescent) — so Fs_ReadN
; and Fs_WriteN are never live at once and can share the bytes.  Zero growth
; (the bank-$02 KGlobals region is at its $02FE00 ceiling).  Owner: fs driver.
;------------------------------------------------------------------------------
_fwnSrcBank             EQU _frnDstBank         ; source bank (caller, low byte)
_fwnSrcOff              EQU _frnDstOff          ; source offset (running cursor)
_fwnRemaining           EQU _frnRemaining       ; bytes still to write
_fwnTotal               EQU _frnTotal           ; bytes written so far (ret in Y)
_fwnFd                  EQU _frnFd              ; saved fd

;------------------------------------------------------------------------------
; _fsMountTable migrated to heap (M_FS) — see fs_mount_ptr in dpmap.s.
;------------------------------------------------------------------------------
KMem_Fs_end             EQU *

;------------------------------------------------------------------------------
; Bus and device tables.  Owner: device layer.
; Zero-init: covered by _KMem_ClearGlobals (KMem_KGlobals region extends here).
; Dev_Init will also call _ZeroBankRegion for its owned sub-regions (phase 5).
;------------------------------------------------------------------------------
; apple/fgx#81: _dev_allocDevEntry used to stash the slot number in `_blkBuf+2`,
; which is not spare -- it IS `_blkNumHi` ($14, include/dpmap.s), the block
; layer's 32-bit block-key HIGH word.  Enumeration therefore left the slot
; number latched there, and the next Blk_Read added slot<<16 to its block
; number.  Same alias as apple/fgx#91, which fixed it in RamDisk_RegisterDev
; and left this copy.  A NAMED BYTE THE DEVICE LAYER OWNS cannot alias anything
; -- borrowing a neighbour's DP cell is what produced both bugs.
_devAllocSlot           DS  1               ; slot scratch across _dev_allocDevEntry
; THE PAD BECAME A NAMED BYTE, for the reason stated above it: this layer owns
; its scratch rather than borrowing a neighbour's cell.  Holds the first
; INVALID unit number on the bus being enumerated -- the SmartPort device count
; plus one, or SP_UNIT_MAX+1 when the port does not answer the roll call.
_devUnitLimit           DS  1               ; first out-of-range unit (count+1)
_busTable               DS  8*8             ; FS_MAX_BUSES * 8 B padded per entry
KMem_busTable_end       EQU *
KMem_busTable_canary    DS  1
; _devTable migrated to heap (M_KERN) — see dev_table_ptr in dpmap.s.
_diskStates             DS  32*8            ; FS_MAX_DEVICES * DSS_SIZE
KMem_diskStates_end     EQU *
KMem_diskStates_canary  DS  1

;------------------------------------------------------------------------------
; The user pool's page map (src/kernel/bank.s): 2.11BSD's resource map, NPROC
; slots of {size, addr} in 256-byte pages (CMAPSIZ is NPROC in 2.11BSD's
; param.c).  The width is a literal because NPROC is not in scope this early;
; bank.s carries the ERR that pins the two together.  Init: Bank_Init.
;------------------------------------------------------------------------------
_coremap                DS      128             ; NMAP (= NPROC) slots of 4 bytes
KMem_Coremap_end        EQU     *
KMem_Coremap_canary     DS      1
_rmSize                 DS      2               ; bank.s scratch: the request
_rmP                    DS      2               ;   the address placed or freed
_rmEnd                  DS      2               ;   one past a piece
_rmStart                DS      2               ;   the slot a split opens
_rmStrict               DS      2               ;   1 = pass 1 of Rm_Alloc
_rmPool                 DS      2               ;   banks in the pool (claimed)

; (slice-3 B.1 retired SpawnArg0/SpawnArg1.  argv/envp are now staged onto
; the child's user stack by _Loader_StageArgs at posix_spawn time.)

; Character-device registry.  The 384-byte table itself MOVED TO THE HEAP
; (soft-global, 2026-06-05): _Chardev_InitBuiltins Kmalloc's it and reaches it
; via the DP long-pointer _cdTablePtr (dpmap.s); chardev.s + jumptable.s access
; it with [_cdTablePtr],Y.  Reclaimed 384 static bytes of KGlobals -- and the
; table's address no longer drifts with kernel layout (the /dev-resolution
; heisenbug class).  _chardev_count stays static (a scalar; abs DBR-relative).
; Owner: src/kernel/chardev.s.  Zero-init: _KMem_ClearGlobals.
_chardev_count          DS  1               ; populated entries (0..16)
_cdRegArgOpsLo          DS  2
_cdRegArgOpsBank        DS  1
_cdRegArgMinor          DS  1
_cdRegArgFlags          DS  1               ; CD_Flags, from Y's high byte
_cdRegIdx               DS  1
_cdRegEntryOff          DS  2
_cdLkpIdx               DS  1
_cdLkpEntryOff          DS  2
_cdLkpSuffixPtr         DS  2
_cdLkpSuffixLen         DS  1
_cdLkpTmp               DS  2
_cdDispOpsLo            DS  2
_cdDispOpsBank          DS  1
_cdDispMinor            DS  1
_cdDispEntryOff         DS  2
; _Chardev_Bulk's scratch.  WRITTEN AND READ ENTIRELY BEFORE THE DISPATCH, never
; across it: a bulk op can BLOCK (_PtyM_Write sleeps on a full pty ring) and
; apple/fgx#89 is what a kernel singleton costs when another task reaches it
; during that sleep.  The op's own arguments travel on the stack for the same
; reason.
_cdBulkArg              DS  2               ; (uio bank << 8) | chardev idx,
                                            ;   the idx byte's bit 4 being the
                                            ;   ioflag -- see _Chardev_Bulk
_cdBulkFlag             DS  2               ; VFS_IO_NDELAY, split out of the
                                            ;   above and handed to the bulk op
_cdBulkSlotBk           DS  2               ; the bulk slot's OWN third byte --
                                            ;   NOT the record's CD_OpsBank,
                                            ;   which is the live bank and is
                                            ;   never zero.  For the
                                            ;   both-halves-zero test.
; THE WRITE PATH'S uio IS NOT HERE -- it is U_TtyIov/U_TtyUio in the U-AREA
; (include/kernel.s), because it is PER TASK.  It was a pair of statics here
; for one afternoon and that was a defect: a uio is a cursor the discipline
; consumes across a sleep, so two concurrent writers shared one.  The finding
; is written up beside the fields.
_cdArgByte              DS  2               ; arg byte for COPS_Write (set by
                                            ; _Sys_Write CHARDEV branch before
                                            ; _Chardev_Write call; loaded into
                                            ; A by _Chardev_Dispatch right
                                            ; before the JSL into the module.
                                            ; ALSO set by jumptable.s's
                                            ; @kc_cdwrite -- the VFS reaches
                                            ; the same drivers as of UFS 1.13b)
; _cdArgFlag -- the op's `flag' argument, IO_NDELAY today (VFS_IO_NDELAY, the
; vnode.h bit, so one spelling reaches both routes).  Loaded into X by
; _Chardev_Dispatch immediately before the JSL, and ZEROED THERE as it is
; consumed: a caller with no flag to pass must not inherit the previous
; caller's, and forgetting to set it has to mean "blocking" rather than
; "whatever the last write wanted".
;
; A SINGLETON, and safe as one for the same reason _cdArgByte is: written by
; the caller and read by the dispatch with nothing in between that can sleep.
; What apple/fgx#89 punishes is state held ACROSS a blocking op; this is spent
; before the op starts.
; THE TTY BANK'S ONE IMPORT FROM vfs.mod, resolved once at boot by
; _Tty_LoadVfsPtr and read by _FarSh_Uiomove.  apple/fgx#108 T3.
;
; HERE AND NOT IN THE TTY BANK, because the resolve needs Mod_FindVtable and
; that is core code; the shim that uses them is core code too, so the values
; never cross a bank at all.  The tty bank reaches uiomove by JSLing the shim,
; the way it already reaches wakeup.
;
; ONE SLOT, NOT THE WHOLE VFSCORE TABLE.  ufs.mod copies all of it because it
; calls a dozen entries; the tty bank calls exactly one, and a subset-sized
; destination fed to a whole-table copy loop is a measured overrun
; (apple/fgx#169).  A single-slot resolve reads the slot it wants.
;
; _ttyVfsBank IS THE RESOLVED FLAG.  Zero means the resolve never ran or found
; no vfs.mod, and the shim refuses rather than PILECALLing into bank zero.
_ttyVfsUreadc           DS  2               ; ureadc's offset within vfs.mod
                                            ;   (apple/fgx#108 T3, ttread)
_ttyVfsBank             DS  2               ; low byte = vfs.mod's live bank
_ttyVfsUio              DS  2               ; uiomove's offset within that bank
_cdArgFlag              DS  2
; _Sys_CdFlag -- the per-byte loops' copy of the descriptor's non-blocking bit,
; read ONCE from [_fcbPtr] before the loop and parked on the kernel stack
; around each dispatch.  Read per iteration instead, it would be the apple/
; fgx#89 shape again: _Chardev_Write sleeps, another task's syscall resolves
; _fcbPtr to its own descriptor, and the woken loop asks the wrong FCB.
_Sys_CdFlag             DS  2
; _cdKcName -- where KSVC_CDLOOKUP stages a device name it was handed in
; ANOTHER BANK, so that _Chardev_LookupSuffix (which takes a kernel-bank
; pointer and an explicit length) can be given one.  Sixteen bytes because
; CD_Name holds fifteen characters and a name longer than that cannot match
; anything registered.  One writer, jumptable.s's @kc_cdlookup, and nothing
; reads it after that call returns.
_cdKcName               DS  16
; Cross-bank MOD_REGISTERCHARDEV scratch (jumptable.s
; _Mod_RegisterCharDevImpl).  Live only for the duration of one
; registration.
_cdRegCallerBank        DS  2
_cdRegArgOpsLoX         DS  2               ; renamed slot — caller-side ops offset
_cdRegArgNameLo         DS  2               ; caller-side name offset

; _Sys_InstallSccIrq scratch (jumptable.s _Sys_InstallSccIrqImpl).  Live
; only for the duration of one SYS_INSTALL_SCC_IRQ call.
_sccIrqArgChan          DS  2
_sccIrqArgIsrLo         DS  2
_sccIrqArgIsrBank       DS  2
_sccIrqCmdLo            DS  2
_sccIrqSerFlagLo        DS  2
_sccIrqSerFlagBank      DS  2
_sccIrqSerFlagMask      DS  2

; Kernel IRQ trampoline saved-vector slot.  Holds the original 4-byte
; JML instruction that lived at $E10010 before _KernIrq_Install patched
; it.  The dispatcher's "not our IRQ" path is literally `JML
; _kernIrqSavedVect` — execution lands here, reads the saved JML opcode
; + 24-bit address as code, and jumps to the original ROM IRQ chain
; (preserves heartbeat, AppleTalk, etc.).  See gno-kern sim/sim.asm
; for the canonical SIM pattern this mirrors.
_kernIrqSavedVect       DS  4

; SCC chan B RX ring buffer (IRQ producer / serial_read consumer).
; Phase 2 of the IRQ-driven serial work — _KernIrq_Dispatch drains
; $E0C03A into _sccRxBuf[_sccRxHead++], serial_read pops from
; _sccRxBuf[_sccRxTail++].  256-byte ring so head/tail are single
; bytes that wrap naturally; empty iff head==tail.  No overrun
; flag in v1 — a fast producer just overwrites unread data.
; RETIRED at apple/fgx#108 T7 step 3, and 256 bytes of this bank with it.  The
; chan-B ring held arrived-but-unread bytes because nothing else did; the
; receive interrupt hands each byte to `ttyinput' at arrival now and `t_rawq'
; holds them, with upstream's own TTYHOG overflow handling in place of this
; ring's silent discard-when-full.  Chan A keeps its ring below: it is
; AppleTalk's, it has no `struct tty', and its bytes still meet no discipline.
;
; WHAT REPLACES IT IS A COUNTER, not a queue: every byte the chan-B handler
; receives, whether or not the line is held.  It is the DENOMINATOR the
; witnesses need -- "t_rawq is empty" and "nothing was ever sent" read the same
; without it.
_sccRxCountB            DS  2

; Chan B `d_stop' dispatches -- the witness `serial_stop' never had.
;
; apple/fgx#240 made d_stop reachable and NOTHING MEASURED IT: the serial line
; was the only device with a d_stop body, so the wrong dispatch that bug caused
; found a zero slot everywhere else and returned in silence.  T7 makes the line
; a real tty, so `ttyinput's stop arm reaches it -- `if (CCEQ(tp->t_stopc, c))
; ... kc_cdstop((int)tp->t_dev, 0)' (tty.c:1093-1096) -- and a `^S' from the
; PEER is now a dispatch this can count.
_sccStopsB              DS  2
;
; IT READ 0 UNTIL apple/fgx#247, and that is how #247 was found: with `t_stopc'
; unseeded `ttyinput's stop arm could not match a `^S' and NO path dispatched
; d_stop at all.  Seeding the line at bind time fixed it, and `t7stop' is the
; witness #240 never had -- 39 bytes in, TS_TTSTOP set, four dispatches.

SCC_RX_BUF_SIZE         EQU 256         ; chan A's ring below still uses it

; Chan B open count -- how many descriptors hold /dev/tty01 right now.
;
; apple/fgx#108 T7.  2.11BSD's receive interrupt refuses to feed the discipline
; on a line nobody holds:
;
;     if ((tp->t_state & TS_ISOPEN) == 0) {
;             wakeup((caddr_t)&tp->t_rawq);
;             continue;                       -- discard the character
;     }
;         -- dzrint, vendor/2.11BSD/usr/sys/pdpuba/dz.c:229-235
;
; FGX CANNOT TEST TS_ISOPEN, and that was MEASURED rather than assumed: on a
; booted machine all six lines read t_state = $00000010, CARR_ON alone, the
; console with a getty on it included.  `tty_devinit' sets `t_oproc' and
; TS_CARR_ON for every bound line and says in as many words that TS_ISOPEN
; "belongs to `ttyopen' (tty.c:2159), which is `l_open'" -- and FGX's open path
; does not reach it yet.  So the bit is not maintained, and porting the guard
; against it would discard EVERY character on EVERY line, keyboard included.
;
; THE DRIVER'S OWN OPEN COUNT IS THE SAME QUESTION with state FGX does keep, and
; the driver is where upstream asks it.  Upstream's `wakeup' half has no
; counterpart here: it is for a process blocked in open awaiting carrier, and
; FGX raises carrier at bind time, so nothing ever waits.
;
; IN THE KERNEL BANK, beside the rings, for the reason they are: `serial_isr'
; runs with DBR on the kernel bank and its own header forbids module-bank state
; without a PHB/PHK/PLB dance around it.
_sccOpenB               DS  2

; SCC chan A RX ring buffer (printer port / tty00).  Mirror of the chan-B
; ring above; same SPSC discipline (ISR producer, serial_read consumer).
_sccRxBufA              DS  SCC_RX_BUF_SIZE
_sccRxHeadA             DS  1
_sccRxTailA             DS  1

;==============================================================================
; SIM (Serial Interrupt Manager) globals — Phase 1 kernel lift.
; See docs/superpowers/specs/2026-05-27-fgx-sim-kernel-lift-design.md
;==============================================================================

SIM_HANDLER_MAX  EQU  4

; Handler registry — 4 × {mask:1, addr_lo:1, addr_mi:1, addr_hi:1} = 16 B.
_simHandlerTbl    DS  SIM_HANDLER_MAX*4
_simHandlerCount  DS  1                 ; 0..SIM_HANDLER_MAX
_simHandlerLimit  DS  1                 ; count*4 (pre-multiplied walk bound)
_simChanOwned     DS  1                 ; OR of all live masks (gno ourSerFlag)

; ROM-version-cached JML targets — populated by _SimInitExitTable at boot.
; Each is "JML $FFxxxx" = 4 bytes ($5C opcode + 24-bit addr).
_simExitBrk       DS  4                 ; ROM 01: $FFB85F / ROM 03: $FFBD16
_simExitHandled   DS  4                 ; ROM 01: $FFBA86 / ROM 03: $FFBF58
_simExitSccChn    DS  4                 ; ROM 01: $FFB85E / ROM 03: $FFBD15
_simExitMain      DS  4                 ; ROM 01: $FFB843 / ROM 03: $FFBCFA

; Self-modifying trampoline for handler dispatch (SIM design §3.2 Q2).
; RELOCATED 2026-06-11 to the bank-0 FGX_INTVEC gateway (see _simTramp in the
; DUM $000320 block): the two `JSL _simTramp` sites in sim.s bake the cell's
; bank, so a kernel-bank cell would point into the old $02 after relocation.
; A fixed bank-0 cell makes both JSLs relocation-invariant; the cell's JML
; target still carries the registered handler's own (dynamic) bank.

; Handler-entry RR3 stash (lets a handler check multiple RR3 bits after
; per-byte Reset Highest IUS may have cleared others).
_isrEntryRR3      DS  1

; AppleTalk port ownership (set at boot by _DetectAppleTalkPort).
;   0 = none, 1 = chan A (printer), 2 = chan B (modem)
_apTalkPort       DS  1

; SCC TX ring — SPSC: producer = serial_write (kernel CPU), consumer =
; serial_isr (handler).  256-byte ring; 8-bit head/tail naturally wrap.
SCC_TX_BUF_SIZE   EQU  256
_sccTxBuf         DS  SCC_TX_BUF_SIZE
_sccTxHead        DS  1                 ; producer (kernel)
_sccTxTail        DS  1                 ; consumer (handler)
_sccTxInProgress  DS  1                 ; 0=idle, 1=byte in shift register

; SCC chan A TX ring (printer port / tty00).  Mirror of the chan-B TX ring.
_sccTxBufA         DS  SCC_TX_BUF_SIZE
_sccTxHeadA        DS  1                 ; producer (kernel)
_sccTxTailA        DS  1                 ; consumer (handler)
_sccTxInProgressA  DS  1                 ; 0=idle, 1=byte in shift register

; Install/remove arg-stashing scratch — used only during _Sys_SimInstall/
; RemoveImpl execution.  Not touched by the dispatcher or handlers, so no
; SEI bracket needed beyond what the impls already do.
_simInArgMask     DS  1
_simInArgOff      DS  2
_simInArgBank     DS  1

; SIM stats — 32-bit each.  Surfaced later via a deferred SYS_SIM_STATS
; syscall; for now visible only in MAME debugger.
; Dropped vs prior (2026-06-24): the 5 serial-side per-IRQ/per-byte counters
; (_simStatRxIrqs/_simStatTxIrqs/_simStatRxBytes/_simStatTxBytes/_simStatRxDrop,
; 20 B) — reclaimed to fit the chan-A (tty00) rings under the $02FE00 KGlobals
; ceiling, and to shrink serial_isr / its chan-A mirror.  The dispatcher-level
; counters below stay (cheap, sim.s-owned).  The standalone simtest.s keeps its
; own full stat set.  (Restore here + in serial_isr if SYS_SIM_STATS lands.)
_simStatTotal     DS  4
_simStatScc       DS  4
_simStatNotScc    DS  4

; (Former `ERR _simHandlerTbl-$02FA95` drift-anchor RETIRED 2026-06-05: serial.mod
;  now AUTO-RESOLVES its TX-ring + SIM-stat addresses from the kernel build
;  listing via tools/gen_kernel_exports.py, so the SIM block may drift freely.)

; Kern_LogDec16 scratch.  Placed AFTER the SIM block so it can't shift
; the hard-coded SCC-ring / SIM-stat EQUs baked into serial.mod (see
; feedback_module_kernel_address_baking).
_klogDecVal             DS  2               ; running value (trial-subtraction)
_klogDecLead            DS  1               ; leading-zero suppression flag

; Tree-file ($3) master-index buffer (ProDOS tree storage, Phase A).  One
; (P3.3-iv: _fsMasterBuf retired — tree state lives in pinned F2 pool
; entries via per-FCB pin records.)

; SIM Phase-0b: non-SCC "generic source" IRQ-handler registry (Uthernet/W5100
; slot IRQ etc.).  Walked by _KernIrq_Dispatch on non-SCC IRQs; written by
; _Sim_InstallGeneric.  Tail-appended after all module-baked KAD_/SIM-stat
; addresses so it shifts none (feedback_memmap_middle_insertion_breaks_boot).
SIM_GENERIC_MAX         EQU  2
_simGenericTbl          DS   SIM_GENERIC_MAX*3  ; N x {addr_lo, addr_mi, addr_bank}
_simGenericCount        DS   1                  ; 0..SIM_GENERIC_MAX
_simGenericLimit        DS   1                  ; count*3 (pre-multiplied walk bound)

; Uthernet II IRQ observability (Phase 0b): the W5100 ISR bumps _u2IrqCount on
; each claimed slot IRQ and records the IRQR it saw — read by the net_irq gate.
_u2IrqCount             DS   1                  ; claimed-IRQ count (8-bit; >0 = fired)
_u2IrqLastIR            DS   1                  ; last IRQR ($0015) the ISR saw
; IRQ-driven RX (2026-06-04): lazy ISR flags readiness; bus-safety statics.
_u2RxReady              DS   1                  ; per-socket readable bitmask (bit n = socket n)
_u2Locked               DS   1                  ; 1 = foreground owns the W5100 bus (IMR-gating)
_u2Imr                  DS   1                  ; software IMR shadow (0 unarmed, $EF armed)
_arSaveH                DS   1                  ; transparent-ISR: saved indirect-bus AR hi
_arSaveL                DS   1                  ; transparent-ISR: saved indirect-bus AR lo
_u2SltSave              DS   1                  ; ISR-saved SLTROMSEL (re-assert slot-1 ext)
; slotscan (boot card scan): the detected W5100 slot + its SLTROMSEL bit, plus
; the per-slot result table (7 records of {flags, sig[6]}).  Inline DS statics
; (zero-filled at boot by _KMem_ClearGlobals); tail-appended so no KAD offset shifts.
_u2Slot                 DS   1                  ; detected W5100 slot (1..7; 0 = none)
_u2SltBit               DS   1                  ; (1<<slot) SLTROMSEL mask for that slot
_ssSltSave              DS   1                  ; _ScanSlots-saved SLTROMSEL (restore at end)
_slotTab                DS   49                 ; 7 x {flags, sig[0..5]} for slots 1..7
_ssSlot                 DS   1                  ; _ScanSlots current slot 1..7 (byte)
_ssSltBitTmp            DS   1                  ; (1<<slot) low byte (byte)
_ssPage                 DS   2                  ; slot<<8 (ROM page index base) (word)
_ssRecOff               DS   2                  ; _slotTab record offset for this slot (word)
_ssTmp                  DS   2                  ; scratch: mul-by-7 / _SlotHasRom reference (word)
_ssSigByte              DS   1                  ; sig read byte stash (byte)
_kSockWakePending       DS   2                  ; W5100 ISR sets (1) on a claimed socket
                                                ; IRQ; swtch @sw_save wakes WCHAN_SOCK +
                                                ; clears it, so a blocked recv/connect/send
                                                ; wakes even while a busy bg task spins (the
                                                ; idle-loop socket wake never runs then).
                                                ; Gated so it doesn't over-poll the slow
                                                ; W5100 on every switch.  Boot-zeroed.
_docOwner               DS   2                  ; pid of the task that claimed the DOC
                                                ; (SYS_SOUND_CLAIM); 0 = none.  _Exit_Core
                                                ; runs Sound_StopDoc when this task TERMINATES
                                                ; (kill/exit) so audio stops on kill but keeps
                                                ; playing when backgrounded/stopped.  Boot-zeroed.
_screenOwner            DS   2                  ; pid that claimed the screen (SYS_SCREEN_CTL);
                                                ; 0 = none.  _Exit_Core restores the console
                                                ; (Con_RenderAll) when this task TERMINATES,
                                                ; so a killed gfx tool doesn't leave the
                                                ; console suspended.  Boot-zeroed.
_gfxScanArmed           DS   2                  ; 3200-color scanline engine armed (0=no).
                                                ; The generic IRQ handler declines when 0.
_gfxScanInstalled       DS   2                  ; generic handler registered once (0=no).
_gfxScanTop             DS   2                  ; vert-count offset of SHR line 0 (calibration).
_gfxScanCount           DS   4                  ; DIAG: 32-bit _GfxScanHnd entry count (0=not wired,
                                                ; ~100/frame=working, astronomically huge=ack storm).
; _docVecSave moved to the FAR kernel bank with the sound driver (2026-08-01).
; It was only ever touched by sound.s, so it travels with it and stays
; DBR-relative there -- no cross-bank access, nothing to patch.
_cwdTblPtr              DS   3                  ; heap base of the per-task cwd table
                                                ; ((NPROC+1)*CWD_MAX, M_KERN); read via abs
                                                ; (DBR=kernel-bank) in swtch/Task_* to compute
                                                ; slot ptrs into _fsCwdPtr/_kCopyPtr.  Boot-set.
_procNameTblPtr         DS   3                  ; heap base of the per-task process-name table
                                                ; ((NPROC+1)*PROC_NAME_MAX, M_KERN).  Boot-set.
;
; KGlobals ends here, at the kernel-bank top ($FE00 offset) ceiling.  (The
; MOD_JT once sat here at $02FE00; under the relocatable kernel it lives in
; bank 0 at MOD_JT_BASE=$00032E — the historical $02FExx addresses below
; describe the OLD kernel-bank layout at bug-time.)  The W5100 DIAG ring +
; netdump capture statics that used to follow are relocated ABOVE this region
; (the W5BPF block below): in this slot they overflowed into the then-resident
; MOD_JT slots ($02FE00-$02FE71), so _Net_DrainFrame corrupted the jump table
; (e.g. _bpfRxrd aliased SYS_SIM_INSTALL @ $02FE6A; _bpfSnapBuf spanned
; SYS_KERNLOG @ $02FE46) -> W5100 RX_RD desync firehose + garbled console.
;
; Periodic-metadata-sync throttle (file-growth visibility, 2026-06-16).  Holds
; the low 16 bits of _kSystemTicks at the last Fs_Write metadata flush; Fs_Write
; commits the dir entry once ~1s of writing has elapsed so ls/cat/tail see a
; long write (e.g. `ping ... > log &`) grow instead of staying 0-byte until
; close.  Kernel-only (no prodos.mod KAD_ alias) -> tail-appended here so it
; doesn't shift any KAD_-baked offset.  Garbage-tolerant: a stale value just
; forces an immediate first sync.  See docs/ROADMAP.md (in-core inode cache).
_fwSyncTick             DS  2
; /RAM5 RAM-disk adopt/create state (see include/ramdisk.s + src/drivers/
; ramdisk/ramdisk.s).  Kernel-only (no prodos.mod KAD_ alias) -> tail-appended
; so they don't shift any KAD_-baked offset.  Zero-filled at boot by
; _KMem_ClearGlobals, so _rdPresent starts 0 ("no buffer").
_rdBufPtr               DS  3                   ; /RAM5 buffer base (24-bit, deref'd MM handle); 0 = none
_rdSizeBytes            DS  4                   ; /RAM5 buffer size in bytes (from RD_CurDiskSize)
_rdBlocks               DS  2                   ; /RAM5 block count (= _rdSizeBytes/512; <=4096 for 2 MB)
_rdPresent              DS  1                   ; 1 once a buffer is adopted/created, else 0
; Train-2 M-1 (2026-07-17): the arena BLOCK TABLE — the seam that takes the
; kernel from "one contiguous boot REST claim" to N MM blocks (M-2 grows it
; at runtime; M-3 shrinks the boot claim).  The table itself is HEAP-
; resident (a 64B static tripped the \$02FE00 globals ERR — the coupled
; ceilings, live) reached via KHEAP_USE _kBlkTabBase + [_kHeapCur],Y —
; the first real _kHeapCur consumer, per the DP-relief forward rule.
; Row format (8 B, 16 rows): +0 base bank, +1 bank count, +2 kind (0=free
; tombstone, 1=boot REST claim, 2=MM kernel-arena bank, 3=MM user-grant bank
; from the pool-dry Bank_Alloc path, 4=dedicated big-malloc block),
; +3 OWNER PID (kind 4 only; 0 = kernel/unowned), +4..+7 MM handle (0 = none).
; Row 0 = the boot REST claim; kinds 3/4 are disposed + tombstoned by
; _BlkRow_DisposeByBank and their rows reused.
; The owner byte was the +3 pad until 2026-08-02 (#11): a kind-4 block is
; USER memory outside the task's data bank, so fork has to snapshot it and
; exit has to free it, and both need to know whose it is.  No layout change --
; the byte already existed.
; The loader hands off the CLAIMED bank count (KFGX_REST_COUNT) so a
; clamped small-RAM machine can't over-hand user banks (Bank_Alloc bounds
; against _kUserBankCount, not the fixed BANK_USER_COUNT).
_kBlkCount              DS  1                   ; live block-table rows
_kBlkTabBase            DS  3                   ; 24-bit heap base of the block table (_BlkTab_Init).

_kcDpSaveBase           DS  3                   ; 24-bit heap base of the kernel-C
                                                ;   register-file save table
                                                ;   (NPROC * KC_DP_STRIDE), allocated
                                                ;   by _AllocKcDpSave.  ON THE HEAP
                                                ;   RATHER THAN IN THE CODE REGION:
                                                ;   as a DS it was 1408 bytes of a
                                                ;   bank with 1607 to spare, which is
                                                ;   how the debug build came to
                                                ;   overflow its ceiling by 249.
                                                ;   Every other table this size is
                                                ;   Kmalloc'd for the same reason.
                                                ;   NO LONGER GATED, apple/fgx#204:
                                                ;   the table has to exist whenever
                                                ;   kernel C does, and kernel C is not
                                                ;   gated on KCPROBE -- vfs.mod says so
                                                ;   in as many words, and the tty
                                                ;   bank's C sleeps in `ttywait' since
                                                ;   T4 increment 4.  Three bytes, and
                                                ;   the committed kcprobe = 1 build
                                                ;   already carried them.
                                                ; train-3 F1: the in-core inode table shares this
                                                ; heap block at +INODE_TAB_OFF (KGlobals is at its
                                                ; $02FE00 ceiling — no room for a 2nd base static;
                                                ; separate when KGlobals is reclaimed for F2).
_bmSyncIdx              DS  1                   ; Bm_Sync running block index.  MUST be a static:
                                                ;   it survives the Blk_Write calls inside the sync
                                                ;   loop, and Blk_Write's device lookup CLOBBERS
                                                ;   _fsTmp0/_fsTmp0+1 (block.s ~L496) — the index
                                                ;   previously lived in _fsTmp0+1 and became the
                                                ;   device-ptr high byte after the first write: a
                                                ;   layout-dependent bitmap WRITE STORM (up to ~256
                                                ;   writes ≈ 4.5s) or a lucky immediate exit.  The
                                                ;   dp-scratch-aliasing class, found via train-2 M-1's
                                                ;   +64B heap shift flipping the garbage (2026-07-17).
; fsync(2)'s descriptor, held across `_Fcb_LookupPtr' (which clobbers A and
; _shTmp0) so the seam call below it still has the fd.  apple/fgx#355.
;
; NO PLACEMENT CONSTRAINT.  This used to be appended here because a declaration
; added above `_kBlkTabBase' shifted it and a RAM-poisoned boot then died.  That
; was BLKCACHE_USE reading `_kBlkTabBase' with the wrong DBR -- it took the
; symbol's offset out of the HEAP bank, so which garbage it read as the block
; table's base depended on where the symbol sat.  Fixed; the offset no longer
; decides anything and this region can be reordered like any other.
_ffsFd                  DS  2
KMem_KGlobals_end       EQU *                   ; must stay <= kernel-bank top $FE00

KMem_end                EQU *

                DEND

; Hard ceiling guard (the invariant whose absence let the overflow ship):
; KGlobals must not reach the kernel-bank top reserved region at offset $FE00
; (the BlkTramp/loader-handoff area; this is where the MOD_JT used to sit before
; it moved to bank 0 at MOD_JT_BASE=$00032E).  Literal $02FE00 = that kernel-bank
; top under the $02 assembly ORG; the ERR pins the live build to it.
                ERR     KMem_KGlobals_end-1/$02FE00

;------------------------------------------------------------------------------
; netdump capture block layout — Kmalloc'd (M_KERN) at boot by _Bpf_InitDev, NOT
; a hand-picked static address.  The earlier $02FF00 placement aliased the
; loader/BlkTramp/CoutTramp handoff ($02FF00-17) -> a fake "size heisenbug"
; (the open broke at certain kernel sizes); the one before that aliased the
; MOD_JT slots -> the W5100 firehose.  Let the memory manager place it.
; These are FIELD OFFSETS into the block; the driver reaches them via the DP
; long-pointers _bpfBase / _bpfSnapPtr (dpmap.s) with [dp],Y (the heap block
; lives outside the kernel data bank, DBR=kernel-bank).  _bpfPhys is loop-local
; now (DP temp _bpfPhysTmp).
;------------------------------------------------------------------------------
BPF_CapState    EQU  0      ; 1 byte : 0=idle, 1=capturing
BPF_Sat         EQU  2      ; 2 bytes: saturation-event count (full-RX events)
BPF_SatRept     EQU  4      ; 2 bytes: last BPF_Sat surfaced to userland (sentinel)
BPF_FrameLen    EQU  6      ; 2 bytes: drain scratch — MACRAW prefix length (payload+2)
BPF_CapLen      EQU  8      ; 2 bytes: drain scratch — min(payload, BPF_SNAPLEN)
BPF_Rxrd        EQU  10     ; 2 bytes: drain scratch — Sn_RX_RD value
BPF_SnapBuf     EQU  12     ; 66 bytes: one record {caplen.w, datalen.w, frame...}
BPF_BLK_SIZE    EQU  80     ; total block size (rounded up from 78)

;------------------------------------------------------------------------------
; Compile-time guard.  Merlin32 `ERR expr` fails if expr is non-zero;
; `x-1/LIMIT` evaluates to 1 iff x > LIMIT, so it's our overflow guard.
;------------------------------------------------------------------------------
                ERR     KMem_end-1/FGX_HEAP     ; overflow into FGX_HEAP (see kernel.s)
                ERR     KMem_end-1/$02FF00      ; must not overlap BlkTramp handoff

;------------------------------------------------------------------------------
; BANK-0 STACK ARENA / KERNEL-C PAGE geometry.
;
; The arena must end EXACTLY where the kernel-C direct page starts -- an
; overlap corrupts the page kernel C runs on, a gap silently wastes bank 0.
; Equality, so any drift fires.  Both come from one derivation
; (tools/ninja/genconfig.py), and this is the one invariant of it Merlin32 can
; express.  The others -- that page is the last one below the I/O space, and
; src/boot/stage2.s aliases the layout rather than copying it -- live in
; tools/check_bank0_geometry.py: the layout resolves through nested-brace
; expressions Merlin32 cannot evaluate (it has no operator precedence), and
; stage 2 assembles standalone and never sees this file.
;------------------------------------------------------------------------------
                ERR     FGX_STK_ARENA+{FGX_STK_ARENA_PAGES*256}-FGX_DP_KERNELC

; (Former `ERR _sccRxBuf/_sccRxHead/_sccRxTail` drift-anchors RETIRED 2026-06-05.
;  serial.mod used to hard-code these SCC ring addresses as EQUs and these
;  anchors caught drift.  Now serial.mod AUTO-RESOLVES them from the kernel build
;  listing at build time (tools/gen_kernel_exports.py, BSD ld-A style), so they
;  may drift freely -- the generator, not an anchor, is the guard.)

;==============================================================================
; BANK $02 — Loader handoff area ($02FF00..$02FF08)
;
; Wire-protocol between the boot loader (bank $00 assembly) and the kernel
; (bank $02).  Loader writes these bytes after SmartPort discovery and before
; MVN'ing the kernel into bank $02.  Kernel-side init reads them.
;
; - $02FF00..$02FF05: BlkTramp handoff (block.s -> Blk_Init builds SmartPort
;   trampoline JSL operand from EntryLo/Hi/Bank).
; - $02FF06..$02FF07: CoutTramp handoff (boot_console.s -> _BootCon_Init
;   patches its JSL operand from CoutEntryLo/Hi; bank is implicitly $00,
;   not stored separately).
; - $02FF08..$02FF17: _PreStaged_Banks — zero-terminated list of banks
;   into which stage 2 has MVN'd the FGXM module segments of /fgxunix.
;   Entry 0 is the FST (prodos today, FAT32 future); kernel iterates
;   the list calling Mod_RegisterPreLoaded for each non-zero entry,
;   then calls _Fst_LoadOpsPtr once.  Slot 0 was historically the
;   single-module _Prodos_Bank byte (slice 5n-1); the list shape lands
;   in the stage-2 preload.conf generalization (2026-05-17) without
;   shifting the byte's address.  Max 16 entries; kernel-side loop
;   stops at the first zero.
;
; Loader.s uses hardcoded addresses because it's assembled separately from
; the kernel; the kernel side references the labels below.
;
; Moved from $02BF00 to $02FF00 so the static data region below can grow
; to ~$02FF00 if needed (~$3400 larger than the old ceiling).
;==============================================================================

                DUM     $02FF00

_BlkTramp_EntryLo   DS  1                       ; $02FF00 BlkTramp entry byte lo
_BlkTramp_EntryHi   DS  1                       ; $02FF01 BlkTramp entry byte hi
_BlkTramp_EntryBank DS  1                       ; $02FF02 BlkTramp entry bank
_BlkTramp_ParamsLo  DS  1                       ; $02FF03 BlkTrampParams lo
_BlkTramp_ParamsHi  DS  1                       ; $02FF04 BlkTrampParams hi
_BlkTramp_ParamsBank DS 1                       ; $02FF05 BlkTrampParams bank
_CoutTramp_EntryLo  DS  1                       ; $02FF06 CoutTramp entry byte lo
_CoutTramp_EntryHi  DS  1                       ; $02FF07 CoutTramp entry byte hi
_PreStaged_Banks    DS  16                      ; $02FF08..$02FF17 — zero-
                                                ; terminated list of banks
                                                ; stage 2 pre-staged from
                                                ; /fgxunix's segment table
KMem_BlkTramp_end   EQU *
; KGlobals overflow sentinel — relocated here ($02FF18, the fixed free spot just
; after the loader handoff).  KGlobals fills exactly to the kernel-bank top
; ($FE00 offset; $02FE00 under the $02 ORG), so its canary can't sit at its own
; _end; a sentinel needs a fixed address (can't be Kmalloc'd).  Stamped by
; _KMem_WriteCanaries (main.s) and read by the smoke test, like every canary
; here (tools/check_canaries.py).
KMem_KGlobals_canary DS  1                       ; $02FF18
                ERR     KMem_KGlobals_canary-$02FF18    ; pin (free, post-handoff)

                DEND

MAX_PRESTAGED       EQU 16                      ; sizeof(_PreStaged_Banks);
                                                ; stage 2 caps writes and
                                                ; the kernel loop matches.

;==============================================================================
; BANK $03 — console ring buffers.
;
; Whole-bank allocations used by the console driver for CharBuf / AttrBuf
; and their alt-screen snapshots.  Total use: about 20 KB inside the 64 KB
; bank; remainder is free for future console growth.
;
; Historically this bank was also claimed by src/kernel/ipc.s (dormant
; stub not in the build) — that claim is invalid and ipc.s has been
; moved to bank $05.
;==============================================================================

                DUM     $030000

CON_CHARBUF     DS      $1F40                   ; 8000 B: 100 rows × 80 codepoints
                DS      $00C0                   ; pad to $032000
CON_ATTRBUF     DS      $1F40                   ; 8000 B: 100 rows × 80 flags
                DS      $00C0                   ; pad to $034000
CON_FGBUF       DS      $1F40                   ; 8000 B: 100 rows × 80 fg palette idx
                DS      $00C0                   ; pad to $036000
CON_BGBUF       DS      $1F40                   ; 8000 B: 100 rows × 80 bg palette idx
                DS      $00C0                   ; pad to $038000
CON_ALT_CBUF    DS      $07D0                   ; 2000 B: alt-screen char snapshot
                DS      $0030                   ; pad to $038800
CON_ALT_ABUF    DS      $07D0                   ; 2000 B: alt-screen flags snapshot
                DS      $0030                   ; pad to $039000
CON_ALT_FGBUF   DS      $07D0                   ; 2000 B: alt-screen fg snapshot
                DS      $0030                   ; pad to $039800
CON_ALT_BGBUF   DS      $07D0                   ; 2000 B: alt-screen bg snapshot
KMem_Bank3_end  EQU     *

                DEND

                ERR     KMem_Bank3_end-1/$040000  ; must fit in bank $03

;==============================================================================
; BANK $04 — console PreExp font tables (32 KB + 32 KB).
;
; Regular + bold PreExp font variants for the 16 fg/bg attribute combos.
; Each variant is 2016 B (126 glyphs × 16 bytes); 16 variants fit in ~32 KB
; rounded up to the half-bank.
;
; Declared as EQU rather than DS/DUM: Merlin32 limits any single DUM block's
; DS total to 64 KB, which this region would hit exactly.  EQU gives us the
; same "single source of truth" without crossing that limit, at the cost of
; not enforcing mid-bank collisions (bank $04 has only two allocations; if
; a third ever arrives, revisit this with a DUM-of-EQUs split).
;==============================================================================

CON_PREEXP_REG_BASE   EQU  $040000              ; regular PreExp: 16 variants
CON_PREEXP_BOLD_BASE  EQU  $048000              ; bold PreExp:    16 variants

;==============================================================================
; BANK $00 — non-DP allocations inside FGX_INTVEC region ($0300..$07FF).
;
; The kernel reserves $0300..$07FF as "interrupt vectors" (per kernel.s
; FGX_INTVEC), but one concrete slot lives here today: the IDROUTINE
; trampoline that _DetectHardware patches in to call $FE1F from a
; bank-0 context.  Declared here so any future claim on this range is
; forced through memmap.s and can't collide silently.
;==============================================================================

; --- Cells moved BELOW the firmware-scratched $03C8-$03CF window -------------
; ROOT CAUSE (RESUME 2026-06-12 gateway-cell-collision): the IIgs ROM IRQ path
; stomps $03C8..$03CC with ascending bytes during interrupt handling, despite the
; "firmware-free" claim below.  That corrupted _mlEntryJSL's JSL operand+RTL (it
; sat at $03C7-$03CB), so prodos.mod's mod_init RTL'd into garbage and the boot
; died.  _mlEntryJSL is kernel-internal (symbol-referenced by modload.s +
; jumptable.s only), so it moves freely; park it in the $0300 headroom.  The 5-byte
; hole left at $03C7 keeps KFGX_REST_ANCHOR pinned at $03CC (stage2.s EQU).
                DUM     $000300
_mlEntryJSL     DS      5                       ; $0300 module mod_init dispatch (moved from $03C7)
KFGX_REST_COUNT DS      1                       ; $0305 CLAIMED rest-of-OS bank count
                                                ;   (loader-written; small-RAM clamp.
                                                ;   0 = legacy loader → consumers use
                                                ;   the assembly constant.  MOVED from
                                                ;   $03CE: the 3.5"/IWM ROM driver's
                                                ;   boot-time scratch reaches past the
                                                ;   documented $03C8..$03CC stomp zone
                                                ;   and corrupted it on FLOPPY boots —
                                                ;   Bank_Init then computed a garbage
                                                ;   pool bound and boot died pre-shell.
                                                ;   $0305 sits beside _mlEntryJSL,
                                                ;   which survives the same boots.  M-3.)
KFGX_REST_HANDLE DS     4                       ; $0306-$0309 the REST claim's MM
                                                ;   handle (loader-written; only
                                                ;   meaningful when KFGX_REST_COUNT
                                                ;   != 0).  _BlkTab_Init copies it
                                                ;   into block-table row 0 so the
                                                ;   boot claim is MM-accounted like
                                                ;   every runtime claim (M-4).
; Preemption P2' — USER-READABLE resched mirror.  The heartbeat writes 1 here
; whenever it sets _kYieldReq (quantum expiry or kbd input); the syscall
; dispatcher writes 0 when it services the yield.  Userland can't cheaply poll
; the kernel-bank _kYieldReq (its bank relocates $02->$7D), so fcc's loop
; safepoint reads THIS fixed bank-0 word (LDAL $00030A) instead.  Word (not
; byte) so the M=16 LDAL needs no mask.  Lives in the firmware-free $0300-$03CF
; window, in the $030A..$031F gap.
KFGX_YIELD_MIRROR DS   2                        ; $030A user-readable resched flag
; KERNEL TRAP REPORT (apple/fgx#261).  The fcc stack-overflow traps in
; src/kernel/far/fcc_ktrap.s stop the machine with a border colour and a spin,
; and a colour is the whole of what a wedged machine could say.  apple/fgx#194
; and apple/fgx#225 each cost a long bisect for that reason -- #225 worst,
; because the guard fired on a FICTIONAL floor with a healthy stack and
; presented as a layout lottery.
;
; These four words are what the trap writes before it spins.  HERE, and not in
; the kernel bank, for three reasons: bank 0 at a FIXED address is readable
; without knowing where the kernel relocated to; $0300-$03CF is the
; firmware-free window so nothing else claims it; and a stack overflow is
; precisely the event that makes the kernel's own structures untrustworthy.
;
; MAGIC IS ZEROED AT BOOT (main.s, beside _KcDp_Zero) and written only by a
; trap, so a NON-ZERO magic means a trap fired in THIS boot.  Without the zero
; these are whatever the last run left, and a reader would be told a trap fired
; whenever the bytes happened to look right -- which is the failure mode the
; report exists to end, reintroduced one level up.
; RESERVED HERE, ADDRESSED FROM include/kernel.s.  The EQUs live there because
; every kernel-C module PUTs kernel.s and fcc_ktrap.s but NOT this file, so DUM
; labels are out of scope in a module.  This keeps the eight bytes claimed and
; documented -- so nothing else takes $030C -- and the ERR below makes a drift
; between the reservation and the EQUs a BUILD failure rather than four stores
; into somebody else's cells.
; DECLARED BECAUSE THEY WERE NOT, and a literal is invisible to this map.  The
; apple/fgx#242 language-card instrumentation writes both through literals:
; $C0DE to $030C as a positive control, and STATEREG parked at $030E, every
; heartbeat tick.  Because neither appeared here, the trap-report cells were
; placed on top of them TWICE -- reading back $C0DE the first time and $C500 the
; second, the low byte overwritten by the STATEREG park.
;
; A cell that exists only as a literal is a cell this file will hand to somebody
; else.  Grepping the sources missed both; the authoritative survey is
; `STAL/LDAL $0003xx' over the built kernel listings.
KFGX_LC_PROBE   DS      2                       ; $030C toolbox.s LC control
KFGX_LC_STATE   DS      2                       ; $030E toolbox.s STATEREG park
_KFGX_TRAP_RSV  DS      8                       ; $0310..$0317, see kernel.s
                ERR     _KFGX_TRAP_RSV-KFGX_TRAP_MAGIC
; THE RUNNING TASK'S KERNEL SLOT PAGE, reserved here and addressed from
; kernel.s for the reason the trap cells give: a module PUTs kernel.s and not
; this file, and ENTERK reads this cell on every kernel call a module makes.
_KFGX_KDP_RSV   DS      2                       ; $0318, see kernel.s
                ERR     _KFGX_KDP_RSV-KFGX_CUR_KDP
_LD_TRAMP_RSV   DS      4                       ; $031A LD_TRAMP, see kernel.s
                ERR     _LD_TRAMP_RSV-LD_TRAMP
                DEND

                DUM     $000320

IDROUTINE_TRAMP DS      4                       ; JSR $FE1F + RTL (4 bytes)
_FPSIM_TRAMP_RSV DS     4                       ; $0324 FPSIM_TRAMP, see kernel.s
                ERR     _FPSIM_TRAMP_RSV-FPSIM_TRAMP
_SYS_TRAMP_RSV  DS      4                       ; $0328 SYS_TRAMP, see kernel.s
                ERR     _SYS_TRAMP_RSV-SYS_TRAMP
; Relocatable-kernel anchor (2026-06-10).  The loader writes the live kernel
; bank here after the MVN; kernel-internal entry installs derive their bank
; from PHK, so this is the canonical record for diagnostics/probes and any
; future cross-bank consumer.  Lives in the firmware-free $0300-$03CF window.
KFGX_ANCHOR     DS      1                       ; $032C live kernel bank byte (loader-written)
KFGX_ANCHOR_MAG DS      1                       ; $032D magic $4B ('K') = anchor valid
; Module jump table, relocated 2026-06-11 from $02FE00 (top of the kernel bank,
; which moves under the relocatable-kernel campaign) into this bank-0 gateway.
; 6-byte header + 32 × 4-byte JML cells = 134 bytes, $032E..$03B3 — inside the
; firmware-free $0300-$03CF window.  _JT_Init (jumptable.s) builds it; modules
; JSL the FIXED bank-0 slot addresses, so they never need the kernel bank.
; Literal $032E here (modules.s is PUT after memmap.s, so its MOD_JT_BASE EQU
; isn't visible yet); the ERR below pins the two to agree.
MOD_JT_GATEWAY  DS      134                     ; $032E..$03B3 — 32 slots (6 hdr + 32×4); = modules.s MOD_JT_BASE
_simTramp       DS      4                       ; $03B4 SIM IRQ handler trampoline — moved here
                                                ;   from the kernel bank so `JSL _simTramp`
                                                ;   (sim.s) is relocation-invariant
; 4 more self-modifying JSL trampoline cells (chardev / FST / net / modload
; dispatch), relocated 2026-06-11 from the kernel bank: they were `$22 <tgt> $6B`
; reached via `JSL <cell>` + STAL patches, both baking $02, so they jumped to the
; STALE $02 staging copy once the kernel relocated.  Fixed bank-0 addresses make
; the JSL + STAL self-consistent.  Each = JSL <target> + RTL; the $22/$6B opcodes
; are written once by _JT_Init, the 24-bit target (+1/+2/+3) per dispatch.
_cdTrampJSL     DS      5                       ; $03B8 chardev dispatch (chardev.s)
                DS      5                       ; $03BD-$03C1 — RESERVED GAP
_netTrampJSL    DS      5                       ; $03C2 net op dispatch (net_dispatch.s)
                DS      5                       ; $03C7-$03CB — RESERVED GAP; $03C8 is in the
                                                ;   firmware scratch zone anyway.
                                                ; BOTH GAPS ARE HELD RATHER THAN RECLAIMED so
                                                ; KFGX_REST_ANCHOR stays at $03CC: the BOOT
                                                ; LOADER writes that address, so it is an
                                                ; agreement with a program this build does not
                                                ; contain.
; Rest-of-OS handle anchor (2026-06-11, two-handle MM model).  The loader writes
; the rest-of-OS handle's base bank here; the kernel seeds _restBaseBank from it.
; Fits the firmware-free $0300-$03CF window ($03CC..$03CD).
KFGX_REST_ANCHOR     DS  1                       ; $03CC rest-of-OS base bank (loader-written)
KFGX_REST_ANCHOR_MAG DS  1                       ; $03CD magic $4B ('K') = rest anchor valid
                                                ; (KFGX_REST_COUNT moved to $0305 —
                                                ;  the floppy ROM driver stomps here)
KMem_IDTramp_end EQU *

                DEND

                ERR     KMem_IDTramp_end-1/$0800  ; fits in FGX_INTVEC range
                ERR     MOD_JT_GATEWAY-$00032E    ; gateway base must == modules.s MOD_JT_BASE
