;==============================================================================
; alloc.s - libc-core typed allocator (K&R boundary-tag free-list style).
;
; Depends on: alloc_state.s (M_* + field offsets), str.s/mem.s.
;
; Chunk layout in a heap bank:
;   +0     data_size   (2 B, user-region bytes excluding header + guard)
;   +2     type        (2 B, M_* index; 0 = free)
;   +4     next_chunk  (2 B, offset of next chunk header in this bank)
;   +6     next_free   (2 B, offset of next free chunk; valid when type=0)
;   +8     user data (N bytes)
;   +8+N   guard byte ($A5 when allocated; unchecked when free)
;   pad    to next even offset
;==============================================================================

;------------------------------------------------------------------------------
; Kmem_Init - called once at boot, after _KMem_ClearGlobals + _DetectHardware.
;
; Enumerates heap banks starting at KMEM_HEAP_FIRST_BANK ($07).  For each,
; writes a single big free chunk covering the bank's usable range and
; populates one arena record.  Caps the arena count at
; min(RAMBanks - KMEM_HEAP_FIRST_BANK, KMEM_MAX_ARENAS).  Wraps PHP/PLP.
;------------------------------------------------------------------------------
Kmem_Init       MX      %00
                PHP
                REP     #$30

                ; Phase 2B: cache the heap's first bank = _restBaseBank +
                ; REST_HEAP_FIRST_OFF (== $07 at the $02 build).  Used below for
                ; the arena-count cap AND by _SoftGlob_ValidatePtr, so the "in
                ; heap?" bounds track the dynamic rest-of-OS handle, not a stale
                ; $07.  Word: bank in low byte, high byte 0 (16-bit SBC safe).
                LDA     _restBaseBank
                AND     #$00FF
                CLC
                ADC     #REST_HEAP_FIRST_OFF
                STA     _kHeapFirstBank

                ; Boot-time arena fill: stay inside the heap range.
                ; KMEM_MAX_ARENAS is the slot ceiling for the table (lazy growth
                ; into user-pool banks happens later via _Kmem_GrowOneArena);
                ; KMEM_BOOT_ARENAS is the count seeded here.  Capped by the actual
                ; RAM banks available above the heap base.
                LDA     RAMBanks
                AND     #$00FF              ; RAMBanks is stored as a byte-valued word
                SEC
                SBC     _kHeapFirstBank     ; reserve banks $00.._kHeapFirstBank-1
                BPL     @ki_notNeg
                LDA     #0                  ; guard against 0-bank hardware
@ki_notNeg      CMP     #KMEM_BOOT_ARENAS
                BCC     @ki_cap
                LDA     #KMEM_BOOT_ARENAS
@ki_cap         STA     _libcTmp0           ; target arena count

                LDA     #0
                STA     Kmem_ArenaCount

                ; First arena bank = the cached dynamic heap base.
                LDA     _kHeapFirstBank
                STA     _libcTmp1           ; running bank number (low byte)

                LDX     #0                  ; arena index
@ki_L           CPX     _libcTmp0
                BCS     @ki_done
                PHX
                JSR     _Kmem_InitOneArena  ; uses _libcTmp1 = bank; X = arena idx
                PLX
                INX
                INC     _libcTmp1
                BRA     @ki_L
@ki_done        STX     Kmem_ArenaCount
                ; Log heap-arena init to dmesg (arenas start at the dynamic
                ; heap base _kHeapFirstBank, not a fixed bank).
                LDA     #_kmem_initMsg
                STA     _conStrPtr
                JSR     Kern_LogStr
                PLP
                RTS

_kmem_initMsg   ASC     'libc: heap arenas init ok',00

;------------------------------------------------------------------------------
; Kmalloc - first-fit allocator.
;
; In:   A = size (bytes; must be > 0).  X = type (M_* index, 0..M_LAST-1).
; Out:  C=1 success: 24-bit ptr written to _kmallocResult (lo, hi, bank).
;       C=0 failure: A = errno (ENOMEM = out of space; EINVAL = size==0).
;
; Algorithm: walk arenas in order.  For each arena, walk its free list;
; first chunk with data_size >= size wins.  If the remainder after
; splitting is >= CH_HEADER_LEN + CH_GUARD_LEN + 8 (header + guard + at
; least 8 B user), split — else take the whole chunk (small internal
; fragmentation, avoids tiny unusable free chunks).
;
; MX:       Caller %00; preserves M/X via PHP/PLP.
; Clobbers: A, X, Y, _libcTmp0/1/2, _libcDstPtr, _libcSrcPtr, _kmem_*,
;           _kmallocResult.  Caller's `_libcTmp2` is left pointing at the
;           allocated chunk's header — anyone using `_libcTmp2` as a long
;           pointer to caller data MUST re-establish it after Kmalloc.
;------------------------------------------------------------------------------
Kmalloc         MX      %00
                PHP
                REP     #$30
                CMP     #0
                BEQ     @k_einval
                ; Coarse-click rounding: round the request up to a 16-byte
                ; boundary (cuts free-list fragmentation; cheap because kernel
                ; blocks are few and long-lived).  Skip for absurd >=$FFF0
                ; requests so the size+15 add can't wrap a 16-bit value; those
                ; can't fit an arena anyway and fail cleanly in _Kmem_TryAlloc.
                CMP     #$FFF0
                BCS     @k_haveSize
                CLC
                ADC     #$000F
                AND     #$FFF0
@k_haveSize     STA     _libcTmp0           ; size (16-byte-rounded)
                STX     _libcTmp1           ; type (0..7)

                LDX     #0                  ; arena idx
@k_arenaL       CPX     Kmem_ArenaCount
                BCC     @k_arenaTry
                ; Exhausted current arenas.  Phase-1 multi-bank heap:
                ; ask Bank_Alloc for one more user-pool bank, turn it into
                ; a fresh arena, and retry from the new slot.  If
                ; Bank_Alloc has nothing or we've hit KMEM_MAX_ARENAS,
                ; fall through to ENOMEM.
                JSR     _Kmem_GrowOneArena
                BCS     @k_arenaTry         ; X is now the new arena idx;
                                            ; retry the alloc against it
                LDA     #ENOMEM
                PLP
                CLC
                RTS
@k_arenaTry     JSR     _Kmem_TryAlloc      ; X = arena idx; size in _libcTmp0
                BCS     @k_hit              ; C=1 on success; _kmallocResult filled
                INX
                BRA     @k_arenaL
@k_hit          JSR     _Kmem_BumpTypeStats
                PLP
                SEC
                RTS
@k_einval       LDA     #EINVAL
                PLP
                CLC
                RTS

