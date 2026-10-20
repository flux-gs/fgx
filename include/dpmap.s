;==============================================================================
; dpmap.s - Authoritative kernel direct-page (bank $00) layout.
;
; Every kernel DP allocation ($00-$FF) is declared in one DUM/DEND block so
; no two modules can silently claim overlapping bytes.  Replaces the
; previously scattered EQUs in include/shell.s, include/fs.s,
; include/console.s, src/drivers/block/block.s, and src/drivers/fs/path.s
; — a layout that had three modules (console scratch, block params, fs
; transients) all claiming $D0-$DD under a fragile "caller-saved"
; convention.  Memory `feedback_dp_scratch_aliasing.md` traces three real
; bugs to that convention (scroll+help corruption, date "01:00:06",
; boot "!" prompt).
;
; Discipline:
;   - Persistent module state keeps its existing addresses (minimizes
;     churn and preserves cycle-exact behavior where it matters).
;   - Block and fs transients relocated to $10-$1F, out of any overlap
;     with console scratch ($D0-$DF).  Console scratch is now exclusively
;     the console's.
;   - _conTmp3/_conTmp4 still intentionally alias _conFontPtr — that
;     overlap is INSIDE the console driver and never crosses a module
;     boundary, so it's a design choice not a hazard.
;   - Compile-time ERR catches overflow past $100.
;==============================================================================

                DUM     $00

;------------------------------------------------------------------------------
; $00-$0F: was blanket-reserved as "65816 zero-page (vectors, reset, etc.)".
; That description was wrong -- 65816 vectors live at $00FFE0-$00FFFF and never
; in a direct page.  The REAL reason this range was left alone is kernel.s's
; FGX_DP_KERNEL note: until Toolbox_AllocKernelDP runs, D=$0000, so these
; offsets land on bank-0 $00:0000-$00:000F, which firmware and the Memory
; Manager scratch freely.  After that call the kernel DP is a private
; MM-allocated page and the range is the kernel's alone.
;
; So it is usable -- by anything that runs AFTER Toolbox_AllocKernelDP.  Carving
; from the START of the block is deliberate: it shifts nothing below it, which
; matters because prodos.mod hand-syncs DP offsets (prodos.s hardcodes
; KDP_fsTmp2 EQU $1A) and a resize anywhere in $10-$1F would break it silently.
;------------------------------------------------------------------------------
_fsPathPtr      DS      3                   ; $00  long ptr to the caller's path
                                            ;   string.  Path_Resolve reads it
                                            ;   with [_fsPathPtr],Y so the path's
                                            ;   BANK travels with the pointer
                                            ;   instead of being inherited from
                                            ;   DBR -- see src/drivers/fs/path.s.
                                            ;   VALID ONLY AFTER
                                            ;   Toolbox_AllocKernelDP (see above);
                                            ;   Path_Resolve needs a live
                                            ;   filesystem, so it always is.
                DS      $0D                 ; $03-$0F still reserved

;------------------------------------------------------------------------------
; $10-$1F: block driver + fs transient parameters.  Moved here from
; $D0-$DD (console scratch zone) to eliminate the cross-module alias.
;------------------------------------------------------------------------------
_blkNum         DS      2                   ; Blk_Read: block number, LOW word
_blkBuf         DS      2                   ; Blk_Read: dest buffer (bank $02 offset)
_blkNumHi       DS      2                   ; $14: block number, HIGH word.  Was
                                            ;   _blkUnit (retired) + pad, so the
                                            ;   32-bit key cost no DP and shifted
                                            ;   nothing -- _fsTmp2 stays at $1A and
                                            ;   prodos.mod's hardcoded KDP_* offsets
                                            ;   are untouched.
                                            ;
                                            ;   CALLER INPUT ONLY, AND IT SELF-CLEANS.
                                            ;   Blk_Read/Blk_Write latch it into the
                                            ;   block driver's _blkCurHi and ZERO it
                                            ;   in the same breath, so it reads 0 at
                                            ;   all times except inside a 32-bit
                                            ;   caller's own store-then-call window.
                                            ;   That is why the ~60 sites that write
                                            ;   _blkNum alone did not have to be
                                            ;   swept: a stale high word cannot
                                            ;   survive to the next operation, so
                                            ;   16-bit callers stay correct by
                                            ;   construction rather than by audit.
                                            ;   _blkCurHi, not this cell, is what
                                            ;   the device and cache layers read.
