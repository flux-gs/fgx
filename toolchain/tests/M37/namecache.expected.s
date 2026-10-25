                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from namecache.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT kc_panic
kc_panic            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #kc_panic_FRAMESIZE
                DO      kc_panic_STKGUARD
                BCC     kc_panic_stkovf
                CMP     _fcc_stkfloor
                BCS     kc_panic_stkok
kc_panic_stkovf       JMP     _fcc_stkoflow
                FIN
kc_panic_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #99
                PHA
                FGX2_FARCALL exit
                TAY
                PLA
                TYA
                TAY
                TSC
                CLC
                ADC     #kc_panic_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
kc_panic_FRAMESIZE   EQU     0
kc_panic_STKGUARD    EQU     0
                FGX2_EXPORT kc_sleep
kc_sleep            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #kc_sleep_FRAMESIZE
                DO      kc_sleep_STKGUARD
                BCC     kc_sleep_stkovf
                CMP     _fcc_stkfloor
                BCS     kc_sleep_stkok
kc_sleep_stkovf       JMP     _fcc_stkoflow
                FIN
kc_sleep_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                TAY
                TSC
                CLC
                ADC     #kc_sleep_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
kc_sleep_FRAMESIZE   EQU     0
kc_sleep_STKGUARD    EQU     0
                FGX2_EXPORT kc_wakeup
kc_wakeup            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #kc_wakeup_FRAMESIZE
                DO      kc_wakeup_STKGUARD
                BCC     kc_wakeup_stkovf
                CMP     _fcc_stkfloor
                BCS     kc_wakeup_stkok
kc_wakeup_stkovf       JMP     _fcc_stkoflow
                FIN
kc_wakeup_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                TAY
                TSC
                CLC
                ADC     #kc_wakeup_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
kc_wakeup_FRAMESIZE   EQU     0
kc_wakeup_STKGUARD    EQU     0
                FGX2_EXPORT kc_curpid
kc_curpid            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #kc_curpid_FRAMESIZE
                DO      kc_curpid_STKGUARD
                BCC     kc_curpid_stkovf
                CMP     _fcc_stkfloor
                BCS     kc_curpid_stkok
kc_curpid_stkovf       JMP     _fcc_stkoflow
                FIN
kc_curpid_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #kc_curpid_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
kc_curpid_FRAMESIZE   EQU     0
kc_curpid_STKGUARD    EQU     0
                FGX2_EXPORT vinvalbuf
vinvalbuf            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vinvalbuf_FRAMESIZE
                DO      vinvalbuf_STKGUARD
                BCC     vinvalbuf_stkovf
                CMP     _fcc_stkfloor
                BCS     vinvalbuf_stkok
vinvalbuf_stkovf       JMP     _fcc_stkoflow
                FIN
vinvalbuf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #vinvalbuf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vinvalbuf_FRAMESIZE   EQU     0
vinvalbuf_STKGUARD    EQU     0
                FGX2_EXPORT _namecache_op_nop
_namecache_op_nop            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_namecache_op_nop_FRAMESIZE
                DO      _namecache_op_nop_STKGUARD
                BCC     _namecache_op_nop_stkovf
                CMP     _fcc_stkfloor
                BCS     _namecache_op_nop_stkok
_namecache_op_nop_stkovf       JMP     _fcc_stkoflow
                FIN
_namecache_op_nop_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_namecache_op_nop_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_op_nop_FRAMESIZE   EQU     0
_namecache_op_nop_STKGUARD    EQU     0
                FGX2_EXPORT chrtoblk
chrtoblk            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #chrtoblk_FRAMESIZE
                DO      chrtoblk_STKGUARD
                BCC     chrtoblk_stkovf
                CMP     _fcc_stkfloor
                BCS     chrtoblk_stkok
chrtoblk_stkovf       JMP     _fcc_stkoflow
                FIN
chrtoblk_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+chrtoblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+chrtoblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+chrtoblk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                CMP     #10
                BNE     _namecache_L0
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #chrtoblk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L0
                DO      6+chrtoblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+chrtoblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+chrtoblk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                CMP     #11
                BNE     _namecache_L1
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #chrtoblk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L1
                DO      6+chrtoblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+chrtoblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+chrtoblk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                CMP     #12
                BNE     _namecache_L2
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #chrtoblk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L2
                DO      6+chrtoblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+chrtoblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+chrtoblk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                CMP     #13
                BNE     _namecache_L3
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #chrtoblk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L3
                DO      6+chrtoblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+chrtoblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+chrtoblk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                CMP     #14
                BNE     _namecache_L4
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #chrtoblk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L4
                DO      6+chrtoblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+chrtoblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+chrtoblk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                CMP     #15
                BNE     _namecache_L5
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #chrtoblk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L5
                DO      6+chrtoblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+chrtoblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+chrtoblk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                CMP     #16
                BNE     _namecache_L6
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #chrtoblk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L6
                DO      6+chrtoblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+chrtoblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+chrtoblk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                CMP     #17
                BNE     _namecache_L7
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #chrtoblk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L7
                LDA     #65535
                TAY
                TSC
                CLC
                ADC     #chrtoblk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
chrtoblk_FRAMESIZE   EQU     0
chrtoblk_STKGUARD    EQU     0
                FGX2_EXPORT vfs_setcacheops
vfs_setcacheops            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vfs_setcacheops_FRAMESIZE
                DO      vfs_setcacheops_STKGUARD
                BCC     vfs_setcacheops_stkovf
                CMP     _fcc_stkfloor
                BCS     vfs_setcacheops_stkok
vfs_setcacheops_stkovf       JMP     _fcc_stkoflow
                FIN
vfs_setcacheops_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vfs_setcacheops_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_setcacheops_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_setcacheops_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfs_setcacheops_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_setcacheops_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_setcacheops_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                STA     _namecache_vfs_cacheops
                LDA     _fcc_fpr0+2
                STA     _namecache_vfs_cacheops+2
                TAY
                TSC
                CLC
                ADC     #vfs_setcacheops_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vfs_setcacheops_FRAMESIZE   EQU     0
vfs_setcacheops_STKGUARD    EQU     0
                FGX2_EXPORT vfs_setspecops
vfs_setspecops            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vfs_setspecops_FRAMESIZE
                DO      vfs_setspecops_STKGUARD
                BCC     vfs_setspecops_stkovf
                CMP     _fcc_stkfloor
                BCS     vfs_setspecops_stkok
vfs_setspecops_stkovf       JMP     _fcc_stkoflow
                FIN
vfs_setspecops_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vfs_setspecops_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_setspecops_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_setspecops_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfs_setspecops_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_setspecops_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_setspecops_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                STA     _namecache_vfs_specops
                LDA     _fcc_fpr0+2
                STA     _namecache_vfs_specops+2
                TAY
                TSC
                CLC
                ADC     #vfs_setspecops_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vfs_setspecops_FRAMESIZE   EQU     0
vfs_setspecops_STKGUARD    EQU     0
                FGX2_EXPORT _namecache_zerobytes
_namecache_zerobytes            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_namecache_zerobytes_FRAMESIZE
                DO      _namecache_zerobytes_STKGUARD
                BCC     _namecache_zerobytes_stkovf
                CMP     _fcc_stkfloor
                BCS     _namecache_zerobytes_stkok
_namecache_zerobytes_stkovf       JMP     _fcc_stkoflow
                FIN
_namecache_zerobytes_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+_namecache_zerobytes_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_namecache_zerobytes_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_namecache_zerobytes_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img0
                DO      6+_namecache_zerobytes_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_zerobytes_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_zerobytes_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+_namecache_zerobytes_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_zerobytes_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_zerobytes_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
_namecache_L8
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                DEC
                STA     _fcc_img0
                LDA     _fcc_tmp_b
                TAX
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCS     _namecache_L9
                LDA     #0
                SEP     #$20
                MX      %10
                STA     [_fcc_img1]
                REP     #$20
                MX      %00
                INC     _fcc_img1
                BRA     _namecache_L8
_namecache_L9
                TAY
                TSC
                CLC
                ADC     #_namecache_zerobytes_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_zerobytes_FRAMESIZE   EQU     0
_namecache_zerobytes_STKGUARD    EQU     0
                FGX2_EXPORT vntblinit
vntblinit            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vntblinit_FRAMESIZE
                DO      vntblinit_STKGUARD
                BCC     vntblinit_stkovf
                CMP     _fcc_stkfloor
                BCS     vntblinit_stkok
vntblinit_stkovf       JMP     _fcc_stkoflow
                FIN
vntblinit_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vntblinit_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vntblinit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vntblinit_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vntblinit_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vntblinit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vntblinit_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                STA     vnode_pool
                LDA     _fcc_fpr0+2
                STA     vnode_pool+2
                LDA     #10496
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                STA     specinfo_pool
                LDA     _fcc_fpr0+2
                STA     specinfo_pool+2
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_img0
_namecache_L10
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #8
                BVC     _namecache_L13
                EOR     #$8000
_namecache_L13
                BPL     _namecache_L12
                LDA     #speclisth
                PHA
                LDA     _fcc_img0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     #0
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
_namecache_L11
                INC     _fcc_img0
                BRA     _namecache_L10
_namecache_L12
                LDA     _fcc_img0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #896
                PHA
                SEP     #$20
                MX      %10
                LDA     specinfo_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     specinfo_pool
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_zerobytes
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #0
                STA     vnode_free_head
                TAY
                LDA     #0
                STA     vnode_free_head+2
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vnode_free_head
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     vnode_free_tail
                LDA     _fcc_fpr0+2
                STA     vnode_free_tail+2
                LDA     #64
                STA     numvnodes
                LDA     #0
                STA     freevnodes
                LDA     #10496
                PHA
                SEP     #$20
                MX      %10
                LDA     vnode_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_pool
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_zerobytes
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
_namecache_L14
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                SEC
                SBC     #64
                BVC     _namecache_L17
                EOR     #$8000
_namecache_L17
                BPL     _namecache_L16
                SEP     #$20
                MX      %10
                LDA     vnode_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_pool
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_fpr0
                STA     3,S   ; fccstk d=0 b=3
                LDA     #8
                LDY     #52
                STA     [_fcc_fpr0],Y
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vfree
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L15
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRA     _namecache_L14
_namecache_L16
                DO      8+vntblinit_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vntblinit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vntblinit_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vntblinit_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vntblinit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vntblinit_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #10496
                TAX
                CLC
                ADC     #896
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #vntblinit_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vntblinit_FRAMESIZE   EQU     6
vntblinit_STKGUARD    EQU     0
                FGX2_EXPORT vfree
vfree            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vfree_FRAMESIZE
                DO      vfree_STKGUARD
                BCC     vfree_stkovf
                CMP     _fcc_stkfloor
                BCS     vfree_stkok
vfree_stkovf       JMP     _fcc_stkoflow
                FIN
vfree_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #26
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #28
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+vfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     vnode_free_tail+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     vnode_free_tail
                STA     _fcc_fpr1
                LDY     #30
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #32
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                SEP     #$20
                MX      %10
                LDA     vnode_free_tail+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_free_tail
                STA     _fcc_fpr0
                DO      8+vfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+vfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+vfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #26
                STA     _fcc_fpr0
                STA     vnode_free_tail
                LDA     _fcc_fpr0+2
                STA     vnode_free_tail+2
                LDA     freevnodes
                INC
                STA     freevnodes
                TAY
                TSC
                CLC
                ADC     #vfree_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vfree_FRAMESIZE   EQU     0
vfree_STKGUARD    EQU     0
                FGX2_EXPORT vremfree
vremfree            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vremfree_FRAMESIZE
                DO      vremfree_STKGUARD
                BCC     vremfree_stkovf
                CMP     _fcc_stkfloor
                BCS     vremfree_stkok
vremfree_stkovf       JMP     _fcc_stkoflow
                FIN
vremfree_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vremfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vremfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #30
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #32
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+vremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vremfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+vremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vremfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #26
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #28
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+vremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vremfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vremfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #26
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #28
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _namecache_L18
                DO      8+vremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vremfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vremfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #26
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #28
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+vremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vremfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+vremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vremfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #30
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #32
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #30
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #32
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                BRA     _namecache_L19
_namecache_L18
                DO      8+vremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vremfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vremfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #30
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #32
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                STA     vnode_free_tail
                LDA     _fcc_fpr0+2
                STA     vnode_free_tail+2
