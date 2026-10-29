                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from vnodepool.c
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
                LDA     _vnodepool_nslept
                INC
                STA     _vnodepool_nslept
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
                LDA     _vnodepool_invalbufs
                INC
                STA     _vnodepool_invalbufs
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
                FGX2_EXPORT _vnodepool_op_nop
_vnodepool_op_nop            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vnodepool_op_nop_FRAMESIZE
                DO      _vnodepool_op_nop_STKGUARD
                BCC     _vnodepool_op_nop_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_op_nop_stkok
_vnodepool_op_nop_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_op_nop_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_vnodepool_op_nop_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_op_nop_FRAMESIZE   EQU     0
_vnodepool_op_nop_STKGUARD    EQU     0
                FGX2_EXPORT _vnodepool_op_lock
_vnodepool_op_lock            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vnodepool_op_lock_FRAMESIZE
                DO      _vnodepool_op_lock_STKGUARD
                BCC     _vnodepool_op_lock_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_op_lock_stkok
_vnodepool_op_lock_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_op_lock_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     _vnodepool_nlock
                INC
                STA     _vnodepool_nlock
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_vnodepool_op_lock_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_op_lock_FRAMESIZE   EQU     0
_vnodepool_op_lock_STKGUARD    EQU     0
                FGX2_EXPORT _vnodepool_op_unlock
_vnodepool_op_unlock            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vnodepool_op_unlock_FRAMESIZE
                DO      _vnodepool_op_unlock_STKGUARD
                BCC     _vnodepool_op_unlock_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_op_unlock_stkok
_vnodepool_op_unlock_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_op_unlock_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     _vnodepool_nunlock
                INC
                STA     _vnodepool_nunlock
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_vnodepool_op_unlock_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_op_unlock_FRAMESIZE   EQU     0
_vnodepool_op_unlock_STKGUARD    EQU     0
                FGX2_EXPORT _vnodepool_op_inactive
_vnodepool_op_inactive            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vnodepool_op_inactive_FRAMESIZE
                DO      _vnodepool_op_inactive_STKGUARD
                BCC     _vnodepool_op_inactive_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_op_inactive_stkok
_vnodepool_op_inactive_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_op_inactive_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     _vnodepool_ninactive
                INC
                STA     _vnodepool_ninactive
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_vnodepool_op_inactive_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_op_inactive_FRAMESIZE   EQU     0
_vnodepool_op_inactive_STKGUARD    EQU     0
                FGX2_EXPORT _vnodepool_op_reclaim
_vnodepool_op_reclaim            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vnodepool_op_reclaim_FRAMESIZE
                DO      _vnodepool_op_reclaim_STKGUARD
                BCC     _vnodepool_op_reclaim_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_op_reclaim_stkok
_vnodepool_op_reclaim_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_op_reclaim_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     _vnodepool_nreclaim
                INC
                STA     _vnodepool_nreclaim
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_vnodepool_op_reclaim_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_op_reclaim_FRAMESIZE   EQU     0
_vnodepool_op_reclaim_STKGUARD    EQU     0
                FGX2_EXPORT _vnodepool_op_close
_vnodepool_op_close            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vnodepool_op_close_FRAMESIZE
                DO      _vnodepool_op_close_STKGUARD
                BCC     _vnodepool_op_close_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_op_close_stkok
_vnodepool_op_close_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_op_close_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     _vnodepool_nclose
                INC
                STA     _vnodepool_nclose
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_vnodepool_op_close_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_op_close_FRAMESIZE   EQU     0
_vnodepool_op_close_STKGUARD    EQU     0
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
                BNE     _vnodepool_L0
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
_vnodepool_L0
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
                BNE     _vnodepool_L1
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
_vnodepool_L1
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
                BNE     _vnodepool_L2
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
_vnodepool_L2
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
                BNE     _vnodepool_L3
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
_vnodepool_L3
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
                BNE     _vnodepool_L4
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
_vnodepool_L4
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
                BNE     _vnodepool_L5
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
_vnodepool_L5
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
                BNE     _vnodepool_L6
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
_vnodepool_L6
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
                BNE     _vnodepool_L7
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
_vnodepool_L7
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
                STA     _vnodepool_vfs_cacheops
                LDA     _fcc_fpr0+2
                STA     _vnodepool_vfs_cacheops+2
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
                STA     _vnodepool_vfs_specops
                LDA     _fcc_fpr0+2
                STA     _vnodepool_vfs_specops+2
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
                FGX2_EXPORT _vnodepool_zerobytes
_vnodepool_zerobytes            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vnodepool_zerobytes_FRAMESIZE
                DO      _vnodepool_zerobytes_STKGUARD
                BCC     _vnodepool_zerobytes_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_zerobytes_stkok
_vnodepool_zerobytes_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_zerobytes_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+_vnodepool_zerobytes_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vnodepool_zerobytes_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vnodepool_zerobytes_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img0
                DO      6+_vnodepool_zerobytes_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vnodepool_zerobytes_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vnodepool_zerobytes_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+_vnodepool_zerobytes_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vnodepool_zerobytes_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vnodepool_zerobytes_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
_vnodepool_L8
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                DEC
                STA     _fcc_img0
                LDA     _fcc_tmp_b
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCS     _vnodepool_L9
                LDA     #0
                SEP     #$20
                MX      %10
                STA     [_fcc_img1]
                REP     #$20
                MX      %00
                INC     _fcc_img1
                BRA     _vnodepool_L8
_vnodepool_L9
                TAY
                TSC
                CLC
                ADC     #_vnodepool_zerobytes_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_zerobytes_FRAMESIZE   EQU     0
_vnodepool_zerobytes_STKGUARD    EQU     0
                FGX2_EXPORT vntblinit
vntblinit            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                TSC
                SEC
                SBC     #vntblinit_FRAMESIZE-6
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
                STA     _fcc_img18
_vnodepool_L10
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img18
                TAX
                SEC
                SBC     #8
                BVC     _vnodepool_L13
                EOR     #$8000
_vnodepool_L13
                BPL     _vnodepool_L12
                LDA     #speclisth
                PHA
                LDA     _fcc_img18
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
_vnodepool_L11
                INC     _fcc_img18
                BRA     _vnodepool_L10
_vnodepool_L12
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
                FGX2_FARCALL _vnodepool_zerobytes
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
                FGX2_FARCALL _vnodepool_zerobytes
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #0
                STA     _fcc_img18
_vnodepool_L14
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img18
                TAX
                SEC
                SBC     #64
                BVC     _vnodepool_L17
                EOR     #$8000
_vnodepool_L17
                BPL     _vnodepool_L16
                SEP     #$20
                MX      %10
                LDA     vnode_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_pool
                STA     _fcc_fpr0
                LDA     _fcc_img18
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #8
                LDY     #52
                STA     [_fcc_img16],Y
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vfree
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L15
                INC     _fcc_img18
                BRA     _vnodepool_L14
_vnodepool_L16
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
                ADC     #vntblinit_FRAMESIZE-6
                TCS
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
vntblinit_FRAMESIZE   EQU     12
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
                STA     _fcc_img0
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
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #26
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #28
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img0
                SEP     #$20
                MX      %10
                LDA     vnode_free_tail+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     vnode_free_tail
                STA     _fcc_fpr1
                LDY     #30
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #32
                STA     [_fcc_img0],Y
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
                LDA     _fcc_img0
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_img1
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
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
                STA     _fcc_img0
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
                STA     _fcc_img1
                LDY     #30
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #32
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #26
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #28
                LDA     [_fcc_img0],Y
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
                LDY     #26
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #28
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vnodepool_L18
                LDY     #26
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #28
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #30
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #32
                LDA     [_fcc_img0],Y
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
                BRA     _vnodepool_L19
_vnodepool_L18
                LDY     #30
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #32
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                STA     vnode_free_tail
                LDA     _fcc_fpr0+2
                STA     vnode_free_tail+2
_vnodepool_L19
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #26
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #28
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #30
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #32
                STA     [_fcc_img0],Y
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
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #getnewvnode_FRAMESIZE-4
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L21
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L21
                LDA     #1
                BRA     _vnodepool_L22
_vnodepool_L21
                LDA     #0
_vnodepool_L22
                CMP     #0
                BEQ     _vnodepool_L20
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
                ADC     #getnewvnode_FRAMESIZE-4
                TCS
                BRL     getnewvnode_bandx
_vnodepool_L20
                LDY     #2
                LDA     [_fcc_img16],Y
                BEQ     _vnodepool_L23
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vnodepool_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L23
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vremfree
                TSC
                CLC
                ADC     #4
                TCS
                LDY     #52
                LDA     [_fcc_img16],Y
                TAX
                CMP     #8
                BEQ     _vnodepool_L24
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L24
                LDA     #0
                STA     [_fcc_img16]
                LDA     #1
                LDY     #2
                STA     [_fcc_img16],Y
                LDA     #0
                LDY     #4
                STA     [_fcc_img16],Y
                LDA     #0
                LDY     #52
                STA     [_fcc_img16],Y
                LDA     _fcc_img16
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
                STA     [_fcc_img16],Y
                LDA     #0
                JSR     _fcc_long_from_int
                LDY     #10
                STA     [_fcc_img16],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #12
                STA     [_fcc_img16],Y
                TXA
                LDA     #0
                LDY     #50
                STA     [_fcc_img16],Y
                LDA     #0
                LDY     #6
                STA     [_fcc_img16],Y
                LDA     #0
                LDY     #8
                STA     [_fcc_img16],Y
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #42
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #44
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #46
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #48
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #54
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #56
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img16
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
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #24
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #18
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #20
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                SEP     #$20
                MX      %10
                LDA     _vnodepool_vfs_cacheops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _vnodepool_vfs_cacheops
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vnodepool_L25
                SEP     #$20
                MX      %10
                LDA     _vnodepool_vfs_cacheops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _vnodepool_vfs_cacheops
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
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vnodepool_L26-1
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
_vnodepool_L26
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
_vnodepool_L25
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
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
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
                LDA     _fcc_img16
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_img17
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #getnewvnode_FRAMESIZE-4
                TCS
getnewvnode_bandx
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
getnewvnode_FRAMESIZE   EQU     8
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
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vnodepool_L28
                EOR     #$8000
_vnodepool_L28
                BMI     _vnodepool_L27
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vnodepool_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L27
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
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #vget_FRAMESIZE-4
                DO      vget_STKGUARD
                BCC     vget_stkovf
                CMP     _fcc_stkfloor
                BCS     vget_stkok
vget_stkovf       JMP     _fcc_stkoflow
                FIN
