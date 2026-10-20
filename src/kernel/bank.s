;==============================================================================
; bank.s - the user pool's page map.
;
; FGX-Provenance: none.  Original FGX code.  The DESIGN is 2.11BSD's resource
; map (usr/sys/sys/subr_rmap.c), and its own description is quoted below with
; that attribution; none of upstream's code is carried (docs/PROVENANCE.md,
; "Ports and reimplementations").
;
; 2.11BSD's resource map (usr/sys/sys/subr_rmap.c, h/map.h), over the pool of
; user banks in 256-byte pages:
;
;   "A resource map is an array of structures each of which describes a
;    segment of the address space of an available resource.  The segments
;    are described by their base address and length, and sorted in address
;    order. ... Resources are allocated by taking part or all of one of the
;    segments of the map."
;
; _coremap holds {size, addr} pieces, 4 bytes each, in address order, size 0
; ending it; an address is bank << 8 | page.  Allocation is first fit and a
; free coalesces with its neighbours, as malloc() and mfree() do.  Its size is
; 2.11BSD's too: CMAPSIZ is NPROC (sys/conf/param.c).
;
; FGX's rule BSD does not have: no allocation crosses a bank, since a 65816
; code or data segment cannot span one.  Pieces coalesce freely; a request is
; placed at the first address of a piece from which it fits inside one bank,
; and the piece splits when that is not its start.  A request under a bank
; first looks for room that does not start a wholly free bank, so whole banks
; stay whole for data.  tools/coremap_model.py is this file's behaviour, in
; Python, and the coremap probe holds a dumped map to it.
;
; The pool floor is dynamic (_kUserFirstBank = _restBaseBank +
; REST_USER_FIRST_OFF); its size is the loader's claim, at most
; BANK_USER_COUNT.  Memory Manager grants (Bank_Alloc's dry-pool fallback)
; never enter the map: Bank_Free returns them by block-table lookup.
;
; Every routine runs with DBR = the kernel bank: the map is a kernel static,
; read and written DBR-relative so it lands in the live copy under relocation.
;==============================================================================

NMAP            EQU     NPROC                   ; slots, the terminator's included
                ERR     {NMAP*4}-{KMem_Coremap_end-_coremap}

;------------------------------------------------------------------------------
; Bank_Init - the map holds one piece, the claimed pool.  Called once from
; FGX_Entry before Task_Init.  Caller MX %00.  Preserves registers and flags.
;------------------------------------------------------------------------------
Bank_Init       ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                ; The loader's CLAIMED bank count (KFGX_REST_COUNT) bounds the
                ; pool on a small-RAM machine; 0 is a loader that does not
                ; say, and gets the whole pool.
                LDA     #BANK_USER_COUNT
                STA     _rmPool
                LDAL    KFGX_REST_COUNT
                AND     #$00FF
                BEQ     @bi_count
                SEC
                SBC     #REST_USER_FIRST_OFF
                CMP     #BANK_USER_COUNT
                BCS     @bi_count
                STA     _rmPool
@bi_count       LDA     _rmPool
                XBA                             ; pages = banks << 8
                STA     _coremap
                LDA     _kUserFirstBank
                AND     #$00FF
                XBA
                STA     _coremap+2
                STZ     _coremap+4              ; the terminator
                PLP
                RTS

;------------------------------------------------------------------------------
; Bank_Alloc - a whole bank: the lowest wholly free one.
; Returns: C=1 + A = bank number.  C=0 + A = ENOMEM.
; Caller MX %00.  Preserves X/Y.
;------------------------------------------------------------------------------
Bank_Alloc      ENT
                MX      %00
                PHX
                PHY
                PHP
                REP     #$30
                MX      %00
@ba_try         LDA     #256
                JSR     Rm_Alloc
                BCC     @ba_dry
                XBA                             ; the bank is the high byte
                AND     #$00FF
                BRA     @ba_ok
@ba_dry         ; Pool dry.  A cached text no process runs (text.s) holds
                ; pages, and so does a resident library no process uses
                ; (ld.mod); give one back and try again, a text first.  That
                ; is 2.11BSD's malloc(coremap) (subr_rmap.c): short of core it
                ; frees unused text images with xuncore() and retries.
_ktp114         JSL     KTTY_TEXT_RECLAIM       ; an unused text first
                BCS     @ba_try
_ktp111         JSL     KTTY_LD_RECLAIM         ; then an unused library
                BCS     @ba_try
                ; A Memory Manager bank, recorded as a kind=3 USER-GRANT
                ; block-table row: the boot pool is a working set, not the
                ; ceiling.  Refused (masked-IRQ context, table full, before
                ; the table) is ENOMEM.  Bank_Free returns these by table
                ; lookup; they are not in the map.
                LDA     #1                      ; one bank
                LDX     #3                      ; kind 3 = user grant
                JSR     _MM_ClaimBanksToRow     ; C=1 -> A = bank
                BCC     @ba_fail
                AND     #$00FF
@ba_ok          STA     _shTmp0
                PLP
                PLY
                PLX
                LDA     _shTmp0
                SEC
                RTS
@ba_fail        PLP
                PLY
                PLX
                LDA     #ENOMEM
                CLC
                RTS

;------------------------------------------------------------------------------
; Bank_Free - return a whole bank.  A pool bank goes back to the map; any
; other is an MM grant, disposed by block-table lookup, or a no-op if it is
; neither.
; Input:  A (low byte) = bank number.
; Caller MX %00.  Preserves X/Y.
;------------------------------------------------------------------------------
Bank_Free       ENT
                MX      %00
                PHX
                PHY
                PHP
                REP     #$30
                MX      %00
                AND     #$00FF
                STA     _shTmp1                 ; the bank
                SEC
                SBC     _kUserFirstBank         ; idx (wraps if below the pool)
                CMP     _rmPool
                BCC     @bf_pool
                LDA     _shTmp1
                LDX     #3                      ; kind 3 = user grant
                JSR     _BlkRow_DisposeByBank   ; C is advisory
                BRA     @bf_done
@bf_pool        LDA     _shTmp1
                XBA
                TAX                             ; X = bank << 8
                LDA     #256
                JSR     Rm_Free
@bf_done        PLP
                PLY
                PLX
                RTS

;------------------------------------------------------------------------------
; Bank_MarkUsed - take a given pool bank out of the map.  No-op outside the
; pool, or if the bank is not wholly free.  Mod_RegisterPreLoaded uses it for
; the bank the loader pre-staged a module into, bypassing Bank_Alloc.
; Input:  A (low byte) = bank number.
; Caller MX %00.  Preserves X/Y.
;------------------------------------------------------------------------------
Bank_MarkUsed   ENT
                MX      %00
                PHX
                PHY
                PHP
                REP     #$30
                MX      %00
                AND     #$00FF
                STA     _shTmp1
                SEC
                SBC     _kUserFirstBank
                CMP     _rmPool
                BCS     @bmu_done
                LDA     _shTmp1
                XBA
                TAX
                LDA     #256
                JSR     Rm_Claim
@bmu_done       PLP
                PLY
                PLX
                RTS

;------------------------------------------------------------------------------
; Core_Alloc - pages for a placed code segment.
; In:  A = pages, 1..255.  Out: C=1 + A = address (bank << 8 | page); C=0 no
; room after every unused text and library has been given back, retrying
; after each, as Bank_Alloc does.  Never asks the Memory Manager: a caller
; with no pages takes a whole bank from Bank_Alloc instead.
; Caller MX %00.  Preserves X/Y.
;------------------------------------------------------------------------------
Core_Alloc      ENT
                MX      %00
                PHX
                PHY
                PHP
                REP     #$30
                MX      %00
                PHA                             ; the request, across reclaims
@ca_try         LDA     1,S
                JSR     Rm_Alloc
                BCS     @ca_ok
_ktp125         JSL     KTTY_TEXT_RECLAIM
                BCS     @ca_try
_ktp126         JSL     KTTY_LD_RECLAIM
                BCS     @ca_try
                PLA
                PLP
                PLY
                PLX
                CLC
                RTS
@ca_ok          STA     _shTmp0
                PLA
                PLP
                PLY
                PLX
                LDA     _shTmp0
                SEC
                RTS

;------------------------------------------------------------------------------
; Core_Free - give back what Core_Alloc or Bank_Alloc gave.
; In:  A = pages (0 = the whole bank, through Bank_Free), X = address.
; Caller MX %00.  Preserves X/Y.
;------------------------------------------------------------------------------
Core_Free       ENT
                MX      %00
                PHX
                PHY
                PHP
                REP     #$30
                MX      %00
                AND     #$00FF
                BNE     @cf_pages
                TXA
                XBA                             ; the bank
                JSR     Bank_Free
                BRA     @cf_out
@cf_pages       JSR     Rm_Free
@cf_out         PLP
                PLY
                PLX
                RTS

;------------------------------------------------------------------------------
; Rm_Alloc - malloc(coremap, size) with the bank rule.
; In:  A = pages, 1..256.  Out: C=1 + A = address; C=0 no room.
; MX %00.  Clobbers X/Y.
;------------------------------------------------------------------------------
Rm_Alloc        MX      %00
                STA     _rmSize
                LDA     #1
                STA     _rmStrict               ; pass 1 keeps whole banks whole
@ra_pass        LDX     #0
@ra_scan        LDA     _coremap,X
                BEQ     @ra_endPass
                ; p = a, or the next bank's start if the request would cross
                LDA     _coremap+2,X
                AND     #$00FF
                CLC
                ADC     _rmSize
                CMP     #257
                LDA     _coremap+2,X
                BCC     @ra_p
                ORA     #$00FF
                INC
@ra_p           STA     _rmP
                LDA     _coremap+2,X
                CLC
                ADC     _coremap,X
                STA     _rmEnd                  ; one past the piece
                LDA     _rmP
                CLC
                ADC     _rmSize
                CMP     _rmEnd
                BEQ     @ra_fits
                BCS     @ra_next                ; p + size > end
@ra_fits        LDA     _rmStrict
                BEQ     @ra_take
                LDA     _rmSize
                CMP     #256
                BCS     @ra_take                ; a whole bank is never deferred
                LDA     _rmP
                AND     #$00FF
                BNE     @ra_take                ; p inside a partly used bank
                LDA     _rmEnd
                SEC
                SBC     _rmP
                CMP     #256
                BCS     @ra_next                ; p starts a wholly free bank
@ra_take        JSR     _Rm_Take
                BCS     @ra_out
@ra_next        INX
                INX
                INX
                INX
                BRA     @ra_scan
@ra_endPass     LDA     _rmStrict
                BEQ     @ra_none
                STZ     _rmStrict
                BRA     @ra_pass
@ra_none        CLC
@ra_out         RTS

;------------------------------------------------------------------------------
; Rm_Claim - take [addr, addr + size) out of the piece that holds it.
; In:  A = pages, X = address.  Out: C=1 taken; C=0 not wholly free, or the
; map is full.  MX %00.  Clobbers X/Y.
;------------------------------------------------------------------------------
Rm_Claim        MX      %00
                STA     _rmSize
                STX     _rmP
                LDX     #0
@rc_scan        LDA     _coremap,X
                BEQ     @rc_no
                LDA     _rmP
                CMP     _coremap+2,X
                BCC     @rc_next                ; addr below the piece
                LDA     _coremap+2,X
                CLC
                ADC     _coremap,X
                STA     _rmEnd
                LDA     _rmP
                CLC
                ADC     _rmSize
                CMP     _rmEnd
                BEQ     @rc_take
                BCC     @rc_take
@rc_next        INX
                INX
                INX
                INX
                BRA     @rc_scan
@rc_take        JMP     _Rm_Take
@rc_no          CLC
                RTS

;------------------------------------------------------------------------------
; _Rm_Take - take _rmSize pages at _rmP from the piece at X, which holds
; [_rmP, _rmP + _rmSize) and ends at _rmEnd.  When _rmP is not the piece's
; start the piece splits first, and that needs a free slot.
; Out: C=1 + A = _rmP; C=0 the map is full (X = the piece again).
;------------------------------------------------------------------------------
_Rm_Take        MX      %00
                LDA     _rmP
                CMP     _coremap+2,X
                BEQ     @rt_carve
                STX     _rmStart
                JSR     _Rm_Term
                CPX     #{NMAP-1}*4
                BCS     @rt_full
                JSR     _Rm_Up
                LDX     _rmStart
                LDA     _rmP
                SEC
                SBC     _coremap+2,X
                STA     _coremap,X              ; the left piece keeps [a, p)
                LDA     _rmEnd
                SEC
                SBC     _rmP
                STA     _coremap+4,X            ; the right one is [p, end)
                LDA     _rmP
                STA     _coremap+6,X
                INX
                INX
                INX
                INX
@rt_carve       LDA     _coremap,X
                SEC
                SBC     _rmSize
                STA     _coremap,X
                BEQ     @rt_gone
                LDA     _coremap+2,X
                CLC
                ADC     _rmSize
                STA     _coremap+2,X
                BRA     @rt_ok
@rt_gone        JSR     _Rm_Down                ; "move the rest of the map to the left"
@rt_ok          LDA     _rmP
                SEC
                RTS
@rt_full        LDX     _rmStart
                CLC
                RTS

;------------------------------------------------------------------------------
; Rm_Free - mfree(coremap, size, addr): sort the range into the map and
; combine it with a neighbour on either side.  A range that abuts neither
; needs a new slot; with none, its pages are lost and logged, as mfree
; prints "overflow, lost %u clicks".
; In:  A = pages, X = address.  MX %00.  Clobbers X/Y.
;------------------------------------------------------------------------------
Rm_Free         MX      %00
                STA     _rmSize
                STX     _rmP
                LDX     #0
@rf_find        LDA     _coremap,X              ; the piece after the range
                BEQ     @rf_at
                LDA     _coremap+2,X
                CMP     _rmP
                BEQ     @rf_on
                BCS     @rf_at
@rf_on          INX
                INX
                INX
                INX
                BRA     @rf_find
@rf_at          CPX     #0
                BEQ     @rf_right
                LDA     _coremap-4+2,X          ; the piece on the left
                CLC
                ADC     _coremap-4,X
                CMP     _rmP
                BNE     @rf_right
                LDA     _coremap-4,X            ; abuts: grow it
                CLC
                ADC     _rmSize
                STA     _coremap-4,X
                LDA     _coremap,X              ; and take in the right one too?
                BEQ     @rf_done
                LDA     _rmP
                CLC
                ADC     _rmSize
                CMP     _coremap+2,X
                BNE     @rf_done
                LDA     _coremap-4,X
                CLC
                ADC     _coremap,X
                STA     _coremap-4,X
                JMP     _Rm_Down
@rf_right       LDA     _coremap,X
                BEQ     @rf_new
                LDA     _rmP
                CLC
                ADC     _rmSize
                CMP     _coremap+2,X
                BNE     @rf_new
                LDA     _rmP                    ; abuts the right one: extend it down
                STA     _coremap+2,X
                LDA     _coremap,X
                CLC
                ADC     _rmSize
                STA     _coremap,X
@rf_done        RTS
@rf_new         STX     _rmStart
                JSR     _Rm_Term
                CPX     #{NMAP-1}*4
                BCS     @rf_lost
                JSR     _Rm_Up
                LDX     _rmStart
                LDA     _rmSize
                STA     _coremap,X
                LDA     _rmP
                STA     _coremap+2,X
                RTS
@rf_lost        LDA     #_rmLost1
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _rmSize
                JSR     Kern_LogDec16
                LDA     #_rmLost2
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _rmP
                JSR     Kern_LogHex16
                JMP     Kern_LogEOL

_rmLost1        ASC     'coremap: overflow, lost ',00
_rmLost2        ASC     ' pages at $',00

;------------------------------------------------------------------------------
; Slot moves.  _Rm_Term: X -> the terminator's offset, from X on.  _Rm_Up:
; X = the terminator; every slot from _rmStart to it moves up one.
; _Rm_Down: X = a slot to drop; every slot after it moves down one.
;------------------------------------------------------------------------------
_Rm_Term        MX      %00
                LDA     _coremap,X
                BEQ     @rtm_out
                INX
                INX
                INX
                INX
                BRA     _Rm_Term
@rtm_out        RTS

_Rm_Up          MX      %00
                LDA     _coremap,X
                STA     _coremap+4,X
                LDA     _coremap+2,X
                STA     _coremap+6,X
                CPX     _rmStart
                BEQ     @ru_out
                DEX
                DEX
                DEX
                DEX
                BRA     _Rm_Up
@ru_out         RTS

_Rm_Down        MX      %00
                LDA     _coremap+6,X
                STA     _coremap+2,X
                LDA     _coremap+4,X
                STA     _coremap,X
                BEQ     @rd_out
                INX
                INX
                INX
                INX
                BRA     _Rm_Down
@rd_out         RTS