_namecache_L19
                DO      8+vremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vremfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vremfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #26
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #28
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+vremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vremfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vremfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #30
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #32
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                LDA     freevnodes
                DEC
                STA     freevnodes
                TAY
                TSC
                CLC
                ADC     #vremfree_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vremfree_FRAMESIZE   EQU     0
vremfree_STKGUARD    EQU     0
                FGX2_EXPORT getnewvnode
getnewvnode            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #getnewvnode_FRAMESIZE
                DO      getnewvnode_STKGUARD
                BCC     getnewvnode_stkovf
                CMP     _fcc_stkfloor
                BCS     getnewvnode_stkok
getnewvnode_stkovf       JMP     _fcc_stkoflow
                FIN
getnewvnode_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                LDA     vnode_free_head+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_free_head
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L21
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L21
                LDA     #1
                BRA     _namecache_L22
_namecache_L21
                LDA     #0
_namecache_L22
                CMP     #0
                BEQ     _namecache_L20
                DO      18+getnewvnode_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+getnewvnode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+getnewvnode_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_fpr0+2
                DO      16+getnewvnode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+getnewvnode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+getnewvnode_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #23
                TAY
                TSC
                CLC
                ADC     #getnewvnode_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L20
                LDY     #2
                LDA     [_fcc_fpr0],Y
                BEQ     _namecache_L23
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L23
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vremfree
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #8
                BEQ     _namecache_L24
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L24
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     [_fcc_fpr0]
                LDA     #1
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     #0
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     #0
                LDY     #52
                STA     [_fcc_fpr0],Y
                LDA     _fcc_fpr0
                DO      6+getnewvnode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+getnewvnode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+getnewvnode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDY     #58
                STA     [_fcc_fpr0],Y
                LDA     #0
                JSR     _fcc_long_from_int
                LDY     #10
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #12
                STA     [_fcc_fpr0],Y
                TXA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                LDY     #50
                STA     [_fcc_fpr0],Y
                LDA     #0
                LDY     #6
                STA     [_fcc_fpr0],Y
                LDA     #0
                LDY     #8
                STA     [_fcc_fpr0],Y
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #42
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #44
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #46
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #48
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #54
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #56
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                DO      14+getnewvnode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+getnewvnode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+getnewvnode_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+getnewvnode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+getnewvnode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+getnewvnode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1
                LDY     #22
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #24
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #18
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #20
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                SEP     #$20
                MX      %10
                LDA     _namecache_vfs_cacheops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _namecache_vfs_cacheops
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _namecache_L25
                SEP     #$20
                MX      %10
                LDA     _namecache_vfs_cacheops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _namecache_vfs_cacheops
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _namecache_L26-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_namecache_L26
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
_namecache_L25
                DO      10+getnewvnode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+getnewvnode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+getnewvnode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+getnewvnode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+getnewvnode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+getnewvnode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL insmntque
                TSC
                CLC
                ADC     #8
                TCS
                DO      18+getnewvnode_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+getnewvnode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+getnewvnode_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_fpr0+2
                DO      16+getnewvnode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+getnewvnode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+getnewvnode_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #getnewvnode_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
getnewvnode_FRAMESIZE   EQU     4
getnewvnode_STKGUARD    EQU     1
                FGX2_EXPORT vref
vref            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vref_FRAMESIZE
                DO      vref_STKGUARD
                BCC     vref_stkovf
                CMP     _fcc_stkfloor
                BCS     vref_stkok
vref_stkovf       JMP     _fcc_stkoflow
                FIN
vref_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vref_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vref_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vref_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vref_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vref_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vref_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _namecache_L28
                EOR     #$8000
_namecache_L28
                BMI     _namecache_L27
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L27
                DO      8+vref_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vref_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vref_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vref_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vref_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vref_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                INC
                LDY     #2
                STA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #vref_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vref_FRAMESIZE   EQU     0
vref_STKGUARD    EQU     0
                FGX2_EXPORT vget
vget            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vget_FRAMESIZE
                DO      vget_STKGUARD
                BCC     vget_stkovf
                CMP     _fcc_stkfloor
                BCS     vget_stkok
vget_stkovf       JMP     _fcc_stkoflow
                FIN
vget_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vget_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vget_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vget_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vget_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vget_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vget_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #256
                BEQ     _namecache_L29
                LDA     [_fcc_fpr0]
                TAX
                ORA     #512
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_sleep
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #vget_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L29
                LDY     #2
                LDA     [_fcc_fpr0],Y
                BNE     _namecache_L30
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vremfree
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L30
                DO      8+vget_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vget_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vget_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vget_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vget_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vget_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                INC
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #vget_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vget_FRAMESIZE   EQU     0
vget_STKGUARD    EQU     0
                FGX2_EXPORT vrele
vrele            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vrele_FRAMESIZE
                DO      vrele_STKGUARD
                BCC     vrele_stkovf
                CMP     _fcc_stkfloor
                BCS     vrele_stkok
vrele_stkovf       JMP     _fcc_stkoflow
                FIN
vrele_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vrele_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vrele_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vrele_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vrele_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vrele_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vrele_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _namecache_L32
                EOR     #$8000
_namecache_L32
                BMI     _namecache_L31
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L31
                DO      8+vrele_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vrele_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vrele_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vrele_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vrele_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vrele_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                DEC
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _namecache_L34
                EOR     #$8000
_namecache_L34
                BPL     _namecache_L33
                TAY
                TSC
                CLC
                ADC     #vrele_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L33
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vfree
                TSC
                CLC
                ADC     #4
                TCS
                DO      8+vrele_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vrele_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vrele_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vrele_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vrele_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vrele_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #22
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #24
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #96
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #98
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+vrele_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+vrele_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+vrele_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+vrele_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vrele_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vrele_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _namecache_L35-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_namecache_L35
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #vrele_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vrele_FRAMESIZE   EQU     0
vrele_STKGUARD    EQU     1
                FGX2_EXPORT vhold
vhold            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vhold_FRAMESIZE
                DO      vhold_STKGUARD
                BCC     vhold_stkovf
                CMP     _fcc_stkfloor
                BCS     vhold_stkok
vhold_stkovf       JMP     _fcc_stkoflow
                FIN
vhold_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vhold_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vhold_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vhold_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vhold_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vhold_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vhold_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                INC
                LDY     #4
                STA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #vhold_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vhold_FRAMESIZE   EQU     0
vhold_STKGUARD    EQU     0
                FGX2_EXPORT holdrele
holdrele            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #holdrele_FRAMESIZE
                DO      holdrele_STKGUARD
                BCC     holdrele_stkovf
                CMP     _fcc_stkfloor
                BCS     holdrele_stkok
holdrele_stkovf       JMP     _fcc_stkoflow
                FIN
holdrele_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+holdrele_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+holdrele_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+holdrele_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+holdrele_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+holdrele_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+holdrele_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                TAX
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _namecache_L37
                EOR     #$8000
_namecache_L37
                BMI     _namecache_L36
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L36
                DO      8+holdrele_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+holdrele_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+holdrele_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+holdrele_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+holdrele_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+holdrele_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                DEC
                LDY     #4
                STA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #holdrele_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
holdrele_FRAMESIZE   EQU     0
holdrele_STKGUARD    EQU     0
                FGX2_EXPORT insmntque
insmntque            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #insmntque_FRAMESIZE
                DO      insmntque_STKGUARD
                BCC     insmntque_stkovf
                CMP     _fcc_stkfloor
                BCS     insmntque_stkok
insmntque_stkovf       JMP     _fcc_stkoflow
                FIN
insmntque_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+insmntque_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+insmntque_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #38
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #40
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _namecache_L38
                DO      8+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+insmntque_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+insmntque_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #38
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #40
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+insmntque_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+insmntque_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #34
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #36
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+insmntque_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+insmntque_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #34
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #36
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _namecache_L39
                DO      8+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+insmntque_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+insmntque_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #34
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #36
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+insmntque_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+insmntque_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #38
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #40
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #38
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #40
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
_namecache_L39
_namecache_L38
                DO      8+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+insmntque_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+insmntque_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #34
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #36
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+insmntque_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+insmntque_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #38
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #40
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+insmntque_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+insmntque_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+insmntque_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+insmntque_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr1
                LDY     #18
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #20
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      12+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+insmntque_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+insmntque_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L41
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L41
                LDA     #1
                BRA     _namecache_L42
_namecache_L41
                LDA     #0
_namecache_L42
                CMP     #0
                BEQ     _namecache_L40
                TAY
                TSC
                CLC
                ADC     #insmntque_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L40
                DO      8+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+insmntque_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+insmntque_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+insmntque_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+insmntque_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr1
                LDY     #16
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #18
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #34
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #36
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      12+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+insmntque_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+insmntque_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDY     #16
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #18
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _namecache_L43
                DO      12+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+insmntque_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+insmntque_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDY     #16
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #18
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+insmntque_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+insmntque_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #34
                STA     _fcc_fpr1
                LDY     #38
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #40
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
_namecache_L43
                DO      12+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+insmntque_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+insmntque_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                DO      8+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+insmntque_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+insmntque_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #16
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #18
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+insmntque_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+insmntque_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+insmntque_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+insmntque_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+insmntque_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+insmntque_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                CLC
                ADC     #16
                STA     _fcc_fpr1
                LDY     #38
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #40
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #insmntque_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
insmntque_FRAMESIZE   EQU     0
insmntque_STKGUARD    EQU     0
                FGX2_EXPORT _namecache_specalloc
_namecache_specalloc            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_namecache_specalloc_FRAMESIZE
                DO      _namecache_specalloc_STKGUARD
                BCC     _namecache_specalloc_stkovf
                CMP     _fcc_stkfloor
                BCS     _namecache_specalloc_stkok
_namecache_specalloc_stkovf       JMP     _fcc_stkoflow
                FIN
_namecache_specalloc_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_img0
_namecache_L44
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #64
                BVC     _namecache_L47
                EOR     #$8000
_namecache_L47
                BMI     *+5
                BRL     _namecache_L46
                SEP     #$20
                MX      %10
                LDA     specinfo_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     specinfo_pool
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L49
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L49
                LDA     #1
                BRA     _namecache_L50
_namecache_L49
                LDA     #0
_namecache_L50
                CMP     #0
                BNE     *+5
                BRL     _namecache_L48
                SEP     #$20
                MX      %10
                LDA     specinfo_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     specinfo_pool
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                DO      8+_namecache_specalloc_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_specalloc_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_specalloc_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_namecache_specalloc_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_specalloc_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_specalloc_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     specinfo_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     specinfo_pool
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #_namecache_specalloc_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L48
_namecache_L45
                INC     _fcc_img0
                BRL     _namecache_L44
_namecache_L46
                LDA     _fcc_img0
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #_namecache_specalloc_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_specalloc_FRAMESIZE   EQU     2
_namecache_specalloc_STKGUARD    EQU     0
                FGX2_EXPORT _namecache_specfree
_namecache_specfree            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_namecache_specfree_FRAMESIZE
                DO      _namecache_specfree_STKGUARD
                BCC     _namecache_specfree_stkovf
                CMP     _fcc_stkfloor
                BCS     _namecache_specfree_stkok
_namecache_specfree_stkovf       JMP     _fcc_stkoflow
                FIN
_namecache_specfree_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_namecache_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_specfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_specfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+_namecache_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_specfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_specfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #4
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #6
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+_namecache_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_specfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_specfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                JSR     _fcc_long_from_int
                LDY     #8
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #10
                STA     [_fcc_fpr0],Y
                TXA
                DO      8+_namecache_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_specfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_specfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #65535
                LDY     #12
                STA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #_namecache_specfree_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_specfree_FRAMESIZE   EQU     0
_namecache_specfree_STKGUARD    EQU     0
                FGX2_EXPORT checkalias
checkalias            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #checkalias_FRAMESIZE
                DO      checkalias_STKGUARD
                BCC     checkalias_stkovf
                CMP     _fcc_stkfloor
                BCS     checkalias_stkok
checkalias_stkovf       JMP     _fcc_stkoflow
                FIN
checkalias_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+checkalias_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+checkalias_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #3
                BEQ     _namecache_L51
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #4
                BEQ     _namecache_L51
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #checkalias_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L51
                DO      10+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+checkalias_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                LSR
                LSR
                LSR
                LSR
                LSR
                TAX
                DO      10+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+checkalias_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAX
                LDA     #8
                TAY
                TYA
                DEC
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #speclisth
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
checkalias_uL_loop
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_ptr
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_namecache_L52
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _namecache_L54
                DO      10+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+checkalias_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                PHA
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _namecache_L56
                DO      8+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+checkalias_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+checkalias_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _namecache_L55