;------------------------------------------------------------------------------
; _SoftGlob_ValidatePtr - always-on pointer-validity guard for "soft globals".
;
; The kernel-memory modernization (docs/superpowers/specs/
; 2026-06-04-fgx-kernel-memory-modernization-design.md) moves per-subsystem
; state out of fixed bank-$02 / DP addresses (the source of three
; address-collision heisenbugs in a month) into Kmalloc'd blocks reached by a
; DP long-pointer.  A soft-globals block MUST live in the heap (bank >=
; _kHeapFirstBank, the dynamic heap base = _restBaseBank + REST_HEAP_FIRST_OFF;
; == $07 only in the old fixed layout).  A "pointer" whose bank is below the
; heap base (an old fixed $00-$06 kernel bank) means Kmalloc returned junk, the
; slot was never initialised, or it got corrupted -- HALT loudly here rather
; than let a [slot],Y deref scribble
; on the kernel.  This runs always-on (not debug-only):
; the few cycles at alloc time buy a loud failure instead of silent corruption.
;
; In:   _kmallocResult (24-bit ptr, freshly returned by Kmalloc).  MX %00.
; Out:  returns (RTS) if the bank is a legal heap bank; else logs + _Halt.
; Clobbers: A.
;
; RECIPE for a new soft-globals subsystem (mirror src/kernel/main.s
; _AllocDevTable):
;   1. include/dpmap.s: add a 3-byte DP long-pointer slot `_xxxBase`.
;   2. include/memmap.s: replace the static `DS` block with field OFFSET EQUs
;      (XXX_Field EQU n) + a total XXX_BLK_SIZE; delete the DS + any ERR anchor.
;   3. _Xxx_Init (called at boot before first use):
;        LDA #XXX_BLK_SIZE / LDX #M_KERN / JSR Kmalloc / BCC <allocfail>
;        store _kmallocResult{,+2} into _xxxBase / _xxxBase+2
;        JSR _SoftGlob_ValidatePtr      <- this guard
;        zero-fill via [_xxxBase],Y loop
;   4. convert every access: `op label,Y` -> `LDY #XXX_Field / op [_xxxBase],Y`
;      (INC/DEC have no [dp],Y form: use LDA/INC/STA).  [dp],Y is DBR-independent
;      -- a bonus for cross-bank callers that previously needed DBR=$02.
;------------------------------------------------------------------------------
_SoftGlob_ValidatePtr ENT
                MX      %00
                PHP
                SEP     #$20
                MX      %10
                LDA     _kmallocResult+2            ; result bank byte
                CMP     _kHeapFirstBank             ; >= dynamic heap base (reloc)?
                BCC     @sgv_bad                    ; (Kmem_Init cached the byte; was
                                                    ;  the fixed $07, wrong under reloc)
                REP     #$20
                MX      %00
                PLP
                RTS
@sgv_bad        REP     #$20
                MX      %00
                LDA     #_sgv_badMsg
                STA     _conStrPtr
                JSR     Kern_LogStr
                JMP     _Halt
_sgv_badMsg     ASC     'kern: soft-globals ptr not in heap (BUG)',00

;------------------------------------------------------------------------------
; _Kmem_TryAlloc - try to satisfy request _libcTmp0 (size) in arena X.
;                   On success: write _kmallocResult = user ptr; update
;                   arena.used + allocs + peak; set type + guard on chunk.
;                   Returns C=1 hit, C=0 miss.
;------------------------------------------------------------------------------
_Kmem_TryAlloc  MX      %00
                ; arena record addr -> _libcDstPtr
                TXA
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #Kmem_Arenas
                STA     _libcDstPtr
                ; Set long-ptr bank byte = arena.bank; offset will be chunk.
                SEP     #$20
                LDA     (_libcDstPtr)         ; ARENA_BANK
                STA     _libcTmp2+2
                REP     #$20
                ; cur = arena.freehead; prev_free_slot_addr = &arena.freehead
                LDY     #ARENA_FREEHEAD
                LDA     (_libcDstPtr),Y
                STA     _libcTmp2            ; cur offset
                ; For linked-list update, we track the "source of truth" for
                ; the incoming next-free pointer.  Simplification: instead of
                ; a pointer-to-slot, we remember whether the chunk came from
                ; arena.freehead (prev_is_head = 1) or from a previous chunk's
                ; CH_FREENEXT (prev_is_head = 0, prev_offset in scratch).
                ; For v1 we take the simple route: always start at freehead
                ; and track a "prev" offset (or -1 meaning the head slot).
                LDA     #0                   ; prev = 0 => fresh walk, use arena.freehead
                STA     _kmem_prev
@k_walkL        LDA     _libcTmp2
                BEQ     @k_miss               ; cur == 0 => end of free list
                ; Read cur's size
                LDY     #CH_SIZE
                LDA     [_libcTmp2],Y
                CMP     _libcTmp0
                BCS     @k_fit                ; size >= need -> take it
                ; skip; advance prev, then cur = cur.CH_FREENEXT
                LDA     _libcTmp2
                STA     _kmem_prev
                LDY     #CH_FREENEXT
                LDA     [_libcTmp2],Y
                STA     _libcTmp2
                BRA     @k_walkL

@k_miss         CLC
                RTS

@k_fit
                ; cur's size is in A (reread for safety)
                LDY     #CH_SIZE
                LDA     [_libcTmp2],Y
                STA     _kmem_avail
                ; remainder = avail - need
                LDA     _kmem_avail
                SEC
                SBC     _libcTmp0
                ; If remainder >= CH_HEADER_LEN + CH_GUARD_LEN + 8 = 17,
                ; split.  Else take whole.
                CMP     #CH_HEADER_LEN+CH_GUARD_LEN+8
                BCC     @k_takeWhole
                ; --- Split path ---
                STA     _kmem_remain
                ; new_chunk_off = cur + CH_HEADER_LEN + size + CH_GUARD_LEN
                ; (+ pad to even if needed; assume even sizes for v1)
                LDA     _libcTmp2
                CLC
                ADC     #CH_HEADER_LEN
                ADC     _libcTmp0
                CLC
                ADC     #CH_GUARD_LEN
                ; ensure even
                LSR
                BCC     @k_nop               ; was even; we shifted right — restore
                ; odd case not expected since sizes are word-aligned
@k_nop          ; trick: we shouldn't actually have shifted; reconstruct
                ; Simpler: skip the alignment logic — spec says sizes even.
                LDA     _libcTmp2
                CLC
                ADC     #CH_HEADER_LEN
                ADC     _libcTmp0
                ADC     #CH_GUARD_LEN
                STA     _kmem_newOff         ; new chunk offset

                ; Write new chunk header.  Use _libcSrcPtr as scratch long-ptr.
                LDA     _kmem_newOff
                STA     _libcSrcPtr
                SEP     #$20
                LDA     _libcTmp2+2           ; same bank as cur
                STA     _libcSrcPtr+2
                REP     #$20
                ; new.CH_SIZE = remainder - (CH_HEADER_LEN + CH_GUARD_LEN)
                LDA     _kmem_remain
                SEC
                SBC     #CH_HEADER_LEN+CH_GUARD_LEN
                LDY     #CH_SIZE
                STA     [_libcSrcPtr],Y
                ; new.CH_TYPE = M_FREE
                LDA     #M_FREE
                LDY     #CH_TYPE
                STA     [_libcSrcPtr],Y
                ; new.CH_NEXT = cur.CH_NEXT  (new becomes cur's successor
                ; in the allocated-chunk chain)
                LDY     #CH_NEXT
                LDA     [_libcTmp2],Y
                LDY     #CH_NEXT
                STA     [_libcSrcPtr],Y
                ; new.CH_FREENEXT = cur.CH_FREENEXT
                LDY     #CH_FREENEXT
                LDA     [_libcTmp2],Y
                LDY     #CH_FREENEXT
                STA     [_libcSrcPtr],Y
                ; cur.CH_NEXT = new_off
                LDA     _kmem_newOff
                LDY     #CH_NEXT
                STA     [_libcTmp2],Y
                ; cur.CH_SIZE = size (shrink)
                LDA     _libcTmp0
                LDY     #CH_SIZE
                STA     [_libcTmp2],Y
                ; Replace cur in free list with new_off
                LDA     _kmem_newOff
                JSR     _Kmem_RelinkFree
                BRA     @k_finish

@k_takeWhole    ; Take whole chunk: remove cur from free list.
                LDY     #CH_FREENEXT
                LDA     [_libcTmp2],Y
                JSR     _Kmem_RelinkFree

