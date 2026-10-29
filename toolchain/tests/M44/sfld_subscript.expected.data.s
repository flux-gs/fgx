;---------------------------------------
; fcc 0.0 — data segment for sfld_subscript.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT g
g               DA      $0000
                DFB     $61
                DFB     $62
                DFB     $63
                DFB     $64
                DFB     $65
                DFB     $66
                DFB     $67
                DFB     $00
                DA      $0000
                DA      $0001
                DA      $0000
                DA      $0002
                DA      $0000
                DA      $0028
r               LIBC_DATA_PTR _Ga;g+4
                LIBC_DATA_PTR _Ga;g+20
                FGX2_RELOC_COUNT 4
