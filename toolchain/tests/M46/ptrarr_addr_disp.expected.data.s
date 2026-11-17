;---------------------------------------
; fcc 0.0 — data segment for ptrarr_addr_disp.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT t
t               DS      10
                FGX2_EXPORT iarr
iarr            DS      10
tp              LIBC_DATA_PTR _Ga;t+4
                LIBC_DATA_PTR _Ga;t
                LIBC_DATA_PTR _Ga;t+2
                LIBC_DATA_PTR _Ga;t+8
ip              LIBC_DATA_PTR _Ga;iarr+6
                LIBC_DATA_PTR _Ga;iarr
                LIBC_DATA_PTR _Ga;iarr+4
                FGX2_RELOC_COUNT 10
