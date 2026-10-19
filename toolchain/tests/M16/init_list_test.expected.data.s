;---------------------------------------
; fcc 0.0 — data segment for init_list_test.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
g_explicit      DA      $0007
                DA      $000E
                DA      $0015
                DA      $0000
                DA      $0000
g_inferred      DA      $000A
                DA      $0014
                DA      $000C
g_negs          DA      $FFFF
                DA      $FFFE
                DA      $0008
                FGX2_RELOC_COUNT 1
