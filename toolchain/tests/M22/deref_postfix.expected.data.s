;---------------------------------------
; fcc 0.0 — data segment for deref_postfix.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
g0              FGX2_LONG_PTR _Sg;_deref_postfix_S0;0
g1              FGX2_LONG_PTR _Sg;_deref_postfix_S1;0
tab             DS      8

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _deref_postfix_S0
_deref_postfix_S0             HEX     41,78,00
                FGX2_EXPORT _deref_postfix_S1
_deref_postfix_S1             HEX     42,78,00
                FGX2_RELOC_COUNT 5
