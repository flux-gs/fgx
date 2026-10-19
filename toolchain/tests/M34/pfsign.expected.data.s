;---------------------------------------
; fcc 0.0 — data segment for pfsign.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
buf             DS      16

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _pfsign_S0
_pfsign_S0             HEX     25,36,64,00
                FGX2_EXPORT _pfsign_S1
_pfsign_S1             HEX     25,30,36,64,00
                FGX2_EXPORT _pfsign_S2
_pfsign_S2             HEX     25,2D,36,64,58,00
                FGX2_EXPORT _pfsign_S3
_pfsign_S3             HEX     25,38,6C,64,00
                FGX2_RELOC_COUNT 5
