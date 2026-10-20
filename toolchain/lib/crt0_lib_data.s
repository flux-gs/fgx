;==============================================================================
; crt0_lib_data.s - crt0_lib.s's data, in the data segment of every program
; that starts through crt0_lib (fgx_dyn's and fgx_static's links).
;
; _lib_copy's MVN: its bank bytes are written per call, so it lives in the
; process's data bank, never in shared code.  At $0100 or above, behind the
; data segment's 256-byte pad, so no operand naming it is direct-page.
;==============================================================================
                FGX2_EXPORT _lib_copy_cell
_lib_copy_cell  DFB     $54,$00,$00             ; MVN: opcode, dst bank, src bank
                DFB     $6B                     ; RTL
