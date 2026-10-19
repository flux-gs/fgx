;---------------------------------------
; fcc 0.0 — data segment for libso_shapes2.c
;---------------------------------------
                FGX2_MODE 2
_libso_shapes2_FA0       FGX2_LONG_PTR _Fa;g;0

;-------------------------------
; M7 globals
;-------------------------------
x               DA      $000B
                FGX2_EXPORT _libc_blk_libso_shapes2
_libc_blk_libso_shapes2 DA      libso_shapes2__BT
                FGX2_EXPORT libso_shapes2__BT
libso_shapes2__BT          ANOP
                ERR     *-libso_shapes2__BT-0
_libso_shapes2_fp DS      4
                ERR     *-libso_shapes2__BT-4
_libso_shapes2_arr DS      8
                ERR     *-libso_shapes2__BT-12
_libso_shapes2_ll DS      8
                ERR     *-libso_shapes2__BT-20
_libso_shapes2_v DS      6
                ERR     *-libso_shapes2__BT-26
_libso_shapes2_m DS      12
                ERR     *-libso_shapes2__BT-38
_libso_shapes2_d DS      8
                ERR     *-libso_shapes2__BT-46
_libso_shapes2_q DS      8
                ERR     *-libso_shapes2__BT-54
_libso_shapes2_ptrs DS      8
                ERR     *-libso_shapes2__BT-62
_libso_shapes2_c DS      1
                ERR     *-libso_shapes2__BT-63
_libso_shapes2_n DS      2
                FGX2_RELOC_COUNT 4