_namecache_L56
                BRA     _namecache_L53
_namecache_L55
                LDY     #2
                LDA     [_fcc_fpr0],Y
                BNE     _namecache_L57
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     checkalias_uL_loop
_namecache_L57
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vget
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                CMP     #0
                BEQ     _namecache_L58
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     checkalias_uL_loop
_namecache_L58
                BRA     _namecache_L54
_namecache_L53
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _namecache_L52
_namecache_L54
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L61
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L61
                LDA     #1
                BRA     _namecache_L62
_namecache_L61
                LDA     #0
_namecache_L62
                CMP     #0
                BNE     _namecache_L60
                LDY     #58
                LDA     [_fcc_fpr0],Y
                CMP     #0
                BNE     *+5
                BRL     _namecache_L59
_namecache_L60
                DO      8+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+checkalias_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+checkalias_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_fpr1+2
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _namecache_specalloc
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     _fcc_fpr0
                STA     _fcc_fpr1
                LDA     _fcc_fpr0+2
                STA     _fcc_fpr1+2
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDA     _fcc_fpr1
                LDY     #54
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #56
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+checkalias_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+checkalias_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      10+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+checkalias_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                LDY     #12
                STA     [_fcc_fpr0],Y
                DO      8+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+checkalias_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+checkalias_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_ptr
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                LDY     #4
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #6
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+checkalias_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+checkalias_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                JSR     _fcc_long_from_int
                LDY     #8
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #10
                STA     [_fcc_fpr0],Y
                TXA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                DO      8+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+checkalias_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+checkalias_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L64
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L64
                LDA     #0
                BRA     _namecache_L65
_namecache_L64
                LDA     #1
_namecache_L65
                CMP     #0
                BEQ     _namecache_L63
                DO      8+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+checkalias_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+checkalias_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #2048
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #2048
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vrele
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L63
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #checkalias_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L59
                LDA     #0
                PHA
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vclean
                TSC
                CLC
                ADC     #6
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                DO      8+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+checkalias_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+checkalias_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #22
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #24
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #22
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #24
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                DO      8+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+checkalias_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+checkalias_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #58
                LDA     [_fcc_fpr1],Y
                LDY     #58
                STA     [_fcc_fpr0],Y
                DO      8+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+checkalias_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+checkalias_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                LDY     #52
                STA     [_fcc_fpr0],Y
                DO      14+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+checkalias_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_fpr0+2
                DO      12+checkalias_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+checkalias_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+checkalias_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL insmntque
                TSC
                CLC
                ADC     #8
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #checkalias_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
checkalias_FRAMESIZE   EQU     8
checkalias_STKGUARD    EQU     0
                FGX2_EXPORT bdevvp
bdevvp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #bdevvp_FRAMESIZE
                DO      bdevvp_STKGUARD
                BCC     bdevvp_stkovf
                CMP     _fcc_stkfloor
                BCS     bdevvp_stkok
bdevvp_stkovf       JMP     _fcc_stkoflow
                FIN
bdevvp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                LDA     _namecache_vfs_specops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _namecache_vfs_specops
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L67
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L67
                LDA     #1
                BRA     _namecache_L68
_namecache_L67
                LDA     #0
_namecache_L68
                CMP     #0
                BEQ     _namecache_L66
                DO      10+bdevvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bdevvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bdevvp_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+bdevvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bdevvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bdevvp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #bdevvp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L66
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _namecache_vfs_specops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _namecache_vfs_specops
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                BEQ     _namecache_L69
                DO      10+bdevvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bdevvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bdevvp_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+bdevvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bdevvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bdevvp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     9,S   ; fccstk d=0 b=9
                TAY
                TSC
                CLC
                ADC     #bdevvp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L69
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #3
                LDY     #52
                STA     [_fcc_fpr0],Y
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      10+bdevvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bdevvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bdevvp_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                PHA
                LDA     9,S   ; fccstk d=6 b=3
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=6 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL checkalias
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _namecache_L70
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vput
                TSC
                CLC
                ADC     #4
                TCS
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_namecache_L70
                DO      10+bdevvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bdevvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bdevvp_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+bdevvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bdevvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bdevvp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #bdevvp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bdevvp_FRAMESIZE   EQU     10
bdevvp_STKGUARD    EQU     0
                FGX2_EXPORT vfinddev
vfinddev            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vfinddev_FRAMESIZE
                DO      vfinddev_STKGUARD
                BCC     vfinddev_stkovf
                CMP     _fcc_stkfloor
                BCS     vfinddev_stkok
vfinddev_stkovf       JMP     _fcc_stkoflow
                FIN
vfinddev_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+vfinddev_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfinddev_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfinddev_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+vfinddev_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfinddev_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfinddev_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                LDA     _fcc_img0
                LSR
                LSR
                LSR
                LSR
                LSR
                CLC
                ADC     _fcc_img0
                TAX
                LDA     #8
                TAY
                TYA
                SEC
                SBC     #1
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    speclisth+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    speclisth,X
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_namecache_L71
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _namecache_L73
                LDA     _fcc_img0
                PHA
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _namecache_L75
                LDA     _fcc_img1
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _namecache_L74
_namecache_L75
                BRA     _namecache_L72
_namecache_L74
                DO      12+vfinddev_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+vfinddev_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+vfinddev_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+vfinddev_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vfinddev_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vfinddev_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #vfinddev_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L72
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _namecache_L71
_namecache_L73
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #vfinddev_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vfinddev_FRAMESIZE   EQU     4
vfinddev_STKGUARD    EQU     0
                FGX2_EXPORT spec_securechr
spec_securechr            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #spec_securechr_FRAMESIZE
                DO      spec_securechr_STKGUARD
                BCC     spec_securechr_stkovf
                CMP     _fcc_stkfloor
                BCS     spec_securechr_stkok
spec_securechr_stkovf       JMP     _fcc_stkoflow
                FIN
spec_securechr_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     securelevel
                TAX
                SEC
                SBC     #1
                BVC     _namecache_L77
                EOR     #$8000
_namecache_L77
                BPL     _namecache_L76
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #spec_securechr_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L76
                DO      6+spec_securechr_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+spec_securechr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+spec_securechr_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                FGX2_FARCALL chrtoblk
                TAY
                PLA
                TYA
                STA     5,S   ; fccstk d=0 b=5
                TAX
                CMP     #65535
                BNE     _namecache_L78
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #spec_securechr_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L78
                LDA     5,S   ; fccstk d=0 b=5
                LSR
                LSR
                LSR
                LSR
                LSR
                CLC
                ADC     5,S   ; fccstk d=0 b=5
                TAX
                LDA     #8
                TAY
                TYA
                SEC
                SBC     #1
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    speclisth+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    speclisth,X
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_img0
_namecache_L79
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _namecache_L81
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     _namecache_L83
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #3
                BEQ     _namecache_L82
_namecache_L83
                BRA     _namecache_L80
_namecache_L82
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #8
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_and
                ORA     _fcc_long_hi
                BEQ     _namecache_L84
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #spec_securechr_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L84
_namecache_L80
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _namecache_L79
_namecache_L81
                LDA     _fcc_img0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #spec_securechr_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
spec_securechr_FRAMESIZE   EQU     6
spec_securechr_STKGUARD    EQU     0
                FGX2_EXPORT vfs_getsecurelevel
vfs_getsecurelevel            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vfs_getsecurelevel_FRAMESIZE
                DO      vfs_getsecurelevel_STKGUARD
                BCC     vfs_getsecurelevel_stkovf
                CMP     _fcc_stkfloor
                BCS     vfs_getsecurelevel_stkok
vfs_getsecurelevel_stkovf       JMP     _fcc_stkoflow
                FIN
vfs_getsecurelevel_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     securelevel
                TAY
                TSC
                CLC
                ADC     #vfs_getsecurelevel_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vfs_getsecurelevel_FRAMESIZE   EQU     0
vfs_getsecurelevel_STKGUARD    EQU     0
                FGX2_EXPORT vfs_setsecurelevel
vfs_setsecurelevel            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vfs_setsecurelevel_FRAMESIZE
                DO      vfs_setsecurelevel_STKGUARD
                BCC     vfs_setsecurelevel_stkovf
                CMP     _fcc_stkfloor
                BCS     vfs_setsecurelevel_stkok
vfs_setsecurelevel_stkovf       JMP     _fcc_stkoflow
                FIN
vfs_setsecurelevel_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+vfs_setsecurelevel_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_setsecurelevel_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_setsecurelevel_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDX     #1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _namecache_L86
                EOR     #$8000
_namecache_L86
                BPL     _namecache_L85
                LDA     #22
                TAY
                TSC
                CLC
                ADC     #vfs_setsecurelevel_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L85
                DO      6+vfs_setsecurelevel_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_setsecurelevel_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_setsecurelevel_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     securelevel
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #vfs_setsecurelevel_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vfs_setsecurelevel_FRAMESIZE   EQU     0
vfs_setsecurelevel_STKGUARD    EQU     0
                FGX2_EXPORT vcount
vcount            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vcount_FRAMESIZE
                DO      vcount_STKGUARD
                BCC     vcount_stkovf
                CMP     _fcc_stkfloor
                BCS     vcount_stkok
vcount_stkovf       JMP     _fcc_stkoflow
                FIN
vcount_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vcount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vcount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vcount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vcount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vcount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vcount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #2048
                CMP     #0
                BNE     _namecache_L87
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #vcount_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L87
vcount_uL_loop
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                DO      8+vcount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vcount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vcount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vcount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vcount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vcount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_namecache_L88
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _namecache_L90
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                PHA
                DO      10+vcount_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vcount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vcount_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+vcount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vcount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vcount_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _namecache_L92
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                PHA
                DO      10+vcount_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vcount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vcount_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+vcount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vcount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vcount_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _namecache_L91
_namecache_L92
                BRA     _namecache_L89
_namecache_L91
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                BNE     _namecache_L93
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     vcount_uL_loop
_namecache_L93
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
_namecache_L89
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _namecache_L88
_namecache_L90
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #vcount_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vcount_FRAMESIZE   EQU     6
vcount_STKGUARD    EQU     0
                FGX2_EXPORT vput
vput            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vput_FRAMESIZE
                DO      vput_STKGUARD
                BCC     vput_stkovf
                CMP     _fcc_stkfloor
                BCS     vput_stkok
vput_stkovf       JMP     _fcc_stkoflow
                FIN
vput_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vput_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vput_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vput_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vput_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vput_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vput_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #22
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #24
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #108
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #110
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+vput_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+vput_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+vput_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+vput_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vput_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vput_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _namecache_L94-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_namecache_L94
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                DO      8+vput_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vput_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vput_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vput_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vput_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vput_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vrele
                TSC
                CLC
                ADC     #4
                TCS
                TAY
                TSC
                CLC
                ADC     #vput_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vput_FRAMESIZE   EQU     0
vput_STKGUARD    EQU     1
                FGX2_EXPORT vclean
vclean            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vclean_FRAMESIZE
                DO      vclean_STKGUARD
                BCC     vclean_stkovf
                CMP     _fcc_stkfloor
                BCS     vclean_stkok
vclean_stkovf       JMP     _fcc_stkoflow
                FIN
vclean_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vclean_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vclean_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     5,S   ; fccstk d=0 b=5
                BEQ     _namecache_L95
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vref
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L95
                DO      8+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vclean_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vclean_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #256
                BEQ     _namecache_L96
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L96
                DO      8+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vclean_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vclean_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #256
                STA     [_fcc_fpr0]
                LDY     #22
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #24
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #104
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #106
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+vclean_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vclean_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _namecache_L97-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_namecache_L97
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                DO      10+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vclean_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAX
                AND     #4
                BEQ     _namecache_L98
                LDA     #1
                PHA
                DO      10+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vclean_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vclean_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vinvalbuf
                TSC
                CLC
                ADC     #6
                TCS
