;---------------------------------------
; fcc 0.0 — data segment for signed_char.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
c               DFB     $F0
u               DFB     $F0
buf             DFB     $80
                DFB     $00
                FGX2_RELOC_COUNT 1
