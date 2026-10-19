;---------------------------------------
; fcc 0.0 — data segment for libso_shapes3.c
;---------------------------------------
                FGX2_MODE 2
_libso_shapes3_FA8       FGX2_LONG_PTR _Fa;g;0
_libso_shapes3_FA9       FGX2_LONG_PTR _Fa;g;0

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT _libc_blk_libso_shapes3
_libc_blk_libso_shapes3 DA      libso_shapes3__BT
                FGX2_EXPORT libso_shapes3__BT
libso_shapes3__BT          ANOP
                ERR     *-libso_shapes3__BT-0
_libso_shapes3_n DS      2
                ERR     *-libso_shapes3__BT-2
_libso_shapes3_p DS      4
                ERR     *-libso_shapes3__BT-6
_libso_shapes3_tab DS      8
                ERR     *-libso_shapes3__BT-14
_libso_shapes3_fp DS      4
                FGX2_RELOC_COUNT 5
