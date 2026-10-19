;==============================================================================
; text.s - the shared-text table: a program's code banks, loaded once and used
; by every process running it.  A tenant of the tty bank for its room.
;
; FGX-Provenance: none.  Original FGX code.  The DESIGN is 2.11BSD's
; (usr/sys/h/text.h, usr/sys/sys/vm_text.c), named and quoted in a sentence
; below; none of upstream's code is carried (docs/PROVENANCE.md, "Ports and
; reimplementations").
;
; 2.11BSD's `struct text' (usr/sys/h/text.h) and its vm_text.c, without the
; swap: an entry is x_iptr's identity, x_caddr's core and x_size (each code
; segment's bank, page and page count in the pool's map, bank.s) and x_count.
; x_daddr and x_ccount go because FGX has no swap area, so a text is either
; loaded or gone; x_flag goes with ETXTBSY (a text here is an in-memory copy,
; so writing the file cannot change a running program).
;
; AN ENTRY IS CLAIMED BEFORE ITS LOAD AND FILLED AFTER IT (KTTY_TEXT_CLAIM,
; KTTY_TEXT_FILL), so the pages a load places a segment in belong to an entry
; from the start and never to a process.  A claim the load gives up -- its
; exec failed -- is freed when its reference goes (_Tx_Unref).
;
; THE KEY IS THE FILE'S DEVICE, INODE AND CHANGE TIME, as fstat(2) reports
; them (the loader's _Ld_TextKey), not a held vnode: ctime moves on every
; write, truncate, chmod and link change, so a rewritten or replaced file never
; matches its old text, and nothing here pins a vnode, a mount or an unlinked
; file's blocks.  An entry whose inode is 0 is free; UFS never numbers a file 0.
;
; "All text under 2.10 is sticky in an LRU cache" (vm_text.c xfree): a text
; whose count reaches 0 stays loaded, and KTTY_TEXT_RECLAIM -- xuncore() --
; frees the least recently used one when Bank_Alloc finds the pool dry.
;
; _kTextOf[pid-1] is the text a process runs, 0 = none (uncached, or not
; FGX2).  Only this file touches it: the core says which pid, never where.
;
; Every slot is entered by JSL from the core, MX %00, and sets its own DBR.
; KTTY_TEXT_FIND, KTTY_TEXT_CLAIM and KTTY_TEXT_FILL read the caller's key and
; lists through a long pointer kept on the stack, with D moved onto it, so
; they touch no shared direct page -- except when CLAIM reclaims, which runs on
; the caller's page, because Bank_Free keeps its scratch there.
;==============================================================================

NTEXT           EQU     16
TX_DEV          EQU     0               ; 2: st_dev
TX_INO          EQU     2               ; 2: st_ino; 0 = free entry
TX_CTIME        EQU     4               ; 4: st_ctime
TX_BANKS        EQU     8               ; 8: bank per segment; 0 = not text
TX_PAGE         EQU     16              ; 8: its first page in that bank
TX_NPG          EQU     24              ; 8: its pages, 0 = the whole bank
TX_COUNT        EQU     32              ; 1: x_count, processes running it
TX_STAMP        EQU     33              ; 2: last use, for reclaim order
TX_SIZE         EQU     36              ; padded: _Tx_Off is 32+4

TXP             EQU     1               ; D-relative long pointer (see header)
TX_YOUNG        EQU     1               ; seconds: a text changed this recently
                                        ;   is not cached (KTTY_TEXT_REG)

_kTextTab       DS      NTEXT*TX_SIZE
_kTextOf        DS      NPROC
_txClock        DS      2               ; use stamp source
_txIdx          DS      2               ; scan index, 1..NTEXT
_txTmp          DS      2
_txList         DS      2               ; FIND: the caller's list offset
_txBest         DS      2               ; RECLAIM: oldest candidate's offset
_txBestAge      DS      2

;------------------------------------------------------------------------------
; _Tx_Off - A = index 1..NTEXT -> X = its entry's offset.  MX %00.
;------------------------------------------------------------------------------
_Tx_Off         MX      %00
                DEC
                ASL
                ASL
                STA     _txTmp                  ; (i-1)*4
                ASL
                ASL
                ASL                             ; (i-1)*32
                CLC
                ADC     _txTmp
                TAX
                RTS

;------------------------------------------------------------------------------
; _Tx_Touch - X = entry offset: x_count++ and a fresh use stamp.  MX %00.
;------------------------------------------------------------------------------
_Tx_Touch       MX      %00
                SEP     #$20
                MX      %10
                INC     _kTextTab+TX_COUNT,X
                REP     #$20
                MX      %00
                INC     _txClock
                LDA     _txClock
                STA     _kTextTab+TX_STAMP,X
                RTS

;------------------------------------------------------------------------------
; _Tx_Unref - A = index (0 = none): x_count--.  At 0 the text stays cached,
; unless it was claimed and never filled (its load failed): that entry has no
; banks, and goes.  MX %00.  Preserves Y.
;------------------------------------------------------------------------------
_Tx_Unref       MX      %00
                AND     #$00FF
                BEQ     @txu_done
                JSR     _Tx_Off
                SEP     #$20
                MX      %10
                LDA     _kTextTab+TX_COUNT,X
                BEQ     @txu_8                  ; never wraps to 255
                DEC     _kTextTab+TX_COUNT,X
                BNE     @txu_8
                PHY
                LDY     #8
@txu_bank       LDA     _kTextTab+TX_BANKS,X
                BNE     @txu_kept               ; a filled text stays cached
                INX
                DEY
                BNE     @txu_bank
                REP     #$20
                MX      %00
                TXA
                SEC
                SBC     #8
                TAX
                STZ     _kTextTab+TX_INO,X      ; an empty claim: free it
@txu_kept       PLY
@txu_8          REP     #$20
                MX      %00
@txu_done       RTS

;------------------------------------------------------------------------------
; _Tx_Reclaim - xuncore(): free the least recently used text no process runs:
; each segment's pages (or its whole bank) back to the pool, the entry
; cleared.
; Out: C=1 one went, C=0 none.  MX %00.  Clobbers A/X/Y.
;------------------------------------------------------------------------------
_Tx_Reclaim     MX      %00
                LDA     #$FFFF
                STA     _txBest
                LDX     #0
@txr_scan       LDA     _kTextTab+TX_INO,X
                BEQ     @txr_next
                LDA     _kTextTab+TX_COUNT,X
                AND     #$00FF
                BNE     @txr_next
                LDA     _txClock                ; age = clock - stamp, so the
                SEC                             ;   order survives the clock
                SBC     _kTextTab+TX_STAMP,X    ;   wrapping
                LDY     _txBest
                BMI     @txr_take               ; first candidate
                CMP     _txBestAge
                BCC     @txr_next
@txr_take       STA     _txBestAge
                STX     _txBest
@txr_next       TXA
                CLC
                ADC     #TX_SIZE
                TAX
                CPX     #NTEXT*TX_SIZE
                BCC     @txr_scan
                LDX     _txBest
                BPL     @txr_free
                CLC
                RTS
@txr_free       LDY     #8
@txr_seg        LDA     _kTextTab+TX_NPG,X
                AND     #$00FF
                STA     _txTmp                  ; pages, 0 = the whole bank
                SEP     #$20
                MX      %10
                LDA     _kTextTab+TX_BANKS,X
                BEQ     @txr_nob
                XBA
                LDA     _kTextTab+TX_PAGE,X     ; C = bank << 8 | page
                REP     #$20
                MX      %00
                PHX
                PHY
                TAX
                LDA     _txTmp
_ctp079         JSL     _FarSh_Core_Free
                PLY
                PLX
@txr_nob        REP     #$20
                MX      %00
                INX
                DEY
                BNE     @txr_seg
                LDX     _txBest
                STZ     _kTextTab+TX_INO,X      ; the entry is free
                SEC
                RTS

;==============================================================================
; KTTY_TEXT_FIND - is this file's text loaded?
; In:  A = key offset, X = its bank (8 bytes: dev, ino, ctime);
;      Y = offset, same bank, of a 16-byte list to receive the text's banks
;      and then its pages.
; Out: C=1 + A = index, x_count taken; C=0 not loaded.  Clobbers X/Y.
;==============================================================================
_KTty_TextFind  MX      %00
                PHB
                PHD
                PHX                             ; long pointer: bank...
                PHA                             ; ...and offset
                TSC
                TCD                             ; [TXP] = the caller's key
                PHK
                PLB
                STY     _txList
                LDA     #1
                STA     _txIdx
                LDX     #0
@ktf_scan       LDA     _kTextTab+TX_INO,X
                BEQ     @ktf_next
                LDY     #2
                CMP     [TXP],Y
                BNE     @ktf_next
                LDA     _kTextTab+TX_DEV,X
                CMP     [TXP]
                BNE     @ktf_next
                LDY     #4
                LDA     _kTextTab+TX_CTIME,X
                CMP     [TXP],Y
                BNE     @ktf_next
                LDY     #6
                LDA     _kTextTab+TX_CTIME+2,X
                CMP     [TXP],Y
                BEQ     @ktf_hit
@ktf_next       INC     _txIdx
                TXA
                CLC
                ADC     #TX_SIZE
                TAX
                CPX     #NTEXT*TX_SIZE
                BCC     @ktf_scan
                CLC
                BRA     @ktf_out
@ktf_hit        JSR     _Tx_Touch
                LDA     _txList
                STA     TXP                     ; [TXP] = the bank list now
                LDY     #0
@ktf_copy       LDA     _kTextTab+TX_BANKS,X
                STA     [TXP],Y
                INX
                INX
                INY
                INY
                CPY     #16
                BCC     @ktf_copy
                LDA     _txIdx
                SEC
@ktf_out        PLX                             ; drop the pointer; P survives
                PLX
                PLD
                PLB
                RTL

;==============================================================================
; KTTY_TEXT_CLAIM - an entry for a text about to be loaded: the key, no
; banks yet, x_count = 1.  KTTY_TEXT_FILL records the segments once they are
; in; until then nothing finds it (FIND matches the key, and a load runs to
; its end before another starts), and nothing reclaims it (its count is 1).
; In:  A = key offset, X = its bank.
; Out: C=1 + A = index; C=0 the table is full of running texts (the caller
; loads into banks of its own).  Clobbers X/Y.  A full table first gives up
; its least recently used unused text, as xalloc's caller would find one
; through xuncore.
;
; A FILE CHANGED IN THE LAST TX_YOUNG SECONDS IS NOT CACHED (C=0).  The key's
; change time is whole seconds, so a rewrite in the same second as this load
; would carry this key and be served the old text; declining a text changed
; in [now - TX_YOUNG, now] means a later rewrite, stamped at or after now by
; this clock, never matches a cached key.  A change time after now came from
; another clock (a volume built elsewhere, a clock set back), which no write
; here stamps, so it is cached.  NFS clients refuse to trust a recently
; modified file's attributes for the same reason.
;==============================================================================
_KTty_TextClaim MX      %00
                PHB
                PHD
                PHX
                PHA
                TSC
                TCD
                PHK
                PLB
                LDY     #0                      ; UTC
                PHK
                PEA     @ktr_now-1
                JMP     _KTty_Now               ; A = now lo, X = now hi
@ktr_now        STA     _txIdx                  ; now, low word (scratch)
                STX     _txBest                 ;   high word (scratch)
                SEC
                SBC     #TX_YOUNG
                STA     _txTmp                  ; (now - TX_YOUNG), low word
                TXA
                SBC     #0
                STA     _txBestAge              ;   high word (scratch)
                LDY     #6
                LDA     [TXP],Y                 ; the key's change time, high
                CMP     _txBestAge
                BCC     @ktr_look               ; older than the window
                BNE     @ktr_hi
                LDY     #4
                LDA     [TXP],Y
                CMP     _txTmp
                BCC     @ktr_look
@ktr_hi         LDY     #6                      ; ...and not after now: a time
                LDA     [TXP],Y                 ;   this clock has not reached
                CMP     _txBest                 ;   came from another one, and
                BCC     @ktr_young              ;   no write here can stamp it
                BNE     @ktr_look
                LDY     #4
                LDA     [TXP],Y
                CMP     _txIdx
                BEQ     @ktr_young
                BCS     @ktr_look
@ktr_young      CLC                             ; too young to trust
                BRL     @ktr_out
@ktr_look       LDA     #1
                STA     _txIdx
                LDX     #0
@ktr_scan       LDA     _kTextTab+TX_INO,X
                BEQ     @ktr_got
                INC     _txIdx
                TXA
                CLC
                ADC     #TX_SIZE
                TAX
                CPX     #NTEXT*TX_SIZE
                BCC     @ktr_scan
                LDA     5                       ; the caller's D, under the pointer:
                PHD                             ;   Bank_Free keeps scratch on the
                TCD                             ;   direct page, and D is the stack
                JSR     _Tx_Reclaim             ;   here
                PLD
                BCS     @ktr_look
                BRA     @ktr_out                ; C=0: full
@ktr_got        STX     _txTmp
                LDY     #0                      ; the key...
@ktr_key        LDA     [TXP],Y
                STA     _kTextTab+TX_DEV,X
                INX
                INX
                INY
                INY
                CPY     #8
                BCC     @ktr_key
                LDY     #12                     ; ...then no segments yet:
@ktr_zero       STZ     _kTextTab+TX_DEV,X      ;   banks, pages, page counts
                INX
                INX
                DEY
                BNE     @ktr_zero
                LDX     _txTmp
                SEP     #$20
                MX      %10
                STZ     _kTextTab+TX_COUNT,X    ; x_count starts at 0...
                REP     #$20
                MX      %00
                JSR     _Tx_Touch               ; ...and is taken to 1
                LDA     _txIdx
                SEC
@ktr_out        PLX
                PLX
                PLD
                PLB
                RTL

;==============================================================================
; KTTY_TEXT_FILL - record a claimed text's segments, now loaded.
; In:  A = index; X = list bank, Y = list offset: 24 bytes, a bank per segment
;      (0 = not text), then each one's first page, then its pages (0 = the
;      whole bank).  Clobbers X/Y.
;==============================================================================
_KTty_TextFill  MX      %00
                PHB
                PHD
                PHA                             ; the index, at D+5 below
                PHX                             ; long pointer: bank...
                PHY                             ; ...and offset
                TSC                             ;   (A is S from here)
                TCD                             ; [TXP] = the caller's list
                PHK
                PLB
                LDA     5                       ; the index
                JSR     _Tx_Off
                LDY     #0
