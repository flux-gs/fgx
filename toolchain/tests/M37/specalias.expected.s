                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from specalias.c
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
                LDA     _specalias_nslept
                INC
                STA     _specalias_nslept
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
                LDA     _specalias_invalbufs
                INC
                STA     _specalias_invalbufs
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
                FGX2_EXPORT _specalias_note
_specalias_note            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_note_FRAMESIZE
                DO      _specalias_note_STKGUARD
                BCC     _specalias_note_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_note_stkok
_specalias_note_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_note_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     _specalias_n_trace
                TAX
                TXA
                SEC
                SBC     #24
                BVC     _specalias_L1
                EOR     #$8000
_specalias_L1
                BMI     *+5
                BRL     _specalias_L0
                LDA     #_specalias_trace
                PHA
                LDA     _specalias_n_trace
                STA     _fcc_tmp_b
                INC
                STA     _specalias_n_trace
                LDA     _fcc_tmp_b
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                DO      8+_specalias_note_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_note_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_note_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
_specalias_L0
                TAY
                TSC
                CLC
                ADC     #_specalias_note_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_note_FRAMESIZE   EQU     0
_specalias_note_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_saw
_specalias_saw            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_saw_FRAMESIZE
                DO      _specalias_saw_STKGUARD
                BCC     _specalias_saw_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_saw_stkok
_specalias_saw_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_saw_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_specalias_saw_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_saw_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_saw_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_specalias_L2
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _specalias_n_trace
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _specalias_L5
                EOR     #$8000
_specalias_L5
                BMI     *+5
                BRL     _specalias_L4
                LDA     _fcc_img0
                ASL
                TAX
                LDA:    _specalias_trace,X
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _specalias_L6
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #_specalias_saw_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L6
_specalias_L3
                INC     _fcc_img0
                BRL     _specalias_L2
_specalias_L4
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_specalias_saw_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_saw_FRAMESIZE   EQU     2
_specalias_saw_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_op_nop
_specalias_op_nop            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_op_nop_FRAMESIZE
                DO      _specalias_op_nop_STKGUARD
                BCC     _specalias_op_nop_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_op_nop_stkok
_specalias_op_nop_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_op_nop_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_specalias_op_nop_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_op_nop_FRAMESIZE   EQU     0
_specalias_op_nop_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_fs_close
_specalias_fs_close            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_fs_close_FRAMESIZE
                DO      _specalias_fs_close_STKGUARD
                BCC     _specalias_fs_close_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_fs_close_stkok
_specalias_fs_close_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_fs_close_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #1
                PHA
                FGX2_FARCALL _specalias_note
                TAY
                PLA
                TYA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_specalias_fs_close_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_fs_close_FRAMESIZE   EQU     0
_specalias_fs_close_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_fs_inactive
_specalias_fs_inactive            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_fs_inactive_FRAMESIZE
                DO      _specalias_fs_inactive_STKGUARD
                BCC     _specalias_fs_inactive_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_fs_inactive_stkok
_specalias_fs_inactive_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_fs_inactive_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #2
                PHA
                FGX2_FARCALL _specalias_note
                TAY
                PLA
                TYA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_specalias_fs_inactive_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_fs_inactive_FRAMESIZE   EQU     0
_specalias_fs_inactive_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_fs_reclaim
_specalias_fs_reclaim            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_fs_reclaim_FRAMESIZE
                DO      _specalias_fs_reclaim_STKGUARD
                BCC     _specalias_fs_reclaim_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_fs_reclaim_stkok
_specalias_fs_reclaim_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_fs_reclaim_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #3
                PHA
                FGX2_FARCALL _specalias_note
                TAY
                PLA
                TYA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_specalias_fs_reclaim_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_fs_reclaim_FRAMESIZE   EQU     0
_specalias_fs_reclaim_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_sp_close
_specalias_sp_close            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_sp_close_FRAMESIZE
                DO      _specalias_sp_close_STKGUARD
                BCC     _specalias_sp_close_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_sp_close_stkok
_specalias_sp_close_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_sp_close_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #4
                PHA
                FGX2_FARCALL _specalias_note
                TAY
                PLA
                TYA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_specalias_sp_close_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_sp_close_FRAMESIZE   EQU     0
_specalias_sp_close_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_sp_lock
_specalias_sp_lock            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_sp_lock_FRAMESIZE
                DO      _specalias_sp_lock_STKGUARD
                BCC     _specalias_sp_lock_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_sp_lock_stkok
_specalias_sp_lock_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_sp_lock_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #5
                PHA
                FGX2_FARCALL _specalias_note
                TAY
                PLA
                TYA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_specalias_sp_lock_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_sp_lock_FRAMESIZE   EQU     0
_specalias_sp_lock_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_sp_unlock
_specalias_sp_unlock            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_sp_unlock_FRAMESIZE
                DO      _specalias_sp_unlock_STKGUARD
                BCC     _specalias_sp_unlock_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_sp_unlock_stkok
_specalias_sp_unlock_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_sp_unlock_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #6
                PHA
                FGX2_FARCALL _specalias_note
                TAY
                PLA
                TYA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_specalias_sp_unlock_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_sp_unlock_FRAMESIZE   EQU     0
_specalias_sp_unlock_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_sp_inactive
_specalias_sp_inactive            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_sp_inactive_FRAMESIZE
                DO      _specalias_sp_inactive_STKGUARD
                BCC     _specalias_sp_inactive_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_sp_inactive_stkok
_specalias_sp_inactive_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_sp_inactive_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #7
                PHA
                FGX2_FARCALL _specalias_note
                TAY
                PLA
                TYA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_specalias_sp_inactive_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_sp_inactive_FRAMESIZE   EQU     0
_specalias_sp_inactive_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_sp_reclaim
_specalias_sp_reclaim            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_sp_reclaim_FRAMESIZE
                DO      _specalias_sp_reclaim_STKGUARD
                BCC     _specalias_sp_reclaim_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_sp_reclaim_stkok
_specalias_sp_reclaim_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_sp_reclaim_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #8
                PHA
                FGX2_FARCALL _specalias_note
                TAY
                PLA
                TYA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_specalias_sp_reclaim_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_sp_reclaim_FRAMESIZE   EQU     0
_specalias_sp_reclaim_STKGUARD    EQU     0
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
                TXA
                CMP     #10
                BEQ     *+5
                BRL     _specalias_L7
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
_specalias_L7
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
                TXA
                CMP     #11
                BEQ     *+5
                BRL     _specalias_L8
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
_specalias_L8
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
                TXA
                CMP     #12
                BEQ     *+5
                BRL     _specalias_L9
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
_specalias_L9
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
                TXA
                CMP     #13
                BEQ     *+5
                BRL     _specalias_L10
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
_specalias_L10
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
                TXA
                CMP     #14
                BEQ     *+5
                BRL     _specalias_L11
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
_specalias_L11
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
                TXA
                CMP     #15
                BEQ     *+5
                BRL     _specalias_L12
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
_specalias_L12
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
                TXA
                CMP     #16
                BEQ     *+5
                BRL     _specalias_L13
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
_specalias_L13
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
                TXA
                CMP     #17
                BEQ     *+5
                BRL     _specalias_L14
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
_specalias_L14
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
                STA     _specalias_vfs_cacheops
                LDA     _fcc_fpr0+2
                STA     _specalias_vfs_cacheops+2
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
                STA     _specalias_vfs_specops
                LDA     _fcc_fpr0+2
                STA     _specalias_vfs_specops+2
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
                FGX2_EXPORT _specalias_zerobytes
_specalias_zerobytes            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_zerobytes_FRAMESIZE
                DO      _specalias_zerobytes_STKGUARD
                BCC     _specalias_zerobytes_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_zerobytes_stkok
_specalias_zerobytes_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_zerobytes_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+_specalias_zerobytes_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_specalias_zerobytes_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_specalias_zerobytes_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img0
                DO      6+_specalias_zerobytes_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_zerobytes_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_zerobytes_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+_specalias_zerobytes_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_zerobytes_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_zerobytes_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
_specalias_L15
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                DEC
                STA     _fcc_img0
                LDA     _fcc_tmp_b
                TAX
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCC     *+5
                BRL     _specalias_L16
                LDA     #0
                SEP     #$20
                MX      %10
                STA     [_fcc_img1]
                REP     #$20
                MX      %00
                INC     _fcc_img1
                BRL     _specalias_L15
_specalias_L16
                TAY
                TSC
                CLC
                ADC     #_specalias_zerobytes_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_zerobytes_FRAMESIZE   EQU     0
_specalias_zerobytes_STKGUARD    EQU     0
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
_specalias_L17
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #8
                BVC     _specalias_L20
                EOR     #$8000