@k_finish       ; Stamp type + guard.  cur remains at _libcTmp2.
                LDA     _libcTmp1
                LDY     #CH_TYPE
                STA     [_libcTmp2],Y
                ; Guard byte at cur + CH_HEADER_LEN + cur.CH_SIZE
                LDY     #CH_SIZE
                LDA     [_libcTmp2],Y
                CLC
                ADC     #CH_HEADER_LEN
                TAY
                SEP     #$20
                LDA     #CH_GUARD
                STA     [_libcTmp2],Y
                REP     #$20
                ; Update arena stats
                LDY     #CH_SIZE
                LDA     [_libcTmp2],Y        ; actual chunk size taken
                PHA
                LDY     #ARENA_USED
                CLC
                ADC     (_libcDstPtr),Y
                STA     (_libcDstPtr),Y
                ; Peak update
                LDY     #ARENA_PEAK
                CMP     (_libcDstPtr),Y
                BCC     @k_noPeak
                STA     (_libcDstPtr),Y
@k_noPeak       LDY     #ARENA_ALLOCS
                LDA     (_libcDstPtr),Y
                CLC
                ADC     #1
                STA     (_libcDstPtr),Y
                PLA                           ; chunk size (not used further)
                ; Build _kmallocResult = cur + CH_HEADER_LEN in arena's bank
                LDA     _libcTmp2
                CLC
                ADC     #CH_HEADER_LEN
                STA     _kmallocResult
                SEP     #$20
                LDA     _libcTmp2+2
                STA     _kmallocResult+2
                REP     #$20
                SEC
                RTS

;------------------------------------------------------------------------------
; _Kmem_RelinkFree - replace `cur` (_libcTmp2) in the free list with the
;                     offset currently in A.  Uses _kmem_prev (= 0 means
;                     "cur was at arena.freehead"; nonzero = chunk offset
;                     of predecessor's CH_FREENEXT field).
;------------------------------------------------------------------------------
_Kmem_RelinkFree MX %00
                PHA
                LDA     _kmem_prev
                BEQ     @rf_head
                ; prev is a chunk offset in this bank; write its CH_FREENEXT
                STA     _libcSrcPtr
                SEP     #$20
                LDA     _libcTmp2+2
                STA     _libcSrcPtr+2
                REP     #$20
                PLA
                LDY     #CH_FREENEXT
                STA     [_libcSrcPtr],Y
                RTS
@rf_head        PLA
                LDY     #ARENA_FREEHEAD
                STA     (_libcDstPtr),Y
                RTS

;------------------------------------------------------------------------------
; _Kmem_BumpTypeStats - after successful alloc, increment TypeStats[type].
;   _libcTmp0 = size (we use this as increment; equivalent to chunk's size
;                     since we fit request exactly after split).
;   _libcTmp1 = type.
;------------------------------------------------------------------------------
_Kmem_BumpTypeStats MX %00
                LDA     _libcTmp1
                ASL
                ASL
                ASL                           ; *8 = KMEM_TYPE_REC_SIZE
                CLC
                ADC     #Kmem_TypeStats
                STA     _libcDstPtr
                ; inuse += size
                LDY     #TS_INUSE
                LDA     (_libcDstPtr),Y
                CLC
                ADC     _libcTmp0
                STA     (_libcDstPtr),Y
                PHA
                ; peak = max(peak, inuse)
                LDY     #TS_PEAK
                CMP     (_libcDstPtr),Y
                BCC     @bt_noPeak
                STA     (_libcDstPtr),Y
@bt_noPeak      ; count++, calls++
                LDY     #TS_COUNT
                LDA     (_libcDstPtr),Y
                CLC
                ADC     #1
                STA     (_libcDstPtr),Y
                LDY     #TS_CALLS
                LDA     (_libcDstPtr),Y
                CLC
                ADC     #1
                STA     (_libcDstPtr),Y
                PLA
                RTS

;------------------------------------------------------------------------------
; malloc wrapper — BSD-compat entry, type = M_ANON.
;------------------------------------------------------------------------------
malloc          MX      %00
                PHP
                REP     #$30
                LDX     #M_ANON
                JSR     Kmalloc
                PLP
                RTS

;------------------------------------------------------------------------------
; Kfree - release the allocation whose 24-bit user-ptr is in _kmallocResult.
;         Validates guard byte; updates stats; inserts into free list;
;         coalesces with forward neighbour if free.  Silent on NULL ptr
;         (lo+hi+bank all zero).  Logs red "HEAP CORRUPT" on guard mismatch
;         or double-free, no halt.
;
; NB: backward coalescing is deferred — free-list walk for predecessor
; is O(freelist), acceptable for v1 but adds code.  Forward-only keeps
; us under the tight code-space budget; Task 6 extends if needed.
;
; MX:       Caller %00; preserves M/X via PHP/PLP.
; Clobbers: A, X, Y, _libcTmp0/1/2, _libcDstPtr, _libcSrcPtr, _kmem_*.
;           Same `_libcTmp2`-clobber hazard as Kmalloc — leaves it pointing
;           at the freed chunk's header.  Re-establish if you used it.
;------------------------------------------------------------------------------
Kfree           MX      %00
                PHP
                REP     #$30

                ; NULL guard: lo+hi+bank all zero?
                LDA     _kmallocResult
                BNE     @kf_notNull
                SEP     #$20
                LDA     _kmallocResult+2
                BNE     @kf_notNullM10
                REP     #$20
                PLP
                RTS
@kf_notNullM10  REP     #$20
@kf_notNull
                ; Compute header long-ptr = user_ptr - CH_HEADER_LEN, same bank.
                LDA     _kmallocResult
                SEC
                SBC     #CH_HEADER_LEN
                STA     _libcTmp2
                SEP     #$20
                LDA     _kmallocResult+2
                STA     _libcTmp2+2
                REP     #$20

                ; IS THIS EVEN OURS?  Asked FIRST, and that ordering is the
                ; whole point: the header reads below are only meaningful for a
                ; pointer that came from this heap.  The arena test used to sit
                ; after them, so a wild pointer got its "type" read out of
                ; whatever it happened to address, and a zero there was reported
                ; as a double-free -- which is how apple/fgx#113 was filed under
                ; the wrong name, and chased as one, before the dump showed a
                ; bank no arena owns.
                JSR     _Kmem_ArenaFromBank
                BCS     @kf_ours
                JMP     @kf_notOurs          ; out of branch range
@kf_ours

                ; Read header fields
                LDY     #CH_SIZE
                LDA     [_libcTmp2],Y
                STA     _libcTmp0            ; size
                LDY     #CH_TYPE
                LDA     [_libcTmp2],Y
                STA     _libcTmp1            ; type
                BNE     @kf_typeOK
                JMP     @kf_dblFree
@kf_typeOK      ; Validate guard byte at CH_HEADER_LEN + size
                LDA     _libcTmp0
                CLC
                ADC     #CH_HEADER_LEN
                TAY
                SEP     #$20
                LDA     [_libcTmp2],Y
                CMP     #CH_GUARD
                BNE     @kf_corruptM10
                REP     #$20

                ; (arena record already in _libcDstPtr from the entry test)

                ; Drop per-type stats
                JSR     _Kmem_DropTypeStats

                ; arena.used -= size, frees++
                LDY     #ARENA_USED
                LDA     (_libcDstPtr),Y
                SEC
                SBC     _libcTmp0
                STA     (_libcDstPtr),Y
                LDY     #ARENA_FREES
                LDA     (_libcDstPtr),Y
                CLC
                ADC     #1
                STA     (_libcDstPtr),Y

                ; Mark chunk free + prepend to free list.
                LDY     #CH_TYPE
                LDA     #M_FREE
                STA     [_libcTmp2],Y
                LDY     #ARENA_FREEHEAD
                LDA     (_libcDstPtr),Y
                LDY     #CH_FREENEXT
                STA     [_libcTmp2],Y         ; chunk.freenext = old head
                LDA     _libcTmp2             ; our offset
                LDY     #ARENA_FREEHEAD
                STA     (_libcDstPtr),Y

                ; Forward coalesce: if chunk.next is nonzero AND that next
                ; chunk is free AND it sits immediately after our end, merge.
                LDY     #CH_NEXT
                LDA     [_libcTmp2],Y
                BEQ     @kf_done              ; no successor
                STA     _libcSrcPtr           ; next chunk offset
                SEP     #$20
                LDA     _libcTmp2+2
                STA     _libcSrcPtr+2
                REP     #$20
                LDY     #CH_TYPE
                LDA     [_libcSrcPtr],Y
                BNE     @kf_done              ; not free
                ; Adjacent? cur_end = cur + CH_HEADER_LEN + cur.size + CH_GUARD_LEN.
                ; If that == next_offset, they're touching.
                LDA     _libcTmp0             ; cur size
                CLC
                ADC     _libcTmp2             ; + cur offset
                CLC
                ADC     #CH_HEADER_LEN+CH_GUARD_LEN
                CMP     _libcSrcPtr
                BNE     @kf_done              ; not contiguous
                ; Merge: cur.size += CH_HEADER_LEN + CH_GUARD_LEN + next.size
                LDY     #CH_SIZE
                LDA     [_libcSrcPtr],Y
                CLC
                ADC     #CH_HEADER_LEN+CH_GUARD_LEN
                CLC
                ADC     _libcTmp0
                STA     [_libcTmp2],Y
                ; cur.next = next.next
                LDY     #CH_NEXT
                LDA     [_libcSrcPtr],Y
                LDY     #CH_NEXT
                STA     [_libcTmp2],Y
                ; Unlink next from free list: since we just inserted cur at
                ; head, cur.freenext = next (if next was already the free
                ; head), OR some other entry.  Walk the free list to remove
                ; `next` wherever it lives.  For simplicity: scan from head.
                JSR     _Kmem_UnlinkFree_libcSrcPtr

@kf_done        PLP
                RTS

@kf_corruptM10  REP     #$20
@kf_corrupt     LDA     #_kmem_corruptMsg
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
@kf_report      ; Shared by the double-free path, which used to print its
                ; message and nothing else -- a warning naming no chunk and no
                ; caller, on a fault whose whole question is "who freed it
                ; twice".  Both arrive here at the same stack depth (PHP, then
                ; a jump), so 2,S is Kfree's return address in either case.
                ; Identify the victim: bank(2) hdr-offset(4) CH_SIZE(4)
                ; CH_TYPE(4) as concatenated hex — corrupt guards are
                ; undebuggable without knowing WHICH chunk was overrun.
                LDA     _libcTmp2+2
                AND     #$00FF
                JSR     Kern_LogHex8
                LDA     _libcTmp2
                JSR     Kern_LogHex16
                LDA     _libcTmp0
                JSR     Kern_LogHex16
                LDA     _libcTmp1
                JSR     Kern_LogHex16
                ; freed user-ptr (bank+offset) and Kfree's return address
                ; (2,S: PHP above the JSR ret-addr) — a bad-guard report is
                ; usually a WILD FREE, so the caller is the actual suspect.
                LDA     _kmallocResult+2
                AND     #$00FF
                JSR     Kern_LogHex8
                LDA     _kmallocResult
                JSR     Kern_LogHex16
                LDA     2,S
                JSR     Kern_LogHex16
                ; user-side caller (valid when reached via _Sys_Free): the
                ; JSL SYS_TRAMP return frame sits at 00:_Sys_UserSP+1
                ; (PCL,PCH,PB) — print PB then PC(hi:lo).
                LDA     _Sys_UserSP
                CLC
                ADC     #3
                TAX
                LDAL    $000000,X               ; low byte = user PB
                JSR     Kern_LogHex8
                LDA     _Sys_UserSP
                INC
                TAX
                LDAL    $000000,X               ; PCH:PCL (return-1)
                JSR     Kern_LogHex16
                ; task id + 16 raw user-stack bytes from 00:_Sys_UserSP+1
                ; (JSL-tramp ret + free()'s frame + free's caller ret) so the
                ; user-side frame chain can be decoded against the listings.
                LDA     _curTask
                JSR     Kern_LogHex8
                LDA     _Sys_UserSP
                INC
                TAX
                LDY     #16
