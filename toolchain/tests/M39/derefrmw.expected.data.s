;---------------------------------------
; fcc 0.0 — data segment for derefrmw.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT _derefrmw_s
_derefrmw_s     DS      16
_derefrmw_sp    LIBC_DATA_PTR _Spg;_derefrmw_s
_derefrmw_fp    DS      4
_derefrmw_buf   DS      8
                FGX2_RELOC_COUNT 3
