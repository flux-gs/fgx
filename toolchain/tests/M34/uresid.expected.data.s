;---------------------------------------
; fcc 0.0 — data segment for uresid.c
;---------------------------------------
                FGX2_MODE 2
_uresid_FA0       FGX2_LONG_PTR _Fa;mk40k;0
_uresid_FA1       FGX2_LONG_PTR _Fa;mk40k;0

;-------------------------------
; M7 globals
;-------------------------------
gfp             DS      4
gu              DS      2
                FGX2_RELOC_COUNT 3
