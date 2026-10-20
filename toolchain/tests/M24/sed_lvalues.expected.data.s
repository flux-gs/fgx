;---------------------------------------
; fcc 0.0 — data segment for sed_lvalues.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
buf             DS      16
rub             DFB     $03
                DFB     $00
ptrarr          DS      16
L               DS      12
                FGX2_RELOC_COUNT 1
