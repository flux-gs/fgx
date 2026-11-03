;---------------------------------------
; fcc 0.0 — data segment for field_ptr_disp.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT tab
tab             DFB     $01
                DFB     $02
                DFB     $03
                DFB     $04
                DFB     $05
                DFB     $06
                DFB     $07
                DFB     $08
                FGX2_EXPORT iarr
iarr            DA      $000A
                DA      $0014
                DA      $001E
                DA      $0028
f               LIBC_DATA_PTR _Ga;tab+3
                LIBC_DATA_PTR _Ga;iarr+4
                LIBC_DATA_PTR _Ga;tab+5
                DA      $0009
                FGX2_RELOC_COUNT 6
