;---------------------------------------
; fcc 0.0 — data segment for struct_init_leaves.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT nv
nv              DS      4
                FGX2_EXPORT nm
nm              DS      4
_struct_init_leaves_zru DA      $0001
                DA      $0000
                DA      $0002
                DA      $0000
                DA      $0003
                DA      $0000
                DA      $0004
                DA      $0000
                DA      $0005
                DA      $0000
                DA      $0006
_struct_init_leaves_part DA      $0007
                DA      $0000
                DA      $0000
                DA      $0000
                DA      $0008
                DA      $0000
                DA      $0000
                DA      $0000
                DA      $0000
                DA      $0000
                DA      $0000
_struct_init_leaves_nulv LIBC_DATA_PTR _Ga;nv
                LIBC_DATA_PTR _Ga;nm
                DA      $0000
                DFB     $00
                DFB     $00
                DA      $0000
                DFB     $00
                DFB     $00
                DA      $0000
                DFB     $00
                DFB     $00
                DA      $0000
                FGX2_RELOC_COUNT 5
