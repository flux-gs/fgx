;---------------------------------------
; fcc 0.0 — data segment for cpa_strlen.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
names           FGX2_LONG_PTR _Sa;_cpa_strlen_S0;0
                FGX2_LONG_PTR _Sa;_cpa_strlen_S1;0
                FGX2_LONG_PTR _Sa;_cpa_strlen_S2;0

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _cpa_strlen_S0
_cpa_strlen_S0             HEX     61,6C,70,68,61,00
                FGX2_EXPORT _cpa_strlen_S1
_cpa_strlen_S1             HEX     62,65,74,61,00
                FGX2_EXPORT _cpa_strlen_S2
_cpa_strlen_S2             HEX     67,61,6D,6D,61,00
                FGX2_RELOC_COUNT 7
