;---------------------------------------
; fcc 0.0 — data segment for od_probe4.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
a               DS      14
vec             DS      16
data            DS      2
tbl             FGX2_LONG_PTR _Fa;put1;0
                FGX2_RELOC_COUNT 2
