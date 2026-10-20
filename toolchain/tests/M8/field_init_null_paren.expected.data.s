;---------------------------------------
; fcc 0.0 — data segment for field_init_null_paren.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT nm
nm              DFB     $2A
                DFB     $78
                DFB     $00
node            DA      $0000
                DFB     $00
                DFB     $00
                DA      $0000
                DFB     $00
                DFB     $00
                LIBC_DATA_PTR _Ga;nm
                FGX2_RELOC_COUNT 3