@ktl_copy       LDA     [TXP],Y
                STA     _kTextTab+TX_BANKS,X
                INX
                INX
                INY
                INY
                CPY     #24
                BCC     @ktl_copy
                PLX
                PLX
                PLX
                PLD
                PLB
                RTL

;==============================================================================
; KTTY_TEXT_RECLAIM - Bank_Alloc's pool is dry: free one unused text.
; Out: C=1 a text's banks went back, C=0 none.  Preserves X/Y.
;==============================================================================
_KTty_TextReclaim MX    %00
                PHB
                PHX
                PHY
                PHK
                PLB
                JSR     _Tx_Reclaim
                PLY
                PLX
                PLB
                RTL

;==============================================================================
; KTTY_TEXT_TOTAL - the text half of 2.11BSD's vmtotal() (sys/vm_sched.c), in
; pages, the coremap's unit:
;   A = t_vmtxt   every loaded text's x_size; also t_rmtxt, nothing swapping
;   X = t_avmtxt  x_size once for each process running it (x_count times)
;   Y = t_armtxt  x_size once for each text some process runs
; Upstream counts a process only while its p_slptime is under maxslp; FGX
; keeps no sleep time, so every process is active.  x_size is the sum of the
; entry's segment page counts, a count of 0 being the whole bank.
;==============================================================================
_txVm           EQU     _txBest                 ; RECLAIM's and FIND's scratch:
_txAvm          EQU     _txBestAge              ;   neither runs inside this
_txArm          EQU     _txList
_KTty_TextTotal MX      %00
                PHB
                PHK
                PLB
                STZ     _txVm
                STZ     _txAvm
                STZ     _txArm
                LDX     #0