_specalias_L20
                BMI     *+5
                BRL     _specalias_L19
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
_specalias_L18
                INC     _fcc_img0
                BRL     _specalias_L17
_specalias_L19
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
                FGX2_FARCALL _specalias_zerobytes
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
                FGX2_FARCALL _specalias_zerobytes
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
_specalias_L21
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                SEC
                SBC     #64
                BVC     _specalias_L24
                EOR     #$8000
_specalias_L24
                BMI     *+5
                BRL     _specalias_L23
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
_specalias_L22
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRL     _specalias_L21
_specalias_L23
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
                TXA
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
                BNE     *+5
                BRL     _specalias_L25
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
                BRL     _specalias_L26
_specalias_L25
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
_specalias_L26
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
                BEQ     *+5
                BRL     _specalias_L28
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L28
                LDA     #1
                BRL     _specalias_L29
_specalias_L28
                LDA     #0
_specalias_L29
                CMP     #0
                BNE     *+5
                BRL     _specalias_L27
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
_specalias_L27
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                CMP     #0
                BNE     *+5
                BRL     _specalias_L30
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_specalias_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_specalias_L30
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
                TXA
                CMP     #8
                BNE     *+5
                BRL     _specalias_L31
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
_specalias_L31
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
                LDA     _specalias_vfs_cacheops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _specalias_vfs_cacheops
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _specalias_L32
                SEP     #$20
                MX      %10
                LDA     _specalias_vfs_cacheops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _specalias_vfs_cacheops
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
                PEA     _specalias_L33-1
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
_specalias_L33
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
_specalias_L32
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
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _specalias_L35
                EOR     #$8000
_specalias_L35
                BPL     *+5
                BRL     _specalias_L34
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_specalias_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_specalias_L34
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
                TXA
                AND     #256
                CMP     #0
                BNE     *+5
                BRL     _specalias_L36
                LDA     [_fcc_fpr0]
                TAX
                TXA
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
_specalias_L36
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
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L37
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vremfree
                TSC
                CLC
                ADC     #4
                TCS
_specalias_L37
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
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _specalias_L39
                EOR     #$8000
_specalias_L39
                BPL     *+5
                BRL     _specalias_L38
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_specalias_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_specalias_L38
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
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _specalias_L41
                EOR     #$8000
_specalias_L41
                BMI     *+5
                BRL     _specalias_L40
                TAY
                TSC
                CLC
                ADC     #vrele_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L40
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
                PEA     _specalias_L42-1
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
_specalias_L42
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
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _specalias_L44
                EOR     #$8000
_specalias_L44
                BPL     *+5
                BRL     _specalias_L43
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_specalias_S3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_specalias_L43
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
                BRL     _specalias_L45
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
                BNE     *+5
                BRL     _specalias_L46
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
_specalias_L46
_specalias_L45
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
                BEQ     *+5
                BRL     _specalias_L48
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L48
                LDA     #1
                BRL     _specalias_L49
_specalias_L48
                LDA     #0
_specalias_L49
                CMP     #0
                BNE     *+5
                BRL     _specalias_L47
                TAY
                TSC
                CLC
                ADC     #insmntque_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L47
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
                BNE     *+5
                BRL     _specalias_L50
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
_specalias_L50
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
                FGX2_EXPORT _specalias_specalloc
_specalias_specalloc            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_specalloc_FRAMESIZE
                DO      _specalias_specalloc_STKGUARD
                BCC     _specalias_specalloc_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_specalloc_stkok
_specalias_specalloc_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_specalloc_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_img0
_specalias_L51
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #64
                BVC     _specalias_L54
                EOR     #$8000
_specalias_L54
                BMI     *+5
                BRL     _specalias_L53
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
                BEQ     *+5
                BRL     _specalias_L56
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L56
                LDA     #1
                BRL     _specalias_L57
_specalias_L56
                LDA     #0
_specalias_L57
                CMP     #0
                BNE     *+5
                BRL     _specalias_L55
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
                DO      8+_specalias_specalloc_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_specalloc_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_specalloc_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_specalias_specalloc_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_specalloc_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_specalloc_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                ADC     #_specalias_specalloc_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L55
_specalias_L52
                INC     _fcc_img0
                BRL     _specalias_L51
_specalias_L53
                LDA     _fcc_img0
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_specalias_S4
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
                ADC     #_specalias_specalloc_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_specalloc_FRAMESIZE   EQU     2
_specalias_specalloc_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_specfree
_specalias_specfree            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_specfree_FRAMESIZE
                DO      _specalias_specfree_STKGUARD
                BCC     _specalias_specfree_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_specfree_stkok
_specalias_specfree_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_specfree_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_specalias_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_specfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_specfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_specfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_specfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_specfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_specfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_specfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_specfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #65535
                LDY     #12
                STA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #_specalias_specfree_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_specfree_FRAMESIZE   EQU     0
_specalias_specfree_STKGUARD    EQU     0
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
                TXA
                CMP     #3
                BNE     *+5
                BRL     _specalias_L59
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _specalias_L59
                LDA     #1
                BRL     _specalias_L60
_specalias_L59
                LDA     #0
_specalias_L60
                CMP     #0
                BNE     *+5
                BRL     _specalias_L58
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
_specalias_L58
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
_specalias_L61
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
                BRL     _specalias_L63
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
                BEQ     *+5
                BRL     _specalias_L65
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
                BEQ     *+5
                BRL     _specalias_L65
                LDA     #0
                BRL     _specalias_L66
_specalias_L65
                LDA     #1
_specalias_L66
                CMP     #0
                BNE     *+5
                BRL     _specalias_L64
                BRL     _specalias_L62
_specalias_L64
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L67
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
_specalias_L67
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
                CMP     #0
                BNE     *+5
                BRL     _specalias_L68
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     checkalias_uL_loop
_specalias_L68
                BRL     _specalias_L63
_specalias_L62
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
                BRL     _specalias_L61
_specalias_L63
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L72
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L72
                LDA     #1
                BRL     _specalias_L73
_specalias_L72
                LDA     #0
_specalias_L73
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L70
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #58
                LDA     [_fcc_fpr0],Y
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L70
                LDA     #0
                BRL     _specalias_L71
_specalias_L70
                LDA     #1
_specalias_L71
                CMP     #0
                BNE     *+5
                BRL     _specalias_L69
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
                FGX2_FARCALL _specalias_specalloc
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
                BEQ     *+5
                BRL     _specalias_L75
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L75
                LDA     #0
                BRL     _specalias_L76
_specalias_L75
                LDA     #1
_specalias_L76
                CMP     #0
                BNE     *+5
                BRL     _specalias_L74
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
                TXA
                ORA     #2048
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
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
_specalias_L74
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
_specalias_L69
                LDA     #0
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
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
                LDA     _specalias_vfs_specops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _specalias_vfs_specops
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L78
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L78
                LDA     #1
                BRL     _specalias_L79
_specalias_L78
                LDA     #0
_specalias_L79
                CMP     #0
                BNE     *+5
                BRL     _specalias_L77
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
_specalias_L77
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
                LDA     _specalias_vfs_specops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _specalias_vfs_specops
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
                CMP     #0
                BNE     *+5
                BRL     _specalias_L80
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
_specalias_L80
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
                BNE     *+5
                BRL     _specalias_L81
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
_specalias_L81
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
_specalias_L82
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
                BRL     _specalias_L84
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
                BEQ     *+5
                BRL     _specalias_L86
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
                BEQ     *+5
                BRL     _specalias_L86
                LDA     #0
                BRL     _specalias_L87
_specalias_L86
                LDA     #1
_specalias_L87
                CMP     #0
                BNE     *+5
                BRL     _specalias_L85
                BRL     _specalias_L83
_specalias_L85
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
_specalias_L83
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
                BRL     _specalias_L82
_specalias_L84
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
                TXA
                SEC
                SBC     #1
                BVC     _specalias_L89
                EOR     #$8000
_specalias_L89
                BMI     *+5
                BRL     _specalias_L88
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
_specalias_L88
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
                TXA
                CMP     #65535
                BEQ     *+5
                BRL     _specalias_L90
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
_specalias_L90
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
_specalias_L91
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
                BRL     _specalias_L93
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
                BEQ     *+5
                BRL     _specalias_L95
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _specalias_L95
                LDA     #0
                BRL     _specalias_L96
_specalias_L95
                LDA     #1
_specalias_L96
                CMP     #0
                BNE     *+5
                BRL     _specalias_L94
                BRL     _specalias_L92
_specalias_L94
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
                BNE     *+5
                BRL     _specalias_L97
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
_specalias_L97
_specalias_L92
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
                BRL     _specalias_L91
_specalias_L93
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
                TXA
                LDX     #1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _specalias_L99
                EOR     #$8000
