;---------------------------------------
; fcc 0.0 — data segment for declinit_ptr.c
;---------------------------------------
                FGX2_MODE 2
_declinit_ptr_FA0       FGX2_LONG_PTR _Fa;f7;0

;-------------------------------
; M7 globals
;-------------------------------
gs1             DS      4
gs2             DS      4
recs            DS      24
gi              DS      2
                FGX2_RELOC_COUNT 2