@kfc_stkL       LDAL    $000000,X
                JSR     Kern_LogHex8
                INX
                DEY
                BNE     @kfc_stkL
                JSR     Kern_LogEOL
                PLP
                RTS
@kf_notOurs     LDA     #_kmem_notOursMsg
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                JMP     @kf_report              ; CH_SIZE/CH_TYPE print as
                                                ; whatever the wild address
                                                ; happens to hold -- that is
                                                ; the point of showing them
@kf_dblFree     LDA     #_kmem_dblFreeMsg
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                JMP     @kf_report              ; same chunk + caller dump the
                                                ; corrupt path gets: CH_TYPE
                                                ; reads 0 here by definition,
                                                ; which is the tell that this
                                                ; is the double-free arm

;------------------------------------------------------------------------------
; _Kmem_ArenaFromBank - given _libcTmp2+2 = bank byte, set _libcDstPtr to
;                        the matching arena record.  Out: C=1 if found,
;                        C=0 if no arena with that bank.
;------------------------------------------------------------------------------
_Kmem_ArenaFromBank MX %00
                LDX     #0
@kaf_L           CPX     Kmem_ArenaCount
                BCS     @kaf_miss
                TXA
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #Kmem_Arenas
                STA     _libcDstPtr
                SEP     #$20
                LDA     (_libcDstPtr)         ; ARENA_BANK
                CMP     _libcTmp2+2
                BEQ     @kaf_hit
                REP     #$20
                INX
                BRA     @kaf_L
@kaf_hit         REP     #$20
                SEC
                RTS
@kaf_miss        CLC
                RTS

;------------------------------------------------------------------------------
; _Kmem_DropTypeStats - _libcTmp0=size, _libcTmp1=type.  Reverse of bump.
;------------------------------------------------------------------------------
_Kmem_DropTypeStats MX %00
                LDA     _libcTmp1
                ASL
                ASL
                ASL
                CLC
                ADC     #Kmem_TypeStats
                PHA                           ; stash; we'll use _libcDstPtr
                ; Swap into a separate DP slot to avoid clobbering arena ptr
                ; (caller still needs it).  Use _libcSrcPtr as alt.
                PLA
                STA     _libcSrcPtr
                LDY     #TS_INUSE
                LDA     (_libcSrcPtr),Y
                SEC
                SBC     _libcTmp0
                STA     (_libcSrcPtr),Y
                LDY     #TS_COUNT
                LDA     (_libcSrcPtr),Y
                SEC
                SBC     #1
                STA     (_libcSrcPtr),Y
                RTS

;------------------------------------------------------------------------------
; _Kmem_UnlinkFree_libcSrcPtr - remove chunk at _libcSrcPtr from the free list.
;                                Same bank as _libcDstPtr (arena).  Walks the
;                                free list starting at arena.freehead.
;------------------------------------------------------------------------------
_Kmem_UnlinkFree_libcSrcPtr MX %00
                LDY     #ARENA_FREEHEAD
                LDA     (_libcDstPtr),Y
                CMP     _libcSrcPtr
                BNE     @uf_chain
                ; target is head; unlink
                LDY     #CH_FREENEXT
                LDA     [_libcSrcPtr],Y
                LDY     #ARENA_FREEHEAD
                STA     (_libcDstPtr),Y
                RTS
