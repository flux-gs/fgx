;---------------------------------------
; fcc 0.0 — data segment for decay_regress.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
arr             FGX2_LONG_PTR _Sa;_decay_regress_S0;0
                FGX2_LONG_PTR _Sa;_decay_regress_S1;0
                FGX2_LONG_PTR _Sa;_decay_regress_S2;0

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _decay_regress_S0
_decay_regress_S0             HEX     78,00
                FGX2_EXPORT _decay_regress_S1
_decay_regress_S1             HEX     2A,00
                FGX2_EXPORT _decay_regress_S2
_decay_regress_S2             HEX     7A,00
                FGX2_RELOC_COUNT 7
