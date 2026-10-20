;---------------------------------------
; fcc 0.0 — data segment for sigdbr.c
;---------------------------------------
                FGX2_MODE 2
_sigdbr_FA1       FGX2_LONG_PTR _Fa;sig_handler;0

;-------------------------------
; M7 globals
;-------------------------------
sig_flag        DA      $0000
                FGX2_RELOC_COUNT 2
