;---------------------------------------
; fcc 0.0 — data segment for sigsown.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
dst             DS      8

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _sigsown_S0
_sigsown_S0             HEX     61,62,00
                FGX2_EXPORT _sigsown_S1
_sigsown_S1             HEX     63,00
                FGX2_RELOC_COUNT 3
