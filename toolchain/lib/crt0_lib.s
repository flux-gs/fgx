;==============================================================================
; crt0_lib.s - the startup of a program linked against libc's library-mode
; compile (shared libc SP3 spec, section 3), as fgx_static links it.  libc's
; half is _libc_start (libc_start.s), which fills the cells a program cannot
; name; the program keeps its entry, its own fcc runtime cells, main, the
; stdio flush and exit, and the signal stub the kernel enters in segment 0.
; The link defines _crt0_inits, which calls _lib_init for each library's
; blocks.
;
; Entry (the loader's JML): native, MX %11, DBR = the data bank, and only the
; kernel's argv frame on the stack -- so _libc_start, JSL'd before crt0 pushes
; anything, finds it at a fixed depth.
;==============================================================================
                FGX2_EXPORT _crt0_lib
_crt0_lib       MX      %11
                REP     #$30
                MX      %00
                ; The soft-frame pointer: the loader seeds all three bytes
                ; when the binary asks for a soft bank, so a non-zero bank
                ; byte means leave it.
                SEP     #$20
                MX      %10
                LDA     _fcc_sfp+2
                REP     #$20
                MX      %00
                AND     #$00FF
                BNE     @cl_sfpSeeded
                LDA     #$FFFE
                STA     _fcc_sfp
@cl_sfpSeeded
                ; The program's own data-bank cache for int->pointer
                ; conversions (libc's is _libc_start's).
                STZ     _fcc_dbr
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_dbr
                REP     #$20
                MX      %00
                LDA     #_sig_tramp
                FGX2_FARCALL _libc_start
                JSR     _crt0_inits
                FGX2_FARCALL main                   ; A = exit status (RTL)
                AND     #$00FF
                PHA                                 ; exit(main(...)), as 2.11BSD
                FGX2_FARCALL exit                   ; crt0 does; exit does not return
@cl_safety      BRA     @cl_safety

;------------------------------------------------------------------------------
; _sig_tramp - the kernel delivers signals into segment 0 at the offset
; _libc_start published; JML leaves the delivery frame as it is.
;------------------------------------------------------------------------------
_sig_tramp      FGX2_FARJUMP _libc_sigtramp

;------------------------------------------------------------------------------
; _lib_copy(dst, src, n) - copy n bytes from far pointer src to far pointer
; dst with MVN.  MVN's two bank bytes are immediates in the instruction, so
; the MVN is _lib_copy_cell in this process's data bank (crt0_lib_data.s):
; segment 0 is shared text and is never written (shared libc SP5 spec,
; section 5.1).  DBR is the data bank on entry (crt0_dyn and libc's binder
; both run with it); the cell is reached by a JSL built on the stack, since
; its bank is DBR and not a link-time value.  fcc's far-call convention: the
; first argument nearest, each pointer low word then bank word.  n = 0
; copies nothing (MVN would copy 64 KB).
;------------------------------------------------------------------------------
                FGX2_EXPORT _lib_copy
_lib_copy       MX      %00
                LDA     12,S                    ; n
                BEQ     @lc_none
                DEC
                PHB
                PHA                             ; 1,S = n - 1; arguments up 3
                SEP     #$20
                MX      %10
                LDA     9,S                     ; dst bank
                STA     |_lib_copy_cell+1
                LDA     13,S                    ; src bank
                STA     |_lib_copy_cell+2
                REP     #$20
                MX      %00
                LDA     7,S                     ; dst offset
                TAY
                LDA     11,S                    ; src offset
                TAX
                PLA                             ; n - 1
                PHK
                PEA     @lc_back-1              ; the return a JSL would push
                PHB                             ; the cell's bank: DBR
                PEA     _lib_copy_cell-1
                RTL                             ; JSL _lib_copy_cell
@lc_back        PLB                             ; MVN left DBR = dst
@lc_none        RTL