@tt_ent         LDA     _kTextTab+TX_INO,X
                BEQ     @tt_next                ; a free entry
                STZ     _txTmp                  ; this text's x_size
                PHX
                LDY     #8                      ; segments
@tt_seg         LDA     _kTextTab+TX_BANKS,X
                AND     #$00FF
                BEQ     @tt_segNext             ; not a text segment
                LDA     _kTextTab+TX_NPG,X
                AND     #$00FF
                BNE     @tt_pages
                LDA     #256                    ; 0 = the whole bank
@tt_pages       CLC
                ADC     _txTmp
                STA     _txTmp
@tt_segNext     INX
                DEY
                BNE     @tt_seg
                PLX
                LDA     _txTmp                  ; x_size
                CLC
                ADC     _txVm
                STA     _txVm
                LDA     _kTextTab+TX_COUNT,X
                AND     #$00FF
                BEQ     @tt_next                ; cached, nobody running it
                TAY                             ; x_count
                LDA     _txTmp
                CLC
                ADC     _txArm
                STA     _txArm
@tt_avm         LDA     _txTmp
                CLC
                ADC     _txAvm
                STA     _txAvm
                DEY
                BNE     @tt_avm
@tt_next        TXA
                CLC
                ADC     #TX_SIZE
                TAX
                CPX     #NTEXT*TX_SIZE
                BCC     @tt_ent
                LDA     _txVm
                LDX     _txAvm
                LDY     _txArm
                PLB
                RTL

