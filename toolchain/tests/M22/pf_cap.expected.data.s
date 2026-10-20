;---------------------------------------
; fcc 0.0 — data segment for pf_cap.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
b1              DS      16
b2              DS      16
b3              DS      16
b4              DS      16

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _pf_cap_S0
_pf_cap_S0             HEX     25,39,44,00
                FGX2_EXPORT _pf_cap_S1
_pf_cap_S1             HEX     25,55,00
                FGX2_EXPORT _pf_cap_S2
_pf_cap_S2             HEX     25,4F,00
                FGX2_EXPORT _pf_cap_S3
_pf_cap_S3             HEX     25,58,00
                FGX2_EXPORT _pf_cap_S4
_pf_cap_S4             HEX     20,20,2D,31,30,30,30,30,30,00
                FGX2_EXPORT _pf_cap_S5
_pf_cap_S5             HEX     37,30,30,30,30,00
                FGX2_EXPORT _pf_cap_S6
_pf_cap_S6             HEX     32,30,30,30,31,30,00
                FGX2_EXPORT _pf_cap_S7
_pf_cap_S7             HEX     42,45,45,46,00
                FGX2_RELOC_COUNT 9
