;---------------------------------------
; fcc 0.0 — data segment for ampderef.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT row
row             DFB     $68
                DFB     $65
                DFB     $6C
                DFB     $6C
                DFB     $6F
                DFB     $00
                FGX2_EXPORT rp
rp              LIBC_DATA_PTR _Spg;row
pp              LIBC_DATA_PTR _Spg;rp
                FGX2_EXPORT arr
arr             DS      18
                FGX2_EXPORT sp
sp              LIBC_DATA_PTR _Spg;arr
spp             LIBC_DATA_PTR _Spg;sp
                FGX2_RELOC_COUNT 9
