;---------------------------------------
; fcc 0.0 — data segment for tar_ctor.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
blk             DS      16
                FGX2_EXPORT a1
a1              DA      $000A
                DA      $0014
                FGX2_EXPORT a2
a2              DA      $001E
                DA      $0028
m               LIBC_DATA_PTR _Ga;a1
                LIBC_DATA_PTR _Ga;a2

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _tar_ctor_S0
_tar_ctor_S0             HEX     61,00
                FGX2_EXPORT _tar_ctor_S1
_tar_ctor_S1             HEX     62,00
                FGX2_EXPORT _tar_ctor_S2
_tar_ctor_S2             HEX     63,00
                FGX2_EXPORT _tar_ctor_S3
_tar_ctor_S3             HEX     64,00
                FGX2_RELOC_COUNT 9
