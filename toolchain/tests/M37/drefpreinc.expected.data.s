;---------------------------------------
; fcc 0.0 — data segment for drefpreinc.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
buf             DFB     $41
                DFB     $42
                DFB     $43
                DFB     $00
rp              DS      4
pp              DS      4
                FGX2_RELOC_COUNT 1