_specalias_L99
                BMI     *+5
                BRL     _specalias_L98
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
_specalias_L98
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
                TXA
                AND     #2048
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L100
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
_specalias_L100
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
_specalias_L101
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
                BRL     _specalias_L103
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
                BEQ     *+5
                BRL     _specalias_L105
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
                BEQ     *+5
                BRL     _specalias_L105
                LDA     #0
                BRL     _specalias_L106
_specalias_L105
                LDA     #1
_specalias_L106
                CMP     #0
                BNE     *+5
                BRL     _specalias_L104
                BRL     _specalias_L102
_specalias_L104
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L107
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
_specalias_L107
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
_specalias_L102
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
                BRL     _specalias_L101
_specalias_L103
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
                PEA     _specalias_L108-1
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
_specalias_L108
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
                CMP     #0
                BNE     *+5
                BRL     _specalias_L109
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vref
                TSC
                CLC
                ADC     #4
                TCS
_specalias_L109
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
                TXA
                AND     #256
                CMP     #0
                BNE     *+5
                BRL     _specalias_L110
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_specalias_S5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_specalias_L110
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
                TXA
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
                PEA     _specalias_L111-1
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
_specalias_L111
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
                TXA
                AND     #4
                CMP     #0
                BNE     *+5
                BRL     _specalias_L112
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
_specalias_L112
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
                PEA     _specalias_L113-1
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
_specalias_L113
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     5,S   ; fccstk d=0 b=5
                CMP     #0
                BNE     *+5
                BRL     _specalias_L114
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
                TXA
                AND     #4
                CMP     #0
                BNE     *+5
                BRL     _specalias_L115
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
                PEA     _specalias_L116-1
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
_specalias_L116
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
_specalias_L115
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
                PEA     _specalias_L117-1
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
_specalias_L117
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
_specalias_L114
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
                PEA     _specalias_L119-1
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
_specalias_L119
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _specalias_L118
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_specalias_S6
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_specalias_L118
                LDA     5,S   ; fccstk d=0 b=5
                CMP     #0
                BNE     *+5
                BRL     _specalias_L120
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
_specalias_L120
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
                TXA
                AND     #512
                CMP     #0
                BNE     *+5
                BRL     _specalias_L121
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
_specalias_L121
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
                TXA
                AND     #256
                CMP     #0
                BNE     *+5
                BRL     _specalias_L122
                LDA     [_fcc_fpr0]
                TAX
                TXA
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
_specalias_L122
                LDA     #4
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
                TXA
                CMP     #3
                BNE     *+5
                BRL     _specalias_L124
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _specalias_L124
                LDA     #0
                BRL     _specalias_L125
_specalias_L124
                LDA     #1
_specalias_L125
                CMP     #0
                BNE     *+5
                BRL     _specalias_L123
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L127
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L127
                LDA     #1
                BRL     _specalias_L128
_specalias_L127
                LDA     #0
_specalias_L128
                CMP     #0
                BNE     *+5
                BRL     _specalias_L126
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_specalias_S7
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_specalias_L126
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
                BEQ     *+5
                BRL     _specalias_L130
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L130
                LDA     #1
                BRL     _specalias_L131
_specalias_L130
                LDA     #0
_specalias_L131
                CMP     #0
                BNE     *+5
                BRL     _specalias_L129
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
                BRL     _specalias_L132
_specalias_L129
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
_specalias_L133
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
                BRL     _specalias_L135
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
                BEQ     *+5
                BRL     _specalias_L137
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L137
                LDA     #0
                BRL     _specalias_L138
_specalias_L137
                LDA     #1
_specalias_L138
                CMP     #0
                BNE     *+5
                BRL     _specalias_L136
                BRL     _specalias_L134
_specalias_L136
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
                BRL     _specalias_L135
_specalias_L134
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
                BRL     _specalias_L133
_specalias_L135
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L140
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L140
                LDA     #1
                BRL     _specalias_L141
_specalias_L140
                LDA     #0
_specalias_L141
                CMP     #0
                BNE     *+5
                BRL     _specalias_L139
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_specalias_S8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_specalias_L139
_specalias_L132
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
                TXA
                AND     #2048
                CMP     #0
                BNE     *+5
                BRL     _specalias_L142
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
_specalias_L143
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
                BRL     _specalias_L145
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
                BEQ     *+5
                BRL     _specalias_L147
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
                BEQ     *+5
                BRL     _specalias_L147
                LDA     #0
                BRL     _specalias_L148
_specalias_L147
                LDA     #1
_specalias_L148
                CMP     #0
                BNE     *+5
                BRL     _specalias_L146
                BRL     _specalias_L144
_specalias_L146
                INC     _fcc_img0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
_specalias_L144
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
                BRL     _specalias_L143
_specalias_L145
                LDA     _fcc_img0
                STA     9,S   ; fccstk d=0 b=9
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L149
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_specalias_S9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_specalias_L149
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _specalias_L150
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
_specalias_L150
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
_specalias_L142
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _specalias_specfree
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
_specalias_L123
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
                BRL     _specalias_L151
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
                BNE     *+5
                BRL     _specalias_L152
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
                BRL     _specalias_L153
_specalias_L152
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
_specalias_L153
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
_specalias_L151
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
                BNE     *+5
                BRL     _specalias_L154
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_specalias_S10
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_specalias_L154
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
_specalias_L155
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
                BRL     _specalias_L157
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
                BEQ     *+5
                BRL     _specalias_L159
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L159
                LDA     #0
                BRL     _specalias_L160
_specalias_L159
                LDA     #1
_specalias_L160
                CMP     #0
                BNE     *+5
                BRL     _specalias_L158
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     vflush_uL_loop
_specalias_L158
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
                BEQ     *+5
                BRL     _specalias_L162
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L162
                LDA     #1
                BRL     _specalias_L163
_specalias_L162
                LDA     #0
_specalias_L163
                CMP     #0
                BNE     *+5
                BRL     _specalias_L161
                BRL     _specalias_L156
_specalias_L161
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
                TXA
                AND     #1
                CMP     #0
                BNE     *+5
                BRL     _specalias_L165
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                AND     #4
                CMP     #0
                BNE     *+5
                BRL     _specalias_L165
                LDA     #1
                BRL     _specalias_L166
_specalias_L165
                LDA     #0
_specalias_L166
                CMP     #0
                BNE     *+5
                BRL     _specalias_L164
                BRL     _specalias_L156
_specalias_L164
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L167
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
                BRL     _specalias_L156
_specalias_L167
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
                TXA
                AND     #2
                CMP     #0
                BNE     *+5
                BRL     _specalias_L168
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #3
                BNE     *+5
                BRL     _specalias_L170
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _specalias_L170
                LDA     #1
                BRL     _specalias_L171
_specalias_L170
                LDA     #0
_specalias_L171
                CMP     #0
                BNE     *+5
                BRL     _specalias_L169
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
                BRL     _specalias_L172
_specalias_L169
                LDA     #0
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vclean
                TSC
                CLC
                ADC     #6
                TCS
                SEP     #$20
                MX      %10
                LDA     _specalias_vfs_specops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _specalias_vfs_specops
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L174
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L174
                LDA     #1
                BRL     _specalias_L175
_specalias_L174
                LDA     #0
_specalias_L175
                CMP     #0
                BNE     *+5
                BRL     _specalias_L173
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
                BRL     _specalias_L156
_specalias_L173
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _specalias_vfs_specops+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _specalias_vfs_specops
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
_specalias_L172
                BRL     _specalias_L156
_specalias_L168
                LDA     9,S   ; fccstk d=0 b=9
                CLC
                ADC     #1
                STA     9,S   ; fccstk d=0 b=9
_specalias_L156
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _specalias_L155
_specalias_L157
                LDA     9,S   ; fccstk d=0 b=9
                CMP     #0
                BNE     *+5
                BRL     _specalias_L176
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
_specalias_L176
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
                BPL     *+5
                BRL     _specalias_L178
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
                TXA
                SEC
                SBC     #2
                BVC     _specalias_L180
                EOR     #$8000
_specalias_L180
                BMI     *+5
                BRL     _specalias_L178
                LDA     #0
                BRL     _specalias_L179
_specalias_L178
                LDA     #1
_specalias_L179
                CMP     #0
                BNE     *+5
                BRL     _specalias_L177
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
_specalias_L177
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
                TXA
                SEC
                SBC     #1
                BVC     _specalias_L184
                EOR     #$8000
_specalias_L184
                BPL     *+5
                BRL     _specalias_L182
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
                TXA
                LDX     #32
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _specalias_L185
                EOR     #$8000
_specalias_L185
                BPL     *+5
                BRL     _specalias_L182
                LDA     #0
                BRL     _specalias_L183
