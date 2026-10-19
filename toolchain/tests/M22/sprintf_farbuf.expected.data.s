;---------------------------------------
; fcc 0.0 — data segment for sprintf_farbuf.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _sprintf_farbuf_S0
_sprintf_farbuf_S0             HEX     25,64,00
                FGX2_EXPORT _sprintf_farbuf_S1
_sprintf_farbuf_S1             HEX     34,32,34,32,00
                FGX2_RELOC_COUNT 3
