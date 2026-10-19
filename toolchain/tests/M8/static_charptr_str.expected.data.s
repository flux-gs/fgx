;---------------------------------------
; fcc 0.0 — data segment for static_charptr_str.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
main_sl_fmts    FGX2_LONG_PTR _Sg;_static_charptr_str_S0;0
main_sl_fmtd    FGX2_LONG_PTR _Sg;_static_charptr_str_S1;0
main_sl_emsg    FGX2_LONG_PTR _Sg;_static_charptr_str_S2;0

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _static_charptr_str_S0
_static_charptr_str_S0             HEX     25,73,0A,00
                FGX2_EXPORT _static_charptr_str_S1
_static_charptr_str_S1             HEX     25,64,0A,00
                FGX2_EXPORT _static_charptr_str_S2
_static_charptr_str_S2             HEX     61,62,63,64,65,66,67,68,69,6A,00
                FGX2_RELOC_COUNT 7
