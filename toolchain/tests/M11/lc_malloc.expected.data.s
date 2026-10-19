;---------------------------------------
; fcc 0.0 — data segment for lc_malloc.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _lc_malloc_S0
_lc_malloc_S0             HEX     61,6C,6C,6F,63,20,66,61,69,6C,20,70,0A,00
                FGX2_EXPORT _lc_malloc_S1
_lc_malloc_S1             HEX     61,6C,6C,6F,63,20,66,61,69,6C,20,71,0A,00
                FGX2_EXPORT _lc_malloc_S2
_lc_malloc_S2             HEX     63,6C,6F,62,62,65,72,65,64,20,61,3D,25,64,20,62,3D,25,64,0A,00
                FGX2_EXPORT _lc_malloc_S3
_lc_malloc_S3             HEX     70,3D,25,73,20,71,3D,25,73,20,61,3D,25,64,20,62,3D,25,64,0A,00
                FGX2_EXPORT _lc_malloc_S4
_lc_malloc_S4             HEX     66,72,65,65,20,6F,6B,0A,00
                FGX2_RELOC_COUNT 6