_namecache_L98
                DO      8+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vclean_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vclean_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #22
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #24
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                DO      8+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vclean_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vclean_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #dead_vnodeops
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                LDY     #22
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #24
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vclean_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vclean_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                LDY     #58
                STA     [_fcc_fpr0],Y
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #108
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #110
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+vclean_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vclean_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _namecache_L99-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_namecache_L99
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     5,S   ; fccstk d=0 b=5
                CMP     #0
                BNE     *+5
                BRL     _namecache_L100
                DO      10+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vclean_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAX
                AND     #4
                BEQ     _namecache_L101
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #16
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #18
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                PHA
                DO      18+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+vclean_FRAMESIZE,S   ; fccstk d=10 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      16+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+vclean_FRAMESIZE,S   ; fccstk d=10 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     11,S
                STA     _fcc_fpr0
                LDA     13,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _namecache_L102-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_namecache_L102
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
_namecache_L101
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #96
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #98
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+vclean_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vclean_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _namecache_L103-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_namecache_L103
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
_namecache_L100
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #100
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #102
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+vclean_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vclean_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _namecache_L105-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_namecache_L105
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BEQ     _namecache_L104
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S6
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L104
                LDA     5,S   ; fccstk d=0 b=5
                BEQ     _namecache_L106
                DO      8+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vclean_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vclean_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vrele
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L106
                DO      8+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vclean_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vclean_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vclean_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vclean_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #256
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     [_fcc_fpr0]
                TAX
                AND     #512
                BEQ     _namecache_L107
                LDA     [_fcc_fpr0]
                PHA
                LDA     #512
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_wakeup
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L107
                TAY
                TSC
                CLC
                ADC     #vclean_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vclean_FRAMESIZE   EQU     6
vclean_STKGUARD    EQU     1
                FGX2_EXPORT vgone
vgone            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vgone_FRAMESIZE
                DO      vgone_STKGUARD
                BCC     vgone_stkovf
                CMP     _fcc_stkfloor
                BCS     vgone_stkok
vgone_stkovf       JMP     _fcc_stkoflow
                FIN
vgone_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #256
                BEQ     _namecache_L108
                LDA     [_fcc_fpr0]
                TAX
                ORA     #512
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_sleep
                TSC
                CLC
                ADC     #4
                TCS
                TAY
                TSC
                CLC
                ADC     #vgone_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L108
                LDA     #4
                PHA
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vclean
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+vgone_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vgone_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL insmntque
                TSC
                CLC
                ADC     #8
                TCS
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #3
                BEQ     _namecache_L110
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #4
                BEQ     *+5
                BRL     _namecache_L109
_namecache_L110
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L112
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L112
                LDA     #1
                BRA     _namecache_L113
_namecache_L112
                LDA     #0
_namecache_L113
                CMP     #0
                BEQ     _namecache_L111
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S7
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L111
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L115
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L115
                LDA     #1
                BRA     _namecache_L116
_namecache_L115
                LDA     #0
_namecache_L116
                CMP     #0
                BEQ     _namecache_L114
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #4
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                BRL     _namecache_L117
_namecache_L114
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_namecache_L118
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _namecache_L120
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L122
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L122
                LDA     #0
                BRA     _namecache_L123
_namecache_L122
                LDA     #1
_namecache_L123
                CMP     #0
                BEQ     _namecache_L121
                BRA     _namecache_L119
_namecache_L121
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #4
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #4
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #6
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                BRA     _namecache_L120
_namecache_L119
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _namecache_L118
_namecache_L120
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L125
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L125
                LDA     #1
                BRA     _namecache_L126
_namecache_L125
                LDA     #0
_namecache_L126
                CMP     #0
                BEQ     _namecache_L124
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L124
_namecache_L117
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #2048
                CMP     #0
                BNE     *+5
                BRL     _namecache_L127
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_img0
_namecache_L128
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _namecache_L130
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                PHA
                DO      10+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vgone_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _namecache_L132
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                PHA
                DO      10+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vgone_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _namecache_L131
_namecache_L132
                BRA     _namecache_L129
_namecache_L131
                INC     _fcc_img0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
_namecache_L129
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _namecache_L128
_namecache_L130
                LDA     _fcc_img0
                STA     9,S   ; fccstk d=0 b=9
                BNE     _namecache_L133
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L133
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CMP     #1
                BNE     _namecache_L134
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #2048
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_fpr0]
_namecache_L134
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #2048
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_fpr0]
_namecache_L127
                LDY     #54
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_specfree
                TSC
                CLC
                ADC     #4
                TCS
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #54
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #56
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
_namecache_L109
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #30
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #32
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _namecache_L135
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vremfree
                TSC
                CLC
                ADC     #4
                TCS
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     vnode_free_head+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     vnode_free_head
                STA     _fcc_fpr1
                LDY     #26
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #28
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #vnode_free_head
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                LDY     #30
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #32
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                SEP     #$20
                MX      %10
                LDA     vnode_free_head+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_free_head
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _namecache_L136
                SEP     #$20
                MX      %10
                LDA     vnode_free_head+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_free_head
                STA     _fcc_fpr0
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #26
                STA     _fcc_fpr1
                LDY     #30
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #32
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                BRA     _namecache_L137
_namecache_L136
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #26
                STA     _fcc_fpr0
                STA     vnode_free_tail
                LDA     _fcc_fpr0+2
                STA     vnode_free_tail+2
_namecache_L137
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                STA     vnode_free_head
                LDA     _fcc_fpr0+2
                STA     vnode_free_head+2
                LDA     freevnodes
                CLC
                ADC     #1
                STA     freevnodes
_namecache_L135
                DO      8+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vgone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vgone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vgone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vgone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #8
                LDY     #52
                STA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #vgone_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vgone_FRAMESIZE   EQU     10
vgone_STKGUARD    EQU     0
                FGX2_EXPORT vflush
vflush            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vflush_FRAMESIZE
                DO      vflush_STKGUARD
                BCC     vflush_stkovf
                CMP     _fcc_stkfloor
                BCS     vflush_stkok
vflush_stkovf       JMP     _fcc_stkoflow
                FIN
vflush_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vflush_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vflush_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vflush_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vflush_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vflush_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vflush_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #22
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #20
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0040
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_and
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _namecache_L138
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S10
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L138
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
vflush_uL_loop
                DO      8+vflush_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vflush_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vflush_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vflush_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vflush_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vflush_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #16
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #18
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_namecache_L139
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _namecache_L141
                LDY     #18
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #20
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+vflush_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vflush_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vflush_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+vflush_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vflush_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vflush_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L143
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L143
                LDA     #0
                BRA     _namecache_L144
_namecache_L143
                LDA     #1
_namecache_L144
                CMP     #0
                BEQ     _namecache_L142
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     vflush_uL_loop
_namecache_L142
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #34
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #36
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                DO      12+vflush_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+vflush_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+vflush_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+vflush_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vflush_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vflush_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L146
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L146
                LDA     #1
                BRA     _namecache_L147
_namecache_L146
                LDA     #0
_namecache_L147
                CMP     #0
                BEQ     _namecache_L145
                BRL     _namecache_L140
_namecache_L145
                DO      14+vflush_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+vflush_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+vflush_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                TAX
                AND     #1
                BEQ     _namecache_L148
                LDA     [_fcc_fpr0]
                TAX
                AND     #4
                CMP     #0
                BEQ     _namecache_L148
                BRL     _namecache_L140
_namecache_L148
                LDY     #2
                LDA     [_fcc_fpr0],Y
                BNE     _namecache_L149
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
                BRL     _namecache_L140
_namecache_L149
                DO      14+vflush_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+vflush_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+vflush_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                TAX
                AND     #2
                CMP     #0
                BNE     *+5
                BRL     _namecache_L150
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #3
                BEQ     _namecache_L151
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #4
                BEQ     _namecache_L151
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
                BRL     _namecache_L152
_namecache_L151
                LDA     #0
                PHA
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vclean
                TSC
                CLC
                ADC     #6
                TCS
                SEP     #$20
                MX      %10
                LDA     _namecache_vfs_specops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _namecache_vfs_specops
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L154
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L154
                LDA     #1
                BRA     _namecache_L155
_namecache_L154
                LDA     #0
_namecache_L155
                CMP     #0
                BEQ     _namecache_L153
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
                BRA     _namecache_L140
_namecache_L153
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _namecache_vfs_specops+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _namecache_vfs_specops
                STA     _fcc_fpr1
                LDY     #22
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #24
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL insmntque
                TSC
                CLC
                ADC     #8
                TCS
_namecache_L152
                BRA     _namecache_L140
_namecache_L150
                LDA     9,S   ; fccstk d=0 b=9
                CLC
                ADC     #1
                STA     9,S   ; fccstk d=0 b=9
_namecache_L140
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _namecache_L139
_namecache_L141
                LDA     9,S   ; fccstk d=0 b=9
                BEQ     _namecache_L156
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #vflush_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L156
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #vflush_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vflush_FRAMESIZE   EQU     10
vflush_STKGUARD    EQU     0
                FGX2_EXPORT ndinit
ndinit            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ndinit_FRAMESIZE
                DO      ndinit_STKGUARD
                BCC     ndinit_stkovf
                CMP     _fcc_stkfloor
                BCS     ndinit_stkok
ndinit_stkovf       JMP     _fcc_stkoflow
                FIN
ndinit_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #32
                ASL
                STA     _fcc_img0
                DO      8+ndinit_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ndinit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ndinit_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ndinit_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ndinit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ndinit_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     nd_pool
                LDA     _fcc_fpr0+2
                STA     nd_pool+2
                SEP     #$20
                MX      %10
                LDA     nd_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     nd_pool
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                LDA     #158
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     nd_bufs
                LDA     _fcc_fpr0+2
                STA     nd_bufs+2
                SEP     #$20
                MX      %10
                LDA     nd_bufs+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     nd_bufs
                STA     _fcc_fpr0
                LDA     _fcc_img0
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #ndinit_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ndinit_FRAMESIZE   EQU     4
ndinit_STKGUARD    EQU     0
                FGX2_EXPORT ndslot
ndslot            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ndslot_FRAMESIZE
                DO      ndslot_STKGUARD
                BCC     ndslot_stkovf
                CMP     _fcc_stkfloor
                BCS     ndslot_stkok
ndslot_stkovf       JMP     _fcc_stkoflow
                FIN
ndslot_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+ndslot_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ndslot_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ndslot_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                CMP     #0
                BMI     _namecache_L158
                DO      8+ndslot_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ndslot_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ndslot_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                TAX
                SEC
                SBC     #2
                BVC     _namecache_L159
                EOR     #$8000
_namecache_L159
                BMI     _namecache_L157
_namecache_L158
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #ndslot_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L157
                DO      6+ndslot_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ndslot_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ndslot_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                SEC
                SBC     #1
                BVC     _namecache_L162
                EOR     #$8000
_namecache_L162
                BMI     _namecache_L161
                DO      6+ndslot_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ndslot_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ndslot_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDX     #32
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _namecache_L163
                EOR     #$8000
_namecache_L163
                BPL     _namecache_L160
_namecache_L161
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #ndslot_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L160
                SEP     #$20
                MX      %10
                LDA     nd_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     nd_pool
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L165
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L165
                LDA     #1
                BRA     _namecache_L166
_namecache_L165
                LDA     #0
_namecache_L166
                CMP     #0
                BEQ     _namecache_L164
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #ndslot_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L164
                DO      6+ndslot_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ndslot_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ndslot_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                DEC
                ASL
                TAX
                DO      8+ndslot_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ndslot_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ndslot_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
                SEP     #$20
                MX      %10
                LDA     nd_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     nd_pool
                STA     _fcc_fpr0
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                LDA     #158
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     _fcc_img0
_namecache_L167
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                SEC
                SBC     #158
                BVC     _namecache_L170
                EOR     #$8000
_namecache_L170
                BPL     _namecache_L169
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_img0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
_namecache_L168
                INC     _fcc_img0
                BRA     _namecache_L167
_namecache_L169
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     nd_bufs+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     nd_bufs
                STA     _fcc_fpr1
                LDA     _fcc_img1
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDY     #20
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #22
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     nd_bufs+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     nd_bufs
                STA     _fcc_fpr1
                LDA     _fcc_img1
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                TAX
                CLC
                ADC     #128
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDY     #24
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #26
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #142
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #136
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #146
                STA     _fcc_fpr0
                LDA     #1
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #136
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #66
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #156
                STA     _fcc_fpr0
                LDA     #1
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #154
                STA     _fcc_fpr0
                LDA     #1
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #ndslot_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ndslot_FRAMESIZE   EQU     8
ndslot_STKGUARD    EQU     0
                FGX2_EXPORT ndget
