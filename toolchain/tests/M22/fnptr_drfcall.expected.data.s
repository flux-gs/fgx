;---------------------------------------
; fcc 0.0 — data segment for fnptr_drfcall.c
;---------------------------------------
                FGX2_MODE 2
_fnptr_drfcall_FA0       FGX2_LONG_PTR _Fa;add3;0
_fnptr_drfcall_FA1       FGX2_LONG_PTR _Fa;add3;0

;-------------------------------
; M7 globals
;-------------------------------
gdisp           DS      4
ggp             DS      4
gfp             DS      4
one             DFB     $01
                FGX2_RELOC_COUNT 3
