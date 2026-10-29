;---------------------------------------
; fcc 0.0 — data segment for fnptr_ptr.c
;---------------------------------------
                FGX2_MODE 2
_fnptr_ptr_FA37       FGX2_LONG_PTR _Fa;add;0
_fnptr_ptr_FA38       FGX2_LONG_PTR _Fa;dbl;0

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT t
t               FGX2_LONG_PTR _Fa;add;0
                FGX2_LONG_PTR _Fa;dbl;0
                FGX2_LONG_PTR _Fa;neg;0
gpp             DS      4
gi              LIBC_DATA_PTR _Spg;t+4
o               DS      6
op              DS      4
                FGX2_RELOC_COUNT 8