vget_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img16
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
                STA     _fcc_img17
                LDA     [_fcc_img16]
                TAX
                AND     #256
                BEQ     _vnodepool_L29
                LDA     [_fcc_img16]
                TAX
                ORA     #512
                STA     [_fcc_img16]
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL kc_sleep
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #vget_FRAMESIZE-4
                TCS
                BRA     vget_bandx
_vnodepool_L29
                LDY     #2
                LDA     [_fcc_img16],Y
                BNE     _vnodepool_L30
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vremfree
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L30
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
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
                ADC     #vget_FRAMESIZE-4
                TCS
vget_bandx
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
vget_FRAMESIZE   EQU     4
vget_STKGUARD    EQU     0
                FGX2_EXPORT vrele
vrele            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #vrele_FRAMESIZE-4
                DO      vrele_STKGUARD
                BCC     vrele_stkovf
                CMP     _fcc_stkfloor
                BCS     vrele_stkok
vrele_stkovf       JMP     _fcc_stkoflow
                FIN
vrele_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img16
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
                STA     _fcc_img17
                LDY     #2
                LDA     [_fcc_img16],Y
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vnodepool_L32
                EOR     #$8000
_vnodepool_L32
                BMI     _vnodepool_L31
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vnodepool_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L31
                LDY     #2
                LDA     [_fcc_img16],Y
                DEC
                LDY     #2
                STA     [_fcc_img16],Y
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vnodepool_L34
                EOR     #$8000
_vnodepool_L34
                BPL     _vnodepool_L33
                TAY
                TSC
                CLC
                ADC     #vrele_FRAMESIZE-4
                TCS
                BRA     vrele_bandx
_vnodepool_L33
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vfree
                TSC
                CLC
                ADC     #4
                TCS
                LDY     #22
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #24
                LDA     [_fcc_img16],Y
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
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vnodepool_L35-1
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
_vnodepool_L35
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #vrele_FRAMESIZE-4
                TCS
vrele_bandx
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
vrele_FRAMESIZE   EQU     4
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
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vnodepool_L37
                EOR     #$8000
_vnodepool_L37
                BMI     _vnodepool_L36
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vnodepool_S3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L36
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
                STA     _fcc_img0
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
                STA     _fcc_img1
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
                STA     _fcc_img2
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
                STA     _fcc_img3
                LDY     #38
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #40
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _vnodepool_L38
                LDY     #38
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #40
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #34
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #36
                LDA     [_fcc_img0],Y
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
                LDY     #34
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #36
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vnodepool_L39
                LDY     #34
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #36
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #38
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #40
                LDA     [_fcc_img0],Y
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
_vnodepool_L39
_vnodepool_L38
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #34
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #36
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #38
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #40
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img2
                LDY     #18
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img3
                LDY     #20
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L41
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L41
                LDA     #1
                BRA     _vnodepool_L42
_vnodepool_L41
                LDA     #0
_vnodepool_L42
                CMP     #0
                BEQ     _vnodepool_L40
                TAY
                TSC
                CLC
                ADC     #insmntque_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_L40
                LDY     #16
                LDA     [_fcc_img2],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #18
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #34
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #36
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDY     #16
                LDA     [_fcc_img2],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #18
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vnodepool_L43
                LDY     #16
                LDA     [_fcc_img2],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #18
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img1
                STA     _fcc_fpr1+2
                LDA     _fcc_img0
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
_vnodepool_L43
                LDA     _fcc_img0
                LDY     #16
                STA     [_fcc_img2],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img1
                LDY     #18
                STA     [_fcc_img2],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img3
                STA     _fcc_fpr1+2
                LDA     _fcc_img2
                CLC
                ADC     #16
                STA     _fcc_fpr1
                LDY     #38
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #40
                STA     [_fcc_img0],Y
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
                FGX2_EXPORT _vnodepool_specalloc
_vnodepool_specalloc            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                TSC
                SEC
                SBC     #_vnodepool_specalloc_FRAMESIZE-2
                DO      _vnodepool_specalloc_STKGUARD
                BCC     _vnodepool_specalloc_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_specalloc_stkok
_vnodepool_specalloc_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_specalloc_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img16
_vnodepool_L44
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #64
                BVC     _vnodepool_L47
                EOR     #$8000
_vnodepool_L47
                BMI     *+5
                BRL     _vnodepool_L46
                SEP     #$20
                MX      %10
                LDA     specinfo_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     specinfo_pool
                STA     _fcc_fpr0
                LDA     _fcc_img16
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
                BNE     _vnodepool_L49
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L49
                LDA     #1
                BRA     _vnodepool_L50
_vnodepool_L49
                LDA     #0
_vnodepool_L50
                CMP     #0
                BEQ     _vnodepool_L48
                SEP     #$20
                MX      %10
                LDA     specinfo_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     specinfo_pool
                STA     _fcc_fpr0
                LDA     _fcc_img16
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
                DO      8+_vnodepool_specalloc_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vnodepool_specalloc_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vnodepool_specalloc_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vnodepool_specalloc_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vnodepool_specalloc_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vnodepool_specalloc_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     _fcc_img16
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
                ADC     #_vnodepool_specalloc_FRAMESIZE-2
                TCS
                BRA     _vnodepool_specalloc_bandx
_vnodepool_L48
_vnodepool_L45
                INC     _fcc_img16
                BRL     _vnodepool_L44
_vnodepool_L46
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vnodepool_S4
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
                ADC     #_vnodepool_specalloc_FRAMESIZE-2
                TCS
_vnodepool_specalloc_bandx
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_specalloc_FRAMESIZE   EQU     4
_vnodepool_specalloc_STKGUARD    EQU     0
                FGX2_EXPORT _vnodepool_specfree
_vnodepool_specfree            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vnodepool_specfree_FRAMESIZE
                DO      _vnodepool_specfree_STKGUARD
                BCC     _vnodepool_specfree_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_specfree_stkok
_vnodepool_specfree_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_specfree_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_vnodepool_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vnodepool_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vnodepool_specfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+_vnodepool_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vnodepool_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vnodepool_specfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                STA     [_fcc_img0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #4
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #6
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                LDA     #0
                JSR     _fcc_long_from_int
                LDY     #8
                STA     [_fcc_img0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #10
                STA     [_fcc_img0],Y
                TXA
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     #65535
                LDY     #12
                STA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #_vnodepool_specfree_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_specfree_FRAMESIZE   EQU     0
_vnodepool_specfree_STKGUARD    EQU     0
                FGX2_EXPORT checkalias
checkalias            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #checkalias_FRAMESIZE-8
                DO      checkalias_STKGUARD
                BCC     checkalias_stkovf
                CMP     _fcc_stkfloor
                BCS     checkalias_stkok
checkalias_stkovf       JMP     _fcc_stkoflow
                FIN
checkalias_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img18
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
                STA     _fcc_img19
                LDY     #52
                LDA     [_fcc_img18],Y
                CMP     #3
                BEQ     _vnodepool_L51
                LDY     #52
                LDA     [_fcc_img18],Y
                TAX
                CMP     #4
                BEQ     _vnodepool_L51
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #checkalias_FRAMESIZE-8
                TCS
                BRL     checkalias_bandx
_vnodepool_L51
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
_vnodepool_L52
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img17
                AND     #$00FF
                ORA     _fcc_img16
                BNE     *+5
                BRL     _vnodepool_L54
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
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img16],Y
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
                BNE     _vnodepool_L56
                LDY     #52
                LDA     [_fcc_img18],Y
                PHA
                LDY     #52
                LDA     [_fcc_img16],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _vnodepool_L55
_vnodepool_L56
                BRA     _vnodepool_L53
_vnodepool_L55
                LDY     #2
                LDA     [_fcc_img16],Y
                BNE     _vnodepool_L57
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     checkalias_uL_loop
_vnodepool_L57
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vget
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                CMP     #0
                BEQ     _vnodepool_L58
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     checkalias_uL_loop
_vnodepool_L58
                BRA     _vnodepool_L54
_vnodepool_L53
                LDY     #54
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img16],Y
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                BRL     _vnodepool_L52
_vnodepool_L54
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L61
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L61
                LDA     #1
                BRA     _vnodepool_L62
_vnodepool_L61
                LDA     #0
_vnodepool_L62
                CMP     #0
                BNE     _vnodepool_L60
                LDY     #58
                LDA     [_fcc_img16],Y
                BNE     *+5
                BRL     _vnodepool_L59
_vnodepool_L60
                LDA     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img18
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_fpr1+2
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _vnodepool_specalloc
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
                LDY     #54
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img18],Y
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
                LDY     #54
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img18],Y
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
                LDY     #54
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img18],Y
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
                LDA     _fcc_img18
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_img19
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L64
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L64
                LDA     #0
                BRA     _vnodepool_L65
_vnodepool_L64
                LDA     #1
_vnodepool_L65
                CMP     #0
                BEQ     _vnodepool_L63
                LDA     [_fcc_img18]
                ORA     #2048
                STA     [_fcc_img18]
                LDA     [_fcc_img16]
                TAX
                ORA     #2048
                STA     [_fcc_img16]
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vrele
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L63
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #checkalias_FRAMESIZE-8
                TCS
                BRL     checkalias_bandx
_vnodepool_L59
                LDA     #0
                PHA
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vclean
                TSC
                CLC
                ADC     #6
                TCS
                LDY     #22
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #24
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #22
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #24
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDY     #58
                LDA     [_fcc_img18],Y
                LDY     #58
                STA     [_fcc_img16],Y
                LDA     #0
                LDY     #52
                STA     [_fcc_img18],Y
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
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL insmntque
                TSC
                CLC
                ADC     #8
                TCS
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #checkalias_FRAMESIZE-8
                TCS
checkalias_bandx
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
checkalias_FRAMESIZE   EQU     16
checkalias_STKGUARD    EQU     0
                FGX2_EXPORT bdevvp
bdevvp            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #bdevvp_FRAMESIZE-8
                DO      bdevvp_STKGUARD
                BCC     bdevvp_stkovf
                CMP     _fcc_stkfloor
                BCS     bdevvp_stkok
bdevvp_stkovf       JMP     _fcc_stkoflow
                FIN
bdevvp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img18
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
                STA     _fcc_img19
                SEP     #$20
                MX      %10
                LDA     _vnodepool_vfs_specops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _vnodepool_vfs_specops
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L67
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L67
                LDA     #1
                BRA     _vnodepool_L68
_vnodepool_L67
                LDA     #0
_vnodepool_L68
                CMP     #0
                BEQ     _vnodepool_L66
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
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
                ADC     #bdevvp_FRAMESIZE-8
                TCS
                BRL     bdevvp_bandx
_vnodepool_L66
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
                LDA     _vnodepool_vfs_specops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _vnodepool_vfs_specops
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
                BEQ     _vnodepool_L69
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
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
                ADC     #bdevvp_FRAMESIZE-8
                TCS
                BRL     bdevvp_bandx
