;---------------------------------------
; fcc 0.0 — data segment for m2d_field.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT F
F               DS      28
pf              LIBC_DATA_PTR _Spg;F
                FGX2_RELOC_COUNT 3