ndget            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ndget_FRAMESIZE
                DO      ndget_STKGUARD
                BCC     ndget_stkovf
                CMP     _fcc_stkfloor
                BCS     ndget_stkok
ndget_stkovf       JMP     _fcc_stkoflow
                FIN
ndget_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+ndget_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ndget_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ndget_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                FGX2_FARCALL kc_curpid
                PHA
                FGX2_FARCALL ndslot
                TAY
                PLA
                PLA
                TYA
                TAY
                TSC
                CLC
                ADC     #ndget_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ndget_FRAMESIZE   EQU     0
ndget_STKGUARD    EQU     0
                FGX2_EXPORT vfs_dounmount
vfs_dounmount            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vfs_dounmount_FRAMESIZE
                DO      vfs_dounmount_STKGUARD
                BCC     vfs_dounmount_stkovf
                CMP     _fcc_stkfloor
                BCS     vfs_dounmount_stkok
vfs_dounmount_stkovf       JMP     _fcc_stkoflow
                FIN
vfs_dounmount_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L173
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L173
                LDA     #1
                BRA     _namecache_L174
_namecache_L173
                LDA     #0
_namecache_L174
                CMP     #0
                BNE     _namecache_L172
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L175
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L175
                LDA     #1
                BRA     _namecache_L176
_namecache_L175
                LDA     #0
_namecache_L176
                CMP     #0
                BEQ     _namecache_L171
_namecache_L172
                LDA     #22
                TAY
                TSC
                CLC
                ADC     #vfs_dounmount_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L171
                DO      8+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                DO      8+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #22
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #20
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0040
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                LDY     #20
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #22
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                LDA     _namecache_vfs_cacheops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _namecache_vfs_cacheops
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _namecache_L177
                SEP     #$20
                MX      %10
                LDA     _namecache_vfs_cacheops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _namecache_vfs_cacheops
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+vfs_dounmount_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vfs_dounmount_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _namecache_L178-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_namecache_L178
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
_namecache_L177
                DO      8+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      14+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+vfs_dounmount_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                PHA
                DO      14+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+vfs_dounmount_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      12+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+vfs_dounmount_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0
                LDA     9,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _namecache_L179-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_namecache_L179
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                STA     5,S   ; fccstk d=0 b=5
                CMP     #0
                BEQ     _namecache_L180
                DO      8+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #22
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #20
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0040
                STA     _fcc_long_hi
                LDA     #$0000
                JSR     _fcc_long_not
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_and
                LDY     #20
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #22
                STA     [_fcc_fpr0],Y
                TXA
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #vfs_dounmount_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L180
                DO      8+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L182
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L182
                LDA     #0
                BRA     _namecache_L183
_namecache_L182
                LDA     #1
_namecache_L183
                CMP     #0
                BNE     *+5
                BRL     _namecache_L181
                DO      8+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L184
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L184
                LDA     #0
                BRA     _namecache_L185
_namecache_L184
                LDA     #1
_namecache_L185
                CMP     #0
                BNE     *+5
                BRL     _namecache_L181
                DO      8+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #4
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                LDY     #4
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #6
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #4
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #6
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
_namecache_L181
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L187
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L187
                LDA     #0
                BRA     _namecache_L188
_namecache_L187
                LDA     #1
_namecache_L188
                CMP     #0
                BEQ     _namecache_L186
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #54
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #56
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #12
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #14
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vrele
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L186
                DO      8+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vfs_dounmount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vfs_dounmount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vfs_dounmount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #22
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #20
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0040
                STA     _fcc_long_hi
                LDA     #$0000
                JSR     _fcc_long_not
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_and
                LDY     #20
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #22
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #vfs_dounmount_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vfs_dounmount_FRAMESIZE   EQU     6
vfs_dounmount_STKGUARD    EQU     1
                FGX2_EXPORT _namecache_nchbucket
_namecache_nchbucket            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_namecache_nchbucket_FRAMESIZE
                DO      _namecache_nchbucket_STKGUARD
                BCC     _namecache_nchbucket_stkovf
                CMP     _fcc_stkfloor
                BCS     _namecache_nchbucket_stkok
_namecache_nchbucket_stkovf       JMP     _fcc_stkoflow
                FIN
_namecache_nchbucket_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_namecache_nchbucket_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nchbucket_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nchbucket_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_namecache_nchbucket_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nchbucket_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nchbucket_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16
                TAX
                SEC
                SBC     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_and
                ASL
                ASL
                ASL
                CLC
                ADC     #nchashtbl
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #_namecache_nchbucket_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_nchbucket_FRAMESIZE   EQU     0
_namecache_nchbucket_STKGUARD    EQU     0
                FGX2_EXPORT _namecache_ncinshash
_namecache_ncinshash            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_namecache_ncinshash_FRAMESIZE
                DO      _namecache_ncinshash_STKGUARD
                BCC     _namecache_ncinshash_stkovf
                CMP     _fcc_stkfloor
                BCS     _namecache_ncinshash_stkok
_namecache_ncinshash_stkovf       JMP     _fcc_stkoflow
                FIN
_namecache_ncinshash_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_namecache_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+_namecache_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_namecache_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_namecache_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+_namecache_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_namecache_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_namecache_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+_namecache_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+_namecache_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_namecache_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_namecache_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+_namecache_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_namecache_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_namecache_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr1
                LDY     #4
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #6
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      12+_namecache_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_namecache_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_namecache_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_namecache_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_namecache_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_namecache_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+_namecache_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_namecache_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #4
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #6
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      12+_namecache_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_namecache_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_namecache_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_namecache_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_namecache_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_namecache_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #_namecache_ncinshash_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_ncinshash_FRAMESIZE   EQU     0
_namecache_ncinshash_STKGUARD    EQU     0
                FGX2_EXPORT _namecache_ncremhash
_namecache_ncremhash            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_namecache_ncremhash_FRAMESIZE
                DO      _namecache_ncremhash_STKGUARD
                BCC     _namecache_ncremhash_stkovf
                CMP     _fcc_stkfloor
                BCS     _namecache_ncremhash_stkok
_namecache_ncremhash_stkovf       JMP     _fcc_stkoflow
                FIN
_namecache_ncremhash_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_namecache_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+_namecache_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_namecache_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+_namecache_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+_namecache_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_namecache_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #4
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #4
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #6
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                TAY
                TSC
                CLC
                ADC     #_namecache_ncremhash_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_ncremhash_FRAMESIZE   EQU     0
_namecache_ncremhash_STKGUARD    EQU     0
                FGX2_EXPORT _namecache_nclru_totail
_namecache_nclru_totail            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_namecache_nclru_totail_FRAMESIZE
                DO      _namecache_nclru_totail_STKGUARD
                BCC     _namecache_nclru_totail_stkovf
                CMP     _fcc_stkfloor
                BCS     _namecache_nclru_totail_stkok
_namecache_nclru_totail_stkovf       JMP     _fcc_stkoflow
                FIN
_namecache_nclru_totail_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L190
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L190
                LDA     #1
                BRA     _namecache_L191
_namecache_L190
                LDA     #0
_namecache_L191
                CMP     #0
                BEQ     _namecache_L189
                TAY
                TSC
                CLC
                ADC     #_namecache_nclru_totail_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L189
                DO      8+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #8
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #12
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                LDY     #12
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #14
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #8
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #10
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     nchtail+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     nchtail
                STA     _fcc_fpr1
                LDY     #12
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #14
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                SEP     #$20
                MX      %10
                LDA     nchtail+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     nchtail
                STA     _fcc_fpr0
                DO      8+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #8
                STA     _fcc_fpr0
                STA     nchtail
                LDA     _fcc_fpr0+2
                STA     nchtail+2
                TAY
                TSC
                CLC
                ADC     #_namecache_nclru_totail_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_nclru_totail_FRAMESIZE   EQU     0
_namecache_nclru_totail_STKGUARD    EQU     0
                FGX2_EXPORT _namecache_nclru_remove
_namecache_nclru_remove            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_namecache_nclru_remove_FRAMESIZE
                DO      _namecache_nclru_remove_STKGUARD
                BCC     _namecache_nclru_remove_stkovf
                CMP     _fcc_stkfloor
                BCS     _namecache_nclru_remove_stkok
_namecache_nclru_remove_stkovf       JMP     _fcc_stkoflow
                FIN
_namecache_nclru_remove_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_namecache_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+_namecache_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_namecache_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #8
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+_namecache_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _namecache_L192
                DO      8+_namecache_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+_namecache_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_namecache_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #12
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #12
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #14
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                BRA     _namecache_L193
_namecache_L192
                DO      8+_namecache_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                STA     nchtail
                LDA     _fcc_fpr0+2
                STA     nchtail+2
_namecache_L193
                TAY
                TSC
                CLC
                ADC     #_namecache_nclru_remove_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_nclru_remove_FRAMESIZE   EQU     0
_namecache_nclru_remove_STKGUARD    EQU     0
                FGX2_EXPORT _namecache_nclru_tohead
_namecache_nclru_tohead            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_namecache_nclru_tohead_FRAMESIZE
                DO      _namecache_nclru_tohead_STKGUARD
                BCC     _namecache_nclru_tohead_stkovf
                CMP     _fcc_stkfloor
                BCS     _namecache_nclru_tohead_stkok
_namecache_nclru_tohead_stkovf       JMP     _fcc_stkoflow
                FIN
_namecache_nclru_tohead_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_namecache_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     nchhead+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     nchhead
                STA     _fcc_fpr1
                LDY     #8
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #10
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+_namecache_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #nchhead
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                LDY     #12
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #14
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                SEP     #$20
                MX      %10
                LDA     nchhead+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     nchhead
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _namecache_L194
                SEP     #$20
                MX      %10
                LDA     nchhead+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     nchhead
                STA     _fcc_fpr0
                DO      8+_namecache_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_namecache_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #8
                STA     _fcc_fpr1
                LDY     #12
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #14
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                BRA     _namecache_L195
_namecache_L194
                DO      8+_namecache_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #8
                STA     _fcc_fpr0
                STA     nchtail
                LDA     _fcc_fpr0+2
                STA     nchtail+2
_namecache_L195
                DO      8+_namecache_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                STA     nchhead
                LDA     _fcc_fpr0+2
                STA     nchhead+2
                TAY
                TSC
                CLC
                ADC     #_namecache_nclru_tohead_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_nclru_tohead_FRAMESIZE   EQU     0
_namecache_nclru_tohead_STKGUARD    EQU     0
                FGX2_EXPORT _namecache_ncdetach
_namecache_ncdetach            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_namecache_ncdetach_FRAMESIZE
                DO      _namecache_ncdetach_STKGUARD
                BCC     _namecache_ncdetach_stkovf
                CMP     _fcc_stkfloor
                BCS     _namecache_ncdetach_stkok
_namecache_ncdetach_stkovf       JMP     _fcc_stkoflow
                FIN
_namecache_ncdetach_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_namecache_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_ncremhash
                TSC
                CLC
                ADC     #4
                TCS
                DO      8+_namecache_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      8+_namecache_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_namecache_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+_namecache_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr1
                LDY     #4
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #6
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #_namecache_ncdetach_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_ncdetach_FRAMESIZE   EQU     0
_namecache_ncdetach_STKGUARD    EQU     0
                FGX2_EXPORT nchinit
nchinit            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #nchinit_FRAMESIZE
                DO      nchinit_STKGUARD
                BCC     nchinit_stkovf
                CMP     _fcc_stkfloor
                BCS     nchinit_stkok
nchinit_stkovf       JMP     _fcc_stkoflow
                FIN
nchinit_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+nchinit_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+nchinit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+nchinit_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+nchinit_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+nchinit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+nchinit_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                STA     namecache_pool
                LDA     _fcc_fpr0+2
                STA     namecache_pool+2
                LDA     #1
                JSR     _fcc_long_from_int
                STA     vnode_next_id
                TAY
                LDA     _fcc_long_hi
                STA     vnode_next_id+2
                TYA
                LDA     #0
                STA     nchstats+0
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     nchstats+2
                TYA
                LDA     #0
                STA     nchstats+4
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     nchstats+6
                TYA
                LDA     #0
                STA     nchstats+8
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     nchstats+10
                TYA
                LDA     #0
                STA     nchstats+12
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     nchstats+14
                TYA
                LDA     #0
                STA     nchstats+16
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     nchstats+18
                TYA
                LDA     #0
                STA     nchstats+20
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     nchstats+22
                TYA
                LDA     #0
                STA     nchstats+24
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     nchstats+26
                TYA
                LDA     #0
                STA     nchstats+28
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     nchstats+30
                TYA
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_img0
_namecache_L196
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #16
                BVC     _namecache_L199
                EOR     #$8000