_specalias_L182
                LDA     #1
_specalias_L183
                CMP     #0
                BNE     *+5
                BRL     _specalias_L181
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
_specalias_L181
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
                BEQ     *+5
                BRL     _specalias_L187
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L187
                LDA     #1
                BRL     _specalias_L188
_specalias_L187
                LDA     #0
_specalias_L188
                CMP     #0
                BNE     *+5
                BRL     _specalias_L186
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
_specalias_L186
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
                TXA
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
_specalias_L189
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                SEC
                SBC     #158
                BVC     _specalias_L192
                EOR     #$8000
_specalias_L192
                BMI     *+5
                BRL     _specalias_L191
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
_specalias_L190
                INC     _fcc_img0
                BRL     _specalias_L189
_specalias_L191
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
                TXA
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
                BEQ     *+5
                BRL     _specalias_L196
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L196
                LDA     #1
                BRL     _specalias_L197
_specalias_L196
                LDA     #0
_specalias_L197
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L194
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L198
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L198
                LDA     #1
                BRL     _specalias_L199
_specalias_L198
                LDA     #0
_specalias_L199
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L194
                LDA     #0
                BRL     _specalias_L195
_specalias_L194
                LDA     #1
_specalias_L195
                CMP     #0
                BNE     *+5
                BRL     _specalias_L193
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
_specalias_L193
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
                LDA     _specalias_vfs_cacheops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _specalias_vfs_cacheops
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _specalias_L200
                SEP     #$20
                MX      %10
                LDA     _specalias_vfs_cacheops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _specalias_vfs_cacheops
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
                PEA     _specalias_L201-1
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
_specalias_L201
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
_specalias_L200
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
                PEA     _specalias_L202-1
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
_specalias_L202
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                STA     5,S   ; fccstk d=0 b=5
                CMP     #0
                BNE     *+5
                BRL     _specalias_L203
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
_specalias_L203
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
                BEQ     *+5
                BRL     _specalias_L207
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L207
                LDA     #0
                BRL     _specalias_L208
_specalias_L207
                LDA     #1
_specalias_L208
                CMP     #0
                BNE     *+5
                BRL     _specalias_L205
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
                BEQ     *+5
                BRL     _specalias_L209
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L209
                LDA     #0
                BRL     _specalias_L210
_specalias_L209
                LDA     #1
_specalias_L210
                CMP     #0
                BNE     *+5
                BRL     _specalias_L205
                LDA     #1
                BRL     _specalias_L206
_specalias_L205
                LDA     #0
_specalias_L206
                CMP     #0
                BNE     *+5
                BRL     _specalias_L204
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
_specalias_L204
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L212
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L212
                LDA     #0
                BRL     _specalias_L213
_specalias_L212
                LDA     #1
_specalias_L213
                CMP     #0
                BNE     *+5
                BRL     _specalias_L211
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
_specalias_L211
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
                FGX2_EXPORT _specalias_nchbucket
_specalias_nchbucket            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_nchbucket_FRAMESIZE
                DO      _specalias_nchbucket_STKGUARD
                BCC     _specalias_nchbucket_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_nchbucket_stkok
_specalias_nchbucket_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_nchbucket_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_specalias_nchbucket_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nchbucket_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nchbucket_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_specalias_nchbucket_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nchbucket_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nchbucket_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16
                TAX
                TXA
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
                ADC     #_specalias_nchbucket_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_nchbucket_FRAMESIZE   EQU     0
_specalias_nchbucket_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_ncinshash
_specalias_ncinshash            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_ncinshash_FRAMESIZE
                DO      _specalias_ncinshash_STKGUARD
                BCC     _specalias_ncinshash_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_ncinshash_stkok
_specalias_ncinshash_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_ncinshash_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_specalias_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+_specalias_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_specalias_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_specalias_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+_specalias_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_specalias_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_specalias_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
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
                DO      8+_specalias_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+_specalias_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_specalias_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_specalias_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+_specalias_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_specalias_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_specalias_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
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
                DO      12+_specalias_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_specalias_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_specalias_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_specalias_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_specalias_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_specalias_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
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
                DO      8+_specalias_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_specalias_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      12+_specalias_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_specalias_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_specalias_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_specalias_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_specalias_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_specalias_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
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
                ADC     #_specalias_ncinshash_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_ncinshash_FRAMESIZE   EQU     0
_specalias_ncinshash_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_ncremhash
_specalias_ncremhash            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_ncremhash_FRAMESIZE
                DO      _specalias_ncremhash_STKGUARD
                BCC     _specalias_ncremhash_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_ncremhash_stkok
_specalias_ncremhash_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_ncremhash_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_specalias_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_specalias_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_specalias_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                ADC     #_specalias_ncremhash_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_ncremhash_FRAMESIZE   EQU     0
_specalias_ncremhash_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_nclru_totail
_specalias_nclru_totail            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_nclru_totail_FRAMESIZE
                DO      _specalias_nclru_totail_STKGUARD
                BCC     _specalias_nclru_totail_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_nclru_totail_stkok
_specalias_nclru_totail_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_nclru_totail_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                BEQ     *+5
                BRL     _specalias_L215
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L215
                LDA     #1
                BRL     _specalias_L216
_specalias_L215
                LDA     #0
_specalias_L216
                CMP     #0
                BNE     *+5
                BRL     _specalias_L214
                TAY
                TSC
                CLC
                ADC     #_specalias_nclru_totail_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L214
                DO      8+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                ADC     #_specalias_nclru_totail_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_nclru_totail_FRAMESIZE   EQU     0
_specalias_nclru_totail_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_nclru_remove
_specalias_nclru_remove            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_nclru_remove_FRAMESIZE
                DO      _specalias_nclru_remove_STKGUARD
                BCC     _specalias_nclru_remove_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_nclru_remove_stkok
_specalias_nclru_remove_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_nclru_remove_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_specalias_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_specalias_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                BNE     *+5
                BRL     _specalias_L217
                DO      8+_specalias_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_specalias_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                BRL     _specalias_L218
_specalias_L217
                DO      8+_specalias_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
_specalias_L218
                TAY
                TSC
                CLC
                ADC     #_specalias_nclru_remove_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_nclru_remove_FRAMESIZE   EQU     0
_specalias_nclru_remove_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_nclru_tohead
_specalias_nclru_tohead            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_nclru_tohead_FRAMESIZE
                DO      _specalias_nclru_tohead_STKGUARD
                BCC     _specalias_nclru_tohead_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_nclru_tohead_stkok
_specalias_nclru_tohead_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_nclru_tohead_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_specalias_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                BNE     *+5
                BRL     _specalias_L219
                SEP     #$20
                MX      %10
                LDA     nchhead+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     nchhead
                STA     _fcc_fpr0
                DO      8+_specalias_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_specalias_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                BRL     _specalias_L220
_specalias_L219
                DO      8+_specalias_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #8
                STA     _fcc_fpr0
                STA     nchtail
                LDA     _fcc_fpr0+2
                STA     nchtail+2
_specalias_L220
                DO      8+_specalias_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                STA     nchhead
                LDA     _fcc_fpr0+2
                STA     nchhead+2
                TAY
                TSC
                CLC
                ADC     #_specalias_nclru_tohead_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_nclru_tohead_FRAMESIZE   EQU     0
_specalias_nclru_tohead_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_ncdetach
_specalias_ncdetach            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_ncdetach_FRAMESIZE
                DO      _specalias_ncdetach_STKGUARD
                BCC     _specalias_ncdetach_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_ncdetach_stkok
_specalias_ncdetach_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_ncdetach_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_specalias_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _specalias_ncremhash
                TSC
                CLC
                ADC     #4
                TCS
                DO      8+_specalias_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      8+_specalias_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_specalias_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_specalias_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_specalias_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                ADC     #_specalias_ncdetach_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_ncdetach_FRAMESIZE   EQU     0
_specalias_ncdetach_STKGUARD    EQU     0
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
_specalias_L221
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #16
                BVC     _specalias_L224
                EOR     #$8000
_specalias_L224
                BMI     *+5
                BRL     _specalias_L223
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
_specalias_L222
                INC     _fcc_img0
                BRL     _specalias_L221
_specalias_L223
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
                BEQ     *+5
                BRL     _specalias_L226
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L226
                LDA     #1
                BRL     _specalias_L227
_specalias_L226
                LDA     #0
_specalias_L227
                CMP     #0
                BNE     *+5
                BRL     _specalias_L225
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
_specalias_L225
                LDA     #64
                TAX
                TXA
                SEC
                SBC     #1
                STA     1,S   ; fccstk d=0 b=1
