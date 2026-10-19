;---------------------------------------
; fcc 0.0 — data segment for od_probe3.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
a               DS      14
vec             DS      16
tbl             FGX2_LONG_PTR _Fa;getput;0
                FGX2_RELOC_COUNT 2