_vnodepool_L69
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #3
                LDY     #52
                STA     [_fcc_img16],Y
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
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
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
                BEQ     _vnodepool_L70
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
_vnodepool_L70
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                STA     _fcc_fpr0
                LDA     _fcc_img16
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_img17
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #bdevvp_FRAMESIZE-8
                TCS
bdevvp_bandx
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
bdevvp_FRAMESIZE   EQU     18
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
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
_vnodepool_L71
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _vnodepool_L73
                LDA     _fcc_img0
                PHA
                LDY     #54
                LDA     [_fcc_img2],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img2],Y
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
                BNE     _vnodepool_L75
                LDA     _fcc_img1
                PHA
                LDY     #52
                LDA     [_fcc_img2],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _vnodepool_L74
_vnodepool_L75
                BRA     _vnodepool_L72
_vnodepool_L74
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
                LDA     _fcc_img2
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_img3
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
_vnodepool_L72
                LDY     #54
                LDA     [_fcc_img2],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img2],Y
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
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                BRL     _vnodepool_L71
_vnodepool_L73
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
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                TSC
                SEC
                SBC     #spec_securechr_FRAMESIZE-6
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
                BVC     _vnodepool_L77
                EOR     #$8000
_vnodepool_L77
                BPL     _vnodepool_L76
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #spec_securechr_FRAMESIZE-6
                TCS
                BRL     spec_securechr_bandx
_vnodepool_L76
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
                STA     _fcc_img18
                TAX
                CMP     #65535
                BNE     _vnodepool_L78
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #spec_securechr_FRAMESIZE-6
                TCS
                BRL     spec_securechr_bandx
_vnodepool_L78
                LDA     _fcc_img18
                LSR
                LSR
                LSR
                LSR
                LSR
                CLC
                ADC     _fcc_img18
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
_vnodepool_L79
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _vnodepool_L81
                LDY     #54
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_img18
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     _vnodepool_L83
                LDY     #52
                LDA     [_fcc_img16],Y
                TAX
                CMP     #3
                BEQ     _vnodepool_L82
_vnodepool_L83
                BRA     _vnodepool_L80
_vnodepool_L82
                LDY     #54
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img16],Y
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
                LDX     #1
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_and
                ORA     _fcc_long_hi
                BEQ     _vnodepool_L84
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #spec_securechr_FRAMESIZE-6
                TCS
                BRA     spec_securechr_bandx
_vnodepool_L84
_vnodepool_L80
                LDY     #54
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img16],Y
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                BRL     _vnodepool_L79
_vnodepool_L81
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #spec_securechr_FRAMESIZE-6
                TCS
spec_securechr_bandx
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
spec_securechr_FRAMESIZE   EQU     12
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
                LDX     #1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vnodepool_L86
                EOR     #$8000
_vnodepool_L86
                BPL     _vnodepool_L85
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
_vnodepool_L85
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
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img20
                TSC
                SEC
                SBC     #vcount_FRAMESIZE-10
                DO      vcount_STKGUARD
                BCC     vcount_stkovf
                CMP     _fcc_stkfloor
                BCS     vcount_stkok
vcount_stkovf       JMP     _fcc_stkoflow
                FIN
vcount_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img18
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
                STA     _fcc_img19
                LDA     [_fcc_img18]
                TAX
                AND     #2048
                CMP     #0
                BNE     _vnodepool_L87
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #vcount_FRAMESIZE-10
                TCS
                BRL     vcount_bandx
_vnodepool_L87
vcount_uL_loop
                LDA     #0
                STA     _fcc_img20
                LDY     #54
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img18],Y
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
_vnodepool_L88
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _vnodepool_L90
                LDY     #54
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                PHA
                LDY     #54
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img18],Y
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
                BNE     _vnodepool_L92
                LDY     #52
                LDA     [_fcc_img16],Y
                PHA
                LDY     #52
                LDA     [_fcc_img18],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _vnodepool_L91
_vnodepool_L92
                BRA     _vnodepool_L89
_vnodepool_L91
                LDY     #2
                LDA     [_fcc_img16],Y
                BNE     _vnodepool_L93
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     vcount_uL_loop
_vnodepool_L93
                LDA     _fcc_img20
                PHA
                LDY     #2
                LDA     [_fcc_img16],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img20
_vnodepool_L89
                LDY     #54
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img16],Y
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                BRL     _vnodepool_L88
_vnodepool_L90
                LDA     _fcc_img20
                TAY
                TSC
                CLC
                ADC     #vcount_FRAMESIZE-10
                TCS
vcount_bandx
                PLA
                STA     _fcc_img20
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
vcount_FRAMESIZE   EQU     16
vcount_STKGUARD    EQU     0
                FGX2_EXPORT vput
vput            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #vput_FRAMESIZE-4
                DO      vput_STKGUARD
                BCC     vput_stkovf
                CMP     _fcc_stkfloor
                BCS     vput_stkok
vput_stkovf       JMP     _fcc_stkoflow
                FIN
vput_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img16
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
                STA     _fcc_img17
                LDY     #22
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #24
                LDA     [_fcc_img16],Y
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
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vnodepool_L94-1
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
_vnodepool_L94
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vrele
                TSC
                CLC
                ADC     #4
                TCS
                TAY
                TSC
                CLC
                ADC     #vput_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
vput_FRAMESIZE   EQU     4
vput_STKGUARD    EQU     1
                FGX2_EXPORT vclean
vclean            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #vclean_FRAMESIZE-8
                DO      vclean_STKGUARD
                BCC     vclean_stkovf
                CMP     _fcc_stkfloor
                BCS     vclean_stkok
vclean_stkovf       JMP     _fcc_stkoflow
                FIN
vclean_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img16
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
                STA     _fcc_img17
                LDY     #2
                LDA     [_fcc_img16],Y
                STA     5,S   ; fccstk d=0 b=5
                BEQ     _vnodepool_L95
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vref
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L95
                LDA     [_fcc_img16]
                TAX
                AND     #256
                BEQ     _vnodepool_L96
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vnodepool_S5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L96
                LDA     [_fcc_img16]
                TAX
                ORA     #256
                STA     [_fcc_img16]
                LDY     #22
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #24
                LDA     [_fcc_img16],Y
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
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vnodepool_L97-1
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
_vnodepool_L97
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
                BEQ     _vnodepool_L98
                LDA     #1
                PHA
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vinvalbuf
                TSC
                CLC
                ADC     #6
                TCS
_vnodepool_L98
                LDY     #22
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #24
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     _fcc_img16
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
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #24
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     #0
                LDY     #58
                STA     [_fcc_img16],Y
                LDY     #108
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #110
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vnodepool_L99-1
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
_vnodepool_L99
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     5,S   ; fccstk d=0 b=5
                BNE     *+5
                BRL     _vnodepool_L100
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
                BEQ     _vnodepool_L101
                LDY     #16
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #18
                LDA     [_fcc_img18],Y
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
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     11,S
                STA     _fcc_fpr0
                LDA     13,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vnodepool_L102-1
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
_vnodepool_L102
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
_vnodepool_L101
                LDY     #96
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #98
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vnodepool_L103-1
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
_vnodepool_L103
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
_vnodepool_L100
                LDY     #100
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #102
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vnodepool_L105-1
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
_vnodepool_L105
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BEQ     _vnodepool_L104
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vnodepool_S6
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L104
                LDA     5,S   ; fccstk d=0 b=5
                BEQ     _vnodepool_L106
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vrele
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L106
                LDA     [_fcc_img16]
                PHA
                LDA     #256
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_img16]
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #512
                BEQ     _vnodepool_L107
                LDA     [_fcc_img16]
                PHA
                LDA     #512
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_img16]
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL kc_wakeup
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L107
                TAY
                TSC
                CLC
                ADC     #vclean_FRAMESIZE-8
                TCS
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
vclean_FRAMESIZE   EQU     14
vclean_STKGUARD    EQU     1
                FGX2_EXPORT vgone
vgone            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img20
                PEI     _fcc_img21
                TSC
                SEC
                SBC     #vgone_FRAMESIZE-12
                DO      vgone_STKGUARD
                BCC     vgone_stkovf
                CMP     _fcc_stkfloor
                BCS     vgone_stkok
vgone_stkovf       JMP     _fcc_stkoflow
                FIN
vgone_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img16
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
                STA     _fcc_img17
                LDA     [_fcc_img16]
                TAX
                AND     #256
                BEQ     _vnodepool_L108
                LDA     [_fcc_img16]
                TAX
                ORA     #512
                STA     [_fcc_img16]
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL kc_sleep
                TSC
                CLC
                ADC     #4
                TCS
                TAY
                TSC
                CLC
                ADC     #vgone_FRAMESIZE-12
                TCS
                BRL     vgone_bandx
_vnodepool_L108
                LDA     #4
                PHA
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
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
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL insmntque
                TSC
                CLC
                ADC     #8
                TCS
                LDY     #52
                LDA     [_fcc_img16],Y
                TAX
                CMP     #3
                BEQ     _vnodepool_L110
                LDY     #52
                LDA     [_fcc_img16],Y
                TAX
                CMP     #4
                BEQ     *+5
                BRL     _vnodepool_L109
_vnodepool_L110
                LDY     #54
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img16],Y
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
                BNE     _vnodepool_L112
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L112
                LDA     #1
                BRA     _vnodepool_L113
_vnodepool_L112
                LDA     #0
_vnodepool_L113
                CMP     #0
                BEQ     _vnodepool_L111
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vnodepool_S7
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L111
                LDY     #54
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img16],Y
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
                LDA     _fcc_img17
                STA     _fcc_fpr1+2
                LDA     _fcc_img16
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L115
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L115
                LDA     #1
                BRA     _vnodepool_L116
_vnodepool_L115
                LDA     #0
_vnodepool_L116
                CMP     #0
                BEQ     _vnodepool_L114
                LDY     #54
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img16],Y
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
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img16],Y
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
                BRL     _vnodepool_L117
_vnodepool_L114
                LDY     #54
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img16],Y
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
_vnodepool_L118
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img19
                AND     #$00FF
                ORA     _fcc_img18
                BNE     *+5
                BRL     _vnodepool_L120
                LDY     #54
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img18],Y
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
                LDA     _fcc_img17
                STA     _fcc_fpr1+2
                LDA     _fcc_img16
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L122
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L122
                LDA     #0
                BRA     _vnodepool_L123
_vnodepool_L122
                LDA     #1
_vnodepool_L123
                CMP     #0
                BEQ     _vnodepool_L121
                BRA     _vnodepool_L119
