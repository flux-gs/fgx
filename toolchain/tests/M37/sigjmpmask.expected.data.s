;---------------------------------------
; fcc 0.0 — data segment for sigjmpmask.c
;---------------------------------------
                FGX2_MODE 2
_sigjmpmask_FA0       FGX2_LONG_PTR _Fa;sjm_onint;0

;-------------------------------
; M7 globals
;-------------------------------
sjm_env         DS      48
sjm_hits        DS      2
                FGX2_RELOC_COUNT 2
