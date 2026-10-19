;---------------------------------------
; fcc 0.0 — data segment for ptr_global_nested_cast_init.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT endarr
endarr          DS      16
bloktop         LIBC_DATA_PTR _Spg;endarr
                FGX2_RELOC_COUNT 3
