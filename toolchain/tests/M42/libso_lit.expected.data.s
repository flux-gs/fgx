;---------------------------------------
; fcc 0.0 — data segment for libso_lit.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT _libc_blk_libso_lit
_libc_blk_libso_lit DA      libso_lit__BT
                FGX2_EXPORT libso_lit__BT
libso_lit__BT          ANOP
                ERR     *-libso_lit__BT-0
_libso_lit_msg  FGX2_LONG_PTR _Sg;_libso_lit_S0;0
                ERR     *-libso_lit__BT-4
_libso_lit_arr  DFB     $61
                DFB     $72
                DFB     $72
                DFB     $2D
                DFB     $69
                DFB     $6E
                DFB     $69
                DFB     $74
                DFB     $00
                FGX2_RELOC_COUNT 4
