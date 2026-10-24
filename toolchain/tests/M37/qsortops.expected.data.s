;---------------------------------------
; fcc 0.0 — data segment for qsortops.c
;---------------------------------------
                FGX2_MODE 2
_qsortops_FA0       FGX2_LONG_PTR _Fa;icmp;0
_qsortops_FA8       FGX2_LONG_PTR _Fa;scmp;0
_qsortops_FA10       FGX2_LONG_PTR _Fa;rcmp;0

;-------------------------------
; M7 globals
;-------------------------------
iv              DS      14
rv              DS      16
                FGX2_RELOC_COUNT 4
