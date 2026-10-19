;---------------------------------------
; fcc 0.0 — data segment for specops.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
speclisth       DS      32
_specops_npanic DA      $0000
_specops_nslept DA      $0000
_specops_cd_opens DA      $0000
_specops_cd_closes DA      $0000
_specops_cd_reads DA      $0000
_specops_cd_writes DA      $0000
_specops_cd_last_idx DA      $FFFF
_specops_cd_last_byte DA      $FFFF
cd_last_flag    DA      $FFFF
cd_dlast_flag   DA      $FFFF
_specops_cd_dreads DA      $0000
_specops_cd_dwrites DA      $0000
_specops_cd_dlast_idx DA      $FFFF
_specops_cd_dstatus DA      $0100
_specops_cd_ioctls DA      $0000
_specops_cd_polls DA      $0000
_specops_cd_ioctlret DA      $0019
_specops_cd_pollmask DA      $0000
_specops_fake_disk DS      64
_specops_fake_buf DS      4
_specops_fake_iov DS      6
_specops_fake_reads DA      $0000
_specops_fake_writes DA      $0000
bfreelist       DS      150
bufhash         DS      800
buf             DS      800
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
spec_vnodeops   FGX2_LONG_PTR _Fa;spec_lookup;0
                FGX2_LONG_PTR _Fa;spec_badop;0
                FGX2_LONG_PTR _Fa;spec_badop;0
                FGX2_LONG_PTR _Fa;spec_open;0
                FGX2_LONG_PTR _Fa;spec_close;0
                FGX2_LONG_PTR _Fa;spec_ebadf;0
                FGX2_LONG_PTR _Fa;spec_ebadf;0
                FGX2_LONG_PTR _Fa;spec_ebadf;0
                FGX2_LONG_PTR _Fa;spec_read;0
                FGX2_LONG_PTR _Fa;spec_write;0
                FGX2_LONG_PTR _Fa;spec_ioctl;0
                FGX2_LONG_PTR _Fa;spec_select;0
                FGX2_LONG_PTR _Fa;spec_badop;0
                FGX2_LONG_PTR _Fa;spec_nullop;0
                FGX2_LONG_PTR _Fa;spec_badop;0
                FGX2_LONG_PTR _Fa;spec_badop;0
                FGX2_LONG_PTR _Fa;spec_badop;0
                FGX2_LONG_PTR _Fa;spec_badop;0
                FGX2_LONG_PTR _Fa;spec_badop;0
                FGX2_LONG_PTR _Fa;spec_badop;0
                FGX2_LONG_PTR _Fa;spec_badop;0
                FGX2_LONG_PTR _Fa;spec_badop;0
                FGX2_LONG_PTR _Fa;spec_badop;0
                FGX2_LONG_PTR _Fa;spec_badop;0
                FGX2_LONG_PTR _Fa;spec_nullop;0
                FGX2_LONG_PTR _Fa;spec_nullop;0
                FGX2_LONG_PTR _Fa;spec_lock;0
                FGX2_LONG_PTR _Fa;spec_unlock;0
                FGX2_LONG_PTR _Fa;spec_bmap;0
                FGX2_LONG_PTR _Fa;spec_strategy;0
                FGX2_LONG_PTR _Fa;spec_print;0
                FGX2_LONG_PTR _Fa;spec_nullop;0
_specops_specbyte DS      1
_specops_vfs_cacheops DS      4
_specops_vfs_specops DS      4
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
_specops_vn_arena DS      11392
fixarena        DS      16384
mnt_a           DS      130

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _specops_S0
_specops_S0             HEX     67,65,74,62,6C,6B,3A,20,76,6E,6F,64,65,20,77,69,74,68,20,6E,6F,20,76,65,63,74,6F,72,00
                FGX2_EXPORT _specops_S1
_specops_S1             HEX     62,69,6F,64,6F,6E,65,3A,20,61,6C,72,65,61,64,79,20,64,6F,6E,65,00
                FGX2_EXPORT _specops_S2
_specops_S2             HEX     62,69,6F,64,6F,6E,65,3A,20,6E,65,67,20,6E,75,6D,6F,75,74,70,75,74,00
                FGX2_EXPORT _specops_S3
_specops_S3             HEX     62,67,65,74,76,70,3A,20,6E,6F,74,20,66,72,65,65,00
                FGX2_EXPORT _specops_S4
_specops_S4             HEX     72,65,61,73,73,69,67,6E,62,75,66,3A,20,6E,6F,20,76,6E,6F,64,65,00
                FGX2_EXPORT _specops_S5
