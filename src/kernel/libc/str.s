;==============================================================================
; str.s - libc-core string primitives.
;
; All routines operate at DBR = kernel-bank ($02 = assembly ORG only).
; PHP/PLP bracketed; internally MX %00.  Pointers are 16-bit kernel-bank
; offsets passed in X/Y.
;
; Public:
;   Str_Len    (X=ptr)                    -> Y = length excl. null
;==============================================================================

;------------------------------------------------------------------------------
; Str_Len - walk until null; return length.
;------------------------------------------------------------------------------
Str_Len         MX      %00
                PHP
                REP     #$30
                STX     _libcSrcPtr
                LDY     #0
                SEP     #$20
@sl_L           LDA     (_libcSrcPtr),Y
                BEQ     @sl_done
                INY
                BRA     @sl_L
@sl_done        REP     #$20
                PLP
                RTS
