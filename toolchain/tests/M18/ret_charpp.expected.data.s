;---------------------------------------
; fcc 0.0 — data segment for ret_charpp.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
tab             DS      8

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _ret_charpp_S0
_ret_charpp_S0             HEX     78,00
                FGX2_EXPORT _ret_charpp_S1
_ret_charpp_S1             HEX     79,7A,00
                FGX2_RELOC_COUNT 3