_vnodepool_L121
                LDY     #54
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #54
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img16],Y
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
                BRA     _vnodepool_L120
_vnodepool_L119
                LDY     #54
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img18],Y
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                BRL     _vnodepool_L118
_vnodepool_L120
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L125
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L125
                LDA     #1
                BRA     _vnodepool_L126
_vnodepool_L125
                LDA     #0
_vnodepool_L126
                CMP     #0
                BEQ     _vnodepool_L124
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vnodepool_S8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L124
_vnodepool_L117
                LDA     [_fcc_img16]
                TAX
                AND     #2048
                CMP     #0
                BNE     *+5
                BRL     _vnodepool_L127
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #0
                STA     _fcc_img20
                TAY
                LDA     #0
                STA     _fcc_img21
                TYA
                LDY     #54
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img16],Y
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_img0
_vnodepool_L128
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img19
                AND     #$00FF
                ORA     _fcc_img18
                BNE     *+5
                BRL     _vnodepool_L130
                LDY     #54
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                PHA
                LDY     #54
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img16],Y
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
                BNE     _vnodepool_L132
                LDY     #52
                LDA     [_fcc_img18],Y
                PHA
                LDY     #52
                LDA     [_fcc_img16],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _vnodepool_L131
_vnodepool_L132
                BRA     _vnodepool_L129
_vnodepool_L131
                INC     _fcc_img0
                LDA     _fcc_img19
                STA     _fcc_img21
                LDA     _fcc_img18
                STA     _fcc_img20
_vnodepool_L129
                LDY     #54
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img18],Y
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                BRL     _vnodepool_L128
_vnodepool_L130
                LDA     _fcc_img0
                STA     9,S   ; fccstk d=0 b=9
                BNE     _vnodepool_L133
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vnodepool_S9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L133
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CMP     #1
                BNE     _vnodepool_L134
                LDA     [_fcc_img20]
                PHA
                LDA     #2048
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_img20]
_vnodepool_L134
                LDA     [_fcc_img16]
                PHA
                LDA     #2048
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_img16]
_vnodepool_L127
                LDY     #54
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #56
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vnodepool_specfree
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #54
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #56
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
_vnodepool_L109
                LDY     #30
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #32
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _vnodepool_L135
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vremfree
                TSC
                CLC
                ADC     #4
                TCS
                LDA     _fcc_img16
                SEP     #$20
                MX      %10
                LDA     vnode_free_head+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     vnode_free_head
                STA     _fcc_fpr1
                LDY     #26
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #28
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img16
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
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #32
                STA     [_fcc_img16],Y
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
                BEQ     _vnodepool_L136
                SEP     #$20
                MX      %10
                LDA     vnode_free_head+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_free_head
                STA     _fcc_fpr0
                LDA     _fcc_img17
                STA     _fcc_fpr1+2
                LDA     _fcc_img16
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
                BRA     _vnodepool_L137
_vnodepool_L136
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                CLC
                ADC     #26
                STA     _fcc_fpr0
                STA     vnode_free_tail
                LDA     _fcc_fpr0+2
                STA     vnode_free_tail+2
_vnodepool_L137
                LDA     _fcc_img16
                STA     vnode_free_head
                LDA     _fcc_img17
                STA     vnode_free_head+2
                LDA     freevnodes
                CLC
                ADC     #1
                STA     freevnodes
_vnodepool_L135
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #8
                LDY     #52
                STA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #vgone_FRAMESIZE-12
                TCS
vgone_bandx
                PLA
                STA     _fcc_img21
                PLA
                STA     _fcc_img20
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
vgone_FRAMESIZE   EQU     22
vgone_STKGUARD    EQU     0
                FGX2_EXPORT vflush
vflush            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img20
                PEI     _fcc_img21
                PEI     _fcc_img22
                TSC
                SEC
                SBC     #vflush_FRAMESIZE-14
                DO      vflush_STKGUARD
                BCC     vflush_stkovf
                CMP     _fcc_stkfloor
                BCS     vflush_stkok
vflush_stkovf       JMP     _fcc_stkoflow
                FIN
vflush_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img18
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
                STA     _fcc_img19
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
                STA     _fcc_img22
                LDY     #22
                LDA     [_fcc_img18],Y
                STA     _fcc_long_hi
                LDY     #20
                LDA     [_fcc_img18],Y
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #64
                STX     _fcc_long_b_hi
                JSR     _fcc_long_and
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _vnodepool_L138
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vnodepool_S10
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L138
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
vflush_uL_loop
                LDY     #16
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #18
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
_vnodepool_L139
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _vnodepool_L141
                LDY     #18
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #20
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img19
                STA     _fcc_fpr1+2
                LDA     _fcc_img18
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L143
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L143
                LDA     #0
                BRA     _vnodepool_L144
_vnodepool_L143
                LDA     #1
_vnodepool_L144
                CMP     #0
                BEQ     _vnodepool_L142
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRA     vflush_uL_loop
_vnodepool_L142
                LDY     #34
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #36
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img21
                LDA     _fcc_fpr0
                STA     _fcc_img20
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
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
                BNE     _vnodepool_L146
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L146
                LDA     #1
                BRA     _vnodepool_L147
_vnodepool_L146
                LDA     #0
_vnodepool_L147
                CMP     #0
                BEQ     _vnodepool_L145
                BRL     _vnodepool_L140
_vnodepool_L145
                LDA     _fcc_img22
                TAX
                AND     #1
                BEQ     _vnodepool_L148
                LDA     [_fcc_img16]
                TAX
                AND     #4
                CMP     #0
                BEQ     _vnodepool_L148
                BRL     _vnodepool_L140
_vnodepool_L148
                LDY     #2
                LDA     [_fcc_img16],Y
                BNE     _vnodepool_L149
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
                BRL     _vnodepool_L140
_vnodepool_L149
                LDA     _fcc_img22
                TAX
                AND     #2
                BNE     *+5
                BRL     _vnodepool_L150
                LDY     #52
                LDA     [_fcc_img16],Y
                TAX
                CMP     #3
                BEQ     _vnodepool_L151
                LDY     #52
                LDA     [_fcc_img16],Y
                TAX
                CMP     #4
                BEQ     _vnodepool_L151
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
                BRL     _vnodepool_L152
_vnodepool_L151
                LDA     #0
                PHA
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vclean
                TSC
                CLC
                ADC     #6
                TCS
                SEP     #$20
                MX      %10
                LDA     _vnodepool_vfs_specops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _vnodepool_vfs_specops
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L154
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L154
                LDA     #1
                BRA     _vnodepool_L155
_vnodepool_L154
                LDA     #0
_vnodepool_L155
                CMP     #0
                BEQ     _vnodepool_L153
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
                BRA     _vnodepool_L140
_vnodepool_L153
                LDA     _fcc_img16
                SEP     #$20
                MX      %10
                LDA     _vnodepool_vfs_specops+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _vnodepool_vfs_specops
                STA     _fcc_fpr1
                LDY     #22
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #24
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL insmntque
                TSC
                CLC
                ADC     #8
                TCS
_vnodepool_L152
                BRA     _vnodepool_L140
_vnodepool_L150
                LDA     9,S   ; fccstk d=0 b=9
                CLC
                ADC     #1
                STA     9,S   ; fccstk d=0 b=9
_vnodepool_L140
                LDA     _fcc_img21
                STA     _fcc_fpr0+2
                LDA     _fcc_img20
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                BRL     _vnodepool_L139
_vnodepool_L141
                LDA     9,S   ; fccstk d=0 b=9
                BEQ     _vnodepool_L156
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #vflush_FRAMESIZE-14
                TCS
                BRA     vflush_bandx
_vnodepool_L156
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #vflush_FRAMESIZE-14
                TCS
vflush_bandx
                PLA
                STA     _fcc_img22
                PLA
                STA     _fcc_img21
                PLA
                STA     _fcc_img20
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
vflush_FRAMESIZE   EQU     24
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
                BMI     _vnodepool_L158
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
                BVC     _vnodepool_L159
                EOR     #$8000
_vnodepool_L159
                BMI     _vnodepool_L157
_vnodepool_L158
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
_vnodepool_L157
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
                BVC     _vnodepool_L162
                EOR     #$8000
_vnodepool_L162
                BMI     _vnodepool_L161
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
                LDX     #32
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vnodepool_L163
                EOR     #$8000
_vnodepool_L163
                BPL     _vnodepool_L160
_vnodepool_L161
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
_vnodepool_L160
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
                BNE     _vnodepool_L165
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L165
                LDA     #1
                BRA     _vnodepool_L166
_vnodepool_L165
                LDA     #0
_vnodepool_L166
                CMP     #0
                BEQ     _vnodepool_L164
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
_vnodepool_L164
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
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     #0
                STA     _fcc_img0
_vnodepool_L167
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                SEC
                SBC     #158
                BVC     _vnodepool_L170
                EOR     #$8000
_vnodepool_L170
                BPL     _vnodepool_L169
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
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
_vnodepool_L168
                INC     _fcc_img0
                BRA     _vnodepool_L167
_vnodepool_L169
                LDA     _fcc_img2
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
                STA     [_fcc_img2],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #22
                STA     [_fcc_img2],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img2
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
                STA     [_fcc_img2],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #26
                STA     [_fcc_img2],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                CLC
                ADC     #142
                STA     _fcc_fpr0
                LDA     _fcc_img3
                STA     _fcc_fpr1+2
                LDA     _fcc_img2
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
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                CLC
                ADC     #146
                STA     _fcc_fpr0
                LDA     #1
                STA     [_fcc_fpr0]
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                CLC
                ADC     #136
                STA     _fcc_fpr0
                LDA     _fcc_img3
                STA     _fcc_fpr1+2
                LDA     _fcc_img2
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
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                CLC
                ADC     #156
                STA     _fcc_fpr0
                LDA     #1
                STA     [_fcc_fpr0]
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                CLC
                ADC     #154
                STA     _fcc_fpr0
                LDA     #1
                STA     [_fcc_fpr0]
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
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
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #vfs_dounmount_FRAMESIZE-8
                DO      vfs_dounmount_STKGUARD
                BCC     vfs_dounmount_stkovf
                CMP     _fcc_stkfloor
                BCS     vfs_dounmount_stkok
vfs_dounmount_stkovf       JMP     _fcc_stkoflow
                FIN
vfs_dounmount_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img16
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
                STA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L173
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L173
                LDA     #1
                BRA     _vnodepool_L174
_vnodepool_L173
                LDA     #0
_vnodepool_L174
                CMP     #0
                BNE     _vnodepool_L172
                LDY     #8
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_img16],Y
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
                BNE     _vnodepool_L175
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L175
                LDA     #1
                BRA     _vnodepool_L176
