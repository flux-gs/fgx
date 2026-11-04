;---------------------------------------
; fcc 0.0 — data segment for blk_extern_struct.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
cmdtab          FGX2_LONG_PTR _Sa;_blk_extern_struct_S0;0
                DA      $0001
                FGX2_LONG_PTR _Sa;_blk_extern_struct_S1;0
                DA      $0002
                FGX2_LONG_PTR _Sa;_blk_extern_struct_S2;0
                DA      $001E
                FGX2_LONG_PTR _Sa;_blk_extern_struct_S3;0
                DA      $000C

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _blk_extern_struct_S0
_blk_extern_struct_S0             HEX     61,00
                FGX2_EXPORT _blk_extern_struct_S1
_blk_extern_struct_S1             HEX     62,00
                FGX2_EXPORT _blk_extern_struct_S2
_blk_extern_struct_S2             HEX     63,00
                FGX2_EXPORT _blk_extern_struct_S3
_blk_extern_struct_S3             HEX     64,00
                FGX2_RELOC_COUNT 9