_namecache_L199
                BPL     _namecache_L198
                LDA     _fcc_img0
                ASL
                ASL
                ASL
                CLC
                ADC     #nchashtbl
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_fpr0
                STA     7,S   ; fccstk d=0 b=7
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr1+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0
                LDA     _fcc_fpr1
                LDY     #4
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #6
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
_namecache_L197
                INC     _fcc_img0
                BRA     _namecache_L196
_namecache_L198
                LDA     _fcc_img0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     nchhead
                TAY
                LDA     #0
                STA     nchhead+2
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nchhead
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     nchtail
                LDA     _fcc_fpr0+2
                STA     nchtail+2
                SEP     #$20
                MX      %10
                LDA     namecache_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     namecache_pool
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L201
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L201
                LDA     #1
                BRA     _namecache_L202
_namecache_L201
                LDA     #0
_namecache_L202
                CMP     #0
                BEQ     _namecache_L200
                LDA     #0
                STA     doingcache
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #nchinit_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L200
                LDA     #64
                TAX
                SEC
                SBC     #1
                STA     1,S   ; fccstk d=0 b=1
_namecache_L203
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                CMP     #0
                BPL     *+5
                BRL     _namecache_L205
                SEP     #$20
                MX      %10
                LDA     namecache_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     namecache_pool
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_fpr0
                STA     3,S   ; fccstk d=0 b=3
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #16
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #18
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #24
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #26
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDA     #0
                JSR     _fcc_long_from_int
                LDY     #20
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #22
                STA     [_fcc_fpr0],Y
                TXA
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDA     #0
                JSR     _fcc_long_from_int
                LDY     #28
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #30
                STA     [_fcc_fpr0],Y
                TXA
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDA     #0
                SEP     #$20
                MX      %10
                LDY     #32
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDA     _fcc_fpr1
                LDY     #4
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #6
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_nclru_tohead
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L204
                LDA     1,S   ; fccstk d=0 b=1
                SEC
                SBC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRL     _namecache_L203
_namecache_L205
                SEP     #$20
                MX      %10
                LDA     namecache_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     namecache_pool
                STA     _fcc_fpr0
                LDA     #64
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #nchinit_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
nchinit_FRAMESIZE   EQU     10
nchinit_STKGUARD    EQU     0
                FGX2_EXPORT namehash
namehash            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #namehash_FRAMESIZE
                DO      namehash_STKGUARD
                BCC     namehash_stkovf
                CMP     _fcc_stkfloor
                BCS     namehash_stkok
namehash_stkovf       JMP     _fcc_stkoflow
                FIN
namehash_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+namehash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+namehash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+namehash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img1
                DO      6+namehash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+namehash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+namehash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img2
                DO      8+namehash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+namehash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+namehash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img3
                LDA     #0
                STA     _fcc_img4
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     _fcc_img5
                TYA
                LDA     #0
                STA     _fcc_img0
_namecache_L206
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _namecache_L209
                EOR     #$8000
_namecache_L209
                BMI     *+5
                BRL     _namecache_L208
                LDA     _fcc_img5
                STA     _fcc_long_hi
                LDA     _fcc_img4
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img5
                STA     _fcc_long_hi
                LDA     _fcc_img4
                STA     _fcc_long_b_hi
                LDA     _fcc_long_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                STA     _fcc_long_hi
                LDA     _fcc_long_b_hi
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                AND     #$00FF
                LDX     #0
                STX     _fcc_long_hi
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     _fcc_img4
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img5
                TYA
_namecache_L207
                INC     _fcc_img0
                BRL     _namecache_L206
_namecache_L208
                LDA     _fcc_img5
                STA     _fcc_long_hi
                LDA     _fcc_img4
                TAY
                TSC
                CLC
                ADC     #namehash_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
namehash_FRAMESIZE   EQU     6
namehash_STKGUARD    EQU     0
                FGX2_EXPORT _namecache_namecmp
_namecache_namecmp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_namecache_namecmp_FRAMESIZE
                DO      _namecache_namecmp_STKGUARD
                BCC     _namecache_namecmp_stkovf
                CMP     _fcc_stkfloor
                BCS     _namecache_namecmp_stkok
_namecache_namecmp_stkovf       JMP     _fcc_stkoflow
                FIN
_namecache_namecmp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      14+_namecache_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_namecache_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_namecache_namecmp_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_img0
                DO      6+_namecache_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_namecmp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+_namecache_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_namecmp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
                DO      10+_namecache_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_namecache_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_namecache_namecmp_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img3
                DO      12+_namecache_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_namecache_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_namecache_namecmp_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img4
_namecache_L210
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                DEC
                STA     _fcc_img0
                LDA     _fcc_tmp_b
                BEQ     _namecache_L211
                LDA     [_fcc_img1]
                INC     _fcc_img1
                AND     #$00FF
                PHA
                LDA     [_fcc_img3]
                INC     _fcc_img3
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _namecache_L212
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #_namecache_namecmp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L212
                BRA     _namecache_L210
_namecache_L211
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_namecache_namecmp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_namecmp_FRAMESIZE   EQU     0
_namecache_namecmp_STKGUARD    EQU     0
                FGX2_EXPORT cache_purge
cache_purge            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #cache_purge_FRAMESIZE
                DO      cache_purge_STKGUARD
                BCC     cache_purge_stkovf
                CMP     _fcc_stkfloor
                BCS     cache_purge_stkok
cache_purge_stkovf       JMP     _fcc_stkoflow
                FIN
cache_purge_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+cache_purge_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_purge_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_purge_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+cache_purge_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_purge_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_purge_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     vnode_next_id+2
                STA     _fcc_long_hi
                LDA     vnode_next_id
                STA     _fcc_tmp_b
                LDA     _fcc_long_hi
                PHA
                LDA     _fcc_tmp_b
                JSR     _fcc_long_add
                STA     vnode_next_id
                TAY
                LDA     _fcc_long_hi
                STA     vnode_next_id+2
                TYA
                PLA
                STA     _fcc_long_hi
                LDA     _fcc_tmp_b
                LDY     #14
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #16
                STA     [_fcc_fpr0],Y
                TXA
                DO      8+cache_purge_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_purge_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_purge_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+cache_purge_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_purge_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_purge_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #16
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #14
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _namecache_L213
                TAY
                TSC
                CLC
                ADC     #cache_purge_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L213
                LDA     #0
                STA     _fcc_img0
_namecache_L214
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #16
                BVC     _namecache_L217
                EOR     #$8000
_namecache_L217
                BMI     *+5
                BRL     _namecache_L216
                LDA     _fcc_img0
                ASL
                ASL
                ASL
                CLC
                ADC     #nchashtbl
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_namecache_L218
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L221
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L221
                LDA     #0
                BRA     _namecache_L222
_namecache_L221
                LDA     #1
_namecache_L222
                CMP     #0
                BEQ     _namecache_L220
                LDA     #0
                JSR     _fcc_long_from_int
                LDY     #28
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #30
                STA     [_fcc_fpr0],Y
                TXA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                JSR     _fcc_long_from_int
                LDY     #20
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #22
                STA     [_fcc_fpr0],Y
                TXA
_namecache_L219
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _namecache_L218
_namecache_L220
_namecache_L215
                INC     _fcc_img0
                BRL     _namecache_L214
_namecache_L216
                DO      8+cache_purge_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_purge_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_purge_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+cache_purge_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_purge_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_purge_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     vnode_next_id+2
                STA     _fcc_long_hi
                LDA     vnode_next_id
                STA     _fcc_tmp_b
                LDA     _fcc_long_hi
                PHA
                LDA     _fcc_tmp_b
                JSR     _fcc_long_add
                STA     vnode_next_id
                TAY
                LDA     _fcc_long_hi
                STA     vnode_next_id+2
                TYA
                PLA
                STA     _fcc_long_hi
                LDA     _fcc_tmp_b
                LDY     #14
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #16
                STA     [_fcc_fpr0],Y
                TXA
                TAY
                TSC
                CLC
                ADC     #cache_purge_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
cache_purge_FRAMESIZE   EQU     10
cache_purge_STKGUARD    EQU     0
                FGX2_EXPORT cache_purgevfs
cache_purgevfs            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #cache_purgevfs_FRAMESIZE
                DO      cache_purgevfs_STKGUARD
                BCC     cache_purgevfs_stkovf
                CMP     _fcc_stkfloor
                BCS     cache_purgevfs_stkok
cache_purgevfs_stkovf       JMP     _fcc_stkoflow
                FIN
cache_purgevfs_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     13,S   ; fccstk d=0 b=13
_namecache_L223
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                SEC
                SBC     #16
                BVC     _namecache_L226
                EOR     #$8000
_namecache_L226
                BMI     *+5
                BRL     _namecache_L225
                LDA     13,S   ; fccstk d=0 b=13
                ASL
                ASL
                ASL
                CLC
                ADC     #nchashtbl
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_namecache_L227
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr1+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L230
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L230
                LDA     #0
                BRA     _namecache_L231
_namecache_L230
                LDA     #1
_namecache_L231
                CMP     #0
                BNE     *+5
                BRL     _namecache_L229
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #16
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #18
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L234
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L234
                LDA     #1
                BRA     _namecache_L235
_namecache_L234
                LDA     #0
_namecache_L235
                CMP     #0
                BNE     _namecache_L233
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #16
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #18
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #18
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #20
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+cache_purgevfs_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_purgevfs_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_purgevfs_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+cache_purgevfs_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_purgevfs_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_purgevfs_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L236
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L236
                LDA     #0
                BRA     _namecache_L237
_namecache_L236
                LDA     #1
_namecache_L237
                CMP     #0
                BEQ     _namecache_L232
_namecache_L233
                BRL     _namecache_L228
_namecache_L232
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #24
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #26
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #16
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #18
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                SEP     #$20
                MX      %10
                LDY     #32
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_ncdetach
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_nclru_remove
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_nclru_tohead
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L228
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _namecache_L227
_namecache_L229
_namecache_L224
                LDA     13,S   ; fccstk d=0 b=13
                CLC
                ADC     #1
                STA     13,S   ; fccstk d=0 b=13
                BRL     _namecache_L223
_namecache_L225
                TAY
                TSC
                CLC
                ADC     #cache_purgevfs_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
cache_purgevfs_FRAMESIZE   EQU     14
cache_purgevfs_STKGUARD    EQU     0
                FGX2_EXPORT cache_lookup
cache_lookup            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #cache_lookup_FRAMESIZE
                DO      cache_lookup_STKGUARD
                BCC     cache_lookup_stkovf
                CMP     _fcc_stkfloor
                BCS     cache_lookup_stkok
cache_lookup_stkovf       JMP     _fcc_stkoflow
                FIN
cache_lookup_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     doingcache
                BNE     _namecache_L238
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #cache_lookup_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L238
                DO      8+cache_lookup_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_lookup_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_lookup_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+cache_lookup_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_lookup_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_lookup_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #42
                LDA     [_fcc_fpr0],Y
                TAX
                LDX     #31
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _namecache_L240
                EOR     #$8000
_namecache_L240
                BPL     _namecache_L239
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nchstats+20
                STA     _fcc_fpr0
                PLA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                JSR     _fcc_long_add
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                DO      8+cache_lookup_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_lookup_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_lookup_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+cache_lookup_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_lookup_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_lookup_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                SEP     #$20
                MX      %10
                LDY     #46
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #cache_lookup_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L239
                LDY     #52
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #54
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                DO      8+cache_lookup_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_lookup_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_lookup_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+cache_lookup_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_lookup_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_lookup_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #40
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #38
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _namecache_nchbucket
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_namecache_L241
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L244
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L244
                LDA     #0
                BRA     _namecache_L245
_namecache_L244
                LDA     #1
_namecache_L245
                CMP     #0
                BNE     *+5
                BRL     _namecache_L243
                LDY     #16
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #18
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr1+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L247
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L247
                LDA     #1
                BRA     _namecache_L248
_namecache_L247
                LDA     #0
