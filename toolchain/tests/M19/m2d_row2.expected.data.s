;---------------------------------------
; fcc 0.0 — data segment for m2d_row2.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT F
F               DS      28
                FGX2_EXPORT FA
FA              DS      56
pf              LIBC_DATA_PTR _Spg;F
pfa             LIBC_DATA_PTR _Spg;FA
                FGX2_EXPORT S3
S3              DS      20
ps3             LIBC_DATA_PTR _Spg;S3
                FGX2_EXPORT H
H               DS      4
ph              LIBC_DATA_PTR _Spg;H
                FGX2_RELOC_COUNT 9
