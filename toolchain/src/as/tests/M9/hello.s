;==============================================================================
; hello.s - first fas-built FGX1 binary.
;
; Hand-written 65816 assembly that fas v0 assembles into a ProDOS
; flat binary loadable as /BIN/HELLO on FGX.  Does NOT use crt0,
; libc, or args — pure SYS_TRAMP syscalls so we exercise just the
; instruction encodings fas owns through M0-M8.
;
; Behavior: prints "hi" + CR to stdout (fd=1), exits 0.  Uses CR
; ($0D) not LF ($0A) because the FGX console honours CR as a
; newline and silently drops LF (userland that doesn't go through
; libc pf_emit's LF→CR translation must emit CR directly).
;
; Syscall ABI (FGX kernel):
;   JSL SYS_TRAMP / DFB <num>
;   SYS_WRITE: A=fd, X=ptr (own bank), Y=len.   Returns C=1+A=len ok.
;   SYS_EXIT:  A.lo=status.                     Never returns.
;==============================================================================

                MX      %11
                ORG     $0B0000

SYS_EXIT        EQU     1
SYS_WRITE       EQU     4
SYS_TRAMP       EQU     $000328

;------------------------------------------------------------------------------
; FGX1 header — 16 bytes, parsed by the loader.
;------------------------------------------------------------------------------
hello_hdr       ASC     'FGX1'
                DFB     <$0B0000                ; load addr lo
                DFB     >$0B0000                ; load addr mid
                DFB     ^$0B0000                ; load addr bank
                DFB     $00
                DA      hello_entry-$0B0000     ; entry offset
                DA      hello_end-hello_text    ; text size
                DA      0                       ; data size (none)
                DFB     $00
                DFB     $00

hello_text      EQU     *

;------------------------------------------------------------------------------
; Entry.  Loader leaves us in native mode, MX %11, DBR = bank from the
; resume frame.  Set DBR = own bank explicitly via PHK/PLB so own-bank
; absolute references resolve correctly, then widen to MX %00 for the
; 16-bit immediates SYS_WRITE expects.
;------------------------------------------------------------------------------
hello_entry     PHK
                PLB
                REP     #$30
                MX      %00

                LDA     #1                      ; A = fd 1 (stdout)
                LDX     #msg                    ; X = own-bank ptr to msg
                LDY     #3                      ; Y = 3 bytes ("hi" + CR)
                JSL     SYS_TRAMP
                DFB     SYS_WRITE

                LDA     #0                      ; status = 0
                JSL     SYS_TRAMP
                DFB     SYS_EXIT
                ; SYS_EXIT never returns — but pad with BRK so a
                ; runaway PC traps loudly.
                BRK

;------------------------------------------------------------------------------
; Data.
;------------------------------------------------------------------------------
msg             ASC     'hi'
                DFB     $0D                     ; CR — FGX console
                                                ; treats this as newline

hello_end       EQU     *
