;---------------------------------------
; fcc 0.0 — data segment for od_probe.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
gs              DS      6
gbuf            DS      4
tbl             FGX2_LONG_PTR _Fa;f2;0
                FGX2_RELOC_COUNT 2
