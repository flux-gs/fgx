;---------------------------------------
; fcc 0.0 — data segment for fconv_call.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
gi              DA      $0002
gl              DA      $EE90
                DA      $FFFE
gc              DFB     $41
F               DS      4
FN              DS      4
L               DS      4
                FGX2_RELOC_COUNT 1
