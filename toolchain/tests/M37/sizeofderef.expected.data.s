;---------------------------------------
; fcc 0.0 — data segment for sizeofderef.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT c
c               DS      1
                FGX2_EXPORT cp
cp              LIBC_DATA_PTR _Spg;c
pp              LIBC_DATA_PTR _Spg;cp
                FGX2_EXPORT iv
iv              DS      2
ip              LIBC_DATA_PTR _Spg;iv
                FGX2_RELOC_COUNT 7
