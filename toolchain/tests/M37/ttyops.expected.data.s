;---------------------------------------
; fcc 0.0 — data segment for ttyops.c
;---------------------------------------
                FGX2_MODE 2
_ttyops_FA4       FGX2_LONG_PTR _Fa;onint;0

;-------------------------------
; M7 globals
;-------------------------------
sgbuf           DS      8
hits            DS      2
                FGX2_RELOC_COUNT 2