_vnodepool_L175
                LDA     #0
_vnodepool_L176
                CMP     #0
                BEQ     _vnodepool_L171
_vnodepool_L172
                LDA     #22
                TAY
                TSC
                CLC
                ADC     #vfs_dounmount_FRAMESIZE-8
                TCS
                BRL     vfs_dounmount_bandx
_vnodepool_L171
                LDY     #12
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDY     #22
                LDA     [_fcc_img16],Y
                STA     _fcc_long_hi
                LDY     #20
                LDA     [_fcc_img16],Y
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
                STA     [_fcc_img16],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #22
                STA     [_fcc_img16],Y
                TXA
                SEP     #$20
                MX      %10
                LDA     _vnodepool_vfs_cacheops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _vnodepool_vfs_cacheops
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vnodepool_L177
                SEP     #$20
                MX      %10
                LDA     _vnodepool_vfs_cacheops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _vnodepool_vfs_cacheops
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
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vnodepool_L178-1
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
_vnodepool_L178
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
_vnodepool_L177
                LDY     #8
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_img16],Y
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
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     7,S
                STA     _fcc_fpr0
                LDA     9,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vnodepool_L179-1
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
_vnodepool_L179
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                STA     5,S   ; fccstk d=0 b=5
                CMP     #0
                BEQ     _vnodepool_L180
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
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
                ADC     #vfs_dounmount_FRAMESIZE-8
                TCS
                BRL     vfs_dounmount_bandx
_vnodepool_L180
                LDA     [_fcc_img16]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img16],Y
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
                BNE     _vnodepool_L182
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L182
                LDA     #0
                BRA     _vnodepool_L183
_vnodepool_L182
                LDA     #1
_vnodepool_L183
                CMP     #0
                BNE     *+5
                BRL     _vnodepool_L181
                LDY     #4
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_img16],Y
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
                BNE     _vnodepool_L184
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L184
                LDA     #0
                BRA     _vnodepool_L185
_vnodepool_L184
                LDA     #1
_vnodepool_L185
                CMP     #0
                BNE     *+5
                BRL     _vnodepool_L181
                LDY     #4
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_img16]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img16],Y
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
                LDA     [_fcc_img16]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_img16],Y
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                STA     [_fcc_img16]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #4
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #6
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
_vnodepool_L181
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L187
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L187
                LDA     #0
                BRA     _vnodepool_L188
_vnodepool_L187
                LDA     #1
_vnodepool_L188
                CMP     #0
                BEQ     _vnodepool_L186
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #54
                STA     [_fcc_img18],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #56
                STA     [_fcc_img18],Y
                REP     #$20
                MX      %00
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #12
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #14
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img18
                FGX2_FARCALL vrele
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L186
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
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
                ADC     #vfs_dounmount_FRAMESIZE-8
                TCS
vfs_dounmount_bandx
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
vfs_dounmount_FRAMESIZE   EQU     14
vfs_dounmount_STKGUARD    EQU     1
                FGX2_EXPORT _vnodepool_nchbucket
_vnodepool_nchbucket            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vnodepool_nchbucket_FRAMESIZE
                DO      _vnodepool_nchbucket_STKGUARD
                BCC     _vnodepool_nchbucket_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_nchbucket_stkok
_vnodepool_nchbucket_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_nchbucket_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_vnodepool_nchbucket_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vnodepool_nchbucket_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vnodepool_nchbucket_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_vnodepool_nchbucket_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vnodepool_nchbucket_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vnodepool_nchbucket_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDX     #15
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
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
                ADC     #_vnodepool_nchbucket_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_nchbucket_FRAMESIZE   EQU     0
_vnodepool_nchbucket_STKGUARD    EQU     0
                FGX2_EXPORT _vnodepool_ncinshash
_vnodepool_ncinshash            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vnodepool_ncinshash_FRAMESIZE
                DO      _vnodepool_ncinshash_STKGUARD
                BCC     _vnodepool_ncinshash_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_ncinshash_stkok
_vnodepool_ncinshash_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_ncinshash_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_vnodepool_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vnodepool_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vnodepool_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+_vnodepool_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vnodepool_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vnodepool_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                DO      10+_vnodepool_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vnodepool_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vnodepool_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img2
                DO      12+_vnodepool_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vnodepool_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vnodepool_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img3
                LDA     [_fcc_img2]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                STA     [_fcc_img0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img2
                LDY     #4
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img3
                LDY     #6
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     [_fcc_img2]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img0
                LDY     #4
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img1
                LDY     #6
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img0
                STA     [_fcc_img2]
                SEP     #$20
                MX      %10
                LDA     _fcc_img1
                LDY     #2
                STA     [_fcc_img2],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #_vnodepool_ncinshash_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_ncinshash_FRAMESIZE   EQU     0
_vnodepool_ncinshash_STKGUARD    EQU     0
                FGX2_EXPORT _vnodepool_ncremhash
_vnodepool_ncremhash            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vnodepool_ncremhash_FRAMESIZE
                DO      _vnodepool_ncremhash_STKGUARD
                BCC     _vnodepool_ncremhash_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_ncremhash_stkok
_vnodepool_ncremhash_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_ncremhash_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_vnodepool_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vnodepool_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vnodepool_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+_vnodepool_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vnodepool_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vnodepool_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                LDY     #4
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_img0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img0],Y
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
                LDA     [_fcc_img0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_img0],Y
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
                ADC     #_vnodepool_ncremhash_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_ncremhash_FRAMESIZE   EQU     0
_vnodepool_ncremhash_STKGUARD    EQU     0
                FGX2_EXPORT _vnodepool_nclru_totail
_vnodepool_nclru_totail            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vnodepool_nclru_totail_FRAMESIZE
                DO      _vnodepool_nclru_totail_STKGUARD
                BCC     _vnodepool_nclru_totail_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_nclru_totail_stkok
_vnodepool_nclru_totail_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_nclru_totail_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_vnodepool_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vnodepool_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vnodepool_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+_vnodepool_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vnodepool_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vnodepool_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                LDY     #8
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_img0],Y
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
                BNE     _vnodepool_L190
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L190
                LDA     #1
                BRA     _vnodepool_L191
_vnodepool_L190
                LDA     #0
_vnodepool_L191
                CMP     #0
                BEQ     _vnodepool_L189
                TAY
                TSC
                CLC
                ADC     #_vnodepool_nclru_totail_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_L189
                LDY     #12
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_img0],Y
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
                LDY     #8
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_img0],Y
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #8
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #10
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img0
                SEP     #$20
                MX      %10
                LDA     nchtail+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     nchtail
                STA     _fcc_fpr1
                LDY     #12
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #14
                STA     [_fcc_img0],Y
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
                LDA     _fcc_img0
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_img1
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                STA     nchtail
                LDA     _fcc_fpr0+2
                STA     nchtail+2
                TAY
                TSC
                CLC
                ADC     #_vnodepool_nclru_totail_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_nclru_totail_FRAMESIZE   EQU     0
_vnodepool_nclru_totail_STKGUARD    EQU     0
                FGX2_EXPORT _vnodepool_nclru_remove
_vnodepool_nclru_remove            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vnodepool_nclru_remove_FRAMESIZE
                DO      _vnodepool_nclru_remove_STKGUARD
                BCC     _vnodepool_nclru_remove_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_nclru_remove_stkok
_vnodepool_nclru_remove_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_nclru_remove_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_vnodepool_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vnodepool_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vnodepool_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+_vnodepool_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vnodepool_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vnodepool_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                LDY     #12
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_img0],Y
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
                LDY     #8
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vnodepool_L192
                LDY     #8
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_img0],Y
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
                BRA     _vnodepool_L193
