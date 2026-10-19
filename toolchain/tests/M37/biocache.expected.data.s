;---------------------------------------
; fcc 0.0 — data segment for biocache.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
_biocache_stub_slept DA      $0000
_biocache_stub_panic DA      $0000
_biocache_fake_disk DS      64
_biocache_fake_reads DA      $0000
_biocache_fake_writes DA      $0000
fakeops         FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_strategy;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
                FGX2_LONG_PTR _Fa;_biocache_fake_nop;0
bfreelist       DS      150
bufhash         DS      800
buf             DS      800
fixarena        DS      16384
vn              DS      492

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _biocache_S0
_biocache_S0             HEX     67,65,74,62,6C,6B,3A,20,76,6E,6F,64,65,20,77,69,74,68,20,6E,6F,20,76,65,63,74,6F,72,00
                FGX2_EXPORT _biocache_S1
_biocache_S1             HEX     62,69,6F,64,6F,6E,65,3A,20,61,6C,72,65,61,64,79,20,64,6F,6E,65,00
                FGX2_EXPORT _biocache_S2
_biocache_S2             HEX     62,69,6F,64,6F,6E,65,3A,20,6E,65,67,20,6E,75,6D,6F,75,74,70,75,74,00
                FGX2_EXPORT _biocache_S3
_biocache_S3             HEX     62,67,65,74,76,70,3A,20,6E,6F,74,20,66,72,65,65,00
                FGX2_EXPORT _biocache_S4
_biocache_S4             HEX     72,65,61,73,73,69,67,6E,62,75,66,3A,20,6E,6F,20,76,6E,6F,64,65,00
                FGX2_EXPORT _biocache_S5
_biocache_S5             HEX     76,66,6C,75,73,68,62,75,66,3A,20,6E,6F,74,20,64,69,72,74,79,00
                FGX2_EXPORT _biocache_S6
_biocache_S6             HEX     76,69,6E,76,61,6C,62,75,66,3A,20,66,6C,75,73,68,20,66,61,69,6C,65,64,00
                FGX2_RELOC_COUNT 40
