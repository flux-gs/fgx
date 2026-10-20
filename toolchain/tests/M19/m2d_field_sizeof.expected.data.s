;---------------------------------------
; fcc 0.0 — data segment for m2d_field_sizeof.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT O
O               DS      32
pO              LIBC_DATA_PTR _Spg;O
                FGX2_RELOC_COUNT 3
