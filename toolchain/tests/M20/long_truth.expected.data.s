;---------------------------------------
; fcc 0.0 — data segment for long_truth.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
lt_hi           DA      $0000
                DA      $0001
lt_zero         DA      $0000
                DA      $0000
lt_lo           DA      $002A
                DA      $0000
lt_negzero      DA      $0000
                DA      $0000
                DA      $0000
                DA      $8000
lt_fone         DA      $0000
                DA      $0000
                DA      $0000
                DA      $3FF0
                FGX2_RELOC_COUNT 1
