;---------------------------------------
; fcc 0.0 — data segment for vnodepool.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
speclisth       DS      32
_vnodepool_nslept DA      $0000
_vnodepool_nvxsleeps DA      $0000
_vnodepool_invalbufs DA      $0000
_vnodepool_nlock DA      $0000
_vnodepool_nunlock DA      $0000
_vnodepool_ninactive DA      $0000
_vnodepool_nreclaim DA      $0000
_vnodepool_nclose DA      $0000
fakeops         FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_close;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_inactive;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_reclaim;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_lock;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_unlock;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
dead_vnodeops   FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
spec_vnodeops   FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
                FGX2_LONG_PTR _Fa;_vnodepool_op_nop;0
_vnodepool_vfs_cacheops DS      4
_vnodepool_vfs_specops DS      4
vnode_pool      DS      4
vnode_free_head DS      4
vnode_free_tail DS      4
numvnodes       DS      2
freevnodes      DS      2
specinfo_pool   DS      4
securelevel     DA      $0000
nd_pool         DS      4
nd_bufs         DS      4
vnode_next_id   DS      4
namecache_pool  DS      4
nchashtbl       DS      128
nchhead         DS      4
nchtail         DS      4
nchstats        DS      32
doingcache      DA      $0001
ufs_cacheops    FGX2_LONG_PTR _Fa;cache_purge;0
                FGX2_LONG_PTR _Fa;cache_purgevfs;0
_vnodepool_vn_arena DS      11392
_vnodepool_nc_arena DS      4096
mnt_a           DS      130
mnt_b           DS      130

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _vnodepool_S0
_vnodepool_S0             HEX     67,65,74,6E,65,77,76,6E,6F,64,65,3A,20,66,72,65,65,20,76,6E,6F,64,65,20,69,73,6E,27,74,00
                FGX2_EXPORT _vnodepool_S1
_vnodepool_S1             HEX     76,72,65,66,3A,20,7A,65,72,6F,20,75,73,65,63,6F,75,6E,74,00
                FGX2_EXPORT _vnodepool_S2
_vnodepool_S2             HEX     76,72,65,6C,65,3A,20,7A,65,72,6F,20,75,73,65,63,6F,75,6E,74,00
                FGX2_EXPORT _vnodepool_S3
_vnodepool_S3             HEX     68,6F,6C,64,72,65,6C,65,3A,20,7A,65,72,6F,20,68,6F,6C,64,63,6E,74,00
                FGX2_EXPORT _vnodepool_S4
_vnodepool_S4             HEX     63,68,65,63,6B,61,6C,69,61,73,3A,20,6F,75,74,20,6F,66,20,73,70,65,63,69,6E,66,6F,00
                FGX2_EXPORT _vnodepool_S5
_vnodepool_S5             HEX     76,63,6C,65,61,6E,3A,20,64,65,61,64,6C,6F,63,6B,00
                FGX2_EXPORT _vnodepool_S6
_vnodepool_S6             HEX     76,63,6C,65,61,6E,3A,20,63,61,6E,6E,6F,74,20,72,65,63,6C,61,69,6D,00
                FGX2_EXPORT _vnodepool_S7
_vnodepool_S7             HEX     76,67,6F,6E,65,3A,20,64,65,76,69,63,65,20,76,6E,6F,64,65,20,77,69,74,68,20,6E,6F,20,73,70,65,63,69,6E,66,6F,00
                FGX2_EXPORT _vnodepool_S8
_vnodepool_S8             HEX     76,67,6F,6E,65,3A,20,6D,69,73,73,69,6E,67,20,62,64,65,76,00
                FGX2_EXPORT _vnodepool_S9
_vnodepool_S9             HEX     76,67,6F,6E,65,3A,20,6D,69,73,73,69,6E,67,20,61,6C,69,61,73,00
                FGX2_EXPORT _vnodepool_S10
_vnodepool_S10            HEX     76,66,6C,75,73,68,3A,20,6E,6F,74,20,62,75,73,79,00
                FGX2_RELOC_COUNT 110
