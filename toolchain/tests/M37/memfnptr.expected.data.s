;---------------------------------------
; fcc 0.0 — data segment for memfnptr.c
;---------------------------------------
                FGX2_MODE 2
_memfnptr_FA0       FGX2_LONG_PTR _Fa;add3;0
_memfnptr_FA1       FGX2_LONG_PTR _Fa;dbl;0
_memfnptr_FA2       FGX2_LONG_PTR _Fa;setside;0

;-------------------------------
; M7 globals
;-------------------------------
g_side          DS      2
g_in            DS      6
g_o             DS      8
g_e             DS      4
                FGX2_RELOC_COUNT 4