_specalias_L228
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                CMP     #0
                BPL     *+5
                BRL     _specalias_L230
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
                FGX2_FARCALL _specalias_nclru_tohead
                TSC
                CLC
                ADC     #4
                TCS
_specalias_L229
                LDA     1,S   ; fccstk d=0 b=1
                SEC
                SBC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRL     _specalias_L228
_specalias_L230
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
_specalias_L231
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
                BVC     _specalias_L234
                EOR     #$8000
_specalias_L234
                BMI     *+5
                BRL     _specalias_L233
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
_specalias_L232
                INC     _fcc_img0
                BRL     _specalias_L231
_specalias_L233
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
                FGX2_EXPORT _specalias_namecmp
_specalias_namecmp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_namecmp_FRAMESIZE
                DO      _specalias_namecmp_STKGUARD
                BCC     _specalias_namecmp_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_namecmp_stkok
_specalias_namecmp_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_namecmp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      14+_specalias_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_specalias_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_specalias_namecmp_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_img0
                DO      6+_specalias_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_namecmp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+_specalias_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_specalias_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_specalias_namecmp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
                DO      10+_specalias_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_specalias_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_specalias_namecmp_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img3
                DO      12+_specalias_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_specalias_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_specalias_namecmp_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img4
_specalias_L235
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                DEC
                STA     _fcc_img0
                LDA     _fcc_tmp_b
                CMP     #0
                BNE     *+5
                BRL     _specalias_L236
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
                BNE     *+5
                BRL     _specalias_L237
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #_specalias_namecmp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L237
                BRL     _specalias_L235
_specalias_L236
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_specalias_namecmp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_namecmp_FRAMESIZE   EQU     0
_specalias_namecmp_STKGUARD    EQU     0
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
                BNE     *+5
                BRL     _specalias_L238
                TAY
                TSC
                CLC
                ADC     #cache_purge_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L238
                LDA     #0
                STA     _fcc_img0
_specalias_L239
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #16
                BVC     _specalias_L242
                EOR     #$8000
_specalias_L242
                BMI     *+5
                BRL     _specalias_L241
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
_specalias_L243
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
                BEQ     *+5
                BRL     _specalias_L246
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L246
                LDA     #0
                BRL     _specalias_L247
_specalias_L246
                LDA     #1
_specalias_L247
                CMP     #0
                BNE     *+5
                BRL     _specalias_L245
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
_specalias_L244
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
                BRL     _specalias_L243
_specalias_L245
_specalias_L240
                INC     _fcc_img0
                BRL     _specalias_L239
_specalias_L241
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
_specalias_L248
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                TXA
                SEC
                SBC     #16
                BVC     _specalias_L251
                EOR     #$8000
_specalias_L251
                BMI     *+5
                BRL     _specalias_L250
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
_specalias_L252
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
                BEQ     *+5
                BRL     _specalias_L255
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L255
                LDA     #0
                BRL     _specalias_L256
_specalias_L255
                LDA     #1
_specalias_L256
                CMP     #0
                BNE     *+5
                BRL     _specalias_L254
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
                BEQ     *+5
                BRL     _specalias_L260
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L260
                LDA     #1
                BRL     _specalias_L261
_specalias_L260
                LDA     #0
_specalias_L261
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L258
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
                BEQ     *+5
                BRL     _specalias_L262
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L262
                LDA     #0
                BRL     _specalias_L263
_specalias_L262
                LDA     #1
_specalias_L263
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L258
                LDA     #0
                BRL     _specalias_L259
_specalias_L258
                LDA     #1
_specalias_L259
                CMP     #0
                BNE     *+5
                BRL     _specalias_L257
                BRL     _specalias_L253
_specalias_L257
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
                FGX2_FARCALL _specalias_ncdetach
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
                FGX2_FARCALL _specalias_nclru_remove
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
                FGX2_FARCALL _specalias_nclru_tohead
                TSC
                CLC
                ADC     #4
                TCS
_specalias_L253
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _specalias_L252
_specalias_L254
_specalias_L249
                LDA     13,S   ; fccstk d=0 b=13
                CLC
                ADC     #1
                STA     13,S   ; fccstk d=0 b=13
                BRL     _specalias_L248
_specalias_L250
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
                CMP     #0
                BEQ     _specalias_L265
                LDA     #0
                BRA     _specalias_L266
_specalias_L265
                LDA     #1
_specalias_L266
                CMP     #0
                BNE     *+5
                BRL     _specalias_L264
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
_specalias_L264
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
                TXA
                LDX     #31
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _specalias_L268
                EOR     #$8000
_specalias_L268
                BMI     *+5
                BRL     _specalias_L267
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
_specalias_L267
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
                FGX2_FARCALL _specalias_nchbucket
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
_specalias_L269
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
                BEQ     *+5
                BRL     _specalias_L272
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L272
                LDA     #0
                BRL     _specalias_L273
_specalias_L272
                LDA     #1
_specalias_L273
                CMP     #0
                BNE     *+5
                BRL     _specalias_L271
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
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr1+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L281
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L281
                LDA     #1
                BRL     _specalias_L282
_specalias_L281
                LDA     #0
_specalias_L282
                CMP     #0
                BNE     *+5
                BRL     _specalias_L279
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
                BRL     _specalias_L279
                LDA     #1
                BRL     _specalias_L280
_specalias_L279
                LDA     #0
_specalias_L280
                CMP     #0
                BNE     *+5
                BRL     _specalias_L277
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
                BEQ     *+5
                BRL     _specalias_L277
                LDA     #1
                BRL     _specalias_L278
_specalias_L277
                LDA     #0
_specalias_L278
                CMP     #0
                BNE     *+5
                BRL     _specalias_L275
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
                FGX2_FARCALL _specalias_namecmp
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L275
                LDA     #1
                BRL     _specalias_L276
_specalias_L275
                LDA     #0
_specalias_L276
                CMP     #0
                BNE     *+5
                BRL     _specalias_L274
                BRL     _specalias_L271
_specalias_L274
_specalias_L270
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
                BRL     _specalias_L269
_specalias_L271
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
                BEQ     *+5
                BRL     _specalias_L284
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L284
                LDA     #1
                BRL     _specalias_L285
_specalias_L284
                LDA     #0
_specalias_L285
                CMP     #0
                BNE     *+5
                BRL     _specalias_L283
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
_specalias_L283
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
                BEQ     _specalias_L287
                LDA     #0
                BRA     _specalias_L288
_specalias_L287
                LDA     #1
_specalias_L288
                CMP     #0
                BNE     *+5
                BRL     _specalias_L286
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
                BRL     _specalias_L289
_specalias_L286
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
                BEQ     *+5
                BRL     _specalias_L291
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L291
                LDA     #1
                BRL     _specalias_L292
_specalias_L291
                LDA     #0
_specalias_L292
                CMP     #0
                BNE     *+5
                BRL     _specalias_L290
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
                FGX2_FARCALL _specalias_nclru_totail
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
                BRL     _specalias_L293
_specalias_L290
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
                BNE     *+5
                BRL     _specalias_L294
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
                BRL     _specalias_L295
_specalias_L294
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
                FGX2_FARCALL _specalias_nclru_totail
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
_specalias_L295
_specalias_L293
_specalias_L289
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _specalias_nclru_remove
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
                FGX2_FARCALL _specalias_ncdetach
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
                FGX2_FARCALL _specalias_nclru_tohead
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
                CMP     #0
                BEQ     _specalias_L297
                LDA     #0
                BRA     _specalias_L298
_specalias_L297
                LDA     #1
_specalias_L298
                CMP     #0
                BNE     *+5
                BRL     _specalias_L296
                TAY
                TSC
                CLC
                ADC     #cache_enter_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L296
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
                TXA
                LDX     #31
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _specalias_L300
                EOR     #$8000
_specalias_L300
                BMI     *+5
                BRL     _specalias_L299
                TAY
                TSC
                CLC
                ADC     #cache_enter_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L299
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
                BEQ     *+5
                BRL     _specalias_L302
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L302
                LDA     #1
                BRL     _specalias_L303
_specalias_L302
                LDA     #0
_specalias_L303
                CMP     #0
                BNE     *+5
                BRL     _specalias_L301
                TAY
                TSC
                CLC
                ADC     #cache_enter_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L301
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _specalias_nclru_remove
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
                FGX2_FARCALL _specalias_ncremhash
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
                BNE     *+5
                BRL     _specalias_L304
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
                BRL     _specalias_L305
_specalias_L304
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
_specalias_L305
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
_specalias_L306
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
                BVC     _specalias_L309
                EOR     #$8000
_specalias_L309
                BMI     *+5
                BRL     _specalias_L308
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
_specalias_L307
                INC     _fcc_img0
                BRL     _specalias_L306
