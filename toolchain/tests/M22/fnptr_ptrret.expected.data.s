;---------------------------------------
; fcc 0.0 — data segment for fnptr_ptrret.c
;---------------------------------------
                FGX2_MODE 2
_fnptr_ptrret_FA0       FGX2_LONG_PTR _Fa;pick;0

;-------------------------------
; M7 globals
;-------------------------------
buf             DS      4
fp              DS      4
                FGX2_RELOC_COUNT 2