_namecache_L248
                CMP     #0
                BNE     *+5
                BRL     _namecache_L246
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #22
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #20
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     15,S   ; fccstk d=4 b=11
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=4 b=9
                STA     _fcc_fpr0
                LDY     #16
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _namecache_L246
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #32
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                PHA
                DO      10+cache_lookup_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+cache_lookup_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+cache_lookup_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+cache_lookup_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_lookup_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_lookup_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #42
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _namecache_L246
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #32
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                PHA
                DO      10+cache_lookup_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+cache_lookup_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+cache_lookup_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+cache_lookup_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_lookup_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_lookup_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #28
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #30
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     9,S   ; fccstk d=6 b=3
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=6 b=1
                CLC
                ADC     #33
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_namecmp
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                CMP     #0
                BNE     _namecache_L246
                BRA     _namecache_L243
_namecache_L246
_namecache_L242
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _namecache_L241
_namecache_L243
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L250
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L250
                LDA     #1
                BRA     _namecache_L251
_namecache_L250
                LDA     #0
_namecache_L251
                CMP     #0
                BEQ     _namecache_L249
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nchstats+16
                STA     _fcc_fpr0
                PLA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                JSR     _fcc_long_add
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #cache_lookup_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L249
                DO      8+cache_lookup_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_lookup_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_lookup_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+cache_lookup_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_lookup_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_lookup_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #46
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                CMP     #0
                BNE     _namecache_L252
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nchstats+8
                STA     _fcc_fpr0
                PLA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                JSR     _fcc_long_add
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                BRL     _namecache_L253
_namecache_L252
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #24
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #26
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L255
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L255
                LDA     #1
                BRA     _namecache_L256
_namecache_L255
                LDA     #0
_namecache_L256
                CMP     #0
                BEQ     _namecache_L254
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nchstats+4
                STA     _fcc_fpr0
                PLA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                JSR     _fcc_long_add
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_nclru_totail
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #cache_lookup_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
                BRL     _namecache_L257
_namecache_L254
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #30
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #28
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDY     #24
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #26
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #16
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _namecache_L258
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nchstats+12
                STA     _fcc_fpr0
                PLA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                JSR     _fcc_long_add
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                BRL     _namecache_L259
_namecache_L258
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nchstats
                STA     _fcc_fpr0
                PLA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                JSR     _fcc_long_add
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_nclru_totail
                TSC
                CLC
                ADC     #4
                TCS
                DO      8+cache_lookup_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_lookup_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_lookup_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+cache_lookup_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_lookup_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_lookup_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDY     #24
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #26
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #48
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #50
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #cache_lookup_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L259
_namecache_L257
_namecache_L253
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_nclru_remove
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_ncdetach
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_nclru_tohead
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #cache_lookup_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
cache_lookup_FRAMESIZE   EQU     12
cache_lookup_STKGUARD    EQU     0
                FGX2_EXPORT cache_enter
cache_enter            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #cache_enter_FRAMESIZE
                DO      cache_enter_STKGUARD
                BCC     cache_enter_stkovf
                CMP     _fcc_stkfloor
                BCS     cache_enter_stkok
cache_enter_stkovf       JMP     _fcc_stkoflow
                FIN
cache_enter_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     doingcache
                BNE     _namecache_L260
                TAY
                TSC
                CLC
                ADC     #cache_enter_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L260
                DO      8+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #42
                LDA     [_fcc_fpr0],Y
                TAX
                LDX     #31
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _namecache_L262
                EOR     #$8000
_namecache_L262
                BPL     _namecache_L261
                TAY
                TSC
                CLC
                ADC     #cache_enter_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L261
                SEP     #$20
                MX      %10
                LDA     nchhead+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     nchhead
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L264
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L264
                LDA     #1
                BRA     _namecache_L265
_namecache_L264
                LDA     #0
_namecache_L265
                CMP     #0
                BEQ     _namecache_L263
                TAY
                TSC
                CLC
                ADC     #cache_enter_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L263
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_nclru_remove
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_ncremhash
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                DO      8+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #48
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #50
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #24
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #26
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #48
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #50
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _namecache_L266
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                DO      8+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #48
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #50
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #16
                LDA     [_fcc_fpr1],Y
                STA     _fcc_long_hi
                LDY     #14
                LDA     [_fcc_fpr1],Y
                LDY     #28
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #30
                STA     [_fcc_fpr0],Y
                TXA
                BRA     _namecache_L267
_namecache_L266
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                JSR     _fcc_long_from_int
                LDY     #28
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #30
                STA     [_fcc_fpr0],Y
                TXA
_namecache_L267
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                DO      8+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #52
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #54
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #16
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #18
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                DO      8+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #52
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #54
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #16
                LDA     [_fcc_fpr1],Y
                STA     _fcc_long_hi
                LDY     #14
                LDA     [_fcc_fpr1],Y
                LDY     #20
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #22
                STA     [_fcc_fpr0],Y
                TXA
                LDA     _fcc_fpr0
                DO      8+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #42
                LDA     [_fcc_fpr1],Y
                AND     #$00FF
                SEP     #$20
                MX      %10
                LDY     #32
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_img0
_namecache_L268
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                PHA
                DO      10+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+cache_enter_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_enter_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #42
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                BVC     _namecache_L271
                EOR     #$8000
_namecache_L271
                BPL     _namecache_L270
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #33
                STA     _fcc_fpr0
                LDA     _fcc_img0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                DO      8+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #28
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #30
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDA     _fcc_img0
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
_namecache_L269
                INC     _fcc_img0
                BRL     _namecache_L268
_namecache_L270
                LDA     _fcc_img0
                STA     5,S   ; fccstk d=0 b=5
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #8
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #10
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     nchtail+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     nchtail
                STA     _fcc_fpr1
                LDY     #12
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #14
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                SEP     #$20
                MX      %10
                LDA     nchtail+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     nchtail
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #8
                STA     nchtail
                LDA     _fcc_fpr0+2
                STA     nchtail+2
                DO      8+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+cache_enter_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+cache_enter_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+cache_enter_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #40
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #38
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _namecache_nchbucket
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_ncinshash
                TSC
                CLC
                ADC     #8
                TCS
                TAY
                TSC
                CLC
                ADC     #cache_enter_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
cache_enter_FRAMESIZE   EQU     6
cache_enter_STKGUARD    EQU     0
                FGX2_EXPORT _namecache_seek
_namecache_seek            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_namecache_seek_FRAMESIZE
                DO      _namecache_seek_STKGUARD
                BCC     _namecache_seek_stkovf
                CMP     _fcc_stkfloor
                BCS     _namecache_seek_stkok
_namecache_seek_stkovf       JMP     _fcc_stkoflow
                FIN
_namecache_seek_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_img0
_namecache_L272
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                DO      12+_namecache_seek_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_namecache_seek_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_namecache_seek_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_ptr+2
                DO      10+_namecache_seek_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_namecache_seek_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_namecache_seek_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                CMP     #0
                BEQ     _namecache_L273
                INC     _fcc_img0
                BRA     _namecache_L272
_namecache_L273
                LDA     _fcc_img0
                STA     1,S   ; fccstk d=0 b=1
                DO      8+_namecache_seek_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_namecache_seek_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_namecache_seek_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_namecache_seek_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_namecache_seek_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_namecache_seek_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     nd+52
                TAY
                LDA     _fcc_ptr+2
                STA     nd+54
                TYA
                DO      12+_namecache_seek_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_namecache_seek_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_namecache_seek_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_namecache_seek_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_namecache_seek_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_namecache_seek_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     nd+28
                TAY
                LDA     _fcc_ptr+2
                STA     nd+30
                TYA
                LDA     1,S   ; fccstk d=0 b=1
                STA     nd+42
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL namehash
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     nd+38
                TAY
                LDA     _fcc_long_hi
                STA     nd+40
                TYA
                LDA     #1
                SEP     #$20
                MX      %10
                STA     nd+46
                REP     #$20
                MX      %00
                LDA     #0
                STA     nd+48
                TAY
                LDA     #0
                STA     nd+50
                TYA
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #_namecache_seek_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_seek_FRAMESIZE   EQU     2
_namecache_seek_STKGUARD    EQU     0
                FGX2_EXPORT _namecache_hashed
_namecache_hashed            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_namecache_hashed_FRAMESIZE
                DO      _namecache_hashed_STKGUARD
                BCC     _namecache_hashed_stkovf
                CMP     _fcc_stkfloor
                BCS     _namecache_hashed_stkok
_namecache_hashed_stkovf       JMP     _fcc_stkoflow
                FIN
_namecache_hashed_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_namecache_L274
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #16
                BVC     _namecache_L277
                EOR     #$8000
_namecache_L277
                BMI     *+5
                BRL     _namecache_L276
                LDA     _fcc_img0
                ASL
                ASL
                ASL
                CLC
                ADC     #nchashtbl
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_namecache_L278
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L281
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L281
                LDA     #0
                BRA     _namecache_L282
_namecache_L281
                LDA     #1
_namecache_L282
                CMP     #0
                BEQ     _namecache_L280
                LDA     _fcc_img1
                INC
                STA     _fcc_img1
                PHA
                LDA     #64
                TAX
                INC
                INC
                STA     _fcc_tmp_b
                PLA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _namecache_L284
                EOR     #$8000
_namecache_L284
                BPL     _namecache_L283
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_namecache_hashed_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L283
_namecache_L279
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _namecache_L278
_namecache_L280
_namecache_L275
                INC     _fcc_img0
                BRL     _namecache_L274
_namecache_L276
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #_namecache_hashed_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_hashed_FRAMESIZE   EQU     12
_namecache_hashed_STKGUARD    EQU     0
                FGX2_EXPORT _namecache_lrulen
_namecache_lrulen            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_namecache_lrulen_FRAMESIZE
                DO      _namecache_lrulen_STKGUARD
                BCC     _namecache_lrulen_stkovf
                CMP     _fcc_stkfloor
                BCS     _namecache_lrulen_stkok
_namecache_lrulen_stkovf       JMP     _fcc_stkoflow
                FIN
_namecache_lrulen_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
                SEP     #$20
                MX      %10
                LDA     nchhead+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     nchhead
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_namecache_L285
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _namecache_L287
                LDY     #12
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L290
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L290
                LDA     #1
                BRA     _namecache_L291
_namecache_L290
                LDA     #0
_namecache_L291
                CMP     #0
                BNE     _namecache_L289
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L292
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L292
                LDA     #0
                BRA     _namecache_L293
_namecache_L292
                LDA     #1
_namecache_L293
                CMP     #0
                BEQ     _namecache_L288
_namecache_L289
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_namecache_lrulen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L288
                LDA     _fcc_img0
                INC
                STA     _fcc_img0
                PHA
                LDA     #64
                TAX
                INC
                INC
                STA     _fcc_tmp_b
                PLA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _namecache_L295
                EOR     #$8000
_namecache_L295
                BPL     _namecache_L294
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_namecache_lrulen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L294
_namecache_L286
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _namecache_L285
_namecache_L287
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #_namecache_lrulen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_lrulen_FRAMESIZE   EQU     6
_namecache_lrulen_STKGUARD    EQU     0
                FGX2_EXPORT _namecache_reset
_namecache_reset            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_namecache_reset_FRAMESIZE
                DO      _namecache_reset_STKGUARD
                BCC     _namecache_reset_stkovf
                CMP     _fcc_stkfloor
                BCS     _namecache_reset_stkok
_namecache_reset_stkovf       JMP     _fcc_stkoflow
                FIN
_namecache_reset_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_nc_arena
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vntblinit
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL nchinit
                TSC
                CLC
                ADC     #4
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ufs_cacheops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vfs_setcacheops
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #0
                STA     mnt_a+16
                TAY
                LDA     #0
                STA     mnt_a+18
                TYA
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                LDA     #0
                STA     mnt_a+20
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     mnt_a+22
                TYA
                LDA     #0
                STA     mnt_b+16
                TAY
                LDA     #0
                STA     mnt_b+18
                TYA
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                LDA     #0
                STA     mnt_b+20
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     mnt_b+22
                TYA
                TAY
                TSC
                CLC
                ADC     #_namecache_reset_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_reset_FRAMESIZE   EQU     0
_namecache_reset_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #main_FRAMESIZE
                DO      main_STKGUARD
                BCC     main_stkovf
                CMP     _fcc_stkfloor
                BCS     main_stkok
main_stkovf       JMP     _fcc_stkoflow
                FIN