_specalias_L308
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
                FGX2_FARCALL _specalias_nchbucket
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
                FGX2_FARCALL _specalias_ncinshash
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
                FGX2_EXPORT _specalias_spec_inuse
_specalias_spec_inuse            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_spec_inuse_FRAMESIZE
                DO      _specalias_spec_inuse_STKGUARD
                BCC     _specalias_spec_inuse_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_spec_inuse_stkok
_specalias_spec_inuse_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_spec_inuse_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_specalias_L310
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #64
                BVC     _specalias_L313
                EOR     #$8000
_specalias_L313
                BMI     *+5
                BRL     _specalias_L312
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
                BEQ     *+5
                BRL     _specalias_L315
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L315
                LDA     #0
                BRL     _specalias_L316
_specalias_L315
                LDA     #1
_specalias_L316
                CMP     #0
                BNE     *+5
                BRL     _specalias_L314
                INC     _fcc_img1
_specalias_L314
_specalias_L311
                INC     _fcc_img0
                BRL     _specalias_L310
_specalias_L312
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #_specalias_spec_inuse_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_spec_inuse_FRAMESIZE   EQU     4
_specalias_spec_inuse_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_chainlen
_specalias_chainlen            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_chainlen_FRAMESIZE
                DO      _specalias_chainlen_STKGUARD
                BCC     _specalias_chainlen_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_chainlen_stkok
_specalias_chainlen_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_chainlen_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_specalias_chainlen_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_specalias_chainlen_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_specalias_chainlen_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
                LDA     _fcc_img1
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
_specalias_L317
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
                BRL     _specalias_L319
                LDA     _fcc_img0
                INC
                STA     _fcc_img0
                PHA
                LDA     #64
                TAX
                TXA
                INC
                INC
                STA     _fcc_tmp_b
                PLA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _specalias_L321
                EOR     #$8000
_specalias_L321
                BMI     *+5
                BRL     _specalias_L320
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_specalias_chainlen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L320
_specalias_L318
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
                BRL     _specalias_L317
_specalias_L319
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #_specalias_chainlen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_chainlen_FRAMESIZE   EQU     6
_specalias_chainlen_STKGUARD    EQU     0
                FGX2_EXPORT _specalias_reset
_specalias_reset            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_specalias_reset_FRAMESIZE
                DO      _specalias_reset_STKGUARD
                BCC     _specalias_reset_stkovf
                CMP     _fcc_stkfloor
                BCS     _specalias_reset_stkok
_specalias_reset_stkovf       JMP     _fcc_stkoflow
                FIN
_specalias_reset_stkok        TCS
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
                LDA     #_specalias_vn_arena
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
                LDA     #spec_vnodeops
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vfs_setspecops
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
                STA     _specalias_n_trace
                LDA     #0
                STA     _specalias_invalbufs
                TAY
                TSC
                CLC
                ADC     #_specalias_reset_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_reset_FRAMESIZE   EQU     0
_specalias_reset_STKGUARD    EQU     0
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
                FGX2_FARCALL _specalias_reset
                LDA     #769
                LSR
                LSR
                LSR
                LSR
                LSR
                TAX
                TXA
                CLC
                ADC     #769
                TAX
                LDA     #8
                TAY
                TYA
                DEC
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                TAX
                LDA     #777
                LSR
                LSR
                LSR
                LSR
                LSR
                TAY
                TYA
                CLC
                ADC     #777
                TAY
                LDA     #8
                DEC
                STA     _fcc_tmp_b
                TYA
                AND     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _specalias_L322
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
_specalias_L322
                LDA     #769
                LSR
                LSR
                LSR
                LSR
                LSR
                TAX
                TXA
                CLC
                ADC     #769
                TAX
                LDA     #8
                TAY
                TYA
                DEC
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                TAX
                LDA     #770
                LSR
                LSR
                LSR
                LSR
                LSR
                TAY
                TYA
                CLC
                ADC     #770
                TAY
                LDA     #8
                DEC
                STA     _fcc_tmp_b
                TYA
                AND     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _specalias_L323
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
_specalias_L323
                LDA     #769
                LSR
                LSR
                LSR
                LSR
                LSR
                TAX
                TXA
                CLC
                ADC     #769
                TAX
                LDA     #8
                TAY
                TYA
                DEC
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                STA     27,S   ; fccstk d=0 b=27
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
                BNE     *+5
                BRL     _specalias_L324
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
_specalias_L324
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
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
                LDA     #769
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L326
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L326
                LDA     #0
                BRL     _specalias_L327
_specalias_L326
                LDA     #1
_specalias_L327
                CMP     #0
                BNE     *+5
                BRL     _specalias_L325
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
_specalias_L325
                FGX2_FARCALL _specalias_spec_inuse
                CMP     #0
                BNE     *+5
                BRL     _specalias_L328
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
_specalias_L328
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
                CMP     #0
                BNE     *+5
                BRL     _specalias_L329
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
_specalias_L329
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #3
                LDY     #52
                STA     [_fcc_fpr0],Y
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
                LDA     #769
                PHA
                LDA     13,S   ; fccstk d=6 b=7
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=6 b=5
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L331
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L331
                LDA     #0
                BRL     _specalias_L332
_specalias_L331
                LDA     #1
_specalias_L332
                CMP     #0
                BNE     *+5
                BRL     _specalias_L330
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
_specalias_L330
                FGX2_FARCALL _specalias_spec_inuse
                TAX
                TXA
                CMP     #1
                BNE     *+5
                BRL     _specalias_L333
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
_specalias_L333
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
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
                TAX
                TXA
                CMP     #769
                BNE     *+5
                BRL     _specalias_L334
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
_specalias_L334
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
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
                LDA     27,S   ; fccstk d=0 b=27
                ASL
                ASL
                CLC
                ADC     #speclisth
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L336
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L336
                LDA     #0
                BRL     _specalias_L337
_specalias_L336
                LDA     #1
_specalias_L337
                CMP     #0
                BNE     *+5
                BRL     _specalias_L335
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
_specalias_L335
                LDA     27,S   ; fccstk d=0 b=27
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
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L339
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L339
                LDA     #0
                BRL     _specalias_L340
_specalias_L339
                LDA     #1
_specalias_L340
                CMP     #0
                BNE     *+5
                BRL     _specalias_L338
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
_specalias_L338
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L342
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L342
                LDA     #0
                BRL     _specalias_L343
_specalias_L342
                LDA     #1
_specalias_L343
                CMP     #0
                BNE     *+5
                BRL     _specalias_L341
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
_specalias_L341
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                AND     #2048
                CMP     #0
                BNE     *+5
                BRL     _specalias_L344
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
_specalias_L344
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
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
                BNE     *+5
                BRL     _specalias_L345
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
_specalias_L345
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
                CMP     #0
                BNE     *+5
                BRL     _specalias_L346
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
_specalias_L346
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDA     #3
                LDY     #52
                STA     [_fcc_fpr0],Y
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     25,S   ; fccstk d=0 b=25
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
                LDA     #769
                PHA
                LDA     17,S   ; fccstk d=6 b=11
                STA     _fcc_fpr0+2
                LDA     15,S   ; fccstk d=6 b=9
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L348
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L348
                LDA     #0
                BRL     _specalias_L349
_specalias_L348
                LDA     #1
_specalias_L349
                CMP     #0
                BNE     *+5
                BRL     _specalias_L347
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
_specalias_L347
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     27,S   ; fccstk d=2 b=25
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _specalias_L350
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
_specalias_L350
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                AND     #2048
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L351
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
_specalias_L351
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                AND     #2048
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L352
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
_specalias_L352
                LDA     27,S   ; fccstk d=0 b=27
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
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr1+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L354
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L354
                LDA     #0
                BRL     _specalias_L355
_specalias_L354
                LDA     #1
_specalias_L355
                CMP     #0
                BNE     *+5
                BRL     _specalias_L353
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
_specalias_L353
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
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
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L357
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L357
                LDA     #0
                BRL     _specalias_L358
_specalias_L357
                LDA     #1
_specalias_L358
                CMP     #0
                BNE     *+5
                BRL     _specalias_L356
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
_specalias_L356
                FGX2_FARCALL _specalias_spec_inuse
                TAX
                TXA
                CMP     #2
                BNE     *+5
                BRL     _specalias_L359
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
_specalias_L359
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
                BNE     *+5
                BRL     _specalias_L360
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
_specalias_L360
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDA     #3
                LDY     #52
                STA     [_fcc_fpr0],Y
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
                LDA     #777
                PHA
                LDA     21,S   ; fccstk d=6 b=15
                STA     _fcc_fpr0+2
                LDA     19,S   ; fccstk d=6 b=13
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L362
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L362
                LDA     #0
                BRL     _specalias_L363
_specalias_L362
                LDA     #1
