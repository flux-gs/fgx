;---------------------------------------
; fcc 0.0 — data segment for init_nested.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
a               DA      $0001
                DA      $0002
                DA      $0003
                DA      $0004
                DA      $0005
b               DA      $0001
                DA      $0002
                DA      $0003
                DA      $0004
                DA      $0005
c               DA      $0001
                DA      $0002
                DA      $0000
                DA      $0000
                DA      $0000
g               DA      $0007
                DA      $0001
                DA      $0002
                DA      $0003
                DA      $0004
                DA      $0000
                DA      $0000
                DFB     $61
                DFB     $62
                DFB     $00
                DFB     $00
                DFB     $63
                DFB     $64
                DFB     $65
                DFB     $00
arr             DA      $0001
                DA      $0002
                DA      $0003
                DA      $0004
                DA      $0005
                DA      $0006
                DA      $0007
                DA      $0008
                DA      $0000
                DA      $0000
                FGX2_RELOC_COUNT 1