_vnodepool_L192
                LDY     #12
                LDA     [_fcc_img0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                STA     nchtail
                LDA     _fcc_fpr0+2
                STA     nchtail+2
_vnodepool_L193
                TAY
                TSC
                CLC
                ADC     #_vnodepool_nclru_remove_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_nclru_remove_FRAMESIZE   EQU     0
_vnodepool_nclru_remove_STKGUARD    EQU     0
                FGX2_EXPORT _vnodepool_nclru_tohead
_vnodepool_nclru_tohead            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vnodepool_nclru_tohead_FRAMESIZE
                DO      _vnodepool_nclru_tohead_STKGUARD
                BCC     _vnodepool_nclru_tohead_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_nclru_tohead_stkok
_vnodepool_nclru_tohead_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_nclru_tohead_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_vnodepool_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vnodepool_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vnodepool_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+_vnodepool_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vnodepool_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vnodepool_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                LDA     _fcc_img0
                SEP     #$20
                MX      %10
                LDA     nchhead+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     nchhead
                STA     _fcc_fpr1
                LDY     #8
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #10
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img0
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
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #14
                STA     [_fcc_img0],Y
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
                BEQ     _vnodepool_L194
                SEP     #$20
                MX      %10
                LDA     nchhead+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     nchhead
                STA     _fcc_fpr0
                LDA     _fcc_img1
                STA     _fcc_fpr1+2
                LDA     _fcc_img0
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
                BRA     _vnodepool_L195
_vnodepool_L194
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                STA     nchtail
                LDA     _fcc_fpr0+2
                STA     nchtail+2
_vnodepool_L195
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                STA     nchhead
                LDA     _fcc_fpr0+2
                STA     nchhead+2
                TAY
                TSC
                CLC
                ADC     #_vnodepool_nclru_tohead_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_nclru_tohead_FRAMESIZE   EQU     0
_vnodepool_nclru_tohead_STKGUARD    EQU     0
                FGX2_EXPORT _vnodepool_ncdetach
_vnodepool_ncdetach            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #_vnodepool_ncdetach_FRAMESIZE-4
                DO      _vnodepool_ncdetach_STKGUARD
                BCC     _vnodepool_ncdetach_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_ncdetach_stkok
_vnodepool_ncdetach_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_ncdetach_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_vnodepool_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vnodepool_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vnodepool_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img16
                DO      8+_vnodepool_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vnodepool_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vnodepool_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img17
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _vnodepool_ncremhash
                TSC
                CLC
                ADC     #4
                TCS
                LDA     _fcc_img16
                STA     [_fcc_img16]
                SEP     #$20
                MX      %10
                LDA     _fcc_img17
                LDY     #2
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img16
                LDY     #4
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img17
                LDY     #6
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #_vnodepool_ncdetach_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_ncdetach_FRAMESIZE   EQU     4
_vnodepool_ncdetach_STKGUARD    EQU     0
                FGX2_EXPORT nchinit
nchinit            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img20
                TSC
                SEC
                SBC     #nchinit_FRAMESIZE-10
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
                STA     _fcc_img20
_vnodepool_L196
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img20
                TAX
                SEC
                SBC     #16
                BVC     _vnodepool_L199
                EOR     #$8000
_vnodepool_L199
                BPL     _vnodepool_L198
                LDA     _fcc_img20
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     _fcc_img18
                STA     [_fcc_img18]
                SEP     #$20
                MX      %10
                LDA     _fcc_img19
                LDY     #2
                STA     [_fcc_img18],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img19
                STA     _fcc_fpr1+2
                LDA     _fcc_img18
                STA     _fcc_fpr1
                LDY     #4
                STA     [_fcc_img18],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #6
                STA     [_fcc_img18],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
_vnodepool_L197
                INC     _fcc_img20
                BRA     _vnodepool_L196
_vnodepool_L198
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
                BNE     _vnodepool_L201
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L201
                LDA     #1
                BRA     _vnodepool_L202
_vnodepool_L201
                LDA     #0
_vnodepool_L202
                CMP     #0
                BEQ     _vnodepool_L200
                LDA     #0
                STA     doingcache
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #nchinit_FRAMESIZE-10
                TCS
                BRL     nchinit_bandx
_vnodepool_L200
                LDA     #64
                TAX
                SEC
                SBC     #1
                STA     _fcc_img20
_vnodepool_L203
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img20
                BPL     *+5
                BRL     _vnodepool_L205
                SEP     #$20
                MX      %10
                LDA     namecache_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     namecache_pool
                STA     _fcc_fpr0
                LDA     _fcc_img20
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #16
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #18
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #24
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #26
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                LDA     #0
                JSR     _fcc_long_from_int
                LDY     #20
                STA     [_fcc_img16],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #22
                STA     [_fcc_img16],Y
                TXA
                LDA     #0
                JSR     _fcc_long_from_int
                LDY     #28
                STA     [_fcc_img16],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #30
                STA     [_fcc_img16],Y
                TXA
                LDA     #0
                SEP     #$20
                MX      %10
                LDY     #32
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img16
                STA     [_fcc_img16]
                SEP     #$20
                MX      %10
                LDA     _fcc_img17
                LDY     #2
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img16
                LDY     #4
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img17
                LDY     #6
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _vnodepool_nclru_tohead
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L204
                DEC     _fcc_img20
                BRL     _vnodepool_L203
_vnodepool_L205
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
                ADC     #nchinit_FRAMESIZE-10
                TCS
nchinit_bandx
                PLA
                STA     _fcc_img20
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
nchinit_FRAMESIZE   EQU     20
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
_vnodepool_L206
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
                BVC     _vnodepool_L209
                EOR     #$8000
_vnodepool_L209
                BMI     *+5
                BRL     _vnodepool_L208
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
_vnodepool_L207
                INC     _fcc_img0
                BRL     _vnodepool_L206
_vnodepool_L208
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
                FGX2_EXPORT _vnodepool_namecmp
_vnodepool_namecmp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vnodepool_namecmp_FRAMESIZE
                DO      _vnodepool_namecmp_STKGUARD
                BCC     _vnodepool_namecmp_stkovf
                CMP     _fcc_stkfloor
                BCS     _vnodepool_namecmp_stkok
_vnodepool_namecmp_stkovf       JMP     _fcc_stkoflow
                FIN
_vnodepool_namecmp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      14+_vnodepool_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_vnodepool_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_vnodepool_namecmp_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_img0
                DO      6+_vnodepool_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vnodepool_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vnodepool_namecmp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+_vnodepool_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vnodepool_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vnodepool_namecmp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
                DO      10+_vnodepool_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vnodepool_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vnodepool_namecmp_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img3
                DO      12+_vnodepool_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vnodepool_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vnodepool_namecmp_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img4
_vnodepool_L210
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                DEC
                STA     _fcc_img0
                LDA     _fcc_tmp_b
                BEQ     _vnodepool_L211
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
                BEQ     _vnodepool_L212
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #_vnodepool_namecmp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_L212
                BRA     _vnodepool_L210
_vnodepool_L211
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_vnodepool_namecmp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_namecmp_FRAMESIZE   EQU     0
_vnodepool_namecmp_STKGUARD    EQU     0
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
                STA     _fcc_img3
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
                STA     _fcc_img4
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
                STA     [_fcc_img3],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #16
                STA     [_fcc_img3],Y
                TXA
                LDA     _fcc_img4
                STA     _fcc_fpr0+2
                LDA     _fcc_img3
                STA     _fcc_fpr0
                LDY     #16
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #14
                LDA     [_fcc_fpr0],Y
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _vnodepool_L213
                TAY
                TSC
                CLC
                ADC     #cache_purge_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnodepool_L213
                LDA     #0
                STA     _fcc_img0
_vnodepool_L214
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #16
                BVC     _vnodepool_L217
                EOR     #$8000
_vnodepool_L217
                BMI     *+5
                BRL     _vnodepool_L216
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
                STA     _fcc_img6
                LDA     _fcc_fpr0
                STA     _fcc_img5
                LDA     [_fcc_img5]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img5],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
_vnodepool_L218
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr0
                LDA     _fcc_img6
                STA     _fcc_fpr1+2
                LDA     _fcc_img5
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L221
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L221
                LDA     #0
                BRA     _vnodepool_L222
_vnodepool_L221
                LDA     #1
_vnodepool_L222
                CMP     #0
                BEQ     _vnodepool_L220
                LDA     #0
                JSR     _fcc_long_from_int
                LDY     #28
                STA     [_fcc_img1],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #30
                STA     [_fcc_img1],Y
                TXA
                LDA     #0
                JSR     _fcc_long_from_int
                LDY     #20
                STA     [_fcc_img1],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #22
                STA     [_fcc_img1],Y
                TXA
_vnodepool_L219
                LDA     [_fcc_img1]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img1],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                BRA     _vnodepool_L218
_vnodepool_L220
_vnodepool_L215
                INC     _fcc_img0
                BRL     _vnodepool_L214
_vnodepool_L216
                LDA     _fcc_img4
                STA     _fcc_fpr0+2
                LDA     _fcc_img3
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
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img20
                PEI     _fcc_img21
                PEI     _fcc_img22
                TSC
                SEC
                SBC     #cache_purgevfs_FRAMESIZE-14
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
                STA     _fcc_img22
_vnodepool_L223
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img22
                TAX
                SEC
                SBC     #16
                BVC     _vnodepool_L226
                EOR     #$8000
_vnodepool_L226
                BMI     *+5
                BRL     _vnodepool_L225
                LDA     _fcc_img22
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     [_fcc_img18]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
_vnodepool_L227
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     _fcc_img19
                STA     _fcc_fpr1+2
                LDA     _fcc_img18
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L230
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L230
                LDA     #0
                BRA     _vnodepool_L231
_vnodepool_L230
                LDA     #1
_vnodepool_L231
                CMP     #0
                BNE     *+5
                BRL     _vnodepool_L229
                LDA     [_fcc_img16]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img21
                LDA     _fcc_fpr0
                STA     _fcc_img20
                LDY     #16
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #18
                LDA     [_fcc_img16],Y
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
                BNE     _vnodepool_L234
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L234
                LDA     #1
                BRA     _vnodepool_L235
_vnodepool_L234
                LDA     #0
_vnodepool_L235
                CMP     #0
                BNE     _vnodepool_L233
                LDY     #16
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #18
                LDA     [_fcc_img16],Y
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
                BNE     _vnodepool_L236
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L236
                LDA     #0
                BRA     _vnodepool_L237
_vnodepool_L236
                LDA     #1
_vnodepool_L237
                CMP     #0
                BEQ     _vnodepool_L232
_vnodepool_L233
                BRA     _vnodepool_L228
_vnodepool_L232
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #24
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #26
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #16
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #18
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                LDA     #0
                SEP     #$20
                MX      %10
                LDY     #32
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _vnodepool_ncdetach
                TSC
                CLC
                ADC     #4
                TCS
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _vnodepool_nclru_remove
                TSC
                CLC
                ADC     #4
                TCS
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _vnodepool_nclru_tohead
                TSC
                CLC
                ADC     #4
                TCS
_vnodepool_L228
                LDA     _fcc_img21
                STA     _fcc_fpr0+2
                LDA     _fcc_img20
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                BRL     _vnodepool_L227
_vnodepool_L229
_vnodepool_L224
                INC     _fcc_img22
                BRL     _vnodepool_L223
_vnodepool_L225
                TAY
                TSC
                CLC
                ADC     #cache_purgevfs_FRAMESIZE-14
                TCS
                PLA
                STA     _fcc_img22
                PLA
                STA     _fcc_img21
                PLA
                STA     _fcc_img20
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
cache_purgevfs_FRAMESIZE   EQU     28
cache_purgevfs_STKGUARD    EQU     0
                FGX2_EXPORT cache_lookup
cache_lookup            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img20
                PEI     _fcc_img21
                PEI     _fcc_img22
                PEI     _fcc_img23
                TSC
                SEC
                SBC     #cache_lookup_FRAMESIZE-16
                DO      cache_lookup_STKGUARD
                BCC     cache_lookup_stkovf
                CMP     _fcc_stkfloor
                BCS     cache_lookup_stkok
cache_lookup_stkovf       JMP     _fcc_stkoflow
                FIN
cache_lookup_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img18
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
                STA     _fcc_img19
                LDA     doingcache
                BNE     _vnodepool_L238
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #cache_lookup_FRAMESIZE-16
                TCS
                BRL     cache_lookup_bandx
_vnodepool_L238
                LDY     #42
                LDA     [_fcc_img18],Y
                LDX     #31
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vnodepool_L240
                EOR     #$8000
_vnodepool_L240
                BPL     _vnodepool_L239
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
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
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
                ADC     #cache_lookup_FRAMESIZE-16
                TCS
                BRL     cache_lookup_bandx
_vnodepool_L239
                LDY     #52
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #54
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img23
                LDA     _fcc_fpr0
                STA     _fcc_img22
                LDY     #40
                LDA     [_fcc_img18],Y
                STA     _fcc_long_hi
                LDY     #38
                LDA     [_fcc_img18],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _vnodepool_nchbucket
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     _fcc_img21
                LDA     _fcc_fpr0
                STA     _fcc_img20
                LDA     [_fcc_img20]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img20],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
_vnodepool_L241
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     _fcc_img21
                STA     _fcc_fpr1+2
                LDA     _fcc_img20
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L244
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L244
                LDA     #0
                BRA     _vnodepool_L245
_vnodepool_L244
                LDA     #1
_vnodepool_L245
                CMP     #0
                BNE     *+5
                BRL     _vnodepool_L243
                LDY     #16
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #18
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img23
                STA     _fcc_fpr1+2
                LDA     _fcc_img22
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L247
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L247
                LDA     #1
                BRA     _vnodepool_L248