;==============================================================================
; KTTY_TEXT_UNREF - A = index (0 = none): drop one reference.  An exec that
; fails after its load took one gives it back here.  Preserves X/Y.
;==============================================================================
_KTty_TextUnref MX      %00
                PHB
                PHX
                PHK
                PLB
                JSR     _Tx_Unref
                PLX
                PLB
                RTL

;==============================================================================
; KTTY_TEXT_FORK - A = parent pid, X = child pid: the child runs the parent's
; text, and counts.  2.11BSD newproc (sys/kern_fork.c): "rpp->p_textp =
; rip->p_textp;" and then "if ((rip->p_textp != NULL) && !isvfork) {
; rip->p_textp->x_count++;".  FGX's vfork child counts too: its exec or
; exit drops a reference like any process's.  Preserves X/Y.
;==============================================================================
_KTty_TextFork  MX      %00
                PHB
                PHX
                PHY
                PHK
                PLB
                TAY                             ; Y = parent pid
                SEP     #$20
                MX      %10
                LDA     _kTextOf-1,Y
                STA     _kTextOf-1,X
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @ktk_out
                JSR     _Tx_Off
                JSR     _Tx_Touch
@ktk_out        PLY
                PLX
                PLB
                RTL

;==============================================================================
; KTTY_TEXT_SET - A = pid, X = the text it runs now (0 = none).  The text it
; ran before loses its reference: exit (X = 0) and exec's commit are xfree();
; spawn's first set finds 0 there.  Preserves X/Y.
;==============================================================================
_KTty_TextSet   MX      %00
                PHB
                PHX
                PHY
                PHK
                PLB
                TAY                             ; Y = pid
                SEP     #$20
                MX      %10
                LDA     _kTextOf-1,Y            ; the old text
                XBA
                TXA
                STA     _kTextOf-1,Y            ; the new one
                XBA
                REP     #$20
                MX      %00
                JSR     _Tx_Unref
                PLY
                PLX
                PLB
                RTL
