;---------------------------------------
; fcc 0.0 — data segment for struct_array_elide.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
a               FGX2_LONG_PTR _Sa;_struct_array_elide_S0;0
                DA      $0001
                DA      $000A
                FGX2_LONG_PTR _Sa;_struct_array_elide_S1;0
                DA      $0000
                DA      $0000
                FGX2_LONG_PTR _Sa;_struct_array_elide_S2;0
                DA      $0000
                DA      $0000
b               FGX2_LONG_PTR _Sa;_struct_array_elide_S3;0
                DA      $0001
                DA      $0002
                FGX2_LONG_PTR _Sa;_struct_array_elide_S4;0
                DA      $0003
                DA      $0004
                FGX2_LONG_PTR _Sa;_struct_array_elide_S5;0
                DA      $0005
                DA      $0006

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _struct_array_elide_S0
_struct_array_elide_S0             HEX     6F,6E,65,00
                FGX2_EXPORT _struct_array_elide_S1
_struct_array_elide_S1             HEX     74,77,6F,00
                FGX2_EXPORT _struct_array_elide_S2
_struct_array_elide_S2             HEX     00
                FGX2_EXPORT _struct_array_elide_S3
_struct_array_elide_S3             HEX     78,00
                FGX2_EXPORT _struct_array_elide_S4
_struct_array_elide_S4             HEX     79,00
                FGX2_EXPORT _struct_array_elide_S5
_struct_array_elide_S5             HEX     7A,00
                FGX2_RELOC_COUNT 13