_vnodepool_L247
                LDA     #0
_vnodepool_L248
                CMP     #0
                BNE     *+5
                BRL     _vnodepool_L246
                LDY     #22
                LDA     [_fcc_img16],Y
                STA     _fcc_long_hi
                LDY     #20
                LDA     [_fcc_img16],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDY     #16
                LDA     [_fcc_img22],Y
                STA     _fcc_long_hi
                LDY     #14
                LDA     [_fcc_img22],Y
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
                BEQ     _vnodepool_L246
                LDY     #32
                LDA     [_fcc_img16],Y
                AND     #$00FF
                PHA
                LDY     #42
                LDA     [_fcc_img18],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _vnodepool_L246
                LDY     #32
                LDA     [_fcc_img16],Y
                AND     #$00FF
                PHA
                LDY     #28
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #30
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                CLC
                ADC     #33
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vnodepool_namecmp
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                CMP     #0
                BNE     _vnodepool_L246
                BRA     _vnodepool_L243
_vnodepool_L246
_vnodepool_L242
                LDA     [_fcc_img16]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                BRL     _vnodepool_L241
_vnodepool_L243
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     _fcc_img21
                STA     _fcc_fpr1+2
                LDA     _fcc_img20
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L250
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L250
                LDA     #1
                BRA     _vnodepool_L251
_vnodepool_L250
                LDA     #0
_vnodepool_L251
                CMP     #0
                BEQ     _vnodepool_L249
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
                ADC     #cache_lookup_FRAMESIZE-16
                TCS
                BRL     cache_lookup_bandx
_vnodepool_L249
                LDY     #46
                LDA     [_fcc_img18],Y
                AND     #$00FF
                CMP     #0
                BNE     _vnodepool_L252
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
                BRL     _vnodepool_L253
_vnodepool_L252
                LDY     #24
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #26
                LDA     [_fcc_img16],Y
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
                BNE     _vnodepool_L255
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L255
                LDA     #1
                BRA     _vnodepool_L256
_vnodepool_L255
                LDA     #0
_vnodepool_L256
                CMP     #0
                BEQ     _vnodepool_L254
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
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _vnodepool_nclru_totail
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #cache_lookup_FRAMESIZE-16
                TCS
                BRL     cache_lookup_bandx
                BRL     _vnodepool_L257
_vnodepool_L254
                LDY     #30
                LDA     [_fcc_img16],Y
                STA     _fcc_long_hi
                LDY     #28
                LDA     [_fcc_img16],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDY     #24
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #26
                LDA     [_fcc_img16],Y
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
                BEQ     _vnodepool_L258
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
                BRA     _vnodepool_L259
_vnodepool_L258
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
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _vnodepool_nclru_totail
                TSC
                CLC
                ADC     #4
                TCS
                LDY     #24
                LDA     [_fcc_img16],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #26
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #48
                STA     [_fcc_img18],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #50
                STA     [_fcc_img18],Y
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
                ADC     #cache_lookup_FRAMESIZE-16
                TCS
                BRA     cache_lookup_bandx
_vnodepool_L259
_vnodepool_L257
_vnodepool_L253
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _vnodepool_nclru_remove
                TSC
                CLC
                ADC     #4
                TCS
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _vnodepool_ncdetach
                TSC
                CLC
                ADC     #4
                TCS
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _vnodepool_nclru_tohead
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #cache_lookup_FRAMESIZE-16
                TCS
cache_lookup_bandx
                PLA
                STA     _fcc_img23
                PLA
                STA     _fcc_img22
                PLA
                STA     _fcc_img21
                PLA
                STA     _fcc_img20
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
cache_lookup_FRAMESIZE   EQU     28
cache_lookup_STKGUARD    EQU     0
                FGX2_EXPORT cache_enter
cache_enter            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img20
                TSC
                SEC
                SBC     #cache_enter_FRAMESIZE-10
                DO      cache_enter_STKGUARD
                BCC     cache_enter_stkovf
                CMP     _fcc_stkfloor
                BCS     cache_enter_stkok
cache_enter_stkovf       JMP     _fcc_stkoflow
                FIN
cache_enter_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img18
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
                STA     _fcc_img19
                LDA     doingcache
                BNE     _vnodepool_L260
                TAY
                TSC
                CLC
                ADC     #cache_enter_FRAMESIZE-10
                TCS
                BRL     cache_enter_bandx
_vnodepool_L260
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                STA     _fcc_fpr0
                LDY     #42
                LDA     [_fcc_fpr0],Y
                LDX     #31
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vnodepool_L262
                EOR     #$8000
_vnodepool_L262
                BPL     _vnodepool_L261
                TAY
                TSC
                CLC
                ADC     #cache_enter_FRAMESIZE-10
                TCS
                BRL     cache_enter_bandx
_vnodepool_L261
                SEP     #$20
                MX      %10
                LDA     nchhead+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     nchhead
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L264
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L264
                LDA     #1
                BRA     _vnodepool_L265
_vnodepool_L264
                LDA     #0
_vnodepool_L265
                CMP     #0
                BEQ     _vnodepool_L263
                TAY
                TSC
                CLC
                ADC     #cache_enter_FRAMESIZE-10
                TCS
                BRL     cache_enter_bandx
_vnodepool_L263
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _vnodepool_nclru_remove
                TSC
                CLC
                ADC     #4
                TCS
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _vnodepool_ncremhash
                TSC
                CLC
                ADC     #4
                TCS
                LDY     #48
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #50
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #24
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #26
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDY     #48
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #50
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vnodepool_L266
                LDY     #48
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #50
                LDA     [_fcc_img18],Y
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
                STA     [_fcc_img16],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #30
                STA     [_fcc_img16],Y
                TXA
                BRA     _vnodepool_L267
_vnodepool_L266
                LDA     #0
                JSR     _fcc_long_from_int
                LDY     #28
                STA     [_fcc_img16],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #30
                STA     [_fcc_img16],Y
                TXA
_vnodepool_L267
                LDY     #52
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #54
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #16
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #18
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDY     #52
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #54
                LDA     [_fcc_img18],Y
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
                STA     [_fcc_img16],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #22
                STA     [_fcc_img16],Y
                TXA
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     _fcc_img19
                STA     _fcc_fpr1+2
                LDA     _fcc_img18
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
                STA     _fcc_img20
_vnodepool_L268
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img20
                PHA
                LDY     #42
                LDA     [_fcc_img18],Y
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vnodepool_L271
                EOR     #$8000
_vnodepool_L271
                BPL     _vnodepool_L270
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                CLC
                ADC     #33
                STA     _fcc_fpr0
                LDA     _fcc_img20
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #28
                LDA     [_fcc_img18],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #30
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDA     _fcc_img20
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
_vnodepool_L269
                INC     _fcc_img20
                BRA     _vnodepool_L268
_vnodepool_L270
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #8
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #10
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img16
                SEP     #$20
                MX      %10
                LDA     nchtail+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     nchtail
                STA     _fcc_fpr1
                LDY     #12
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #14
                STA     [_fcc_img16],Y
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
                LDA     _fcc_img16
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_img17
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                CLC
                ADC     #8
                STA     _fcc_fpr0
                STA     nchtail
                LDA     _fcc_fpr0+2
                STA     nchtail+2
                LDY     #40
                LDA     [_fcc_img18],Y
                STA     _fcc_long_hi
                LDY     #38
                LDA     [_fcc_img18],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _vnodepool_nchbucket
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _vnodepool_ncinshash
                TSC
                CLC
                ADC     #8
                TCS
                TAY
                TSC
                CLC
                ADC     #cache_enter_FRAMESIZE-10
                TCS
cache_enter_bandx
                PLA
                STA     _fcc_img20
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
cache_enter_FRAMESIZE   EQU     16
cache_enter_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #main_FRAMESIZE-4
                DO      main_STKGUARD
                BCC     main_stkovf
                CMP     _fcc_stkfloor
                BCS     main_stkok
main_stkovf       JMP     _fcc_stkoflow
                FIN
main_stkok        TCS
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
                LDA     #_vnodepool_vn_arena
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vntblinit
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
                LDA     #_vnodepool_nc_arena
                STA     _fcc_fpr0
                PLA
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
                LDA     freevnodes
                TAX
                CMP     #64
                BEQ     _vnodepool_L272
                LDA     #51
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L272
                SEP     #$20
                MX      %10
                LDA     vnode_free_head+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_free_head
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     vnode_pool+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     vnode_pool
                STA     _fcc_fpr1
                LDA     #0
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
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L274
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L274
                LDA     #0
                BRA     _vnodepool_L275
_vnodepool_L274
                LDA     #1
_vnodepool_L275
                CMP     #0
                BEQ     _vnodepool_L273
                LDA     #52
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L273
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
                LDA     #fakeops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
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
                STA     21,S   ; fccstk d=0 b=21
                BEQ     _vnodepool_L276
                LDA     #53
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L276
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     vnode_pool+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     vnode_pool
                STA     _fcc_fpr1
                LDA     #0
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
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L278
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L278
                LDA     #0
                BRA     _vnodepool_L279
_vnodepool_L278
                LDA     #1
_vnodepool_L279
                CMP     #0
                BEQ     _vnodepool_L277
                LDA     #54
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L277
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #1
                BEQ     _vnodepool_L280
                LDA     #55
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L280
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #16
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #14
                LDA     [_fcc_fpr0],Y
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _vnodepool_L281
                LDA     #56
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L281
                LDA     freevnodes
                TAX
                LDA     #64
                TAY
                TYA
                DEC
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _vnodepool_L282
                LDA     #57
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L282
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
                LDA     #fakeops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
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
                STA     21,S   ; fccstk d=0 b=21
                CMP     #0
                BEQ     _vnodepool_L283
                LDA     #58
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L283
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
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
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
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
                BEQ     _vnodepool_L284
                LDA     #59
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L284
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vref
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #2
                BEQ     _vnodepool_L285
                LDA     #60
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L285
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
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #1
                BEQ     _vnodepool_L286
                LDA     #61
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L286
                LDA     freevnodes
                TAX
                LDA     #64
                TAY
                TYA
                DEC
                DEC
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _vnodepool_L287
                LDA     #62
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L287
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
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                BEQ     _vnodepool_L288
                LDA     #63
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L288
                LDA     freevnodes
                TAX
                LDA     #64
                TAY
                TYA
                DEC
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _vnodepool_L289
                LDA     #64
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L289
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #16
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #14
                LDA     [_fcc_fpr0],Y
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _vnodepool_L290
                LDA     #65
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L290
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #58
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #1
                BEQ     _vnodepool_L291
                LDA     #66
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L291
                LDA     freevnodes
                STA     _fcc_img17
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vget
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BEQ     _vnodepool_L292
                LDA     #67
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L292
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #1
                BEQ     _vnodepool_L293
                LDA     #68
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L293
                LDA     freevnodes
                TAX
                LDA     _fcc_img17
                TAY
                TYA
                DEC
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _vnodepool_L294
                LDA     #69
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L294
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #256
                STA     [_fcc_fpr0]
                LDA     _vnodepool_nslept
                STA     _vnodepool_nvxsleeps
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vget
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                CMP     #1
                BEQ     _vnodepool_L295
                LDA     #70
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L295
                LDA     _vnodepool_nslept
                TAX
                LDA     _vnodepool_nvxsleeps
                TAY
                TYA
                INC
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _vnodepool_L296
                LDA     #71
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L296
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #256
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_fpr0]
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
                LDA     #fakeops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
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
                STA     21,S   ; fccstk d=0 b=21
                BEQ     _vnodepool_L297
                LDA     #71
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L297
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vrele
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #0
                STA     _fcc_img17
                SEP     #$20
                MX      %10
                LDA     vnode_free_head+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_free_head
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
_vnodepool_L298
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vnodepool_L300
                INC     _fcc_img17
