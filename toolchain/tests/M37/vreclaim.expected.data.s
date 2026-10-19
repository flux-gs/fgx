;---------------------------------------
; fcc 0.0 — data segment for vreclaim.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
speclisth       DS      32
_vreclaim_nslept DA      $0000
_vreclaim_fake_disk DS      64
_vreclaim_fake_reads DA      $0000
_vreclaim_fake_writes DA      $0000
bfreelist       DS      150
bufhash         DS      800
buf             DS      800
_vreclaim_trace DS      32
_vreclaim_n_trace DA      $0000
_vreclaim_fs_reclaim_fails DA      $0000
fsops           FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_close;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_inactive;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_reclaim;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_lock;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_unlock;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_strategy;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
spec_vnodeops   FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
                FGX2_LONG_PTR _Fa;_vreclaim_fs_nop;0
dead_vnodeops   FGX2_LONG_PTR _Fa;dead_lookup;0
                FGX2_LONG_PTR _Fa;dead_badop;0
                FGX2_LONG_PTR _Fa;dead_badop;0
                FGX2_LONG_PTR _Fa;dead_open;0
                FGX2_LONG_PTR _Fa;dead_nullop;0
                FGX2_LONG_PTR _Fa;dead_ebadf;0
                FGX2_LONG_PTR _Fa;dead_ebadf;0
                FGX2_LONG_PTR _Fa;dead_ebadf;0
                FGX2_LONG_PTR _Fa;dead_read;0
                FGX2_LONG_PTR _Fa;dead_write;0
                FGX2_LONG_PTR _Fa;dead_ioctl;0
                FGX2_LONG_PTR _Fa;dead_select;0
                FGX2_LONG_PTR _Fa;dead_badop;0
                FGX2_LONG_PTR _Fa;dead_nullop;0
                FGX2_LONG_PTR _Fa;dead_nullop;0
                FGX2_LONG_PTR _Fa;dead_badop;0
                FGX2_LONG_PTR _Fa;dead_badop;0
                FGX2_LONG_PTR _Fa;dead_badop;0
                FGX2_LONG_PTR _Fa;dead_badop;0
                FGX2_LONG_PTR _Fa;dead_badop;0
                FGX2_LONG_PTR _Fa;dead_badop;0
                FGX2_LONG_PTR _Fa;dead_ebadf;0
                FGX2_LONG_PTR _Fa;dead_ebadf;0
                FGX2_LONG_PTR _Fa;dead_badop;0
                FGX2_LONG_PTR _Fa;dead_nullop;0
                FGX2_LONG_PTR _Fa;dead_nullop;0
                FGX2_LONG_PTR _Fa;dead_lock;0
                FGX2_LONG_PTR _Fa;dead_nullop;0
                FGX2_LONG_PTR _Fa;dead_bmap;0
                FGX2_LONG_PTR _Fa;dead_strategy;0
                FGX2_LONG_PTR _Fa;dead_print;0
                FGX2_LONG_PTR _Fa;dead_nullop;0
_vreclaim_vfs_cacheops DS      4
_vreclaim_vfs_specops DS      4
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
_vreclaim_vn_arena DS      11392
fixarena        DS      16384
mnt_a           DS      130

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _vreclaim_S0
_vreclaim_S0             HEX     67,65,74,62,6C,6B,3A,20,76,6E,6F,64,65,20,77,69,74,68,20,6E,6F,20,76,65,63,74,6F,72,00
                FGX2_EXPORT _vreclaim_S1
_vreclaim_S1             HEX     62,69,6F,64,6F,6E,65,3A,20,61,6C,72,65,61,64,79,20,64,6F,6E,65,00
                FGX2_EXPORT _vreclaim_S2
_vreclaim_S2             HEX     62,69,6F,64,6F,6E,65,3A,20,6E,65,67,20,6E,75,6D,6F,75,74,70,75,74,00
                FGX2_EXPORT _vreclaim_S3
_vreclaim_S3             HEX     62,67,65,74,76,70,3A,20,6E,6F,74,20,66,72,65,65,00
                FGX2_EXPORT _vreclaim_S4
_vreclaim_S4             HEX     72,65,61,73,73,69,67,6E,62,75,66,3A,20,6E,6F,20,76,6E,6F,64,65,00
                FGX2_EXPORT _vreclaim_S5
_vreclaim_S5             HEX     76,66,6C,75,73,68,62,75,66,3A,20,6E,6F,74,20,64,69,72,74,79,00
                FGX2_EXPORT _vreclaim_S6
_vreclaim_S6             HEX     76,69,6E,76,61,6C,62,75,66,3A,20,66,6C,75,73,68,20,66,61,69,6C,65,64,00
                FGX2_EXPORT _vreclaim_S7
_vreclaim_S7             HEX     64,65,61,64,5F,72,65,61,64,3A,20,6C,6F,63,6B,00
                FGX2_EXPORT _vreclaim_S8
_vreclaim_S8             HEX     64,65,61,64,5F,77,72,69,74,65,3A,20,6C,6F,63,6B,00
                FGX2_EXPORT _vreclaim_S9
_vreclaim_S9             HEX     64,65,61,64,5F,62,61,64,6F,70,20,63,61,6C,6C,65,64,00
                FGX2_EXPORT _vreclaim_S10
_vreclaim_S10            HEX     67,65,74,6E,65,77,76,6E,6F,64,65,3A,20,66,72,65,65,20,76,6E,6F,64,65,20,69,73,6E,27,74,00
                FGX2_EXPORT _vreclaim_S11
_vreclaim_S11            HEX     76,72,65,66,3A,20,7A,65,72,6F,20,75,73,65,63,6F,75,6E,74,00
                FGX2_EXPORT _vreclaim_S12
_vreclaim_S12            HEX     76,72,65,6C,65,3A,20,7A,65,72,6F,20,75,73,65,63,6F,75,6E,74,00
                FGX2_EXPORT _vreclaim_S13
_vreclaim_S13            HEX     68,6F,6C,64,72,65,6C,65,3A,20,7A,65,72,6F,20,68,6F,6C,64,63,6E,74,00
                FGX2_EXPORT _vreclaim_S14
_vreclaim_S14            HEX     63,68,65,63,6B,61,6C,69,61,73,3A,20,6F,75,74,20,6F,66,20,73,70,65,63,69,6E,66,6F,00
                FGX2_EXPORT _vreclaim_S15
_vreclaim_S15            HEX     76,63,6C,65,61,6E,3A,20,64,65,61,64,6C,6F,63,6B,00
                FGX2_EXPORT _vreclaim_S16
_vreclaim_S16            HEX     76,63,6C,65,61,6E,3A,20,63,61,6E,6E,6F,74,20,72,65,63,6C,61,69,6D,00
                FGX2_EXPORT _vreclaim_S17
_vreclaim_S17            HEX     76,67,6F,6E,65,3A,20,64,65,76,69,63,65,20,76,6E,6F,64,65,20,77,69,74,68,20,6E,6F,20,73,70,65,63,69,6E,66,6F,00
                FGX2_EXPORT _vreclaim_S18
_vreclaim_S18            HEX     76,67,6F,6E,65,3A,20,6D,69,73,73,69,6E,67,20,62,64,65,76,00
                FGX2_EXPORT _vreclaim_S19
_vreclaim_S19            HEX     76,67,6F,6E,65,3A,20,6D,69,73,73,69,6E,67,20,61,6C,69,61,73,00
                FGX2_EXPORT _vreclaim_S20
_vreclaim_S20            HEX     76,66,6C,75,73,68,3A,20,6E,6F,74,20,62,75,73,79,00
                FGX2_RELOC_COUNT 120
