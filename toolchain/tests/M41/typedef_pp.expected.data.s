;---------------------------------------
; fcc 0.0 — data segment for typedef_pp.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT s
s               DFB     $2A
                DFB     $00
sp              LIBC_DATA_PTR _Spg;s
lv              DA      $002A
                DA      $0000
                FGX2_RELOC_COUNT 3
