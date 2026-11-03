;---------------------------------------
; fcc 0.0 — data segment for spec_order.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
_spec_order_gs  DA      $0003
gc              DFB     $61
                DFB     $62
                DFB     $00
                DFB     $00
bump_sl_n       DA      $0001
                FGX2_RELOC_COUNT 1
