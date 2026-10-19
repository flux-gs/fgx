;---------------------------------------
; fcc 0.0 — data segment for fnptr_drift.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
tbl             FGX2_LONG_PTR _Fa;add_a;0
                DA      $0001
                FGX2_LONG_PTR _Fa;add_b;0
                DA      $0002
                FGX2_LONG_PTR _Fa;add_c;0
                DA      $0003
                FGX2_RELOC_COUNT 4
