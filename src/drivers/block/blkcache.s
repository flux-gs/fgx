;==============================================================================
; blkcache.s - block cache core (train-3 F2-a).
;
; Transparent (dev, blk) -> 512 B copy cache that sits UNDER Blk_Read /
; Blk_Write (hooked in F2-b/c); this slice is the inert core + boot self-test.
; Lives in the block-driver segment — its runtime callers are the Blk_* hooks
; in block.s; _BlkCache_Probe and _BlkCache_InvalAll are ENT'd for the main
; segment (boot probe; unmount/mount invalidation).
;
; INVARIANT: a VALID entry holds the bytes last READ from disk for its key.
; A successful Blk_Write DROPS the entry rather than refreshing it (the old
; write-through refresh was retired 2026-07-18 -- it served cache-vs-disk
; inconsistent content under the finer write/read interleave), a failed write
; drops it too (on-disk state indeterminate), and whole-cache invalidation
; covers unmount/mount/rescan (media swap without unmount).
;
; THE KEY IS (dev, 32-bit block) as of UFS deliverable 1.0.  The low word
; arrives in A as it always did; the HIGH word is read from _blkCurHi, the
; block driver's per-operation cell, so no call site had to be touched to
; thread it through.  See include/dpmap.s for why that cell self-clears.
; Never reason from allocation patterns ("a freed block is rewritten before
; it's read") — only from the invariant.
;
; LATCH RULE, for whoever adds the next entry point: NO CACHE-KEY CONSUMER
; WITHOUT A LATCH UPSTREAM.  _blkCurHi is written only at the four gates that
; begin an operation (Blk_Read, Blk_Write, _BlkCache_PinGet,
; _BlkCache_PinAllocZ, each latching _blkNumHi and clearing it), and it is NOT
; cleared when the operation ends -- it simply holds until the next latch.
; Every routine here that touches the key therefore assumes one of those four
; ran first.  A new entry point that consults the cache without latching --
; the natural shape of a flush or a free-path invalidate -- silently keys on
; the PREVIOUS operation's high word and hits or evicts an entry 64 K away.
; Latch at the gate, not in the routine that reads the key.
;
; Storage: shares the block table's Kmalloc'd heap block at +BLKCACHE_OFF
; (KGlobals is at its $02FE00 ceiling — same dodge as the F1 inode table).
; _BlkTab_Init allocs + zeros headers and scratch; buffers start as garbage
; behind invalid headers.  See include/fs.s for the region map.
;
; Scratch contract: these routines run inside Blk_Read/Blk_Write, whose
; callers concede only A, X, Y and _libcTmp2.  The _fsTmp survival contracts
; USED to be contradictory across the codebase (bitmap.s documented Blk_Read
; as clobbering _fsTmp0/1, while prodos.s @rd_freeLoop NEEDS _fsTmp0 to
; survive it) — resolved 2026-07-18: Blk_Read/Blk_Write now SAVE/RESTORE
; _fsTmp0/1 around their disk paths, so hit and miss are behaviorally
; identical (the hit/miss asymmetry was the ls wild-free corruption class).
; The cache itself still touches NEITHER _fsTmp* nor _shTmp*; AllocLRU's scan
; state lives in the cache block's own BCS_* cells.  _BlkCache_Probe is the
; one exception: it runs at boot, pre-FS, and may use _fsTmp0..2.
;
; All routines: caller MX %00, DBR = kernel bank, kernel DP.
; All clobber A, X, Y, _libcTmp2, _kHeapCur (KHEAP_USE convention: every
; consumer repoints the cursor before use).
;==============================================================================

;------------------------------------------------------------------------------
; BLKCACHE_USE - point _kHeapCur at the cache region (+BLKCACHE_OFF into the
; block table's heap block).  Inline KHEAP_USE body — this segment PUTs no
; macros.s.  M=16 in/out.  The +BLKCACHE_OFF add stays 16-bit: Kmalloc blocks
; are bank-contained, so base+8583 never wraps the bank.
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; BCH_IDX - slot index (in A, 16-bit, masked to 0..NBUF-1) -> that slot's
; HEADER offset, i.e. A *= BCH_SIZE.  M=16 in/out.
;
; The stride used to be open-coded as three ASLs in FIFTEEN places, so growing
; the header from 8 bytes to 16 for the 32-bit key meant finding every one of
; them.  Miss one and that site reads headers at half the correct stride: a
; plausible-looking slot, the wrong entry, and a cache serving one block's
; bytes under another block's number.  One definition now.
;------------------------------------------------------------------------------
BCH_IDX         MAC
                ASL
                ASL
                ASL
                ASL
                <<<

BLKCACHE_USE    MAC
                PHB
                PHK
                PLB
                LDA    |_kBlkTabBase
                STA     _kHeapCur
                SEP     #$20
                LDA    |_kBlkTabBase+2
                STA     _kHeapCur+2
                REP     #$20
                PLB
                LDA     _kHeapCur
                CLC
                ADC     #BLKCACHE_OFF
                STA     _kHeapCur
                <<<

;------------------------------------------------------------------------------
; _BlkCache_Lookup - find the VALID entry for (dev, blk); touch its LRU.
; In:  A = block number LOW word, _blkCurHi = HIGH word, X.lo = device index.
; Out: C=1 + A.lo = buffer index (0..BLKCACHE_NBUF-1); C=0 = miss.
; MX:  caller %00; preserved (PHP/PLP).
;------------------------------------------------------------------------------
_BlkCache_Lookup MX     %00
                PHP
                REP     #$30
                STA     _libcTmp2               ; blk (16-bit)
                TXA
                SEP     #$20
                MX      %10
                STA     _libcTmp2+2             ; dev (low byte)
                REP     #$20
                MX      %00
                BLKCACHE_USE
                LDX     #0
@bcl_loop       TXA
                BCH_IDX
                TAY                             ; Y = hdr base = idx*BCH_SIZE
                SEP     #$20
                MX      %10
                LDA     [_kHeapCur],Y           ; BCH_Flags
                AND     #BCH_FL_VALID
                BEQ     @bcl_nextR
                INY
                LDA     [_kHeapCur],Y           ; BCH_Dev
                CMP     _libcTmp2+2
                BNE     @bcl_nextR
                INY
                REP     #$20
                MX      %00
                LDA     [_kHeapCur],Y           ; BCH_Blk low word
                CMP     _libcTmp2
                BNE     @bcl_next
                INY
                INY                             ; -> BCH_BlkHi
                LDA     [_kHeapCur],Y           ; BCH_Blk high word
                CMP    |_blkCurHi
                BEQ     @bcl_hit
                BRA     @bcl_next
@bcl_nextR      REP     #$20
                MX      %00
@bcl_next       INX
                CPX     #BLKCACHE_NBUF
                BCC     @bcl_loop
                PLP
                CLC
                RTS
@bcl_hit        INY
                INY                             ; Y was BCH_BlkHi -> BCH_LruLo
                LDA    |_kSystemTicks
                STA     [_kHeapCur],Y           ; touch
                TXA
                AND     #$00FF
                PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; _BlkCache_AllocLRU - claim a slot for (dev, blk): first INVALID slot, else
; the min-LRU victim.  Writes the full header (dev, blk, VALID, lru = now).
; The caller must fill buffer[idx] IMMEDIATELY — between AllocLRU and the
; content copy the entry lies about its bytes; no path may consult the cache
; in that window (single-threaded kernel, no yield inside Blk_*).  Tick wrap
; (~18 min) can occasionally evict a recently-used slot — harmless, cache
; correctness never depends on WHICH slot is evicted.
; In:  A = block number LOW word, _blkCurHi = HIGH word, X.lo = device index.
; Out: C=1 + A.lo = buffer index; C=0 = NO VICTIM (every candidate pinned),
;      in which case nothing was claimed and no header was touched.
; MX:  caller %00; preserved.
;------------------------------------------------------------------------------
_BlkCache_AllocLRU MX   %00
                PHP
                REP     #$30
                STA     _libcTmp2               ; blk
                TXA
                SEP     #$20
                MX      %10
                STA     _libcTmp2+2             ; dev
                REP     #$20
                MX      %00
                BLKCACHE_USE
                ; Pass 1: first invalid slot.
                LDX     #0
@ba_l1          TXA
                BCH_IDX
                TAY
                SEP     #$20
                MX      %10
                LDA     [_kHeapCur],Y           ; BCH_Flags
                AND     #BCH_FL_VALID
                REP     #$20
                MX      %00
                BEQ     @ba_claim               ; invalid -> X is the slot
                INX
                CPX     #BLKCACHE_LRU_NBUF      ; streaming window is off-limits
                BCC     @ba_l1
                ; Pass 2: min-LRU victim (state in the cache's BCS_* scratch).
                ; P3.3: BUSY (pinned) slots are exempt — a live pointer into
                ; the buffer exists, so it must not be evicted.
                ;
                ; BOTH cells are initialised, and BestIdx carries a SENTINEL.
                ; It used to be left alone while only BestLru was seeded, so a
                ; round in which every candidate was pinned stored nothing and
                ; the load below returned whatever the PREVIOUS call left there
                ; -- a stale index, quite possibly one of the pinned slots,
                ; which was then claimed and refilled under a live pointer.
                ; The old protection was the assumption that pins stay "far
                ; below BLKCACHE_NBUF"; the search is bounded by
                ; BLKCACHE_LRU_NBUF (16) while FS_MAX_FDS is 30, so that was an
                ; assumption, not a check.  apple/fgx#15.
                LDA     #$FFFF
                LDY     #BCS_BestLru
                STA     [_kHeapCur],Y
                LDY     #BCS_BestIdx
                STA     [_kHeapCur],Y           ; sentinel: no victim yet
                LDX     #0
@ba_l2          TXA
                BCH_IDX
                TAY
                SEP     #$20
                MX      %10
                LDA     [_kHeapCur],Y           ; BCH_Flags
                AND     #BCH_FL_BUSY
                REP     #$20
                MX      %00
                BNE     @ba_n2                  ; pinned -> not a victim
                TYA
                ORA     #BCH_LruLo              ; idx*8 has low 3 bits clear
                TAY
                LDA     [_kHeapCur],Y           ; this slot's lru
                LDY     #BCS_BestLru
                CMP     [_kHeapCur],Y
                BCS     @ba_n2                  ; lru >= best -> keep best
                STA     [_kHeapCur],Y           ; new best value
                TXA
                LDY     #BCS_BestIdx
                STA     [_kHeapCur],Y           ; new best slot
@ba_n2          INX
                CPX     #BLKCACHE_LRU_NBUF      ; streaming window is off-limits
                BCC     @ba_l2
                LDY     #BCS_BestIdx
                LDA     [_kHeapCur],Y
                CMP     #$FFFF
                BEQ     @ba_none                ; every candidate pinned
                TAX                             ; X = victim idx
@ba_claim       TXA
                BCH_IDX
                TAY                             ; Y = hdr base
                SEP     #$20
                MX      %10
                LDA     #BCH_FL_VALID
                STA     [_kHeapCur],Y           ; BCH_Flags
                INY
                LDA     _libcTmp2+2
                STA     [_kHeapCur],Y           ; BCH_Dev
                INY
                REP     #$20
                MX      %00
                LDA     _libcTmp2
                STA     [_kHeapCur],Y           ; BCH_Blk low word
                INY
                INY
                LDA    |_blkCurHi
                STA     [_kHeapCur],Y           ; BCH_Blk high word
                INY
                INY                             ; -> BCH_LruLo
                LDA    |_kSystemTicks
                STA     [_kHeapCur],Y
                TXA
                AND     #$00FF
                PLP
                SEC                             ; C=1: A.lo = claimed slot
                RTS

                ; No victim.  The caller must SERVE the block anyway: failing to
                ; cache it is a missed optimisation, failing to read it is a
                ; broken syscall.
@ba_none        PLP
                CLC
                RTS

;------------------------------------------------------------------------------
; _BlkCache_ReadAhead - fill an aligned RUN of BLKCACHE_RA_K slots (4 for a
; 2048-byte unit, _bra_k) with one extended $48 call.  Blk_Read's miss path calls this on an extended bus; on
; success the requested block (and K-1 of its neighbours) are cached, and the
; caller re-consults the cache instead of touching the device.
;
; The run is DIRECT-MAPPED: base_blk = blk & ~(K-1), run = (base_blk / K) mod
; NRUNS, slots run*K .. run*K+K-1.  No cursor state, the transfer is aligned by
; construction, and sequential streaming walks the runs in order.
;
; Adjacent slots are adjacent memory (BUFOFF + idx*512), which is the only
; reason a single transfer can fill K of them.
;
; CORRECTNESS DOES NOT DEPEND ON FILE LAYOUT.  These are consecutive DISK
; blocks, each cached under its own block number, so a fragmented file merely
; wastes the read-ahead -- it can never yield the wrong bytes.
;
; Bails (C=0) rather than forcing it when: the bus is not extended, the cache is
; not initialised, the run would cross the 16-bit block boundary, or ANY slot in
; the run is BUSY (pinned -- a live pointer into that buffer exists, and the
; transfer would rewrite it underneath its holder).
;
; In:  _blkNum = requested block, _fsCurDevIdx = device, _devPtr = device record.
; Out: C=1 = the run is cached (caller should re-Fetch); C=0 = do it the old way.
; MX:  caller %00; preserved.
;------------------------------------------------------------------------------
_BlkCache_ReadAhead MX   %00
                PHP
                REP     #$30
                MX      %00

                ; Cache alive?  (Same not-ready guard as Fetch: before
                ; _BlkTab_Init the base is its load-image zero.)
                SEP     #$20
                MX      %10
                LDA    |_kBlkTabBase+2
                REP     #$20
                MX      %00
                BNE     @bra_cacheUp
@bra_noVeryEarly PLP
                CLC
                RTS
@bra_cacheUp
                ; Streaming?  A one-off read gains nothing from pulling in 7
                ; neighbours and costs the whole transfer.
                ; A 2048-byte unit is read this way or not at all, streaming or
                ; not: its ReadBlock returns a quarter of the sector.
                JSR     _bra_k
                BCS     @bra_seqOk
                LDA    |_blkRaSeq
                BNE     @bra_noVeryEarly
@bra_seqOk

                ; Extended bus?  Asked FIRST, before anything is overwritten:
                ; a $4x call on a standard bus never returns, so there is no
                ; "try it and fall back".  Bailing here also keeps standard
                ; cards untouched -- no pin scan, no invalidation, nothing.
                JSR     _Blk_DevIsExt
                BCS     @bra_isExt
                ; Near exit: every early bail lands here.  The success tail is
                ; far past a branch's reach, so the "no" path gets its own RTS
                ; rather than a chain of trampolines.
@bra_noNear     PLP
                CLC
                RTS
@bra_isExt

                ; base_blk = blk & ~(K-1); bail if the run would wrap 16 bits.
                JSR     _bra_k
                DEC                             ; K-1
                PHA
                EOR     #$FFFF                  ; ~(K-1)
                AND     _blkNum
                STA     _libcTmp2               ; base_blk
                CLC
                ADC     1,S
                PLA                             ; N/Z only: C survives
                BCS     @bra_noNear             ; run crosses $FFFF

                ; slot_base = LRU_NBUF + (base_blk MOD RA_SLOTS).  That IS the
                ; direct map -- K*((base_blk/K) mod RUNS) == base_blk mod
                ; (K*RUNS) -- so no shifting, just a mask and an offset into the
                ; streaming window.  base_blk is already K-aligned, so the
                ; result lands on a run boundary.
                LDA     _libcTmp2
                AND     #BLKCACHE_RA_MASK
                CLC
                ADC     #BLKCACHE_LRU_NBUF      ; into the streaming window only
                STA    |_blkRaSlot             ; slot_base

                BLKCACHE_USE

                ; Refuse the whole run if ANY slot is pinned: a live pointer
                ; into that buffer exists and the transfer would rewrite it
                ; underneath its holder.
                JSR     _bra_k
                TAX
                LDA    |_blkRaSlot
                BCH_IDX
                TAY                             ; Y = first header offset
@bra_pinChk     SEP     #$20
                MX      %10
                LDA     [_kHeapCur],Y           ; BCH_Flags
                AND     #BCH_FL_BUSY
                REP     #$20
                MX      %00
                BNE     @bra_pinned
                TYA
                CLC
                ADC     #BCH_SIZE
                TAY
                DEX
                BNE     @bra_pinChk
                BRA     @bra_runFree
@bra_pinned     PLP
                CLC
                RTS
@bra_runFree

                ; Destination = pool + slot_base*512, in the heap bank.
                LDA    |_blkRaSlot
                XBA                             ; slot_base*256
                ASL                             ; slot_base*512
                CLC
                ADC     #BLKCACHE_BUFOFF
                CLC
                ADC     _kHeapCur
                STA    |_blkRaDstOff
                SEP     #$20
                MX      %10
                LDA    |_kBlkTabBase+2
                STA    |_blkRaDstBank
                REP     #$20
                MX      %00
                JSR     _bra_k
                XBA                             ; K*256
                ASL                             ; K*512
                STA    |_blkRaCount

                ; Issue the call for base_blk, not the requested block -- the
                ; run is aligned.  _blkNum is restored before anything branches
                ; (PLA touches N/Z only, never carry), because every path
                ; downstream still expects the block that was asked for.
                ;
                ; A 2048-BYTE UNIT IS ADDRESSED IN ITS OWN SECTORS: the card
                ; puts Read's address into the SCSI READ unconverted (its ROM,
                ; bank 9 $CCC2), so the run's first block goes over as sector
                ; base_blk/4, high word and all, and comes back.
                LDA     _blkNum
                PHA
                LDA    |_blkCurHi
                PHA
                LDA     _libcTmp2
                STA     _blkNum
                JSR     _bra_k
                BCC     @bra_lba
                LSR    |_blkCurHi
                ROR     _blkNum
                LSR    |_blkCurHi
                ROR     _blkNum
@bra_lba        JSR     _SP_ReadBlockN
                PLA
                STA    |_blkCurHi
                PLA
                STA     _blkNum
                BCC     @bra_fail

                INC    |_blkRaOk
                ; Validate the K headers: (dev, base_blk+i), VALID, lru = now.
                ; Written only AFTER the transfer succeeded -- a header that
                ; claims bytes its buffer does not hold is the one thing this
                ; cache may never do.
                JSR     _bra_k
                TAX
                LDA     _libcTmp2               ; base_blk -> running block no.
                STA    |_blkRaBlk
                LDA    |_blkRaSlot
                BCH_IDX
                TAY                             ; Y = first header offset
@bra_mark       SEP     #$20
                MX      %10
                LDA     #BCH_FL_VALID
                STA     [_kHeapCur],Y           ; BCH_Flags
                INY
                LDA     _fsCurDevIdx
                STA     [_kHeapCur],Y           ; BCH_Dev
                INY
                REP     #$20
                MX      %00
                LDA    |_blkRaBlk
                STA     [_kHeapCur],Y           ; BCH_Blk low word
                INC    |_blkRaBlk
                INY
                INY
                LDA    |_blkCurHi              ; every block in the run shares
                STA     [_kHeapCur],Y           ; one high word -- the alignment
                INY                             ; check above guaranteed it
                INY
                LDA    |_kSystemTicks
                STA     [_kHeapCur],Y           ; BCH_LruLo (now +6)
                TYA
                CLC
                ADC     #BCH_SIZE-BCH_LruLo
                TAY                             ; -> next header
                DEX
                BNE     @bra_mark
                PLP
                SEC
                RTS

                ; The transfer failed AFTER overwriting the run's buffers, so
                ; those slots no longer match their headers -- drop them.  A
                ; stale VALID header here would serve garbage forever.
@bra_fail       INC    |_blkRaFail
                JSR     _bra_k
                TAX
                LDA    |_blkRaSlot
                BCH_IDX
                TAY
@bra_inval      SEP     #$20
                MX      %10
                LDA     #$00
                STA     [_kHeapCur],Y           ; clear VALID
                REP     #$20
                MX      %00
                TYA
                CLC
                ADC     #BCH_SIZE
                TAY
                DEX
                BNE     @bra_inval
@bra_no         PLP
                CLC
                RTS

;------------------------------------------------------------------------------
; _bra_k - the run length for _devPtr's unit: 4 blocks (one 2048-byte sector)
; for a DEV_FLAG_SEC2K unit, BLKCACHE_RA_K for any other.  A sector at a time
; rather than K: a run past the disc's last sector would fail the whole
; transfer, and directory reads are scattered.
; Out: A = K, C=1 iff a 2048-byte unit.  MX %00 in/out; clobbers Y.
;------------------------------------------------------------------------------
_bra_k          MX      %00
                SEP     #$20
                MX      %10
                LDY     #DEV_Flags
                LDA     [_devPtr],Y
                REP     #$20
                MX      %00
                AND     #DEV_FLAG_SEC2K
                BEQ     @brk_disk
                LDA     #4
                SEC
                RTS
@brk_disk       LDA     #BLKCACHE_RA_K
                CLC
                RTS

;------------------------------------------------------------------------------
; _BlkCache_Store - copy the 512 B at kernel-bank:_blkBuf into the pool entry
; for (dev, blk): refresh an existing entry, else claim one via AllocLRU.
; The write-through refresh (F2-b, Blk_Write success) and the read-miss
; populate (F2-c) both land here.
; In:  A = block number (16-bit), X.lo = device index; _blkBuf = source offset
;      (kernel bank — every Blk_* caller's buffer contract).
; MX:  caller %00; preserved.  Ends with DBR = PB (the live kernel bank) —
;      same exit state Blk_Read's MVN path already leaves.
;------------------------------------------------------------------------------
_BlkCache_Store MX      %00
                PHP
                REP     #$30
                JSR     _BlkCache_Lookup        ; hit: LRU touched, A.lo = idx
                BCS     @bcs_have
                ; miss: (blk, dev) still sit in _libcTmp2 from Lookup's stash
                LDA     _libcTmp2+2
                AND     #$00FF
                TAX
                LDA     _libcTmp2
                JSR     _BlkCache_AllocLRU      ; C=1 + A.lo = claimed idx
                BCC     @bcs_noVictim           ; every candidate pinned
@bcs_have       AND     #$00FF
                XBA                             ; idx*256
                ASL                             ; idx*512
                CLC
                ADC     #BLKCACHE_BUFOFF
                CLC
                ADC     _kHeapCur               ; + cache-region offset -> dst
                TAY                             ; Y = dst offset (heap bank)
                LDX     _blkBuf                 ; X = src offset (kernel bank)
                ; Patch the MVN's bank operands in the EXECUTING copy (DBR=PB
                ; trick — write.s @fwn_mvnInst pattern; STAL would patch the
                ; stale $02 assembly image).  Kernel code+data share one
                ; relocated bank, so PHK also names the src/data bank.
                SEP     #$20
                MX      %10
                PHB                             ; save caller DBR
                PHK
                PLB                             ; DBR = executing bank
                LDA    |_kBlkTabBase+2
                STA     @bcs_mvn+1              ; dst-bank operand (heap bank)
                LDA    |_blkCurBufBank          ; caller's buffer bank (1.3c),
                BNE     @bcs_srcSet             ;   0 = the kernel bank
                PHK
                PLA
@bcs_srcSet     STA     @bcs_mvn+2              ; src-bank operand
                PLB                             ; caller DBR back (MVN sets its own)
                REP     #$20
                MX      %00
                LDA     #511                    ; count-1
@bcs_mvn        MVN     $00,$00                 ; src,dst — both patched above
                ; MVN left DBR = dst (heap) bank; restore the Blk_* exit state.
                SEP     #$20
                MX      %10
                PHK
                PLB                             ; DBR = live kernel bank
                REP     #$20
                MX      %00
                PLP
                RTS

                ; Nothing to store into: leave the cache untouched and exit in
                ; the SAME state the copy path does (DBR = live kernel bank),
                ; because callers rely on that, not on whether a copy happened.
                ; The block itself is already in the caller's buffer -- this
                ; path costs a future re-read, nothing more.
@bcs_noVictim   SEP     #$20
                MX      %10
                PHK
                PLB
                REP     #$20
                MX      %00
                PLP
                RTS

;------------------------------------------------------------------------------
; _BlkCache_Fetch - Blk_Read's consult (F2-c): if (dev=_fsCurDevIdx,
; blk=_blkNum) is cached, copy pool -> kernel-bank:_blkBuf and count the hit
; in BCS_HitCount.  The hit path never touches the device — and never touches
; _fsTmp* either, so it is STRICTLY gentler than the disk path it replaces.
; Out: C=1 served from cache (DBR = live kernel bank — the MVN's dst bank IS
;      the contract state, no restore needed); C=0 = miss, caller dispatches.
; MX:  caller %00; preserved.
;------------------------------------------------------------------------------
_BlkCache_Fetch MX      %00
                PHP
                REP     #$30
                ; NOT-READY GUARD: boot does Blk_Reads (module loads, vol scan)
                ; BEFORE _BlkTab_Init allocates the cache block — _kBlkTabBase
                ; is still its load-image zero, and a lookup through it scans
                ; garbage (a false hit MVNs junk over the caller's buffer; this
                ; hung boot when F2-c first landed).  Bank byte 0 = off.
                SEP     #$20
                MX      %10
                LDA    |_kBlkTabBase+2
                REP     #$20
                MX      %00
                BEQ     @bcf_miss
                LDA     _fsCurDevIdx            ; DP byte; hi = neighbor, masked
                TAX
                LDA     _blkNum
                JSR     _BlkCache_Lookup        ; hit: LRU touched, A.lo = idx
                BCC     @bcf_miss
                PHA                             ; hold idx across the counter
                ; ++BCS_HitCount (32-bit; cursor still at the cache region)
                LDY     #BCS_HitCount
                LDA     [_kHeapCur],Y
                INC
                STA     [_kHeapCur],Y
                BNE     @bcf_cntOK
                INY
                INY
                LDA     [_kHeapCur],Y
                INC
                STA     [_kHeapCur],Y
@bcf_cntOK      PLA                             ; A.lo = idx
                AND     #$00FF
                XBA                             ; idx*256
                ASL                             ; idx*512
                CLC
                ADC     #BLKCACHE_BUFOFF
                CLC
                ADC     _kHeapCur
                TAX                             ; X = src offset (heap bank)
                LDY     _blkBuf                 ; Y = dst offset (kernel bank)
                SEP     #$20
                MX      %10
                PHB
                PHK
                PLB                             ; DBR = executing bank for patches
                LDA    |_blkCurBufBank          ; caller's buffer bank (1.3c),
                BNE     @bcf_dstSet             ;   0 = the kernel bank
                PHK
                PLA
@bcf_dstSet     STA     @bcf_mvn+1              ; dst-bank operand
                LDA    |_kBlkTabBase+2
                STA     @bcf_mvn+2              ; src-bank operand = heap bank
                PLB
                REP     #$20
                MX      %00
                LDA     #511                    ; count-1
@bcf_mvn        MVN     $00,$00                 ; pool -> caller buffer
                PLP
                SEC
                RTS
@bcf_miss       PLP
                CLC
                RTS

;------------------------------------------------------------------------------
; _BlkCache_WrOk - Blk_Read MISS-POPULATE hook ONLY (F2-c): copy the just-read
; block into the pool.  Cache invariant (post-F3, 2026-07-18): a VALID entry ≡
; the bytes last READ from disk for (dev, blk).  Populated ONLY from disk reads;
; NEVER from a write buffer.  Reads (dev, blk) from the live _fsCurDevIdx/_blkNum.
;
; The Blk_WRITE path does NOT refresh — it INVALIDATES via _BlkCache_WrInval
; below.  The old "write-through refresh" (valid ≡ disk after write OR read)
; deterministically served cache-vs-disk-inconsistent content under the P2'
; FS write/read interleave (spawn_under_write red bar): a Blk_Read of a file
; block returned DIRECTORY content.  Bisected 2026-07-18: disabling Fetch OR
; switching the write path to invalidate both make it green; the read-miss
; populate (this hook) was never at fault.  Invalidate-on-write makes a valid
; entry consistent-with-disk by construction under ANY interleave, at the cost
; of one re-read after a write.  Read caching (the primary F2 win — hot dir/
; index blocks across path walks and multi-segment loads) is fully preserved.
; MX:  caller %00; preserved.  A not preserved (success paths return no A).
;------------------------------------------------------------------------------
_BlkCache_WrOk  MX      %00
                PHP
                REP     #$30
                SEP     #$20
                MX      %10
                LDA    |_kBlkTabBase+2          ; not-ready guard (see Fetch)
                REP     #$20
                MX      %00
                BEQ     @bwo_off
                LDA     _fsCurDevIdx            ; DP byte; hi = neighbor, callee masks
                TAX
                LDA     _blkNum
                JSR     _BlkCache_Store
@bwo_off        PLP
                RTS

;------------------------------------------------------------------------------
; _BlkCache_WrInval - Blk_Write SUCCESS hook (F3, 2026-07-18): the block just
; changed on disk, so DROP any cached copy — the next read re-fetches from disk
; (the source of truth).  This replaces the old write-through refresh, closing
; the cache-vs-disk-divergence class (see _BlkCache_WrOk).  Mirror of
; _BlkCache_WrFail but for the success path; A not preserved (success paths
; return no A).  Reads (dev, blk) from the live _fsCurDevIdx/_blkNum.
; MX:  caller %00; preserved.
;------------------------------------------------------------------------------
_BlkCache_WrInval MX     %00
                PHP
                REP     #$30
                SEP     #$20
                MX      %10
                LDA    |_kBlkTabBase+2          ; not-ready guard (see Fetch)
                REP     #$20
                MX      %00
                BEQ     @bwi_off
                ; P3.3-iii-B: a pool-source write (Blk_Write FROM the pinned
                ; entry itself) leaves that entry the FRESHEST copy — keep it
                ; VALID; invalidating (or STALE-ing) it would force a wasted
                ; re-read and drop the write-frontier pin's contents.
                SEP     #$20
                MX      %10
                LDA    |_blkSrcPool
                REP     #$20
                MX      %00
                AND     #$00FF
                BNE     @bwi_off
                LDA     _fsCurDevIdx            ; DP byte; hi = neighbor, callee masks
                TAX
                LDA     _blkNum
                JSR     _BlkCache_InvalOne
@bwi_off        PLP
                RTS

;------------------------------------------------------------------------------
; _BlkCache_WrFail - Blk_Write failure hook: the on-disk state is
; indeterminate, so any cached copy must die (NOT be refreshed).
; Preserves A (the errno the error path is returning).  MX: entry ANY.
;------------------------------------------------------------------------------
_BlkCache_WrFail PHP
                REP     #$30
                PHA                             ; errno (lo byte is what matters)
                SEP     #$20
                MX      %10
                LDA    |_kBlkTabBase+2          ; not-ready guard (see Fetch)
                REP     #$20
                MX      %00
                BEQ     @bwf_off
                LDA     _fsCurDevIdx
                TAX
                LDA     _blkNum
                JSR     _BlkCache_InvalOne
@bwf_off        PLA
                PLP
                RTS

;------------------------------------------------------------------------------
; _BlkCache_InvalOne - drop the entry for (dev, blk) if present (write-EIO
; path: on-disk state indeterminate -> the copy must not survive).
; In:  A = block number (16-bit), X.lo = device index.  Miss = no-op.
; MX:  caller %00; preserved.
;------------------------------------------------------------------------------
_BlkCache_InvalOne MX   %00
                PHP
                REP     #$30
                JSR     _BlkCache_Lookup
                BCC     @bio_done
                AND     #$00FF
                BCH_IDX
                TAY                             ; -> BCH_Flags (offset 0)
                SEP     #$20
                MX      %10
                LDA     [_kHeapCur],Y
                BIT     #BCH_FL_BUSY
                BEQ     @bio_drop
                ; P3.3: pinned — the holder's pointer stays live, so keep
                ; VALID and flag STALE; the entry is dropped at unpin.
                ORA     #BCH_FL_STALE
                STA     [_kHeapCur],Y
                REP     #$20
                MX      %00
                PLP
                RTS
@bio_drop       MX      %10
                LDA     #0
                STA     [_kHeapCur],Y
                REP     #$20
                MX      %00
@bio_done       PLP
                RTS

;------------------------------------------------------------------------------
; _BlkCache_PinGet - P3.3: pin (dev, blk) in the pool and return a pointer
; to its 512 B buffer.  Hit: pin + return (zero-copy).  Miss: bounce-read
; via Blk_Read into _blkBounce — the WrOk hook populates the pool — then
; pin the fresh entry.
;
; In:  A = block number (16-bit), X.lo = device index.  _fsCurDevIdx must
;      name the same device (Blk_* convention; the miss path dispatches on
;      it).
; Out: C=1: A = buffer OFFSET (16-bit, heap bank), X.lo = buffer BANK,
;           X.hi = slot idx (pass to _BlkCache_Unpin).
;      C=0 + A = EIO (device read failed, or cache not ready pre-FS-init).
; MX:  caller %00; preserved.  Clobbers A, X, Y, _libcTmp2, _kHeapCur,
;      _blkNum, _blkBuf.  NEVER yields (Model A: pins are syscall-scoped
;      or write-frontier; no sleep while pinned).
;------------------------------------------------------------------------------
_BlkCache_PinGet ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                STA     _blkNum                 ; A = block number (input)
                ; Latch the high word HERE, not in the bounce Blk_Read below:
                ; this routine consults the cache BEFORE any Blk_* entry runs,
                ; so without its own latch it would look the block up against
                ; whatever high word the previous operation left behind.
                LDA     _blkNumHi
                STA    |_blkCurHi
                STZ     _blkNumHi
                ; Preserve the caller's _libcTmp2 (3 bytes, overlapping-word
                ; trick) — Lookup stashes (blk, dev) there, and pin consumers
                ; (e.g. SYS_LISTDIR's output cursor) hold long pointers in it
                ; across directory enumeration.  Same contract precedent as
                ; Blk_Read/Blk_Write preserving _fsTmp0/1.
                LDA     _libcTmp2+1
                PHA
                LDA     _libcTmp2
                PHA
                LDA     _blkNum                 ; A = blk again for Lookup
                JSR     _BlkCache_Lookup
                BCS     @bpg_have
                ; Miss — bounce-read; Blk_Read's WrOk hook stores the block
                ; into the pool (guarded by the not-ready check).  The bounce
                ; target is _fsDirBuf: in every PINNING path (readdir/walk,
                ; P3.3-ii+) that buffer is no longer consumed, and the
                ; remaining dir-op writers use it strictly sequentially
                ; within their own syscall — no interleave under Model A.
                ; (At P3.3 close _fsDirBuf shrinks to a dedicated bounce.)
                ; Re-arm the DP cell: Blk_Read latches it again, and this
                ; pin's high word has to survive into the bounce read rather
                ; than be zeroed by our own latch above.
                LDA    |_blkCurHi
                STA     _blkNumHi
                LDA     #_fsDirBuf
                STA     _blkBuf
                JSR     Blk_Read
                BCS     @bpg_rdOK
@bpg_eio        PLA                             ; restore caller's _libcTmp2
                STA     _libcTmp2
                PLA
                STA     _libcTmp2+1
                LDA     #EIO
                PLP
                CLC
                RTS
@bpg_rdOK       LDA     _fsCurDevIdx
                AND     #$00FF
                TAX
                LDA     _blkNum
                JSR     _BlkCache_Lookup
                BCS     @bpg_have
                ; Still a miss -> cache not ready (boot).  No pin possible.
                BRA     @bpg_eio
@bpg_have       AND     #$00FF
                PHA                             ; [idx]
                BCH_IDX
                TAY
                SEP     #$20
                MX      %10
                LDA     [_kHeapCur],Y           ; BCH_Flags (VALID set)
                ORA     #BCH_FL_BUSY
                STA     [_kHeapCur],Y
                REP     #$20
                MX      %00
                TYA
                CLC
                ADC     #BCH_PinCount
                TAY
                SEP     #$20
                MX      %10
                LDA     [_kHeapCur],Y           ; pin refcount++ (two fds may
                INC                             ;   pin the same block)
                STA     [_kHeapCur],Y
                REP     #$20
                MX      %00
                ; offset = _kHeapCur + BLKCACHE_BUFOFF + idx*512
                ; (_kHeapCur = cache-region base from Lookup's BLKCACHE_USE).
                LDA     1,S                     ; idx
                XBA                             ; *256
                ASL                             ; *512
                CLC
                ADC     #BLKCACHE_BUFOFF
                CLC
                ADC     _kHeapCur
                STA     _blkBuf                 ; hold offset (scratch)
                ; X = idx<<8 | heap bank.
                LDA     1,S                     ; idx
                XBA                             ; idx<<8 (lo byte 0)
                STA     _blkNum                 ; scratch reuse (input consumed)
                SEP     #$20
                MX      %10
                LDA     _kHeapCur+2             ; heap bank
                STA     _blkNum                 ; -> low byte
                REP     #$20
                MX      %00
                LDA     _blkNum                 ; idx<<8 | bank
                TAX
                PLA                             ; drop [idx]
                PLA                             ; restore caller's _libcTmp2
                STA     _libcTmp2
                PLA
                STA     _libcTmp2+1
                LDA     _blkBuf                 ; A = buffer offset
                PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; _BlkCache_PinAllocZ - P3.3-iii-B: pin a FRESHLY-ALLOCATED block with ZEROED
; content — no device read (the disk holds garbage for a block Bm_Alloc just
; handed out).  Lookup first: a stale entry for a freed-then-reallocated block
; number must be reused, never duplicated (two entries for one (dev,blk) would
; diverge).  Hit or claim, the 512 B pool copy is zero-filled and the entry
; pinned (BUSY, PinCount=1 on claim / ++ on hit).
; In:  A = block number (16-bit), X.lo = device index.
; Out: C=1 + A = buffer offset, X = idx<<8 | pool bank (same ABI as PinGet);
;      C=0 + A = EIO only when the cache isn't ready (boot).
; Preserves the caller's _libcTmp2 (PinGet precedent — Lookup/AllocLRU stash
; (blk, dev) there).  MX: caller %00; preserved.
;------------------------------------------------------------------------------
_BlkCache_PinAllocZ ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                STA     _blkNum                 ; blk (scratch hold)
                LDA     _blkNumHi               ; latch the high word (see PinGet;
                STA    |_blkCurHi              ;   this path never reads a device,
                STZ     _blkNumHi               ;   so there is nothing to re-arm)
                LDA     _libcTmp2+1             ; preserve caller _libcTmp2
                PHA                             ;   (overlapping-word trick)
                LDA     _libcTmp2
                PHA
                ; not-ready guard (see PinGet miss path)
                SEP     #$20
                MX      %10
                LDA    |_kBlkTabBase+2
                REP     #$20
                MX      %00
                AND     #$00FF
                BNE     @paz_ready
                PLA
                STA     _libcTmp2
                PLA
                STA     _libcTmp2+1
                LDA     #EIO
                PLP
                CLC
                RTS
@paz_ready      PHX                             ; [dev] (X.lo)
                LDA     _blkNum
                JSR     _BlkCache_Lookup        ; hit -> A.lo = idx
                BCS     @paz_haveIdx
                PLX                             ; dev again
                LDA     _blkNum
                JSR     _BlkCache_AllocLRU      ; C=1 + A.lo = idx
                BCS     @paz_gotSlot
                ; No victim: EVERY candidate is pinned.  Returning a slot here
                ; would hand out a pin on a buffer another holder still points
                ; at, which is the corruption this whole path exists to avoid.
                ; EIO is the honest answer and the caller already handles it.
                PLA
                STA     _libcTmp2
                PLA
                STA     _libcTmp2+1
                LDA     #EIO
                PLP
                CLC
                RTS
@paz_gotSlot    PHX                             ; keep stack shape ([dev] slot)
                ; AllocLRU wrote flags = VALID only; PinCount byte is stale
                ; from the slot's previous life -> SET to 1 (not INC).
                AND     #$00FF
                PHA                             ; [idx]
                BCH_IDX
                CLC
                ADC     #BCH_PinCount
                TAY
                SEP     #$20
                MX      %10
                LDA     #1
                STA     [_kHeapCur],Y
                REP     #$20
                MX      %00
                BRA     @paz_setBusy
@paz_haveIdx    AND     #$00FF
                PHA                             ; [idx]
                BCH_IDX
                CLC
                ADC     #BCH_PinCount
                TAY
                SEP     #$20
                MX      %10
                LDA     [_kHeapCur],Y           ; existing entry: refcount++
                INC
                STA     [_kHeapCur],Y
                REP     #$20
                MX      %00
@paz_setBusy    LDA     1,S                     ; idx
                BCH_IDX
                TAY
                SEP     #$20
                MX      %10
                LDA     [_kHeapCur],Y           ; BCH_Flags |= BUSY
                ORA     #BCH_FL_BUSY
                STA     [_kHeapCur],Y
                REP     #$20
                MX      %00
                ; Zero the 512 B pool copy: off = BUFOFF + idx*512.
                LDA     1,S                     ; idx
                XBA                             ; *256
                ASL                             ; *512
                CLC
                ADC     #BLKCACHE_BUFOFF
                TAY
                LDX     #0
                LDA     #$0000
@paz_zL         STA     [_kHeapCur],Y
                INY
                INY
                INX
                INX
                CPX     #512
                BCC     @paz_zL
                ; Return ABI (mirror PinGet): A = _kHeapCur + BUFOFF + idx*512,
                ; X = idx<<8 | pool bank.
                LDA     1,S                     ; idx
                XBA
                ASL
                CLC
                ADC     #BLKCACHE_BUFOFF
                CLC
                ADC     _kHeapCur
                STA     _blkBuf                 ; hold offset (scratch)
                LDA     1,S                     ; idx
                XBA                             ; idx<<8
                STA     _blkNum                 ; scratch reuse
                SEP     #$20
                MX      %10
                LDA     _kHeapCur+2             ; pool bank
                STA     _blkNum                 ; -> low byte
                REP     #$20
                MX      %00
                LDA     _blkNum
                TAX
                PLA                             ; drop [idx]
                PLA                             ; drop [dev]
                PLA                             ; restore caller's _libcTmp2
                STA     _libcTmp2
                PLA
                STA     _libcTmp2+1
                LDA     _blkBuf
                PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; _BlkCache_Unpin - P3.3: release a pin.  In: A.lo = slot idx.  If the entry
; was invalidated while pinned (STALE), it dies now; otherwise it stays a
; normal VALID cache entry.  MX: caller %00; preserved.  Clobbers A, Y,
; _kHeapCur.
;------------------------------------------------------------------------------
_BlkCache_Unpin ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                AND     #$00FF
                BCH_IDX
                TAY
                BLKCACHE_USE
                TYA
                CLC
                ADC     #BCH_PinCount
                TAY
                SEP     #$20
                MX      %10
                LDA     [_kHeapCur],Y           ; pin refcount--
                DEC
                STA     [_kHeapCur],Y
                BNE     @bup_done               ; another holder remains
                REP     #$20
                MX      %00
                TYA
                SEC
                SBC     #BCH_PinCount
                TAY                             ; -> BCH_Flags
                SEP     #$20
                MX      %10
                LDA     [_kHeapCur],Y
                AND     #$FF-BCH_FL_BUSY
                BIT     #BCH_FL_STALE
                BEQ     @bup_store
                LDA     #0                      ; STALE -> drop entirely
@bup_store      STA     [_kHeapCur],Y
@bup_done       REP     #$20
                MX      %00
                PLP
                RTS

;------------------------------------------------------------------------------
; _BlkCache_InvalAll - invalidate every entry.  ENT: wired to unmount AND
; mount/volume-rescan in F2-b (media swap without unmount is a classic
; ProDOS-era vector); also the probe's reset.
; MX:  caller %00; preserved.
;------------------------------------------------------------------------------
_BlkCache_InvalAll ENT
                MX      %00
                PHP
                REP     #$30
                SEP     #$20
                MX      %10
                LDA    |_kBlkTabBase+2          ; not-ready guard (see Fetch)
                REP     #$20
                MX      %00
                BEQ     @bia_off
                BLKCACHE_USE
                LDX     #0
@bia_l          TXA
                BCH_IDX
                TAY
                SEP     #$20
                MX      %10
                LDA     #0
                STA     [_kHeapCur],Y           ; BCH_Flags = 0
                REP     #$20
                MX      %00
                INX
                CPX     #BLKCACHE_NBUF
                BCC     @bia_l
@bia_off        PLP
                RTS

                DO      BLKPROBE=1
Kern_LogStr     EXT                     ; main-segment dmesg logger
;------------------------------------------------------------------------------
; _BlkCache_Probe - boot self-test (BLKPROBE=1).  Called by main.s right after
; _BlkTab_Init; runs pre-FS and single-threaded, so it may use _fsTmp0..2
; (the runtime routines above may NOT — see the file header).  Validates:
;   miss on empty table; alloc -> hit (same idx) with buffer marker readback
;   (first + last byte of the slot); invalid-first fill of all BLKCACHE_NBUF
;   slots; eviction on the (NBUF+1)th alloc — evicts blk $111 whether boot
;   ticks tie (first-min scan picks slot 0) or advance (slot 0 is the true
;   oldest); single invalidation (miss, neighbor still hits); pool-bounds
;   write/read at the last byte of the last slot; whole-table invalidation.
;   NBUF-parametric — a pool resize must not require touching this probe.
; Leaves the cache all-invalid.  Logs "BLKPROBE: PASS/FAIL" to dmesg.
;------------------------------------------------------------------------------
_BlkCache_Probe ENT
                MX      %00
                PHP
                REP     #$30
                LDA     #1
                STA     _fsTmp0                 ; ok flag
                STZ    |_blkCurHi              ; cases 1-8 are low-word-only
                JSR     _BlkCache_InvalAll
                ; 1: miss on empty
                LDX     #1
                LDA     #$0111
                JSR     _BlkCache_Lookup
                BCC     @bp_1ok
                STZ     _fsTmp0
@bp_1ok         ; 2: alloc + markers + hit + readback
                LDX     #1
                LDA     #$0111
                JSR     _BlkCache_AllocLRU
                AND     #$00FF
                STA     _fsTmp1                 ; idxA
                XBA                             ; idx*256
                ASL                             ; idx*512
                CLC
                ADC     #BLKCACHE_BUFOFF
                TAY                             ; -> buf[idxA][0]
                SEP     #$20
                MX      %10
                LDA     #$A5
                STA     [_kHeapCur],Y
                REP     #$20
                MX      %00
                TYA
                CLC
                ADC     #511
                TAY
                SEP     #$20
                MX      %10
                LDA     #$5A
                STA     [_kHeapCur],Y           ; buf[idxA][511]
                REP     #$20
                MX      %00
                LDX     #1
                LDA     #$0111
                JSR     _BlkCache_Lookup
                BCS     @bp_2hit
                STZ     _fsTmp0
                BRA     @bp_fill
@bp_2hit        AND     #$00FF
                CMP     _fsTmp1
                BEQ     @bp_2idx
                STZ     _fsTmp0
@bp_2idx        LDA     _fsTmp1
                XBA
                ASL
                CLC
                ADC     #BLKCACHE_BUFOFF
                TAY
                SEP     #$20
                MX      %10
                LDA     [_kHeapCur],Y
                CMP     #$A5
                REP     #$20
                MX      %00
                BEQ     @bp_2m1
                STZ     _fsTmp0
@bp_2m1         TYA
                CLC
                ADC     #511
                TAY
                SEP     #$20
                MX      %10
                LDA     [_kHeapCur],Y
                CMP     #$5A
                REP     #$20
                MX      %00
                BEQ     @bp_fill
                STZ     _fsTmp0
@bp_fill        ; 3: fill the other NBUF-1 slots (invalid-first) with
                ; $200..$200+NBUF-2
                LDA     #$0200
                STA     _fsTmp2
@bp_fl          LDX     #1
                LDA     _fsTmp2
                JSR     _BlkCache_AllocLRU
                LDA     _fsTmp2
                INC
                STA     _fsTmp2
                CMP     #$0200+BLKCACHE_NBUF-1
                BCC     @bp_fl
                LDX     #1
                LDA     #$0200+BLKCACHE_NBUF-2
                JSR     _BlkCache_Lookup        ; spot-check a fill member
                BCS     @bp_3ok
                STZ     _fsTmp0
@bp_3ok         ; 4: (NBUF+1)th alloc -> evicts $111 (tie or true-LRU, same victim)
                LDX     #1
                LDA     #$0300
                JSR     _BlkCache_AllocLRU
                LDX     #1
                LDA     #$0300
                JSR     _BlkCache_Lookup
                BCS     @bp_4a
                STZ     _fsTmp0
@bp_4a          LDX     #1
                LDA     #$0111
                JSR     _BlkCache_Lookup
                BCC     @bp_4b
                STZ     _fsTmp0                 ; $111 should be evicted
@bp_4b          ; 5: single invalidation
                LDX     #1
                LDA     #$0205
                JSR     _BlkCache_InvalOne
                LDX     #1
                LDA     #$0205
                JSR     _BlkCache_Lookup
                BCC     @bp_5a
                STZ     _fsTmp0
@bp_5a          LDX     #1
                LDA     #$0206
                JSR     _BlkCache_Lookup
                BCS     @bp_5b
                STZ     _fsTmp0
@bp_5b          ; 6: pool-bounds write/read at the last slot's last byte
                LDA     #{BLKCACHE_NBUF-1}*512+511
                CLC
                ADC     #BLKCACHE_BUFOFF
                TAY
                SEP     #$20
                MX      %10
                LDA     #$C3
                STA     [_kHeapCur],Y
                LDA     [_kHeapCur],Y
                CMP     #$C3
                REP     #$20
                MX      %00
                BEQ     @bp_6ok
                STZ     _fsTmp0
@bp_6ok         ; 7: invalidate all -> $300 misses
                JSR     _BlkCache_InvalAll
                LDX     #1
                LDA     #$0300
                JSR     _BlkCache_Lookup
                BCC     @bp_7ok
                STZ     _fsTmp0
@bp_7ok         ; 8: EVERY victim candidate pinned -> AllocLRU must REFUSE
                ; (apple/fgx#15).  Before the sentinel it returned a stale
                ; BestIdx from a previous call and claimed a PINNED slot,
                ; refilling a buffer under a live pointer.  The protection was
                ; the assumption that pins stay far below the pool size, which
                ; nothing enforced -- FS_MAX_FDS is 30 against a 16-slot victim
                ; pool -- so the assumption is now a check, and this is the
                ; check's check.
                JSR     _BlkCache_InvalAll
                LDX     #0                      ; fill + pin the whole LRU half
@bp_8fill       PHX
                TXA
                CLC
                ADC     #$0400                  ; distinct block numbers
                LDX     #1                      ; dev 1
                JSR     _BlkCache_AllocLRU
                BCS     @bp_8got
                STZ     _fsTmp0                 ; must succeed while slots remain
                BRA     @bp_8next
@bp_8got        AND     #$00FF
                BCH_IDX
                TAY                             ; header base
                SEP     #$20
                MX      %10
                LDA     [_kHeapCur],Y
                ORA     #BCH_FL_BUSY            ; pin it
                STA     [_kHeapCur],Y
                REP     #$20
                MX      %00
@bp_8next       PLX
                INX
                CPX     #BLKCACHE_LRU_NBUF
                BCC     @bp_8fill
                ; POISON the scratch cell first.  The bug is that pass 2 READ
                ; BCS_BestIdx without ever writing it, so the defect only shows
                ; when the leftover value is a plausible slot -- and leaving
                ; that to chance is what made the first version of this test
                ; pass against the unfixed code.  Writing slot 0 here makes the
                ; stale path deterministic: unfixed, the claim returns slot 0,
                ; which is PINNED.
                LDY     #BCS_BestIdx
                LDA     #$0000
                STA     [_kHeapCur],Y

                ; Now every candidate is BUSY: the claim must FAIL, not return
                ; a slot.  A returned index here is the bug.
                LDX     #1
                LDA     #$04FF
                JSR     _BlkCache_AllocLRU
                BCC     @bp_8ok
                STZ     _fsTmp0
@bp_8ok         JSR     _BlkCache_InvalAll      ; drops the pins with the entries

                ; 9: THE 32-BIT KEY (UFS deliverable 1.0).  Two blocks whose
                ; LOW words match and whose HIGH words differ are DIFFERENT
                ; blocks.  Under the old 16-bit key they collided on one entry,
                ; so @bp_9a's lookup HITS and the probe reports FAIL against
                ; the unwidened cache -- which is the point of the case.  A
                ; widening whose only evidence is "the suite still passes" has
                ; produced a regression check, not a gate: nothing else in the
                ; tree addresses a block above 65535 yet, so nothing else can
                ; tell a 32-bit key from a 16-bit one.
                LDA     #$0001
                STA    |_blkCurHi
                LDX     #1
                LDA     #$2345
                JSR     _BlkCache_AllocLRU      ; cache block $0001_2345
                BCS     @bp_9a
                STZ     _fsTmp0
@bp_9a          STZ    |_blkCurHi              ; ask for $0000_2345 instead
                LDX     #1
                LDA     #$2345
                JSR     _BlkCache_Lookup
                BCC     @bp_9b                  ; MUST miss
                STZ     _fsTmp0
@bp_9b          LDA     #$0001                  ; the real one must still hit
                STA    |_blkCurHi
                LDX     #1
                LDA     #$2345
                JSR     _BlkCache_Lookup
                BCS     @bp_9c
                STZ     _fsTmp0
@bp_9c          ; A second high word is a THIRD distinct entry, so the key is
                ; genuinely 32 bits wide rather than 16 bits plus a flag.
                LDA     #$0002
                STA    |_blkCurHi
                LDX     #1
                LDA     #$2345
                JSR     _BlkCache_AllocLRU
                BCS     @bp_9d
                STZ     _fsTmp0
@bp_9d          LDA     #$0001
                STA    |_blkCurHi
                LDX     #1
                LDA     #$2345
                JSR     _BlkCache_Lookup        ; and the first entry survived it
                BCS     @bp_9e
                STZ     _fsTmp0
@bp_9e          STZ    |_blkCurHi              ; leave the cell as boot found it
                JSR     _BlkCache_InvalAll

@bp_report      LDA     _fsTmp0
                BEQ     @bp_fail
                ; A PASS SAYS NOTHING.  The probe still runs and still asserts
                ; everything it did; only the boot console stops carrying its
                ; verdict, which is a developer's line and not a user's.  The
                ; FAIL arm below is untouched and still reaches the screen.
                PLP
                RTS
                BRA     @bp_msg
@bp_fail        LDA     #_blkProbeFail
@bp_msg         STA     _conStrPtr
                JSR     Kern_LogStr
                PLP
                RTS
_blkProbeFail   ASC     'BLKPROBE: FAIL',00
                FIN

;==============================================================================
; END blkcache.s
;==============================================================================
