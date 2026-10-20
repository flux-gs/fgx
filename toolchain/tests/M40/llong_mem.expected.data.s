;---------------------------------------
; fcc 0.0 — data segment for llong_mem.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
gs              DS      12
g               DS      8
garr            DS      24
p               DS      4
n               DA      $0001
gi1             DA      $CDEF
                DA      $89AB
                DA      $4567
                DA      $0123
gi2             DA      $FFFE
                DA      $FFFF
                DA      $FFFF
                DA      $FFFF
                FGX2_EXPORT gi3
gi3             DA      $0001
                DA      $0000
                DA      $0000
                DA      $0000
                DA      $FFFF
                DA      $FFFF
                DA      $FFFF
                DA      $FFFF
                DA      $0000
                DA      $0000
                DA      $0001
                DA      $0000
                DA      $0000
                DA      $0000
                DA      $0000
                DA      $0000
gi4             DA      $F200
                DA      $2A05
                DA      $0001
                DA      $0000
gsi             DA      $0007
                DA      $7788
                DA      $5566
                DA      $3344
                DA      $1122
                DA      $0009
gip             LIBC_DATA_PTR _Spg;gi3+16
main_sl_sl      DA      $FFFB
                DA      $FFFF
                DA      $FFFF
                DA      $FFFF
                FGX2_RELOC_COUNT 3
