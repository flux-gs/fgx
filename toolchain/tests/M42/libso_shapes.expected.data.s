;---------------------------------------
; fcc 0.0 — data segment for libso_shapes.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT _libc_blk_libso_shapes
_libc_blk_libso_shapes DA      libso_shapes__BT
                FGX2_EXPORT libso_shapes__BT
libso_shapes__BT          ANOP
                ERR     *-libso_shapes__BT-0
_libso_shapes_n DS      2
                ERR     *-libso_shapes__BT-2
_libso_shapes_arr DS      8
                ERR     *-libso_shapes__BT-10
_libso_shapes_p DS      4
                ERR     *-libso_shapes__BT-14
_libso_shapes_big DA      $1170
                DA      $0001
                ERR     *-libso_shapes__BT-18
_libso_shapes_buf DS      8
                ERR     *-libso_shapes__BT-26
_libso_shapes_sbuf DS      4
                ERR     *-libso_shapes__BT-30
_libso_shapes_pt DS      4
                ERR     *-libso_shapes__BT-34
fls_sl_calls    DS      2
                FGX2_RELOC_COUNT 3