_fsTmp0         DS      2                   ; fs scratch word
_fsTmp1         DS      2                   ; fs scratch word (also _fsTmpSrcIdx,
                                            ;   the path walker's staging read
                                            ;   index -- see the aliases below)
_fsTmp2         DS      2                   ; fs scratch word (16-bit: dev.s, fs.s
                                            ;   :2507/2512, bitmap.s all use the full
                                            ;   word; prodos.mod hardcodes it at
                                            ;   KDP_fsTmp2 $1A, so it CANNOT be
                                            ;   resized).
_blkEntryPtr    DS      3                   ; long ptr to BlkTramp code in bank $00
                                            ; (used to patch cmd byte at offset +11)
                DS      1                   ; pad to word alignment
_fsCurDevIdx    DS      1                   ; current device idx for block I/O
_devPtr         DS      3                   ; long ptr to current device record
KDp_transients_end EQU *

;------------------------------------------------------------------------------
; $20-$4F: heap-migrated buffer pointers (filled by their owners' Init);
; eventual IPC / scheduler reserve below them.
; NB the per-line "$xx" address comments in this block run +4 vs the actual
; location counter (the $00-$1F transients region overflows to $24).  The
; build listing is ground truth: dev_table_ptr=$2C .. _sigHndPtr=$40 ..
; _bm_ptr=$4C.  Trust the listing, not these comments, when claiming a slot.
; (cur_font_data_ptr=$24 was the first of these anchors until the font
; pointers moved to the far bank, apple/fgx#103; dev_table_ptr replaces it.
; tools/check_probe_offsets.py pins its DS cursor to these three.)
;------------------------------------------------------------------------------
                  DS    8                   ; $20-$27 FREE.  Was
                                            ;   cur_font_data_ptr and
                                            ;   cur_font_long_ptr, which
                                            ;   describe the DEVICE's active
                                            ;   font and so must not be
                                            ;   per-task; they are now
                                            ;   CON_FONT_DATA_PTR /
                                            ;   CON_FONT_LONG_PTR in the far
                                            ;   console bank (apple/fgx#103).
                                            ;   HELD AS PADDING, not reclaimed:
                                            ;   every cell below is addressed by
                                            ;   offset from probes and from the
                                            ;   census, so closing the gap would
                                            ;   move all of them for 8 bytes.
dev_table_ptr     DS    3                   ; $28  long ptr to heap _devTable
                  DS    1                   ; $2B  pad
                  DS    3                   ; $2C  free
                  DS    1                   ; $2F  pad
_cdTablePtr       DS    3                   ; $30 long ptr to heap chardev table
                                            ;     (soft-globals; see chardev.s)
                  DS    1                   ; $33 pad
_modRegPtr        DS    3                   ; $34 long ptr to heap module-vtable
                                            ;     registry (soft-global; modload.s)
                  DS    1                   ; $37 pad
_logSrcPtr        DS    3                   ; $38  long ptr for Kern_LogStrLong
                  DS    1                   ; $3B  pad
_sigHndPtr        DS    3                   ; $40  long ptr to heap signal-handler
                                            ;     tables (soft-global; signal.s)
                  DS    1                   ; $43  pad
_ifTablePtr       DS    3                   ; $44  long ptr to heap ifnet table
                                            ;     (soft-global; ifconfig_sys.s)
                  DS    1                   ; $47  pad
_fd_table_ptr     DS    3                   ; long ptr to fd_table[FS_MAX_FDS]
                  DS    1                   ; pad
_bm_ptr           DS    3                   ; long ptr to volume bitmap buffer
                  DS    1                   ; pad
                  DS    $50-{*}

;------------------------------------------------------------------------------
; $50-$9F: libc-core DP slots (scratch, printf args, allocator result slot,
; walk callback state).  All routines in src/kernel/libc/*.s own these;
; nothing outside libc is allowed to touch them.
;------------------------------------------------------------------------------
_libcTmp0       DS      2                   ; $50  scratch word 0
_libcTmp1       DS      2                   ; $52  scratch word 1
_libcTmp2       DS      3                   ; $54  long-ptr scratch (for [dp],Y)
                DS      1                   ; $57  pad
_libcDstPtr     DS      2                   ; $58  bank-$02 dst ptr for (dp),Y
                DS      2                   ; $5A  pad to word align
_libcSrcPtr     DS      2                   ; $5C  bank-$02 src ptr for (dp),Y
                DS      2                   ; $5E  pad
_kmallocResult  DS      3                   ; $60  Kmalloc return: 24-bit ptr
                DS      1                   ; $63  pad
; (printf arg slots moved out of DP — there's no DP,Y addressing mode,
;  and the slots are only ever accessed via `_kprintfArgs,Y`, which needs
;  abs,Y.  The canonical slots now live in bank-$02 static memory via
;  include/memmap.s; see `_kprintfArgs` there.  The pad space here also
;  hosts BSD-fs scalar globals (bitmap dirty range and size).)
; THE TTY BANK'S OUTPUT RUN (apple/fgx#108 T3 stage 3).  _FarSh_CdWrite is
; handed a far pointer at a contiguous run inside the tty bank's t_outq and has
; to walk it with [dp],Y -- there is no stack-relative indirect LONG mode, so a
; DP cell is the only way to hold it.  PER-TASK, like the rest of this page,
; which is what makes it safe across the sleep _Chardev_Write can take when a
; pty master's ring is full.
_ttyRunPtr      DS      3                   ; $64-$66  long ptr to the run
                DS      1                   ; $67 pad.  $64-$67 was _bm_size,
                                            ;   _bm_dirty_lo and _bm_dirty_hi.
                                            ;   They describe the VOLUME, not
                                            ;   the task, and the kernel direct
                                            ;   page is per-task now -- so they
                                            ;   moved to kernel-bank statics
                                            ;   (include/memmap.s).  See
                                            ;   apple/fgx#103.
_kHeapCur       DS      3                   ; $68-$6A  THE shared heap-cursor long
                                            ;      pointer (DP-relief P1, train 2
                                            ;      phase 0a; design: docs/superpowers/
                                            ;      specs/2026-06-24-dp-pressure-
                                            ;      relief-design.md).  Was the
                                            ;      _kDpFree68 hole (ex-_fst_ops_ptr,
                                            ;      verified dead 2026-06-24) — the
                                            ;      LAST 3-byte-capable DP slot.
                                            ;
                                            ;      RULE (forward, from 2026-07-16):
                                            ;      every NEW heap soft-global keeps
                                            ;      its 24-bit base in a bank-$02
                                            ;      static and reaches the heap via
                                            ;      KHEAP_USE <base> + [_kHeapCur],Y —
                                            ;      NO new dedicated DP long-pointers.
                                            ;
                                            ;      CALLER-SAVED (like _shTmp*): any
                                            ;      foreign JSR may reload it — re-run
                                            ;      KHEAP_USE after calls, never cache
                                            ;      across them (the dp-scratch-
                                            ;      aliasing bug class).  IRQ/sched/
                                            ;      console hot paths keep their
                                            ;      dedicated pointers until measured.
                DS      1                   ; $6B  pad (word alignment)
_fsCwdPtr       DS      3                   ; $6C  long-ptr to CURRENT task's cwd slot
                                            ;      (curproc->fd_cdir analog; swtch repoints
                                            ;      it to _cwdTblPtr+(pid<<7)).  [dp],Y access.
_kCopyPtr       DS      3                   ; $6F  transient kernel copy-dest/aux long-ptr
                                            ;      (Task_InheritCwd/SetName dest, _Sys_Procs
                                            ;      name-source).  Caller-saved scratch.
_tsnPath        DS      2                   ; $72  Task_SetName: bank-$02 path offset
                                            ;      scanned via (_tsnPath),Y for basename
_kmem_prev      DS      2                   ; $74  allocator free-list walker scratch
_kmem_avail     DS      2                   ; $76  chunk size in current iteration
_kmem_remain    DS      2                   ; $78  remaining after split
_kmem_newOff    DS      2                   ; $7A  new-chunk offset after split
_pf_emitVec     DS      2                   ; $7C  printf output sink (Con_Write or buf)
_pf_argIdx      DS      2                   ; $7E  next arg slot to consume
_pf_width       DS      2                   ; $80  min field width
_pf_zeroPad     DS      1                   ; $82  1 iff '0'-pad vs space
                DS      1                   ; $83  pad
_pf_srcIdx      DS      2                   ; $84  format-string walker idx
_pf_strPtr      DS      2                   ; $86  %s arg ptr
_pf_bufPtr      DS      2                   ; $88  sprintf destination buf
_pf_bufMax      DS      2                   ; $8A  snprintf bound
_pf_bufPos      DS      2                   ; $8C  current write offset
_pf_tmp         DS      2                   ; $8E
_pf_t2          DS      2                   ; $90
_pf_numVal      DS      2                   ; $92  raw value (low word) of %d/%u/%x arg
_pf_numHi       EQU     _pf_numVal+2        ; alias: high word of 32-bit val
; (_pf_numBuf moved to bank-\$02 static memory — same reason as _kprintfArgs:
;  STA _pf_numBuf,X emits DP,X but STA _pf_numBuf,Y falls through to abs,Y
;  and the two end up accessing different banks.  See memmap.s.)
;
; The pad space here also hosts BSD-libc fs DP globals (_fcbPtr long pointer
; resolved per Fs_* call from a fd, and the global _errno byte).  Filesystem
; logically belongs in its own block but the IPC reserve at $40-$4F is full
; with heap-migrated table pointers, so we co-tenant the libc pad here.
_fcbPtr         DS      3                   ; $94  long ptr to current FCB
                DS      1                   ; $97  pad
_errno          DS      1                   ; $98  global errno byte (BSD style)
                DS      1                   ; $99  pad
_pf_numLen      DS      2                   ; $9A
_pf_hexCase     DS      1                   ; $9C  0=%x lower, 1=%X upper
_pf_long        DS      1                   ; $9D  1 iff `l` length modifier set
_curTask        DS      2                   ; $9E  current PID (swtch: TCB_TaskID of
                                            ;      the chosen task, sched.s @sw_pick).
                                            ;      ($0000 = no user task / kernel idle)
                                            ;      It said "TCB offset within bank \$02"
                                            ;      until 2026-08-02 and had not been one
                                            ;      for a long time -- every reader treats
                                            ;      it as a pid (seoff = (pid-1)<<5,
                                            ;      _fsCwdPtr = base + (pid<<7)).
                DS      $A0-{*}
_sockTablePtr   DS      3                   ; $A0  long ptr to heap socket-descriptor
                                            ;      table (soft-global; socket.s)
                DS      1                   ; $A3  pad

;------------------------------------------------------------------------------
; $A4-$B9: previously the in-kernel shell's persistent state (_shArgc,
; _shLineLen, _shCursor, _shHistIdx, _shBoot*, etc.), reclaimed when /bin/sh
; became a real userland binary — since RE-CLAIMED by the cooperative
; scheduler / log-ring / pick_next slots declared below.  NOT free; the only
; slack was the 2-byte legacy _pnBestTCB ($B6) — reclaimed as _kTtyRdPtr (pty P1b).
;
; $BA-$BF: general DP scratch, historically named _shTmp*.  Names retained
; because they're referenced throughout the kernel (FS, FCB, Bm, libc).
;
; **Cross-subsystem hazard.**  `_shTmp0/1/2` are NOT preserved across foreign
; JSRs.  In particular:
;   - Fs_Create/Open/Read/Write/Close/Stat/Opendir/Readdir/Closedir all
;     clobber _shTmp0/1/2 (slot scan, name compare, slot offset compute).
;   - _Fcb_LookupPtr writes _shTmp0 (fd-table byte offset).
;   - Bm_Alloc / Bm_Free / Bm_Sync indirectly clobber _shTmp0 via Blk_*.
;
; Treat _shTmp* as caller-saved (like a hardware register) — for state that
; must survive a foreign JSR, use bank-\$02 module-locals (DS at top of
; the .s file).  See feedback_dp_scratch_aliasing memory note for the
; full bug history.
;------------------------------------------------------------------------------
; $A4-$AF: cooperative scheduler soft-globals (claimed from the retired
; in-kernel shell's reclaimed DP region).  _schedTblPtr/_u are long-ptrs to
; Kmalloc'd heap (sched-state table / current task's u-area); the heap blocks
; live outside DBR=kernel-bank so they're reached via [dp],Y.
_schedTblPtr    DS      3                   ; $A4 long ptr to heap scheduler-state table
                DS      1                   ; $A7 pad
_u              DS      3                   ; $A8 long ptr to current task's u-area
                DS      1                   ; $AB pad
                DS      2                   ; $AC FREE (was _nReady -- declared,
                                            ;     never referenced anywhere in
                                            ;     the tree, so it counted no
                                            ;     tasks; deleted 2026-08-13)
                DS      2                   ; $AE FREE (was _schedLastSlot).
                                            ;     Moved to a kernel-bank static:
                                            ;     it is the round-robin cursor
                                            ;     and must be GLOBAL.  Per-task
                                            ;     direct pages gave each task a
                                            ;     private copy, so successive
                                            ;     switches -- which run on the
                                            ;     OUTGOING task's page -- each
                                            ;     advanced a different cursor
                                            ;     and fairness quietly stopped
                                            ;     being round-robin at all.
_kLogBufPtr     DS      3                   ; $B0 long ptr to heap kernel-log ring
                                            ;     (Kmalloc'd in _AllocLogBuf; 0 = not
                                            ;     yet allocated -> ring writes skipped)
                DS      1                   ; $B3 pad
_pnBestPri      DS      2                   ; $B4 pick_next: best (lowest) priority seen
_kTtyRdPtr      DS      2                   ; $B6 tty entry ptr for the ACTIVE
                                            ;     line-discipline read (DBR-rel;
                                            ;     set at read entry; the blocking
                                            ;     key-wait helpers save it on the
                                            ;     per-task stack — pty P1b.
                                            ;     Reclaims legacy _pnBestTCB.)
_pnScan         DS      2                   ; $B8 pick_next: round-robin scan cursor
_shTmp0         DS      2                   ; $BA
_shTmp1         DS      2                   ; $BC
_shTmp2         DS      2                   ; $BE

;------------------------------------------------------------------------------
; $C0-$CF: was 16 free bytes, then 10, and is now 6 ($CA-$CF) -- still the largest
; contiguous run left.  _conFontStage took three at $C0 and _cdKcNamePtr three
; at $C3; both are staging pointers for a dereference into another bank, which
; is the one thing that CANNOT live anywhere else.
;
; Was the console's persistent state (_conWritePtr .. _conAttr).  Those cells
; were never really direct-page state: console_switch.s saved and restored the
; whole run on every virtual-console switch, in a copy loop of its own that
; existed solely because the direct page is an address space the far bank
; cannot reach DBR-relative.  They now live in CON_VT_STATE as VT_WRITE_PTR ..
; VT_ATTR (include/console.s), inside the block that switch already copies, and
; _conRenderState with them as VT_RENDER_STATE -- outside the copied range,
; because it is transient pixel-pipeline state and not session state.
;
; Keep this run whole if you can.  A direct page is 256 bytes and this one is
; otherwise full; a future claimant needing a contiguous block has nowhere else
; to go, and there is no way to make more.
;------------------------------------------------------------------------------
; The one direct-page cell the font pointers still need: [ptr],Y requires the
; POINTER itself to be in the direct page, so a far-bank pointer has to be
; staged here before each dereference.  Per-task is correct for this -- it is a
; transient, live only across one glyph loop, and each loop stages it fresh.
;
; This is the shape the bank-0 census called DP-IRREDUCIBLE: the STORAGE can
; live anywhere, only the DEREFERENCE is pinned.  Three loops stage it, once
; each, outside the loop.
_conFontStage   DS      3                   ; $C0-$C2 far-bank font ptr, staged

; _cdKcNamePtr -- $C3-$C5, claimed at UFS 1.13b, and the run above is 10 bytes
; now rather than 13.  THE NOTE ABOVE ASKED FOR IT TO BE KEPT WHOLE AND THIS
; DOES NOT, so here is what was weighed.
;
; KSVC_CDLOOKUP is handed a device name in the CALLING MODULE's bank and has to
; read it.  Reaching another bank means `LDA [ptr],Y`, and that addressing mode
; requires the pointer itself to be in the direct page -- the same
; DP-IRREDUCIBLE shape _conFontStage above is, and for the identical reason.
;
; WHAT WAS CONSIDERED INSTEAD.  Borrowing _conFontStage: its contract is
; "staged fresh by each user", so nothing holds a value in it, and the cell
; costs nothing.  Refused because the safety argument is "no interrupt path
; makes a chardev call", which is true today, cheap to break, and expensive to
; re-verify -- the shared-DP-cell defects this tree has already paid for
; (apple/fgx#41, #100) were all of that shape.  MVN needs its bank operands as
; assembly-time immediates, so a block move cannot cross a bank chosen at run
; time.  Passing the name on the stack still needs an indirect read to get it
; there.
;
; Three bytes, one writer (jumptable.s's @kc_cdlookup), live for the length of
; one copy loop and never across a call.
_cdKcNamePtr    DS      3                   ; $C3-$C5 module-bank name ptr,
                                            ;   staged for KSVC_CDLOOKUP
_fdFilePtr      DS      3                   ; $C6-$C8 the `struct file' a
                                    ;   descriptor names -- UFS 1.7d I2c.
                                    ;   DIRECT PAGE because it is dereferenced:
                                    ;   the table lives in the FAR bank, so the
                                    ;   core reads it with [dp],Y and there is
                                    ;   no other addressing mode that takes a
                                    ;   runtime 24-bit base.  A far call per
                                    ;   read(2) was the alternative, and that is
                                    ;   a bank round trip on the hottest path
                                    ;   in the system.  Written by _Fcb_FileOf.
                DS      1                   ; $C9 pad (keeps the run word-aligned)
                DS      6                   ; $CA-$CF FREE

;------------------------------------------------------------------------------
; $D0-$DF: console internal scratch (was cross-module — now exclusive).
;------------------------------------------------------------------------------
_conScratch0    DS      2                   ; $D0
_conScratch1    DS      2                   ; $D2
_conScratch2    DS      2                   ; $D4
_conScratch3    DS      2                   ; $D6
_conScratch4    DS      2                   ; $D8
_conScratch5    DS      2                   ; $DA
_conScratch6    DS      2                   ; $DC
_conScratch7    DS      2                   ; $DE

;------------------------------------------------------------------------------
; $E0-$EF: console string ptr + _conTmp* / _conFontPtr (internal aliasing).
;------------------------------------------------------------------------------
_conStrPtr      DS      2                   ; $E0
_conTmp0        DS      2                   ; $E2
_conTmp1        DS      2                   ; $E4
_conTmp2        DS      2                   ; $E6
_conFontPtr     DS      3                   ; $E8-$EA (3-byte long pointer)
                DS      1                   ; $EB pad (aligns _conTmp5)
_conTmp5        DS      2                   ; $EC
_conTmp6        DS      2                   ; $EE

; _conTmp3 and _conTmp4 intentionally alias _conFontPtr — used only
; inside the console driver's font-rebuild path; never crosses a Con_*
; API boundary.
_conTmp3        EQU     _conFontPtr         ; $E8
_conTmp4        EQU     _conFontPtr+2       ; $EA

;------------------------------------------------------------------------------
; Path-resolver byte aliases into _fsTmp words.  Label-relative so they
; follow when _fsTmp0 / _fsTmp1 move.
;------------------------------------------------------------------------------
_fsTmp0h        EQU     _fsTmp0+1           ; high byte of _fsTmp0 word
_fsTmpSrcIdx    EQU     _fsTmp1             ; low byte of _fsTmp1 word

;------------------------------------------------------------------------------
; $F0-$F2: block driver trampoline long-pointer.  Fixed address —
; loader writes to it via the boot handoff at $02BF04..$02BF06.
;------------------------------------------------------------------------------
                DS      $F0-{*}             ; pad to $F0
_blkTrampPtr    DS      3                   ; long pointer: lo/hi/bank
; netdump capture block (kmalloc'd, M_KERN, in _Bpf_InitDev) — accessed via
; these DP long-pointers; the heap block lives outside DBR=kernel-bank so [dp],Y.
_bpfBase        DS      3                   ; $F3-F5 long ptr to the bpf capture block
_bpfSnapPtr     DS      3                   ; $F6-F8 long ptr to BPF_SnapBuf within it
_bpfPhysTmp     DS      2                   ; $F9-FA DrainFrame copy-loop ring position
_pipeTablePtr   DS      3                   ; $FB-FD long ptr to heap pipe-descriptor
                                            ;        table (soft-global; pipe.s)
                DS      $FF-{*}+1           ; remainder to $FF
KDp_end         EQU     *

                DEND

                ERR     KDp_end-1/$100      ; DP must fit in $00-$FF
