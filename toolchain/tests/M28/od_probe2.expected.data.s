;---------------------------------------
; fcc 0.0 — data segment for od_probe2.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
gs              DS      6
g_result        DS      2
tbl             FGX2_LONG_PTR _Fa;f2;0
                FGX2_RELOC_COUNT 2