@uf_chain       ; Walk: prev -> target via CH_FREENEXT
                STA     _kmem_prev            ; reuse scratch for prev offset
                ; long-ptr prev: same bank
                LDA     _kmem_prev
                STA     _libcTmp2             ; reuse (caller cur ptr no longer
                                              ; needed; we've done coalesce maths)
@uf_L           LDY     #CH_FREENEXT
                LDA     [_libcTmp2],Y
                CMP     _libcSrcPtr
                BEQ     @uf_found
                BEQ     @uf_done              ; unreachable guard
                ; Advance: prev = prev.freenext
                STA     _libcTmp2
                BNE     @uf_L
@uf_found       ; prev.freenext = target.freenext
                LDY     #CH_FREENEXT
                LDA     [_libcSrcPtr],Y
                LDY     #CH_FREENEXT
                STA     [_libcTmp2],Y
@uf_done        RTS

;------------------------------------------------------------------------------
; free wrapper — BSD-compat entry.
;------------------------------------------------------------------------------
free            MX      %00
                JSR     Kfree
                RTS

_kmem_corruptMsg  ASC     $1B,"[1;31m!! HEAP CORRUPT: bad guard in Kfree",$1B,"[0m",00
_kmem_dblFreeMsg  ASC     $1B,"[1;31m!! HEAP: double-free detected",$1B,"[0m",00
_kmem_notOursMsg  ASC     $1B,"[1;31m!! HEAP: free of a non-heap pointer",$1B,"[0m",00

;==============================================================================
; Arena helpers
;==============================================================================

;------------------------------------------------------------------------------
; _Kmem_ArenaPtr - X = arena idx; sets _libcDstPtr to the arena record addr.
;                  Preserves X.
;------------------------------------------------------------------------------
_Kmem_ArenaPtr  MX      %00
                TXA
                ASL
                ASL
                ASL
                ASL                          ; *16
                CLC
                ADC     #Kmem_Arenas
                STA     _libcDstPtr
                RTS

;------------------------------------------------------------------------------
; _Kmem_GrowOneArena - acquire one user-pool bank from Bank_Alloc and turn
; it into a fresh kmem arena.  Called when Kmalloc has exhausted every
; existing arena and would otherwise return ENOMEM.
;
; Out: C=1 + X = new arena index (Kmem_ArenaCount was incremented past
;        this slot), or C=0 if KMEM_MAX_ARENAS is hit or Bank_Alloc is
;        out of user banks.
; Clobbers: A, X, Y, _libcTmp0/1/2, _libcDstPtr, _shTmp0/1.
;------------------------------------------------------------------------------
_Kmem_GrowOneArena MX %00
                ; Cap check.
                LDA     Kmem_ArenaCount
                AND     #$00FF
                CMP     #KMEM_MAX_ARENAS
                BCC     @kg_haveSlot
                CLC
                RTS
@kg_haveSlot    ; Caller (Kmalloc) keeps the M_* type in _libcTmp1 and reads
                ; it at chunk-stamp time AFTER we return.  We're about to
                ; clobber _libcTmp1 with the bank byte for InitOneArena;
                ; save the caller's value across our work.
                LDA     _libcTmp1
                PHA                          ; +2: caller's _libcTmp1
                LDA     Kmem_ArenaCount
                AND     #$00FF
                PHA                          ; +2: new arena idx
                ; Ask Bank_Alloc for a free user bank.
                JSR     Bank_Alloc
                BCS     @kg_haveBank
                ; User pool dry — train-2 M-2: grow the heap with a bank
                ; claimed from the IIgs MM at RUNTIME, recorded as an arena
                ; block-table row.  Refuses in masked-IRQ context and pre-
                ; _BlkTab_Init; then we fall through to ENOMEM as before.
                JSR     _Arena_GrowMM        ; C=1 -> A = new bank (low byte)
                BCS     @kg_haveBank
                PLA                          ; drop slot idx
                PLA                          ; restore caller's _libcTmp1
                STA     _libcTmp1
                CLC
                RTS                          ; A=ENOMEM is already lost here;
                                            ; Kmalloc re-loads its own ENOMEM
                                            ; on the fall-through path.
@kg_haveBank    AND     #$00FF
                STA     _libcTmp1            ; bank for _Kmem_InitOneArena
                PLA                          ; recover slot idx
                TAX
                PHX                          ; +2: re-stash for post-init reload
                JSR     _Kmem_InitOneArena   ; consumes X as input,
                                            ; reads _libcTmp1 as bank
                INC     Kmem_ArenaCount
                PLX                          ; restore slot idx for caller
                PLA                          ; restore caller's _libcTmp1
                STA     _libcTmp1
                SEC
                RTS

;------------------------------------------------------------------------------
; _Arena_GrowMM - train-2 M-2: grow the kernel heap by ONE bank claimed from
; the IIgs Memory Manager at RUNTIME, recorded as an arena block-table row
; {base, count=1, kind=2, handle}.
;
; The claim is a single NewHandle($10000, attrLocked|attrNoSpec|attrNoCross|
; attrPage = $801C): per TN.IIGS.078, a page-aligned full-bank block that may
; not cross a bank boundary is BY DEFINITION bank-aligned (the System 6
; Loader's own trick) — no over-allocate-and-round-up like the boot loader's
; MULTI-bank claim needs.  The handle never leaves the table (future
; DisposeHandle); callers only ever see the flat bank.
;
; Growth is legal ONLY from task/syscall context: the toolbox is not
; reentrant, so a masked-IRQ caller (I=1 — the IRQ path and SEI critical
; sections) is refused, as is any call before _BlkTab_Init publishes the
; table — those allocations satisfy-or-fail from resident blocks/arenas.
;
; In:   MX %00, D = kernel DP, DBR = kernel bank (Kmalloc context).
; Out:  C=1 + A = new bank (low byte, 16-bit clean); C=0 refused/failed
;       (_kFgxToolErr holds the toolbox error when NewHandle failed).
; Clobbers: A, X, Y, _libcTmp1/2, _kCopyPtr, _kHeapCur (caller-saved rule),
;           _conStrPtr.  Preserves _libcTmp0 (Kmalloc's pending size).
;------------------------------------------------------------------------------
_Arena_GrowMM   MX      %00
                LDA     #1                      ; one bank
                LDX     #2                      ; kind 2 = kernel arena bank
                JSR     _MM_ClaimBanksToRow
                BCC     @agm_fail
                STA     _libcTmp2               ; stash across the log call
                ; --- dmesg breadcrumb (Kern_LogStr clobbers A,Y only) ---
                LDA     #_agm_grewMsg
                STA     _conStrPtr
                JSR     Kern_LogStr
                LDA     _libcTmp2               ; A = new bank (16-bit clean)
                SEC
                RTS
@agm_fail       CLC
                RTS

_agm_grewMsg    ASC     'kmem: heap grown via runtime MM bank',00

;------------------------------------------------------------------------------
; _MM_ClaimBanksToRow - claim N contiguous bank-aligned banks from the IIgs
; MM at RUNTIME and record them as an arena block-table row {base, count,
; kind, handle}.  Common engine for _Arena_GrowMM (kind=2, count=1) and
; _Kmalloc_Big (kind=4, count=N).  Train-2 M-2/M-4.
;
; count==1 rides TN.IIGS.078: NewHandle($10000, attrLocked|attrNoSpec|
; attrNoCross|attrPage = $801C) is bank-aligned BY DEFINITION — zero waste.
; count>1 cannot use attrNoCross (the block must cross banks): over-allocate
; one slack bank (attr $8008) and round the base UP to a bank boundary —
; the boot loader's LoaderClaimNBanks model (stage2.s).
;
; Refuses (C=0) from masked-IRQ context (I=1 — the toolbox is not
; reentrant; IRQ-path allocations satisfy-or-fail from resident blocks),
; before _BlkTab_Init publishes the table, when no row is free, and on
; count 0 / > MM_CLAIM_MAX_BANKS.  Row slots: first kind==0 tombstone
; (freed big block) is reused, else append past _kBlkCount.
;
; In:   A = bank count (16-bit), X = row kind (low byte).  MX %00.
;       D = kernel DP, DBR = kernel bank (Kmalloc context).
; Out:  C=1 + A = aligned base bank (16-bit clean); C=0 refused/failed
;       (_kFgxToolErr holds the toolbox error when NewHandle failed).
; Clobbers: A, X, Y, _libcTmp1/2, _shTmp0/1, _kCopyPtr, _kHeapCur (caller-
;           saved rule).  Preserves _libcTmp0 (Kmalloc's pending size).
;------------------------------------------------------------------------------
_MM_ClaimBanksToRow MX  %00
                STA     _shTmp0                 ; count (word)
                TXA
                AND     #$00FF
                STA     _shTmp1                 ; kind (word)
                ; --- guards ---
                PHP                             ; capture caller P (I flag)
                SEP     #$20
                MX      %10
                PLA                             ; A.lo = P
                AND     #$04                    ; I set = IRQ/critical context
                BNE     @mcb_refuse8
                LDA     _kBlkTabBase+2          ; table published yet?
                BEQ     @mcb_refuse8            ; (boot allocs pre-_BlkTab_Init)
                REP     #$20
                MX      %00
                LDA     _shTmp0                 ; count sanity: 1..MAX
                BEQ     @mcb_refuse16
                CMP     #MM_CLAIM_MAX_BANKS+1
                BCS     @mcb_refuse16
                ; --- find target row: first kind==0 tombstone, else append ---
                KHEAP_USE _kBlkTabBase          ; cursor -> table (M=16 in/out)
                SEP     #$20
                MX      %10                     ; 16-bit X/Y: 8 x row passes 255
                LDA     _kBlkCount
                STA     _libcTmp2               ; live rows, word-clean for
                STZ     _libcTmp2+1             ;   the 16-bit CPX
                LDX     #0                      ; row index
                LDY     #2                      ; kind byte offset of row 0
@mcb_rowL       CPX     _libcTmp2
                BCS     @mcb_append
                LDA     [_kHeapCur],Y           ; row X's kind
                BEQ     @mcb_haveRow            ; tombstone -> reuse
                INX
                INY                             ; +8: not TYA/TAY, which with
                INY                             ;   M=8 would carry B into Y
                INY
                INY
                INY
                INY
                INY
                INY
                BRA     @mcb_rowL
                ; The refusals sit here, inside the guards' branch reach.
@mcb_refuse16   CLC
                RTS
@mcb_refuse8    REP     #$20
                MX      %00
                CLC
                RTS
@mcb_refuse8x   REP     #$30
                MX      %00
                CLC
                RTS
                MX      %10
@mcb_append     CPX     #BLKTAB_ROWS            ; table capacity (include/fs.s)
                BCS     @mcb_refuse8x
@mcb_haveRow    REP     #$30
                MX      %00
                TYA
                SEC
                SBC     #2                      ; row BASE byte-offset
                STA     _libcTmp1
                ; --- claim: one bank = exact no-cross; N banks = N+1 slack ---
                PHA                             ; result space hi (A = junk)
                PHA                             ; result space lo
                LDA     _shTmp0
                CMP     #1
                BEQ     @mcb_one
                INC                             ; +1 bank alignment slack
                PHA                             ; blockSize hi word = banks
                PEA     $0000                   ; blockSize lo word
                LDA     _kFgxUserID
                PHA
                PEA     $8008                   ; attrLocked|attrNoSpec
                BRA     @mcb_call
@mcb_one        PEA     $0001                   ; blockSize hi word ($10000)
                PEA     $0000                   ; blockSize lo word
                LDA     _kFgxUserID
                PHA
                PEA     $801C                   ; attrLocked|attrNoSpec|attrNoCross|attrPage
@mcb_call       PEA     $0000                   ; locationPtr (ignored)
                PEA     $0000
                LDX     #$0902                  ; _NewHandle
                JSL     $E10000
                BCC     @mcb_gotHandle
                STA     _kFgxToolErr
                PLA                             ; discard result space
                PLA
                CLC
                RTS
@mcb_gotHandle  PLA                             ; handle lo16
                STA     _kCopyPtr
                PLA                             ; handle hi16
                STA     _libcTmp2               ; keep for the row write
                SEP     #$20
                MX      %10
                STA     _kCopyPtr+2             ; bank byte for the deref
                REP     #$20
                MX      %00
                ; --- Deref master ptr -> base; align (verify or round up) ---
                LDY     #0
                LDA     [_kCopyPtr],Y           ; block base lo16
                TAX                             ; X = base lo16
                LDY     #2
                LDA     [_kCopyPtr],Y           ; base bank byte (+junk hi)
                AND     #$00FF
                CPX     #0
                BEQ     @mcb_aligned
                ; Misaligned base.  count==1 used attrNoCross|attrPage and
                ; MUST come back at :0000 (TN#78) — dispose, never scribble.
                ; Multi-bank claims round UP into their slack bank.
                LDX     _shTmp0
                CPX     #1
                BEQ     @mcb_dispose
                INC                             ; round up to next bank
@mcb_aligned    PHA                             ; base bank (word)
                ; --- write the row ---
                KHEAP_USE _kBlkTabBase          ; re-load (foreign JSL above)
                LDA     _libcTmp1               ; row byte-offset
                LSR
                LSR
                LSR                             ; row index (< 256)
                SEP     #$20
                MX      %10
                CMP     _kBlkCount
                BNE     @mcb_reused             ; tombstone reuse — no bump
                INC     _kBlkCount              ; append
@mcb_reused     REP     #$20
                MX      %00
                LDY     _libcTmp1               ; Y = row base byte-offset
                PLA                             ; base bank (word)
                STA     _libcTmp1               ; return-value home (word)
                SEP     #$20
                MX      %10
                STA     [_kHeapCur],Y           ; +0 base bank
                INY
                LDA     _shTmp0                 ; count (low byte)
                STA     [_kHeapCur],Y           ; +1 count (banks)
                INY
                LDA     _shTmp1                 ; kind (low byte)
                STA     [_kHeapCur],Y           ; +2 kind
                INY
                ; +3 owner pid.  A kind-4 dedicated big block is USER memory
                ; living outside the task's data bank, so fork must snapshot it
                ; and exit must free it -- both need to know whose it is (#11).
                ; Every other kind is kernel-wide and stays 0, as does a kind-4
                ; claim made from boot/kernel context (_curTask == 0).
                LDA     _shTmp1                 ; kind (low byte)
                CMP     #4
                BEQ     @mcb_own4
                LDA     #0
                BRA     @mcb_ownW
@mcb_own4       LDA     _curTask                ; pid (0 = kernel/boot context)
@mcb_ownW       STA     [_kHeapCur],Y           ; +3 owner pid
                REP     #$20
                MX      %00
                INY                             ; +4/+5: handle lo16
                LDA     _kCopyPtr
                STA     [_kHeapCur],Y
                INY
                INY                             ; +6/+7: handle hi16
                LDA     _libcTmp2
                STA     [_kHeapCur],Y
                LDA     _libcTmp1               ; A = aligned base bank
                SEC
                RTS
@mcb_dispose    ; one-bank claim came back unaligned (impossible per TN#78);
                ; dispose rather than scribble a misaligned bank.
                LDA     _libcTmp2               ; handle hi16
                PHA
                LDA     _kCopyPtr               ; handle lo16
                PHA
                LDX     #$1002                  ; _DisposeHandle
                JSL     $E10000
                CLC
                RTS

;------------------------------------------------------------------------------
; _Kmalloc_Big - train-2 M-4: satisfy a big (>= KMALLOC_BIG_THRESH or >64KB)
; allocation with a DEDICATED MM block (kind=4 block-table row).  Free lists
; never cross block boundaries — big blocks aren't in any free list; they
; are returned whole and disposed whole (_Kfree_Big).
;
; In:   A = size lo16, X = size hi16 (32-bit size).  MX %00.
; Out:  C=1 + A.lo = base bank (16-bit clean) + Y = 0 (block is bank:0000)
;       and _kmallocResult = {0, bank}; C=0 + A = ENOMEM.
;------------------------------------------------------------------------------
_Kmalloc_Big    MX      %00
                ; banks = hi16 + (lo16 != 0 ? 1 : 0)
                TAY                             ; Y = lo16
                TXA                             ; A = hi16
                CPY     #0
                BEQ     @kb_exact
                INC                             ; ceil to whole banks
@kb_exact       LDX     #4                      ; kind 4 = dedicated big block
                JSR     _MM_ClaimBanksToRow
                BCS     @kb_ok
                LDA     #ENOMEM
                CLC
                RTS
@kb_ok          STA     _libcTmp2               ; base bank
                LDA     #0
                STA     _kmallocResult          ; offset 0
                SEP     #$20
                MX      %10
                LDA     _libcTmp2
                STA     _kmallocResult+2        ; bank
                REP     #$20
                MX      %00
                LDY     #0                      ; offset for the caller
                LDA     _libcTmp2
                AND     #$00FF
                SEC
                RTS

;------------------------------------------------------------------------------
; _Kfree_Big - dispose a dedicated big block by its base bank.  Called from
; _Sys_Free for offset-0 pointers (big blocks are the ONLY allocations at
; bank:0000 — arena chunks always sit past their chunk header).
;
; In:   A = bank (low byte significant).  MX %00.
; Out:  C=1 row found + DisposeHandle'd + row tombstoned (kind=0);
;       C=0 not a live big block (double-free / stray) — caller no-ops.
;------------------------------------------------------------------------------
_Kfree_Big      MX      %00
                LDX     #4                      ; kind 4 = dedicated big block
                ; FALL THROUGH into the kind-parameterized core
;------------------------------------------------------------------------------
; _BlkRow_DisposeByBank - dispose the block-table row {kind, base==bank}:
; DisposeHandle its MM handle and tombstone the row (kind=0; the claim
; engine reuses tombstones).  Kind-parameterized core for _Kfree_Big
; (kind=4 big allocs) and Bank_Free's MM-granted user banks (kind=3).
;
; In:   A = bank (low byte significant), X = kind (low byte).  MX %00.
; Out:  C=1 disposed; C=0 no such live row — caller no-ops.
; Clobbers: A, X, Y, _shTmp0/1, _libcTmp1, _kCopyPtr, _kHeapCur.
;------------------------------------------------------------------------------
_BlkRow_DisposeByBank MX %00
                AND     #$00FF
                STA     _shTmp0                 ; target bank (word)
                TXA
                AND     #$00FF
                STA     _libcTmp1               ; target kind (word)
                SEP     #$20
                MX      %10
                LDA     _kBlkTabBase+2          ; table published?
                BEQ     @kf_no8
                REP     #$20
                MX      %00
                KHEAP_USE _kBlkTabBase
                SEP     #$20
                MX      %10                     ; 16-bit X/Y: 8 x row passes 255
                LDA     _kBlkCount
                STA     _kCopyPtr               ; live rows, word-clean for
                STZ     _kCopyPtr+1             ;   the 16-bit CPX
                LDX     #0                      ; row index
                LDY     #0                      ; row base byte-offset
@kf_rowL        CPX     _kCopyPtr
                BCS     @kf_no8x
                INY
                INY                             ; +2 kind
                LDA     [_kHeapCur],Y
                CMP     _libcTmp1               ; the requested kind?
                BNE     @kf_next
                DEY
                DEY                             ; +0 base
                LDA     [_kHeapCur],Y
                CMP     _shTmp0                 ; our bank?
                BEQ     @kf_found
                INY
                INY
@kf_next        ; advance to next row (Y currently at +2): +6, by INY
                INY                             ;   because TYA/TAY with M=8
                INY                             ;   would carry B into Y
                INY
                INY
                INY
                INY
                INX
                BRA     @kf_rowL
                ; The refusals sit here, inside the guard's branch reach.
@kf_no8         REP     #$20
                MX      %00
                CLC
                RTS
@kf_no8x        REP     #$30
                MX      %00
                CLC
                RTS
@kf_found       ; Y = row base offset.  Pull the handle (16-bit reads).
                REP     #$30
                MX      %00
                TYA
                CLC
                ADC     #4
                TAY                             ; +4 handle lo16
                LDA     [_kHeapCur],Y
                STA     _kCopyPtr               ; stash lo16
                INY
                INY                             ; +6 handle hi16
                LDA     [_kHeapCur],Y
                PHA                             ; push handle hi16
                LDA     _kCopyPtr
                PHA                             ; push handle lo16
                STY     _shTmp1                 ; row +6 offset — Y is NOT
                                                ; preserved across a toolbox JSL
                LDX     #$1002                  ; _DisposeHandle
                JSL     $E10000
                ; Tombstone the row: kind=0, base=0 (claim scan reuses it).
                KHEAP_USE _kBlkTabBase          ; re-load (foreign JSL)
                LDA     _shTmp1
                SEC
                SBC     #6                      ; back to row +0
                TAY
                SEP     #$20
                MX      %10
                LDA     #0
                STA     [_kHeapCur],Y           ; +0 base = 0
                INY
                STA     [_kHeapCur],Y           ; +1 count = 0
                INY
                STA     [_kHeapCur],Y           ; +2 kind = 0 (tombstone)
                REP     #$20
                MX      %00
                SEC
                RTS

;------------------------------------------------------------------------------
; _BlkRow_FindOwned - the kind-4 row walker fork and exit are built on (#11).
; Finds the first kind-4 (dedicated big block) row at or after row index X
; whose +3 owner byte matches A.
;
; A big block is USER memory sitting in banks OUTSIDE the task's data bank, so
; snapshot-fork has to copy it (or the child writes through to the parent, which
; is issue #4 one allocator over) and exit has to free it.  Both need to
; enumerate "the blocks belonging to pid N", which is what this is.
;
; In:   A = owner pid (low byte), X = starting row index.  MX %00.
; Out:  C=1 + A = base bank (16-bit clean), X = bank count, Y = the NEXT row
;       index (feed it back in X to continue the walk);
;       C=0 = no more rows for this owner.
; Clobbers: A, X, Y, _shTmp0/1, _libcTmp1/2, _kHeapCur.
;------------------------------------------------------------------------------
_BlkRow_FindOwned MX    %00
                AND     #$00FF
                STA     _shTmp0                 ; owner pid (word)
                STX     _shTmp1                 ; row cursor (word)
                STZ     _libcTmp1               ; base-bank result (word-clean:
                STZ     _libcTmp2               ;   the reads below are 8-bit)
                SEP     #$20
                MX      %10
                LDA     _kBlkTabBase+2          ; table published?
                BEQ     @fo_no
                REP     #$20
                MX      %00
                KHEAP_USE _kBlkTabBase          ; cursor -> table (M=16 in/out)
@fo_rowL        SEP     #$20
                MX      %10
                LDA     _kBlkCount              ; live rows (a BYTE -- a 16-bit
                REP     #$20                    ;   read would pull _kBlkTabBase)
                MX      %00
                AND     #$00FF
                CMP     _shTmp1
                BEQ     @fo_noC                 ; cursor == count -> past the end
                BCC     @fo_noC
                LDA     _shTmp1
                ASL
                ASL
                ASL                             ; row byte-offset = idx * 8
                TAY
                INY
                INY                             ; +2 kind
                SEP     #$20
                MX      %10
                LDA     [_kHeapCur],Y
                CMP     #4
                BNE     @fo_next
                INY                             ; +3 owner
                LDA     [_kHeapCur],Y
                CMP     _shTmp0                 ; (low byte; _shTmp0 is word-clean)
                BEQ     @fo_found
@fo_next        REP     #$20
                MX      %00
                INC     _shTmp1
                BRA     @fo_rowL
@fo_found       DEY
                DEY
                DEY                             ; +0 base bank
                LDA     [_kHeapCur],Y
                STA     _libcTmp1
                INY
                LDA     [_kHeapCur],Y           ; +1 bank count
                STA     _libcTmp2
                REP     #$20
                MX      %00
                INC     _shTmp1                 ; resume AFTER this row
                LDY     _shTmp1
                LDX     _libcTmp2
                LDA     _libcTmp1
                SEC
                RTS
@fo_no          REP     #$20
                MX      %00
@fo_noC         CLC
                RTS

;------------------------------------------------------------------------------
; _BlkRow_FreeByOwner - dispose every dedicated big block owned by pid A.
; Called at task exit and at a fork child's execve, beside the SE_SbrkBank
; teardown those paths already do: a big block is per-task memory and dies with
; the task, exactly like the private sbrk bank.
;
; Rescans from row 0 each time because _Kfree_Big TOMBSTONES the row it frees,
; which both invalidates a saved cursor and guarantees the scan cannot loop on
; the same row.
;
; In:   A = owner pid (low byte).  MX %00.  Out: A/X/Y clobbered.
;------------------------------------------------------------------------------
_BlkRow_FreeByOwner MX  %00
                AND     #$00FF
                PHA                             ; owner pid (16-bit push)
@bfo_L          PLA
                PHA
                LDX     #0
                JSR     _BlkRow_FindOwned
                BCC     @bfo_done
                AND     #$00FF
                JSR     _Kfree_Big              ; C advisory
                BRA     @bfo_L
@bfo_done       PLA
                RTS

;------------------------------------------------------------------------------
; _BlkRow_OwnerOf - the owner pid of the live kind-4 row based at bank A.
;
; In:   A = bank (low byte).  MX %00.
; Out:  C=1 + A = owner pid (16-bit clean); C=0 = no live kind-4 row there.
; Clobbers: A, X, Y, _shTmp0, _libcTmp1/2, _kHeapCur.
;------------------------------------------------------------------------------
_BlkRow_OwnerOf MX      %00
                AND     #$00FF
                STA     _shTmp0                 ; target bank (word)
                STZ     _libcTmp1               ; owner result (word-clean)
                SEP     #$20
                MX      %10
                LDA     _kBlkTabBase+2
                BEQ     @oo_no
                REP     #$20
                MX      %00
                KHEAP_USE _kBlkTabBase
                LDY     #0                      ; row byte-offset
                LDX     #0                      ; row index
@oo_rowL        SEP     #$20
                MX      %10
                LDA     _kBlkCount
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     _libcTmp2
                CPX     _libcTmp2
                BCS     @oo_noC
                INY
                INY                             ; +2 kind
                SEP     #$20
                MX      %10
                LDA     [_kHeapCur],Y
                CMP     #4
                BNE     @oo_next
                DEY
                DEY                             ; +0 base
                LDA     [_kHeapCur],Y
                CMP     _shTmp0
                BNE     @oo_next3
                INY
                INY
                INY                             ; +3 owner
                LDA     [_kHeapCur],Y
                STA     _libcTmp1
                REP     #$20
                MX      %00
                LDA     _libcTmp1
                SEC
                RTS
@oo_next3       INY
                INY                             ; back to +2
@oo_next        REP     #$20
                MX      %00
                TYA
                CLC
                ADC     #6                      ; +2 -> next row +0
                TAY
                INX
                BRA     @oo_rowL
@oo_no          REP     #$20
                MX      %00
@oo_noC         CLC
                RTS

;------------------------------------------------------------------------------
; _Kmem_InitOneArena - fill arena record X + write the initial free chunk
;                      in bank _libcTmp1:$0000.
;------------------------------------------------------------------------------
_Kmem_InitOneArena MX %00
                ; Arena record addr = Kmem_Arenas + X * 16
                TXA
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #Kmem_Arenas
                STA     _libcDstPtr         ; arena record ptr (bank-$02)

                ; bank byte
                SEP     #$20
                LDA     _libcTmp1
                STA     (_libcDstPtr)       ; ARENA_BANK at offset 0
                LDY     #ARENA_PAD0
                LDA     #0
                STA     (_libcDstPtr),Y
                REP     #$20

                ; first_chunk / freehead both point at the initial chunk at
                ; bank:KMEM_FIRST_CHUNK_OFF.  Offset 0 is reserved so it can
                ; serve as the null/end-of-list sentinel.
                LDA     #KMEM_FIRST_CHUNK_OFF
                LDY     #ARENA_FIRST
                STA     (_libcDstPtr),Y
                LDY     #ARENA_FREEHEAD
                STA     (_libcDstPtr),Y
                ; total
                LDA     #KMEM_ARENA_SIZE_HI
                LDY     #ARENA_TOTAL
                STA     (_libcDstPtr),Y
                ; used, peak, allocs, frees = 0
                LDA     #0
                LDY     #ARENA_USED
                STA     (_libcDstPtr),Y
                LDY     #ARENA_PEAK
                STA     (_libcDstPtr),Y
                LDY     #ARENA_ALLOCS
                STA     (_libcDstPtr),Y
                LDY     #ARENA_FREES
                STA     (_libcDstPtr),Y

                JSR     _Kmem_WriteInitChunk
                RTS

;------------------------------------------------------------------------------
; _Kmem_WriteInitChunk - bank in _libcTmp1; write the initial free chunk at
;                         bank:$0000.  Header = {size=INIT_CHUNK_SIZE,
;                         type=M_FREE, next=0, freenext=0}.  Guard byte
;                         placed at offset CH_HEADER_LEN + INIT_CHUNK_SIZE.
;------------------------------------------------------------------------------
_Kmem_WriteInitChunk MX %00
                ; Long-pointer _libcTmp2 = {bank=_libcTmp1, offset=KMEM_FIRST_CHUNK_OFF}
                SEP     #$20
                LDA     _libcTmp1
                STA     _libcTmp2+2         ; bank byte of long ptr
                REP     #$20
                LDA     #KMEM_FIRST_CHUNK_OFF
                STA     _libcTmp2

                ; Header fields
                LDY     #CH_SIZE
                LDA     #KMEM_INIT_CHUNK_SIZE
                STA     [_libcTmp2],Y
                LDY     #CH_TYPE
                LDA     #M_FREE
                STA     [_libcTmp2],Y
                LDY     #CH_NEXT
                LDA     #0                  ; 0 = end-of-chunk-list sentinel
                STA     [_libcTmp2],Y
                LDY     #CH_FREENEXT
                STA     [_libcTmp2],Y

                ; Guard byte at offset CH_HEADER_LEN + KMEM_INIT_CHUNK_SIZE
                LDY     #CH_HEADER_LEN+KMEM_INIT_CHUNK_SIZE
                SEP     #$20
                LDA     #CH_GUARD
                STA     [_libcTmp2],Y
                REP     #$20
                RTS