_vnodepool_L299
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
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
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                BRA     _vnodepool_L298
_vnodepool_L300
                LDA     _fcc_img17
                TAX
                LDA     freevnodes
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _vnodepool_L301
                LDA     #72
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L301
                SEP     #$20
                MX      %10
                LDA     vnode_free_head+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_free_head
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
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L304
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L304
                LDA     #1
                BRA     _vnodepool_L305
_vnodepool_L304
                LDA     #0
_vnodepool_L305
                CMP     #0
                BNE     _vnodepool_L303
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L306
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L306
                LDA     #1
                BRA     _vnodepool_L307
_vnodepool_L306
                LDA     #0
_vnodepool_L307
                CMP     #0
                BEQ     _vnodepool_L302
_vnodepool_L303
                LDA     #73
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L302
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vremfree
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #0
                STA     _fcc_img17
                SEP     #$20
                MX      %10
                LDA     vnode_free_head+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_free_head
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
_vnodepool_L308
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vnodepool_L310
                INC     _fcc_img17
_vnodepool_L309
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
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
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                BRA     _vnodepool_L308
_vnodepool_L310
                LDA     _fcc_img17
                TAX
                LDA     freevnodes
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _vnodepool_L311
                LDA     #74
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L311
                SEP     #$20
                MX      %10
                LDA     vnode_free_head+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_free_head
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
_vnodepool_L312
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vnodepool_L314
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
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
                BEQ     _vnodepool_L314
_vnodepool_L313
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
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
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                BRA     _vnodepool_L312
_vnodepool_L314
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L316
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L316
                LDA     #1
                BRA     _vnodepool_L317
_vnodepool_L316
                LDA     #0
_vnodepool_L317
                CMP     #0
                BEQ     _vnodepool_L315
                LDA     #75
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L315
                SEP     #$20
                MX      %10
                LDA     vnode_free_tail+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_free_tail
                STA     _fcc_fpr0
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr1+2
                LDA     13,S   ; fccstk d=0 b=13
                CLC
                ADC     #26
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L319
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L319
                LDA     #0
                BRA     _vnodepool_L320
_vnodepool_L319
                LDA     #1
_vnodepool_L320
                CMP     #0
                BEQ     _vnodepool_L318
                LDA     #76
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L318
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vnodepool_vn_arena
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vntblinit
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
                STZ     _fcc_fpr0+2
                LDA     #0
                STA     mnt_b+16
                TAY
                LDA     #0
                STA     mnt_b+18
                TYA
                STZ     _fcc_fpr0+2
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
                LDA     #fakeops
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
                BEQ     _vnodepool_L321
                LDA     #77
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L321
                LDA     mnt_a+18
                STA     _fcc_fpr0+2
                LDA     mnt_a+16
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L323
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L323
                LDA     #0
                BRA     _vnodepool_L324
_vnodepool_L323
                LDA     #1
_vnodepool_L324
                CMP     #0
                BEQ     _vnodepool_L322
                LDA     #78
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L322
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #mnt_a
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L326
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L326
                LDA     #0
                BRA     _vnodepool_L327
_vnodepool_L326
                LDA     #1
_vnodepool_L327
                CMP     #0
                BEQ     _vnodepool_L325
                LDA     #79
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L325
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
                LDA     mnt_a+18
                STA     _fcc_fpr0+2
                LDA     mnt_a+16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L329
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L329
                LDA     #0
                BRA     _vnodepool_L330
_vnodepool_L329
                LDA     #1
_vnodepool_L330
                CMP     #0
                BEQ     _vnodepool_L328
                LDA     #80
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L328
                LDA     mnt_b+18
                STA     _fcc_fpr0+2
                LDA     mnt_b+16
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L332
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L332
                LDA     #0
                BRA     _vnodepool_L333
_vnodepool_L332
                LDA     #1
_vnodepool_L333
                CMP     #0
                BEQ     _vnodepool_L331
                LDA     #81
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L331
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
                LDA     mnt_b+18
                STA     _fcc_fpr0+2
                LDA     mnt_b+16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L335
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L335
                LDA     #0
                BRA     _vnodepool_L336
_vnodepool_L335
                LDA     #1
_vnodepool_L336
                CMP     #0
                BEQ     _vnodepool_L334
                LDA     #82
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L334
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L338
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L338
                LDA     #0
                BRA     _vnodepool_L339
_vnodepool_L338
                LDA     #1
_vnodepool_L339
                CMP     #0
                BEQ     _vnodepool_L337
                LDA     #83
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L337
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vnodepool_vn_arena
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vntblinit
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
                STZ     _fcc_fpr0+2
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
                LDA     #fakeops
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
                BEQ     _vnodepool_L340
                LDA     #84
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L340
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
                LDA     #fakeops
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
                BEQ     _vnodepool_L341
                LDA     #85
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L341
                LDA     mnt_a+18
                STA     _fcc_fpr0+2
                LDA     mnt_a+16
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L343
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L343
                LDA     #0
                BRA     _vnodepool_L344
_vnodepool_L343
                LDA     #1
_vnodepool_L344
                CMP     #0
                BEQ     _vnodepool_L342
                LDA     #86
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L342
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL insmntque
                TSC
                CLC
                ADC     #8
                TCS
                LDA     mnt_a+18
                STA     _fcc_fpr0+2
                LDA     mnt_a+16
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L346
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L346
                LDA     #0
                BRA     _vnodepool_L347
_vnodepool_L346
                LDA     #1
_vnodepool_L347
                CMP     #0
                BEQ     _vnodepool_L345
                LDA     #87
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L345
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
                LDA     mnt_a+18
                STA     _fcc_fpr0+2
                LDA     mnt_a+16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L349
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L349
                LDA     #0
                BRA     _vnodepool_L350
_vnodepool_L349
                LDA     #1
_vnodepool_L350
                CMP     #0
                BEQ     _vnodepool_L348
                LDA     #88
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L348
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vnodepool_vn_arena
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vntblinit
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
                LDA     #fakeops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
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
                BEQ     _vnodepool_L351
                LDA     #89
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L351
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vhold
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #1
                BEQ     _vnodepool_L352
                LDA     #90
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L352
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #1
                BEQ     _vnodepool_L353
                LDA     #91
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L353
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
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                BEQ     _vnodepool_L354
                LDA     #92
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L354
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #1
                BEQ     _vnodepool_L355
                LDA     #93
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L355
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL holdrele
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                BEQ     _vnodepool_L356
                LDA     #94
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L356
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vnodepool_vn_arena
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vntblinit
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
                STA     _fcc_img16
_vnodepool_L357
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #64
                BVC     _vnodepool_L360
                EOR     #$8000
_vnodepool_L360
                BPL     _vnodepool_L359
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
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
                LDA     #fakeops
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
                BEQ     _vnodepool_L361
                LDA     #95
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L361
_vnodepool_L358
                INC     _fcc_img16
                BRA     _vnodepool_L357
_vnodepool_L359
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
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
                LDA     #fakeops
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
                TAX
                CMP     #23
                BEQ     _vnodepool_L362
                LDA     #96
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L362
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L364
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L364
                LDA     #0
                BRA     _vnodepool_L365
_vnodepool_L364
                LDA     #1
_vnodepool_L365
                CMP     #0
                BEQ     _vnodepool_L363
                LDA     #97
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L363
                LDA     freevnodes
                BEQ     _vnodepool_L366
                LDA     #98
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L366
                SEP     #$20
                MX      %10
                LDA     vnode_free_head+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_free_head
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L368
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L368
                LDA     #0
                BRA     _vnodepool_L369
_vnodepool_L368
                LDA     #1
_vnodepool_L369
                CMP     #0
                BEQ     _vnodepool_L367
                LDA     #100
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L367
                LDA     _vnodepool_nreclaim
                STA     _fcc_img17
                LDA     _vnodepool_invalbufs
                STA     _fcc_img16
                SEP     #$20
                MX      %10
                LDA     vnode_pool+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_pool
                STA     _fcc_fpr0
                LDA     #3
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vrele
                TSC
                CLC
                ADC     #4
                TCS
                LDA     freevnodes
                TAX
                CMP     #1
                BEQ     _vnodepool_L370
                LDA     #101
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L370
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
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
                LDA     #fakeops
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
                BEQ     _vnodepool_L371
                LDA     #102
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L371
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     vnode_pool+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     vnode_pool
                STA     _fcc_fpr1
                LDA     #3
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
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vnodepool_L373
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vnodepool_L373
                LDA     #0
                BRA     _vnodepool_L374
_vnodepool_L373
                LDA     #1
_vnodepool_L374
                CMP     #0
                BEQ     _vnodepool_L372
                LDA     #103
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_vnodepool_L372
                LDA     _vnodepool_nreclaim
                TAX
                LDA     _fcc_img17
                TAY
                TYA
                INC
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _vnodepool_L375
                LDA     #104
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_vnodepool_L375
                LDA     _vnodepool_invalbufs
                TAX
                LDA     _fcc_img16
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vnodepool_L377
                EOR     #$8000
_vnodepool_L377
                BMI     _vnodepool_L376
                LDA     #105
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_vnodepool_L376
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #1
                BEQ     _vnodepool_L378
                LDA     #106
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_vnodepool_L378
                LDA     freevnodes
                BEQ     _vnodepool_L379
                LDA     #107
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_vnodepool_L379
                LDA     _vnodepool_nslept
                TAX
                CMP     #1
                BEQ     _vnodepool_L380
                LDA     #108
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_vnodepool_L380
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
main_bandx
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     26
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 158