_specalias_L363
                CMP     #0
                BNE     *+5
                BRL     _specalias_L361
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
_specalias_L361
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                AND     #2048
                CMP     #0
                BNE     *+5
                BRL     _specalias_L364
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
_specalias_L364
                LDA     27,S   ; fccstk d=0 b=27
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
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr1+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L366
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L366
                LDA     #0
                BRL     _specalias_L367
_specalias_L366
                LDA     #1
_specalias_L367
                CMP     #0
                BNE     *+5
                BRL     _specalias_L365
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
_specalias_L365
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
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
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr1+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L369
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L369
                LDA     #0
                BRL     _specalias_L370
_specalias_L369
                LDA     #1
_specalias_L370
                CMP     #0
                BNE     *+5
                BRL     _specalias_L368
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
_specalias_L368
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
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
                BNE     *+5
                BRL     _specalias_L371
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
_specalias_L371
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                LDA     #4
                LDY     #52
                STA     [_fcc_fpr0],Y
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
                LDA     #769
                PHA
                LDA     25,S   ; fccstk d=6 b=19
                STA     _fcc_fpr0+2
                LDA     23,S   ; fccstk d=6 b=17
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L373
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L373
                LDA     #0
                BRL     _specalias_L374
_specalias_L373
                LDA     #1
_specalias_L374
                CMP     #0
                BNE     *+5
                BRL     _specalias_L372
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
_specalias_L372
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                AND     #2048
                CMP     #0
                BNE     *+5
                BRL     _specalias_L375
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
_specalias_L375
                LDA     27,S   ; fccstk d=0 b=27
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
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr1+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L377
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L377
                LDA     #0
                BRL     _specalias_L378
_specalias_L377
                LDA     #1
_specalias_L378
                CMP     #0
                BNE     *+5
                BRL     _specalias_L376
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
_specalias_L376
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
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
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr1+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L380
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L380
                LDA     #0
                BRL     _specalias_L381
_specalias_L380
                LDA     #1
_specalias_L381
                CMP     #0
                BNE     *+5
                BRL     _specalias_L379
                LDA     #99
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L379
                LDA     27,S   ; fccstk d=0 b=27
                PHA
                FGX2_FARCALL _specalias_chainlen
                TAY
                PLA
                TYA
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _specalias_L382
                LDA     #149
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L382
                LDA     #0
                STA     21,S   ; fccstk d=0 b=21
                LDA     #0
                STA     23,S   ; fccstk d=0 b=23
                LDA     21,S   ; fccstk d=0 b=21
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #20
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #3
                PHA
                LDA     #769
                PHA
                FGX2_FARCALL vfinddev
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _specalias_L383
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
_specalias_L383
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_fpr0+2
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_fpr0
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr1+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L387
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L387
                LDA     #0
                BRL     _specalias_L388
_specalias_L387
                LDA     #1
_specalias_L388
                CMP     #0
                BNE     *+5
                BRL     _specalias_L385
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_fpr0+2
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L389
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L389
                LDA     #0
                BRL     _specalias_L390
_specalias_L389
                LDA     #1
_specalias_L390
                CMP     #0
                BNE     *+5
                BRL     _specalias_L385
                LDA     #1
                BRL     _specalias_L386
_specalias_L385
                LDA     #0
_specalias_L386
                CMP     #0
                BNE     *+5
                BRL     _specalias_L384
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
_specalias_L384
                LDA     #0
                STA     21,S   ; fccstk d=0 b=21
                LDA     #0
                STA     23,S   ; fccstk d=0 b=23
                LDA     21,S   ; fccstk d=0 b=21
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #20
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #4
                PHA
                LDA     #769
                PHA
                FGX2_FARCALL vfinddev
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _specalias_L391
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
_specalias_L391
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_fpr0+2
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_fpr0
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr1+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L393
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L393
                LDA     #0
                BRL     _specalias_L394
_specalias_L393
                LDA     #1
_specalias_L394
                CMP     #0
                BNE     *+5
                BRL     _specalias_L392
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
_specalias_L392
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #20
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #3
                PHA
                LDA     #770
                PHA
                FGX2_FARCALL vfinddev
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                TXA
                CMP     #1
                BNE     *+5
                BRL     _specalias_L395
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
_specalias_L395
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vcount
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #2
                BNE     *+5
                BRL     _specalias_L396
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
_specalias_L396
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vref
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
                FGX2_FARCALL vcount
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #3
                BNE     *+5
                BRL     _specalias_L397
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
_specalias_L397
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vcount
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #3
                BNE     *+5
                BRL     _specalias_L398
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
_specalias_L398
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
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vcount
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PHA
                LDA     17,S   ; fccstk d=2 b=15
                STA     _fcc_fpr0+2
                LDA     15,S   ; fccstk d=2 b=13
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _specalias_L399
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
_specalias_L399
                FGX2_FARCALL _specalias_spec_inuse
                STA     25,S   ; fccstk d=0 b=25
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
                FGX2_FARCALL _specalias_spec_inuse
                PHA
                LDA     27,S   ; fccstk d=2 b=25
                TAX
                TXA
                DEC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _specalias_L400
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
_specalias_L400
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
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
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L402
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L402
                LDA     #0
                BRL     _specalias_L403
_specalias_L402
                LDA     #1
_specalias_L403
                CMP     #0
                BNE     *+5
                BRL     _specalias_L401
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
_specalias_L401
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                AND     #2048
                CMP     #0
                BNE     *+5
                BRL     _specalias_L404
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
_specalias_L404
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                AND     #2048
                CMP     #0
                BNE     *+5
                BRL     _specalias_L405
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
_specalias_L405
                LDA     27,S   ; fccstk d=0 b=27
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
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr1+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L407
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L407
                LDA     #0
                BRL     _specalias_L408
_specalias_L407
                LDA     #1
_specalias_L408
                CMP     #0
                BNE     *+5
                BRL     _specalias_L406
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
_specalias_L406
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
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
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr1+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L410
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L410
                LDA     #0
                BRL     _specalias_L411
_specalias_L410
                LDA     #1
_specalias_L411
                CMP     #0
                BNE     *+5
                BRL     _specalias_L409
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
_specalias_L409
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
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
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L413
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L413
                LDA     #0
                BRL     _specalias_L414
_specalias_L413
                LDA     #1
_specalias_L414
                CMP     #0
                BNE     *+5
                BRL     _specalias_L412
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
_specalias_L412
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L416
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L416
                LDA     #0
                BRL     _specalias_L417
_specalias_L416
                LDA     #1
_specalias_L417
                CMP     #0
                BNE     *+5
                BRL     _specalias_L415
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
_specalias_L415
                LDA     27,S   ; fccstk d=0 b=27
                PHA
                FGX2_FARCALL _specalias_chainlen
                TAY
                PLA
                TYA
                TAX
                TXA
                CMP     #3
                BNE     *+5
                BRL     _specalias_L418
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
_specalias_L418
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #8
                BNE     *+5
                BRL     _specalias_L419
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
_specalias_L419
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
                LDA     27,S   ; fccstk d=0 b=27
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
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr1+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L421
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L421
                LDA     #0
                BRL     _specalias_L422
_specalias_L421
                LDA     #1
_specalias_L422
                CMP     #0
                BNE     *+5
                BRL     _specalias_L420
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
_specalias_L420
                LDA     27,S   ; fccstk d=0 b=27
                PHA
                FGX2_FARCALL _specalias_chainlen
                TAY
                PLA
                TYA
                TAX
                TXA
                CMP     #2
                BNE     *+5
                BRL     _specalias_L423
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
_specalias_L423
                FGX2_FARCALL _specalias_reset
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
                LDA     #770
                PHA
                FGX2_FARCALL bdevvp
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _specalias_L424
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
_specalias_L424
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #3
                BNE     *+5
                BRL     _specalias_L425
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
_specalias_L425
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #58
                LDA     [_fcc_fpr0],Y
                CMP     #0
                BNE     *+5
                BRL     _specalias_L426
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
_specalias_L426
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #spec_vnodeops
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L428
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L428
                LDA     #0
                BRL     _specalias_L429
_specalias_L428
                LDA     #1
_specalias_L429
                CMP     #0
                BNE     *+5
                BRL     _specalias_L427
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
_specalias_L427
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
                LDY     #12
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #770
                BNE     *+5
                BRL     _specalias_L430
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
_specalias_L430
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
                BEQ     *+5
                BRL     _specalias_L432
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L432
                LDA     #0
                BRL     _specalias_L433
_specalias_L432
                LDA     #1
