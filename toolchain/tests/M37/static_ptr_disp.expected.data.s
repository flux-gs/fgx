;---------------------------------------
; fcc 0.0 — data segment for static_ptr_disp.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT arr
arr             DS      16
                FGX2_EXPORT iarr
iarr            DS      16
                FGX2_EXPORT obj
obj             DS      4
cp              LIBC_DATA_PTR _Spg;arr+14
ip              LIBC_DATA_PTR _Spg;iarr+4
mp              LIBC_DATA_PTR _Spg;obj+2
ap              LIBC_DATA_PTR _Spg;iarr+4
op              LIBC_DATA_PTR _Spg;obj
                FGX2_RELOC_COUNT 9
