;---------------------------------------
; fcc 0.0 — data segment for global_ptr_init.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT arr
arr             DS      8
p               LIBC_DATA_PTR _Spg;arr
                FGX2_EXPORT second
second          DS      2
q               LIBC_DATA_PTR _Spg;second
                FGX2_RELOC_COUNT 5
