;---------------------------------------
; fcc 0.0 — data segment for sed_addrof.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT tbl
tbl             DS      48
p               LIBC_DATA_PTR _Spg;tbl
                FGX2_EXPORT strs
strs            DS      12
gpp             LIBC_DATA_PTR _Spg;strs
                FGX2_RELOC_COUNT 5
