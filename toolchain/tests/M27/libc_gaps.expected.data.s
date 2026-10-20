;---------------------------------------
; fcc 0.0 — data segment for libc_gaps.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _libc_gaps_S0
_libc_gaps_S0             HEX     68,65,6C,6C,6F,20,77,6F,72,6C,64,00
                FGX2_EXPORT _libc_gaps_S1
_libc_gaps_S1             HEX     5A,0A,00
                FGX2_RELOC_COUNT 3