_specops_S5             HEX     76,66,6C,75,73,68,62,75,66,3A,20,6E,6F,74,20,64,69,72,74,79,00
                FGX2_EXPORT _specops_S6
_specops_S6             HEX     76,69,6E,76,61,6C,62,75,66,3A,20,66,6C,75,73,68,20,66,61,69,6C,65,64,00
                FGX2_EXPORT _specops_S7
_specops_S7             HEX     64,65,61,64,5F,72,65,61,64,3A,20,6C,6F,63,6B,00
                FGX2_EXPORT _specops_S8
_specops_S8             HEX     64,65,61,64,5F,77,72,69,74,65,3A,20,6C,6F,63,6B,00
                FGX2_EXPORT _specops_S9
_specops_S9             HEX     64,65,61,64,5F,62,61,64,6F,70,20,63,61,6C,6C,65,64,00
                FGX2_EXPORT _specops_S10
_specops_S10            HEX     75,72,65,61,64,63,00
                FGX2_EXPORT _specops_S11
_specops_S11            HEX     75,69,6F,6D,6F,76,65,3A,20,6D,6F,64,65,00
                FGX2_EXPORT _specops_S12
_specops_S12            HEX     73,70,65,63,5F,63,6C,6F,73,65,3A,20,6E,6F,74,20,73,70,65,63,69,61,6C,00
                FGX2_EXPORT _specops_S13
_specops_S13            HEX     73,70,65,63,5F,62,61,64,6F,70,20,63,61,6C,6C,65,64,00
                FGX2_EXPORT _specops_S14
_specops_S14            HEX     73,70,65,63,5F,72,65,61,64,20,6D,6F,64,65,00
                FGX2_EXPORT _specops_S15
_specops_S15            HEX     73,70,65,63,5F,72,65,61,64,20,74,79,70,65,00
                FGX2_EXPORT _specops_S16
_specops_S16            HEX     73,70,65,63,5F,77,72,69,74,65,20,6D,6F,64,65,00
                FGX2_EXPORT _specops_S17
_specops_S17            HEX     73,70,65,63,5F,77,72,69,74,65,20,74,79,70,65,00
                FGX2_EXPORT _specops_S18
_specops_S18            HEX     67,65,74,6E,65,77,76,6E,6F,64,65,3A,20,66,72,65,65,20,76,6E,6F,64,65,20,69,73,6E,27,74,00
                FGX2_EXPORT _specops_S19
_specops_S19            HEX     76,72,65,66,3A,20,7A,65,72,6F,20,75,73,65,63,6F,75,6E,74,00
                FGX2_EXPORT _specops_S20
_specops_S20            HEX     76,72,65,6C,65,3A,20,7A,65,72,6F,20,75,73,65,63,6F,75,6E,74,00
                FGX2_EXPORT _specops_S21
_specops_S21            HEX     68,6F,6C,64,72,65,6C,65,3A,20,7A,65,72,6F,20,68,6F,6C,64,63,6E,74,00
                FGX2_EXPORT _specops_S22
_specops_S22            HEX     63,68,65,63,6B,61,6C,69,61,73,3A,20,6F,75,74,20,6F,66,20,73,70,65,63,69,6E,66,6F,00
                FGX2_EXPORT _specops_S23
_specops_S23            HEX     76,63,6C,65,61,6E,3A,20,64,65,61,64,6C,6F,63,6B,00
                FGX2_EXPORT _specops_S24
_specops_S24            HEX     76,63,6C,65,61,6E,3A,20,63,61,6E,6E,6F,74,20,72,65,63,6C,61,69,6D,00
                FGX2_EXPORT _specops_S25
_specops_S25            HEX     76,67,6F,6E,65,3A,20,64,65,76,69,63,65,20,76,6E,6F,64,65,20,77,69,74,68,20,6E,6F,20,73,70,65,63,69,6E,66,6F,00
                FGX2_EXPORT _specops_S26
_specops_S26            HEX     76,67,6F,6E,65,3A,20,6D,69,73,73,69,6E,67,20,62,64,65,76,00
                FGX2_EXPORT _specops_S27
_specops_S27            HEX     76,67,6F,6E,65,3A,20,6D,69,73,73,69,6E,67,20,61,6C,69,61,73,00
                FGX2_EXPORT _specops_S28
_specops_S28            HEX     76,66,6C,75,73,68,3A,20,6E,6F,74,20,62,75,73,79,00
                FGX2_RELOC_COUNT 96
