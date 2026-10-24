;---------------------------------------
; fcc 0.0 — data segment for charpack.c
;---------------------------------------
                FGX2_MODE 2
_charpack_FA16       FGX2_LONG_PTR _Fa;fret;0

;-------------------------------
; M7 globals
;-------------------------------
garr            DS      6
gcc             DFB     $0B
                DFB     $16
gb              DS      8
                FGX2_RELOC_COUNT 2