_specalias_L433
                CMP     #0
                BNE     *+5
                BRL     _specalias_L431
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
_specalias_L431
                FGX2_FARCALL _specalias_spec_inuse
                TAX
                TXA
                CMP     #1
                BNE     *+5
                BRL     _specalias_L434
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
_specalias_L434
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
                CMP     #0
                BNE     *+5
                BRL     _specalias_L435
                LDA     #111
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L435
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #3
                LDY     #52
                STA     [_fcc_fpr0],Y
                LDA     #0
                STA     _specalias_n_trace
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
                LDA     #770
                PHA
                LDA     13,S   ; fccstk d=6 b=7
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=6 b=5
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
                STA     23,S   ; fccstk d=0 b=23
                LDA     _fcc_fpr0
                STA     21,S   ; fccstk d=0 b=21
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_fpr0+2
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L437
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L437
                LDA     #0
                BRL     _specalias_L438
_specalias_L437
                LDA     #1
_specalias_L438
                CMP     #0
                BNE     *+5
                BRL     _specalias_L436
                LDA     #112
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L436
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                CMP     #0
                BNE     *+5
                BRL     _specalias_L439
                LDA     #113
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L439
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L441
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L441
                LDA     #0
                BRL     _specalias_L442
_specalias_L441
                LDA     #1
_specalias_L442
                CMP     #0
                BNE     *+5
                BRL     _specalias_L440
                LDA     #114
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L440
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #58
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #1
                BNE     *+5
                BRL     _specalias_L443
                LDA     #115
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L443
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
                BEQ     *+5
                BRL     _specalias_L445
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L445
                LDA     #0
                BRL     _specalias_L446
_specalias_L445
                LDA     #1
_specalias_L446
                CMP     #0
                BNE     *+5
                BRL     _specalias_L444
                LDA     #116
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L444
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
                LDY     #12
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #770
                BNE     *+5
                BRL     _specalias_L447
                LDA     #117
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L447
                FGX2_FARCALL _specalias_spec_inuse
                TAX
                TXA
                CMP     #1
                BNE     *+5
                BRL     _specalias_L448
                LDA     #118
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L448
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                AND     #2048
                CMP     #0
                BNE     *+5
                BRL     _specalias_L449
                LDA     #119
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L449
                LDA     #8
                PHA
                FGX2_FARCALL _specalias_saw
                TAY
                PLA
                TYA
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L450
                LDA     #120
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L450
                LDA     #4
                PHA
                FGX2_FARCALL _specalias_saw
                TAY
                PLA
                TYA
                CMP     #0
                BNE     *+5
                BRL     _specalias_L451
                LDA     #121
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L451
                LDA     _specalias_invalbufs
                CMP     #0
                BNE     *+5
                BRL     _specalias_L452
                LDA     #122
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L452
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vput
                TSC
                CLC
                ADC     #4
                TCS
                FGX2_FARCALL _specalias_reset
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
                BNE     *+5
                BRL     _specalias_L453
                LDA     #123
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L453
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #3
                LDY     #52
                STA     [_fcc_fpr0],Y
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
                LDA     #769
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L455
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L455
                LDA     #0
                BRL     _specalias_L456
_specalias_L455
                LDA     #1
_specalias_L456
                CMP     #0
                BNE     *+5
                BRL     _specalias_L454
                LDA     #124
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L454
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
                LDA     27,S   ; fccstk d=0 b=27
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
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L458
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L458
                LDA     #0
                BRL     _specalias_L459
_specalias_L458
                LDA     #1
_specalias_L459
                CMP     #0
                BNE     *+5
                BRL     _specalias_L457
                LDA     #125
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L457
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
                CMP     #0
                BNE     *+5
                BRL     _specalias_L460
                LDA     #126
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L460
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L462
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L462
                LDA     #1
                BRL     _specalias_L463
_specalias_L462
                LDA     #0
_specalias_L463
                CMP     #0
                BNE     *+5
                BRL     _specalias_L461
                LDA     #127
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L461
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #3
                LDY     #52
                STA     [_fcc_fpr0],Y
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
                LDA     #769
                PHA
                LDA     13,S   ; fccstk d=6 b=7
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=6 b=5
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L465
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L465
                LDA     #0
                BRL     _specalias_L466
_specalias_L465
                LDA     #1
_specalias_L466
                CMP     #0
                BNE     *+5
                BRL     _specalias_L464
                LDA     #128
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L464
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #8
                BNE     *+5
                BRL     _specalias_L467
                LDA     #129
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L467
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                AND     #2048
                CMP     #0
                BNE     *+5
                BRL     _specalias_L468
                LDA     #130
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L468
                LDA     27,S   ; fccstk d=0 b=27
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
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L470
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L470
                LDA     #0
                BRL     _specalias_L471
_specalias_L470
                LDA     #1
_specalias_L471
                CMP     #0
                BNE     *+5
                BRL     _specalias_L469
                LDA     #131
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L469
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L473
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L473
                LDA     #0
                BRL     _specalias_L474
_specalias_L473
                LDA     #1
_specalias_L474
                CMP     #0
                BNE     *+5
                BRL     _specalias_L472
                LDA     #132
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L472
                FGX2_FARCALL _specalias_spec_inuse
                TAX
                TXA
                CMP     #1
                BNE     *+5
                BRL     _specalias_L475
                LDA     #133
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L475
                FGX2_FARCALL _specalias_reset
                LDA     #$0040
                STA     _fcc_long_hi
                LDA     #$0000
                STA     mnt_a+20
                TAY
                LDA     _fcc_long_hi
                STA     mnt_a+22
                TYA
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
                BNE     *+5
                BRL     _specalias_L476
                LDA     #134
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L476
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #3
                LDY     #52
                STA     [_fcc_fpr0],Y
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
                LDA     #769
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L478
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L478
                LDA     #0
                BRL     _specalias_L479
_specalias_L478
                LDA     #1
_specalias_L479
                CMP     #0
                BNE     *+5
                BRL     _specalias_L477
                LDA     #135
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L477
                LDA     #0
                PHA
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
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
                FGX2_FARCALL vflush
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                TAX
                TXA
                CMP     #16
                BNE     *+5
                BRL     _specalias_L480
                LDA     #136
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L480
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #fsops
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L482
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L482
                LDA     #0
                BRL     _specalias_L483
_specalias_L482
                LDA     #1
_specalias_L483
                CMP     #0
                BNE     *+5
                BRL     _specalias_L481
                LDA     #137
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L481
                LDA     #0
                STA     _specalias_n_trace
                LDA     #2
                PHA
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
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
                FGX2_FARCALL vflush
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _specalias_L484
                LDA     #138
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L484
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #3
                BNE     *+5
                BRL     _specalias_L485
                LDA     #139
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L485
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #spec_vnodeops
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L487
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L487
                LDA     #0
                BRL     _specalias_L488
_specalias_L487
                LDA     #1
_specalias_L488
                CMP     #0
                BNE     *+5
                BRL     _specalias_L486
                LDA     #140
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L486
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
                BEQ     *+5
                BRL     _specalias_L490
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L490
                LDA     #0
                BRL     _specalias_L491
_specalias_L490
                LDA     #1
_specalias_L491
                CMP     #0
                BNE     *+5
                BRL     _specalias_L489
                LDA     #141
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L489
                LDA     mnt_a+18
                STA     _fcc_fpr0+2
                LDA     mnt_a+16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L493
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L493
                LDA     #0
                BRL     _specalias_L494
_specalias_L493
                LDA     #1
_specalias_L494
                CMP     #0
                BNE     *+5
                BRL     _specalias_L492
                LDA     #142
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L492
                LDA     27,S   ; fccstk d=0 b=27
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
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _specalias_L496
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _specalias_L496
                LDA     #0
                BRL     _specalias_L497
_specalias_L496
                LDA     #1
_specalias_L497
                CMP     #0
                BNE     *+5
                BRL     _specalias_L495
                LDA     #143
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L495
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
                LDY     #12
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #769
                BNE     *+5
                BRL     _specalias_L498
                LDA     #144
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L498
                FGX2_FARCALL _specalias_spec_inuse
                TAX
                TXA
                CMP     #1
                BNE     *+5
                BRL     _specalias_L499
                LDA     #145
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L499
                LDA     #1
                PHA
                FGX2_FARCALL _specalias_saw
                TAY
                PLA
                TYA
                CMP     #0
                BNE     *+5
                BRL     _specalias_L500
                LDA     #146
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L500
                LDA     #3
                PHA
                FGX2_FARCALL _specalias_saw
                TAY
                PLA
                TYA
                CMP     #0
                BEQ     *+5
                BRL     _specalias_L501
                LDA     #147
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L501
                LDA     _specalias_nslept
                CMP     #0
                BNE     *+5
                BRL     _specalias_L502
                LDA     #148
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_specalias_L502
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
main_FRAMESIZE   EQU     28
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 196
