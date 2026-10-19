;---------------------------------------
; fcc 0.0 — data segment for statmulti.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
main_sl_a       DA      $0028
main_sl_b       DS      2
main_sl_c       DA      $0002
main_sl_buf     DS      4
main_sl_p       DS      4
main_sl_n       DA      $0064
                DA      $0000
                FGX2_RELOC_COUNT 1
