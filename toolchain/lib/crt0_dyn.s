;==============================================================================
; crt0_dyn.s - the startup of a dynamic program (fgx_dyn): it binds the
; program to its shared libraries on the machine, then continues as
; crt0_lib.s.  crt0 ACQUIREs libc from the registry (READY or nothing:
; "ld.so: libc.so.1 not loaded"), copies libc's core into this data bank
; with its own MVN copier (_lib_copy), and calls libc's binder through the
; row's entry with the kernel's argv frame, the binder's tables, the copier
; and libc's row.  fgx_dyn puts the binder's tables at the tail of the code
; segment with the most room and writes where into _dyn_tab: their offset,
; and a bank byte the loader relocates.
; Entry (the loader's JML): native, MX %11, DBR = the data bank, the
; kernel's argv frame on the stack -- and S is back there before
; _crt0_lib, whose _libc_start finds it at a fixed depth.
;==============================================================================
; The registry's block as crt0 reads it.  toolchain/include/sys/ldctl.h is
; the layout; src/modules/ld/ld.s carries the same offsets, and the host
; test test_dyn.py holds these three copies equal.
LDS_ACQUIRE     EQU     0
LDS_ABORT       EQU     3
B_MAJOR         EQU     16
B_NBANKS        EQU     23
B_BANKS         EQU     24
B_COREBASE      EQU     32
B_CORESIZE      EQU     34
B_TMPL          EQU     36
B_BINDER        EQU     42

                FGX2_EXPORT _crt0_dyn
_crt0_dyn       MX      %11
                REP     #$30
                MX      %00
                TSC
                INC
                PHA                             ; 1,S = the kernel's argv frame
                ; Nothing on the binder's path takes a soft frame (no
                ; recursion), so _fcc_sfp waits for crt0_lib.s.
                ; ACQUIRE libc 1.  READY is the only answer that goes on.
                LDX     #48
@cd_zero        STZ     _dyn_blk,X
                DEX
                DEX
                BPL     @cd_zero
                SEP     #$20
                MX      %10
                LDA     #'l'
                STA     _dyn_blk
                LDA     #'i'
                STA     _dyn_blk+1
                LDA     #'b'
                STA     _dyn_blk+2
                LDA     #'c'
                STA     _dyn_blk+3
                LDA     #1
                STA     _dyn_blk+B_MAJOR
                PHB
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                TAY                             ; Y = the block's bank, this data bank
                LDX     #_dyn_blk
                LDA     #LDS_ACQUIRE
                JSL     SYS_TRAMP
                DFB     SYS_LDCTL
                BCS     @cd_ok
                JMP     @cd_nolibc              ; ENOSYS, EINTR: not usable
@cd_ok          MX      %00
                CMP     #0
                BEQ     @cd_ready
                JMP     @cd_absent              ; 1: nobody has loaded libc
@cd_ready       MX      %00
                LDA     _dyn_blk+B_BINDER
                ORA     _dyn_blk+B_BINDER+1
                BNE     @cd_bind
                JMP     @cd_nolibc              ; a libc with no binder
@cd_bind        MX      %00
                ; libc's core into this data bank: _lib_copy(dst, src, n).
                LDA     _dyn_blk+B_CORESIZE
                PHA                             ; n
                LDA     _dyn_blk+B_NBANKS
                AND     #$00FF
                DEC
                TAX
                LDA     _dyn_blk+B_BANKS,X      ; the last bank, low byte
                AND     #$00FF
                PHA                             ; src's bank word
                LDA     _dyn_blk+B_TMPL
                PHA                             ; src's offset
                SEP     #$20
                MX      %10
                PHB
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                PHA                             ; dst's bank word
                LDA     _dyn_blk+B_COREBASE
                PHA                             ; dst's offset
                FGX2_FARCALL _lib_copy
                TSC
                CLC
                ADC     #10
                TCS
                ; The binder: _ld_bind(frame, tab, copy, blk), through the row.
                ; blk is libc's row as ACQUIRE left it, so the binder needs
                ; no syscall for libc.
                SEP     #$20
                MX      %10
                PHB
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                PHA                             ; blk's bank word: this data bank
                PEA     _dyn_blk                ; blk
                SEP     #$20
                MX      %10
                PHK
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                PHA                             ; copy's bank word
                PEA     _lib_copy               ; copy
                ; The tables' far pointer, from _dyn_tab: the offset fgx_dyn
                ; wrote and the bank the loader relocated (SP5 spec 4.1).  It
                ; is in this bank, so read it with DBR = this bank.
                PHB
                PHK
                PLB
                LDA     |_dyn_tab+2             ; bank in the low byte
                AND     #$00FF
                TAX
                LDA     |_dyn_tab               ; offset
                PLB
                PHX                             ; tab's bank word
                PHA                             ; tab
                LDA     13,S                    ; the frame slot, under 12 bytes
                PHA                             ; frame
                PHK
                PEA     @cd_back-1              ; the return a JSL would push
                SEP     #$20
                MX      %10
                LDA     _dyn_blk+B_BINDER+2
                PHA
                REP     #$20
                MX      %00
                LDA     _dyn_blk+B_BINDER
                DEC
                PHA
                RTL                             ; JSL [binder]
@cd_back        MX      %00
                TSC
                CLC
                ADC     #16                     ; 14 bytes of arguments, the frame slot
                TCS
                JMP     _crt0_lib
@cd_absent      MX      %00
                LDX     #_dyn_blk
                SEP     #$20
                MX      %10
                PHB
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                TAY
                LDA     #LDS_ABORT
                JSL     SYS_TRAMP
                DFB     SYS_LDCTL
@cd_nolibc      MX      %00
                LDA     #2
                LDX     #_dyn_nolibc
                LDY     #28
                JSL     SYS_TRAMP
                DFB     SYS_WRITE
                LDA     #1
                JSL     SYS_TRAMP
                DFB     SYS_EXIT
@cd_stop        BRA     @cd_stop

                FGX2_EXPORT _dyn_tab
_dyn_tab        DA      $0000                   ; the tables' offset (fgx_dyn)
                DFB     $00                     ; their bank (the loader)
                DFB     $00
