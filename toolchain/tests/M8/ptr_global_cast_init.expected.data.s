;---------------------------------------
; fcc 0.0 — data segment for ptr_global_cast_init.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT table
table           DS      8
bp              LIBC_DATA_PTR _Spg;table
                FGX2_RELOC_COUNT 3