main_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #8
                TAX
                CMP     #8
                BEQ     _namecache_L296
                LDA     #51
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L296
                SEP     #$20
                MX      %10
                LDA     namecache_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     namecache_pool
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     namecache_pool+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     namecache_pool
                STA     _fcc_fpr1
                LDA     #0
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                BEQ     _namecache_L297
                LDA     #52
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L297
                SEP     #$20
                MX      %10
                LDA     namecache_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     namecache_pool
                CLC
                ADC     #4
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     namecache_pool+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     namecache_pool
                STA     _fcc_fpr1
                LDA     #0
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #4
                BEQ     _namecache_L298
                LDA     #53
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L298
                LDA     #64
                TAX
                CMP     #64
                BEQ     _namecache_L299
                LDA     #54
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L299
                FGX2_FARCALL _namecache_reset
                FGX2_FARCALL _namecache_lrulen
                TAX
                CMP     #64
                BEQ     _namecache_L300
                LDA     #55
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L300
                FGX2_FARCALL _namecache_hashed
                CMP     #0
                BEQ     _namecache_L301
                LDA     #56
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L301
                SEP     #$20
                MX      %10
                LDA     nchhead+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     nchhead
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     namecache_pool+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     namecache_pool
                STA     _fcc_fpr1
                LDA     #0
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L303
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L303
                LDA     #0
                BRA     _namecache_L304
_namecache_L303
                LDA     #1
_namecache_L304
                CMP     #0
                BEQ     _namecache_L302
                LDA     #57
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L302
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _namecache_L305
                LDA     #58
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L305
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #2
                LDY     #52
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _namecache_L306
                LDA     #59
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L306
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S11
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_lookup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                CMP     #0
                BEQ     _namecache_L307
                LDA     #60
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L307
                LDA     nchstats+18
                STA     _fcc_long_hi
                LDA     nchstats+16
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _namecache_L308
                LDA     #61
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L308
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     nd+48
                TAY
                LDA     _fcc_ptr+2
                STA     nd+50
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_enter
                TSC
                CLC
                ADC     #4
                TCS
                FGX2_FARCALL _namecache_hashed
                TAX
                CMP     #1
                BEQ     _namecache_L309
                LDA     #62
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L309
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S11
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_lookup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                CMP     #$FFFF
                BEQ     _namecache_L310
                LDA     #63
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L310
                LDA     nd+50
                STA     _fcc_fpr0+2
                LDA     nd+48
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L312
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L312
                LDA     #0
                BRA     _namecache_L313
_namecache_L312
                LDA     #1
_namecache_L313
                CMP     #0
                BEQ     _namecache_L311
                LDA     #64
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L311
                LDA     nchstats+2
                STA     _fcc_long_hi
                LDA     nchstats+0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _namecache_L314
                LDA     #65
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L314
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _namecache_L315
                LDA     #66
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L315
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDA     #2
                LDY     #52
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S11
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     15,S   ; fccstk d=4 b=11
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=4 b=9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_lookup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BEQ     _namecache_L316
                LDA     #67
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L316
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S12
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_lookup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BEQ     _namecache_L317
                LDA     #68
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L317
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S13
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_lookup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BEQ     _namecache_L318
                LDA     #69
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L318
                LDA     #0
                STA     nd+48
                TAY
                LDA     #0
                STA     nd+50
                TYA
                STZ     _fcc_fpr0+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_enter
                TSC
                CLC
                ADC     #4
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S13
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                LDA     nchstats+6
                STA     _fcc_long_hi
                LDA     nchstats+4
                STA     23,S   ; fccstk d=0 b=23
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_lookup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                CMP     #2
                BEQ     _namecache_L319
                LDA     #70
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L319
                LDA     nchstats+6
                STA     _fcc_long_hi
                LDA     nchstats+4
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     27,S   ; fccstk d=4 b=23
                TAX
                CLC
                ADC     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _namecache_L320
                LDA     #71
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L320
                FGX2_FARCALL _namecache_reset
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _namecache_L321
                LDA     #72
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L321
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #2
                LDY     #52
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _namecache_L322
                LDA     #73
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L322
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S14
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     nd+48
                TAY
                LDA     _fcc_ptr+2
                STA     nd+50
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_enter
                TSC
                CLC
                ADC     #4
                TCS
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vrele
                TSC
                CLC
                ADC     #4
                TCS
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _namecache_L323
                LDA     #74
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L323
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _namecache_L325
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _namecache_L325
                LDA     #0
                BRA     _namecache_L326
_namecache_L325
                LDA     #1
_namecache_L326
                CMP     #0
                BEQ     _namecache_L324
                LDA     #75
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L324
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
                LDA     nchstats+14
                STA     _fcc_long_hi
                LDA     nchstats+12
                STA     23,S   ; fccstk d=0 b=23
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S14
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_lookup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                CMP     #$FFFF
                BNE     _namecache_L327
                LDA     #76
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L327
                LDA     nchstats+14
                STA     _fcc_long_hi
                LDA     nchstats+12
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     27,S   ; fccstk d=4 b=23
                TAX
                CLC
                ADC     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _namecache_L328
                LDA     #77
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L328
                FGX2_FARCALL _namecache_hashed
                CMP     #0
                BEQ     _namecache_L329
                LDA     #78
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L329
                FGX2_FARCALL _namecache_reset
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _namecache_L330
                LDA     #79
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L330
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #2
                LDY     #52
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _namecache_L331
                LDA     #80
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L331
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S15
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     nd+48
                TAY
                LDA     _fcc_ptr+2
                STA     nd+50
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_enter
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_purge
                TSC
                CLC
                ADC     #4
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S15
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_lookup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BEQ     _namecache_L332
                LDA     #81
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L332
                FGX2_FARCALL _namecache_reset
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _namecache_L333
                LDA     #82
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L333
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #16
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     23,S   ; fccstk d=0 b=23
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_purge
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #16
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #14
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     25,S   ; fccstk d=2 b=23
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _namecache_L334
                LDA     #83
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L334
                FGX2_FARCALL _namecache_reset
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                CMP     #0
                BEQ     _namecache_L335
                LDA     #84
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L335
                LDA     #0
                STA     21,S   ; fccstk d=0 b=21
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_img0
_namecache_L336
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     #31
                TAY
                TYA
                CLC
                ADC     #4
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _namecache_L339
                EOR     #$8000
_namecache_L339
                BPL     _namecache_L338
                LDA     #main_sl_toolong
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #120
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
_namecache_L337
                INC     _fcc_img0
                BRA     _namecache_L336
_namecache_L338
                LDA     _fcc_img0
                STA     21,S   ; fccstk d=0 b=21
                LDA     #main_sl_toolong
                PHA
                LDA     #31
                TAX
                CLC
                ADC     #4
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #0
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     nchstats+22
                STA     _fcc_long_hi
                LDA     nchstats+20
                STA     23,S   ; fccstk d=0 b=23
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #main_sl_toolong
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_lookup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BEQ     _namecache_L340
                LDA     #85
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L340
                LDA     nchstats+22
                STA     _fcc_long_hi
                LDA     nchstats+20
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     27,S   ; fccstk d=4 b=23
                TAX
                CLC
                ADC     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _namecache_L341
                LDA     #86
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L341
                LDA     nd+46
                AND     #$00FF
                BEQ     _namecache_L342
                LDA     #87
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L342
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     nd+48
                TAY
                LDA     _fcc_ptr+2
                STA     nd+50
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_enter
                TSC
                CLC
                ADC     #4
                TCS
                FGX2_FARCALL _namecache_hashed
                CMP     #0
                BEQ     _namecache_L343
                LDA     #88
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L343
                FGX2_FARCALL _namecache_reset
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _namecache_L344
                LDA     #89
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L344
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #2
                LDY     #52
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _namecache_L345
                LDA     #90
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L345
                LDA     #main_sl_nm
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #110
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #main_sl_nm
                PHA
                LDA     #3
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #0
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #0
                STA     21,S   ; fccstk d=0 b=21
_namecache_L346
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     21,S   ; fccstk d=0 b=21
                TAX
                SEC
                SBC     #64
                BVC     _namecache_L349
                EOR     #$8000
_namecache_L349
                BMI     *+5
                BRL     _namecache_L348
                LDA     #main_sl_nm
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #97
                PHA
                LDA     25,S   ; fccstk d=4 b=21
                LDX     #26
                STX     _fcc_tmp_b
                JSR     _fcc_divs16
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                AND     #$00FF
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #main_sl_nm
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #97
                PHA
                LDA     25,S   ; fccstk d=4 b=21
                LDX     #26
                STX     _fcc_tmp_b
                JSR     _fcc_mods16
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                AND     #$00FF
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #main_sl_nm
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     nd+48
                TAY
                LDA     _fcc_ptr+2
                STA     nd+50
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_enter
                TSC
                CLC
                ADC     #4
                TCS
_namecache_L347
                LDA     21,S   ; fccstk d=0 b=21
                CLC
                ADC     #1
                STA     21,S   ; fccstk d=0 b=21
                BRL     _namecache_L346
_namecache_L348
                FGX2_FARCALL _namecache_hashed
                TAX
                CMP     #64
                BEQ     _namecache_L350
                LDA     #91
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L350
                FGX2_FARCALL _namecache_lrulen
                TAX
                CMP     #64
                BEQ     _namecache_L351
                LDA     #92
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L351
                LDA     #main_sl_nm
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #97
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #main_sl_nm
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #97
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #main_sl_nm
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_lookup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                CMP     #$FFFF
                BEQ     _namecache_L352
                LDA     #93
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L352
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     nd+48
                TAY
                LDA     _fcc_ptr+2
                STA     nd+50
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_enter
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #main_sl_nm
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #97
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #main_sl_nm
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #97
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #main_sl_nm
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_lookup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                CMP     #$FFFF
                BEQ     _namecache_L353
                LDA     #94
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L353
                LDA     #main_sl_nm
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #97
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #main_sl_nm
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #98
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #main_sl_nm
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_lookup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BEQ     _namecache_L354
                LDA     #95
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L354
                FGX2_FARCALL _namecache_hashed
                TAX
                CMP     #64
                BEQ     _namecache_L355
                LDA     #96
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L355
                FGX2_FARCALL _namecache_lrulen
                TAX
                CMP     #64
                BEQ     _namecache_L356
                LDA     #97
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L356
                FGX2_FARCALL _namecache_reset
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _namecache_L357
                LDA     #98
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L357
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #2
                LDY     #52
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _namecache_L358
                LDA     #100
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L358
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDA     #2
                LDY     #52
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _namecache_L359
                LDA     #101
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L359
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S17
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     nd+48
                TAY
                LDA     _fcc_ptr+2
                STA     nd+50
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_enter
                TSC
                CLC
                ADC     #4
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S18
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     15,S   ; fccstk d=4 b=11
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=4 b=9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     nd+48
                TAY
                LDA     _fcc_ptr+2
                STA     nd+50
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_enter
                TSC
                CLC
                ADC     #4
                TCS
                FGX2_FARCALL _namecache_hashed
                TAX
                CMP     #2
                BEQ     _namecache_L360
                LDA     #102
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L360
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_purgevfs
                TSC
                CLC
                ADC     #4
                TCS
                FGX2_FARCALL _namecache_hashed
                TAX
                CMP     #1
                BEQ     _namecache_L361
                LDA     #103
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L361
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S17
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_lookup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BEQ     _namecache_L362
                LDA     #104
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L362
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S18
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     15,S   ; fccstk d=4 b=11
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=4 b=9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_lookup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                CMP     #$FFFF
                BEQ     _namecache_L363
                LDA     #105
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L363
                FGX2_FARCALL _namecache_lrulen
                TAX
                CMP     #64
                BEQ     _namecache_L364
                LDA     #106
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L364
                FGX2_FARCALL _namecache_reset
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _namecache_L365
                LDA     #107
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L365
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL getnewvnode
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _namecache_L366
                LDA     #108
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L366
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S19
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     nd+48
                TAY
                LDA     _fcc_ptr+2
                STA     nd+50
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_enter
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #0
                STA     doingcache
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S19
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_lookup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BEQ     _namecache_L367
                LDA     #109
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L367
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_namecache_S20
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _namecache_seek
                TSC
                CLC
                ADC     #8
                TCS
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     nd+48
                TAY
                LDA     _fcc_ptr+2
                STA     nd+50
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL cache_enter
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #1
                STA     doingcache
                FGX2_FARCALL _namecache_hashed
                TAX
                CMP     #1
                BEQ     _namecache_L368
                LDA     #110
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_namecache_L368
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     24
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 219
