                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from vreclaim.c
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
                LDA     _vreclaim_nslept
                INC
                STA     _vreclaim_nslept
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
                FGX2_EXPORT bio_strategy
bio_strategy            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #bio_strategy_FRAMESIZE
                DO      bio_strategy_STKGUARD
                BCC     bio_strategy_stkovf
                CMP     _fcc_stkfloor
                BCS     bio_strategy_stkok
bio_strategy_stkovf       JMP     _fcc_stkoflow
                FIN
bio_strategy_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+bio_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bio_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bio_strategy_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bio_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bio_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bio_strategy_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #34
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #32
                LDA     [_fcc_fpr0],Y
                STA     1,S   ; fccstk d=0 b=1
                BMI     _vreclaim_L1
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                SEC
                SBC     #64
                BVC     _vreclaim_L2
                EOR     #$8000
_vreclaim_L2
                BMI     _vreclaim_L0
_vreclaim_L1
                LDA     [_fcc_fpr0]
                TAX
                ORA     #4
                STA     [_fcc_fpr0]
                LDA     #5
                SEP     #$20
                MX      %10
                LDY     #20
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL biodone
                TSC
                CLC
                ADC     #4
                TCS
                TAY
                TSC
                CLC
                ADC     #bio_strategy_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L0
                LDA     [_fcc_fpr0]
                TAX
                AND     #1
                BEQ     _vreclaim_L3
                LDA     _vreclaim_fake_reads
                INC
                STA     _vreclaim_fake_reads
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
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA:    _vreclaim_fake_disk,X
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                BRA     _vreclaim_L4
_vreclaim_L3
                LDA     _vreclaim_fake_writes
                INC
                STA     _vreclaim_fake_writes
                LDA     #_vreclaim_fake_disk
                PHA
                LDA     3,S   ; fccstk d=2 b=1
                CLC
                ADC     1,S
                TAY
                PLA
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
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
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
_vreclaim_L4
                DO      8+bio_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bio_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bio_strategy_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bio_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bio_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bio_strategy_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL biodone
                TSC
                CLC
                ADC     #4
                TCS
                TAY
                TSC
                CLC
                ADC     #bio_strategy_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bio_strategy_FRAMESIZE   EQU     2
bio_strategy_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_bufhashof
_vreclaim_bufhashof            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_bufhashof_FRAMESIZE
                DO      _vreclaim_bufhashof_STKGUARD
                BCC     _vreclaim_bufhashof_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_bufhashof_stkok
_vreclaim_bufhashof_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_bufhashof_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_vreclaim_bufhashof_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bufhashof_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bufhashof_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_bufhashof_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bufhashof_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bufhashof_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shrs16
                PHA
                DO      14+_vreclaim_bufhashof_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_vreclaim_bufhashof_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_vreclaim_bufhashof_FRAMESIZE,S   ; fccstk d=2 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      12+_vreclaim_bufhashof_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_bufhashof_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_bufhashof_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #16
                TAX
                DEC
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #_vreclaim_bufhashof_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_bufhashof_FRAMESIZE   EQU     0
_vreclaim_bufhashof_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_bremhash
_vreclaim_bremhash            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_bremhash_FRAMESIZE
                DO      _vreclaim_bremhash_STKGUARD
                BCC     _vreclaim_bremhash_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_bremhash_stkok
_vreclaim_bremhash_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_bremhash_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_vreclaim_bremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_bremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+_vreclaim_bremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_bremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #2
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+_vreclaim_bremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_bremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+_vreclaim_bremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_bremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #6
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #8
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #6
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #8
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                TAY
                TSC
                CLC
                ADC     #_vreclaim_bremhash_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_bremhash_FRAMESIZE   EQU     0
_vreclaim_bremhash_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_binshash
_vreclaim_binshash            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_binshash_FRAMESIZE
                DO      _vreclaim_binshash_STKGUARD
                BCC     _vreclaim_binshash_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_binshash_stkok
_vreclaim_binshash_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_binshash_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_vreclaim_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_binshash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_binshash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+_vreclaim_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_binshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+_vreclaim_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_binshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr1
                LDY     #2
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+_vreclaim_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_binshash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_binshash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+_vreclaim_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_binshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+_vreclaim_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_binshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr1
                LDY     #6
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #8
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      12+_vreclaim_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_binshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_vreclaim_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_binshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+_vreclaim_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_binshash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_binshash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #6
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #8
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      12+_vreclaim_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_binshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_vreclaim_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_binshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
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
                ADC     #_vreclaim_binshash_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_binshash_FRAMESIZE   EQU     0
_vreclaim_binshash_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_bremfree
_vreclaim_bremfree            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_bremfree_FRAMESIZE
                DO      _vreclaim_bremfree_STKGUARD
                BCC     _vreclaim_bremfree_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_bremfree_stkok
_vreclaim_bremfree_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_bremfree_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_vreclaim_bremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bremfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_bremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bremfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #16
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+_vreclaim_bremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bremfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_bremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bremfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #10
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #12
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                LDY     #10
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #12
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+_vreclaim_bremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bremfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_bremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bremfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+_vreclaim_bremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bremfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_bremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bremfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #14
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #16
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #14
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #16
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                TAY
                TSC
                CLC
                ADC     #_vreclaim_bremfree_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_bremfree_FRAMESIZE   EQU     0
_vreclaim_bremfree_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_binsheadfree
_vreclaim_binsheadfree            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_binsheadfree_FRAMESIZE
                DO      _vreclaim_binsheadfree_STKGUARD
                BCC     _vreclaim_binsheadfree_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_binsheadfree_stkok
_vreclaim_binsheadfree_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_binsheadfree_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+_vreclaim_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_vreclaim_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+_vreclaim_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDY     #14
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #16
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+_vreclaim_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+_vreclaim_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+_vreclaim_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr1
                LDY     #10
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #12
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #10
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #12
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      12+_vreclaim_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_vreclaim_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                DO      8+_vreclaim_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #10
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #12
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+_vreclaim_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+_vreclaim_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+_vreclaim_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr1
                LDY     #14
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #16
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
                ADC     #_vreclaim_binsheadfree_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_binsheadfree_FRAMESIZE   EQU     0
_vreclaim_binsheadfree_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_binstailfree
_vreclaim_binstailfree            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_binstailfree_FRAMESIZE
                DO      _vreclaim_binstailfree_STKGUARD
                BCC     _vreclaim_binstailfree_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_binstailfree_stkok
_vreclaim_binstailfree_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_binstailfree_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+_vreclaim_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_vreclaim_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #16
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+_vreclaim_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDY     #10
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #12
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+_vreclaim_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+_vreclaim_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+_vreclaim_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr1
                LDY     #14
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #16
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #14
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #16
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      12+_vreclaim_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_vreclaim_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                DO      8+_vreclaim_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #14
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #16
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+_vreclaim_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+_vreclaim_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+_vreclaim_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr1
                LDY     #10
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #12
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
                ADC     #_vreclaim_binstailfree_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_binstailfree_FRAMESIZE   EQU     0
_vreclaim_binstailfree_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_bufinsvn
_vreclaim_bufinsvn            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_bufinsvn_FRAMESIZE
                DO      _vreclaim_bufinsvn_STKGUARD
                BCC     _vreclaim_bufinsvn_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_bufinsvn_stkok
_vreclaim_bufinsvn_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_bufinsvn_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      10+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_ptr
                DO      12+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
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
                LDY     #42
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #44
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr1
                LDY     #46
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #48
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #42
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #44
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vreclaim_L5
                DO      8+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #42
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #44
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                DO      8+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #42
                STA     _fcc_fpr1
                LDY     #46
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #48
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
_vreclaim_L5
                DO      12+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                DO      8+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                TAY
                TSC
                CLC
                ADC     #_vreclaim_bufinsvn_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_bufinsvn_FRAMESIZE   EQU     0
_vreclaim_bufinsvn_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_bufremvn
_vreclaim_bufremvn            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_bufremvn_FRAMESIZE
                DO      _vreclaim_bufremvn_STKGUARD
                BCC     _vreclaim_bufremvn_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_bufremvn_stkok
_vreclaim_bufremvn_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_bufremvn_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_vreclaim_bufremvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bufremvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bufremvn_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_bufremvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bufremvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bufremvn_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #46
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #48
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
                BNE     _vreclaim_L7
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L7
                LDA     #1
                BRA     _vreclaim_L8
_vreclaim_L7
                LDA     #0
_vreclaim_L8
                CMP     #0
                BEQ     _vreclaim_L6
                TAY
                TSC
                CLC
                ADC     #_vreclaim_bufremvn_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L6
                DO      8+_vreclaim_bufremvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bufremvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bufremvn_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_bufremvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bufremvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bufremvn_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #42
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #44
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
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vreclaim_L9
                LDA     _fcc_fpr0
                DO      8+_vreclaim_bufremvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bufremvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bufremvn_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_bufremvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bufremvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bufremvn_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #46
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #48
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #46
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #48
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
_vreclaim_L9
                DO      8+_vreclaim_bufremvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bufremvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bufremvn_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_bufremvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bufremvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bufremvn_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #46
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #48
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+_vreclaim_bufremvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bufremvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bufremvn_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_bufremvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bufremvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bufremvn_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
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
                LDA     _fcc_fpr1+2
                DO      8+_vreclaim_bufremvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_bufremvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_bufremvn_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_bufremvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_bufremvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_bufremvn_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
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
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #_vreclaim_bufremvn_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_bufremvn_FRAMESIZE   EQU     4
_vreclaim_bufremvn_STKGUARD    EQU     0
                FGX2_EXPORT bufinit
bufinit            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #bufinit_FRAMESIZE
                DO      bufinit_STKGUARD
                BCC     bufinit_stkovf
                CMP     _fcc_stkfloor
                BCS     bufinit_stkok
bufinit_stkovf       JMP     _fcc_stkoflow
                FIN
bufinit_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_img0
_vreclaim_L10
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #3
                BVC     _vreclaim_L13
                EOR     #$8000
_vreclaim_L13
                BPL     _vreclaim_L12
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #bfreelist
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
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1
                LDY     #10
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #12
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr1
                LDY     #14
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #16
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
_vreclaim_L11
                INC     _fcc_img0
                BRA     _vreclaim_L10
_vreclaim_L12
                LDA     _fcc_img0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
_vreclaim_L14
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                SEC
                SBC     #16
                BVC     _vreclaim_L17
                EOR     #$8000
_vreclaim_L17
                BPL     _vreclaim_L16
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #bufhash
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
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr1
                LDY     #6
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #8
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
_vreclaim_L15
                LDA     9,S   ; fccstk d=0 b=9
                CLC
                ADC     #1
                STA     9,S   ; fccstk d=0 b=9
                BRL     _vreclaim_L14
_vreclaim_L16
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #bfreelist+100
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
_vreclaim_L18
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                SEC
                SBC     #16
                BVC     _vreclaim_L21
                EOR     #$8000
_vreclaim_L21
                BMI     *+5
                BRL     _vreclaim_L20
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #buf
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #2048
                STA     [_fcc_fpr0]
                LDA     #0
                LDY     #22
                STA     [_fcc_fpr0],Y
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
                LDY     #32
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #34
                STA     [_fcc_fpr0],Y
                TXA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #1024
                LDY     #18
                STA     [_fcc_fpr0],Y
                LDA     #0
                SEP     #$20
                MX      %10
                LDY     #20
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #0
                LDY     #36
                STA     [_fcc_fpr0],Y
                LDA     _fcc_fpr0
                DO      8+bufinit_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bufinit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bufinit_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+bufinit_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bufinit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bufinit_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDA     9,S   ; fccstk d=0 b=9
                ASL
                ASL
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
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1
                LDY     #6
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #8
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
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_binstailfree
                TSC
                CLC
                ADC     #8
                TCS
_vreclaim_L19
                LDA     9,S   ; fccstk d=0 b=9
                CLC
                ADC     #1
                STA     9,S   ; fccstk d=0 b=9
                BRL     _vreclaim_L18
_vreclaim_L20
                TAY
                TSC
                CLC
                ADC     #bufinit_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bufinit_FRAMESIZE   EQU     10
bufinit_STKGUARD    EQU     0
                FGX2_EXPORT incore
incore            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #incore_FRAMESIZE
                DO      incore_STKGUARD
                BCC     incore_stkovf
                CMP     _fcc_stkfloor
                BCS     incore_stkok
incore_stkovf       JMP     _fcc_stkoflow
                FIN
incore_stkok        TCS
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
                LDA     #bufhash
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      16+incore_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+incore_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+incore_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+incore_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+incore_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+incore_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      16+incore_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+incore_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+incore_FRAMESIZE,S   ; fccstk d=8 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      14+incore_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+incore_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+incore_FRAMESIZE,S   ; fccstk d=8 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _vreclaim_bufhashof
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
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
_vreclaim_L22
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
                BNE     _vreclaim_L25
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L25
                LDA     #0
                BRA     _vreclaim_L26
_vreclaim_L25
                LDA     #1
_vreclaim_L26
                CMP     #0
                BNE     *+5
                BRL     _vreclaim_L24
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
                DO      16+incore_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+incore_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+incore_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+incore_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+incore_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+incore_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
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
                BEQ     _vreclaim_L27
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                DO      8+incore_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+incore_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+incore_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+incore_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+incore_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+incore_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vreclaim_L28
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L28
                LDA     #1
                BRA     _vreclaim_L29
_vreclaim_L28
                LDA     #0
_vreclaim_L29
                CMP     #0
                BEQ     _vreclaim_L27
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #2048
                CMP     #0
                BNE     _vreclaim_L27
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #incore_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L27
_vreclaim_L23
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
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
                BRL     _vreclaim_L22
_vreclaim_L24
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #incore_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
incore_FRAMESIZE   EQU     8
incore_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_getnewbuf
_vreclaim_getnewbuf            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_getnewbuf_FRAMESIZE
                DO      _vreclaim_getnewbuf_STKGUARD
                BCC     _vreclaim_getnewbuf_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_getnewbuf_stkok
_vreclaim_getnewbuf_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_getnewbuf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
_vreclaim_getnewbuf_uL_again
_vreclaim_L30
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #bfreelist+100
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDY     #10
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #12
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
                BNE     _vreclaim_L34
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L34
                LDA     #1
                BRA     _vreclaim_L35
_vreclaim_L34
                LDA     #0
_vreclaim_L35
                CMP     #0
                BEQ     _vreclaim_L33
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #bfreelist+50
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
_vreclaim_L33
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #12
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
                BNE     _vreclaim_L37
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L37
                LDA     #0
                BRA     _vreclaim_L38
_vreclaim_L37
                LDA     #1
_vreclaim_L38
                CMP     #0
                BEQ     _vreclaim_L36
                BRA     _vreclaim_L32
_vreclaim_L36
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #64
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_sleep
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L31
                BRL     _vreclaim_L30
_vreclaim_L32
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #12
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
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_bremfree
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #8
                STA     [_fcc_fpr0]
                LDA     [_fcc_fpr0]
                TAX
                AND     #512
                BEQ     _vreclaim_L39
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bwrite
                TSC
                CLC
                ADC     #4
                TCS
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     _vreclaim_getnewbuf_uL_again
_vreclaim_L39
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
                BEQ     _vreclaim_L40
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelvp
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L40
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_bremhash
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1
                LDY     #6
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #8
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #8
                STA     [_fcc_fpr0]
                LDA     #0
                SEP     #$20
                MX      %10
                LDY     #20
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #0
                LDY     #36
                STA     [_fcc_fpr0],Y
                LDA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #_vreclaim_getnewbuf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_getnewbuf_FRAMESIZE   EQU     8
_vreclaim_getnewbuf_STKGUARD    EQU     0
                FGX2_EXPORT getblk
getblk            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #getblk_FRAMESIZE
                DO      getblk_STKGUARD
                BCC     getblk_stkovf
                CMP     _fcc_stkfloor
                BCS     getblk_stkok
getblk_stkovf       JMP     _fcc_stkoflow
                FIN
getblk_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+getblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+getblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+getblk_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+getblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+getblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+getblk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vreclaim_L42
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L42
                LDA     #1
                BRA     _vreclaim_L43
_vreclaim_L42
                LDA     #0
_vreclaim_L43
                CMP     #0
                BEQ     _vreclaim_L41
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L41
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #bufhash
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      16+getblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+getblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+getblk_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+getblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+getblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+getblk_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      16+getblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+getblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+getblk_FRAMESIZE,S   ; fccstk d=8 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      14+getblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+getblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+getblk_FRAMESIZE,S   ; fccstk d=8 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _vreclaim_bufhashof
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
getblk_uL_loop
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
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
_vreclaim_L44
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
                BNE     _vreclaim_L47
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L47
                LDA     #0
                BRA     _vreclaim_L48
_vreclaim_L47
                LDA     #1
_vreclaim_L48
                CMP     #0
                BNE     *+5
                BRL     _vreclaim_L46
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
                DO      16+getblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+getblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+getblk_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+getblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+getblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+getblk_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
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
                BNE     _vreclaim_L50
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                DO      8+getblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+getblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+getblk_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+getblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+getblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+getblk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vreclaim_L51
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L51
                LDA     #0
                BRA     _vreclaim_L52
_vreclaim_L51
                LDA     #1
_vreclaim_L52
                CMP     #0
                BNE     _vreclaim_L50
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #2048
                CMP     #0
                BEQ     _vreclaim_L49
_vreclaim_L50
                BRA     _vreclaim_L45
_vreclaim_L49
                LDA     [_fcc_fpr0]
                TAX
                AND     #8
                BEQ     _vreclaim_L53
                LDA     [_fcc_fpr0]
                TAX
                ORA     #64
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_sleep
                TSC
                CLC
                ADC     #4
                TCS
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     getblk_uL_loop
_vreclaim_L53
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_bremfree
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #8
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #getblk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L45
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
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
                BRL     _vreclaim_L44
_vreclaim_L46
                FGX2_FARCALL _vreclaim_getnewbuf
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+getblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+getblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+getblk_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+getblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+getblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+getblk_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bgetvp
                TSC
                CLC
                ADC     #8
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                DO      12+getblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+getblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+getblk_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      10+getblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+getblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+getblk_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                LDY     #28
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #30
                STA     [_fcc_fpr0],Y
                TXA
                LDA     _fcc_fpr0
                DO      12+getblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+getblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+getblk_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      10+getblk_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+getblk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+getblk_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                LDY     #32
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #34
                STA     [_fcc_fpr0],Y
                TXA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_binshash
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
                ADC     #getblk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
getblk_FRAMESIZE   EQU     8
getblk_STKGUARD    EQU     0
                FGX2_EXPORT brelse
brelse            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #brelse_FRAMESIZE
                DO      brelse_STKGUARD
                BCC     brelse_stkovf
                CMP     _fcc_stkfloor
                BCS     brelse_stkok
brelse_stkovf       JMP     _fcc_stkoflow
                FIN
brelse_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+brelse_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+brelse_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #64
                BEQ     _vreclaim_L54
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_wakeup
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L54
                LDA     #2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #bfreelist
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                TAX
                AND     #64
                BEQ     _vreclaim_L55
                LDA     #2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #bfreelist
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                PHA
                LDA     #64
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #bfreelist+100
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_wakeup
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L55
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #bfreelist
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                TAX
                AND     #64
                BEQ     _vreclaim_L56
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #bfreelist
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                PHA
                LDA     #64
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #bfreelist+50
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_wakeup
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L56
                DO      8+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+brelse_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+brelse_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #4
                BEQ     _vreclaim_L57
                LDA     [_fcc_fpr0]
                TAX
                ORA     #2048
                STA     [_fcc_fpr0]
_vreclaim_L57
                LDA     [_fcc_fpr0]
                TAX
                AND     #2048
                BNE     *+5
                BRL     _vreclaim_L58
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
                BEQ     _vreclaim_L59
                DO      8+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+brelse_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+brelse_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelvp
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L59
                DO      8+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+brelse_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+brelse_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_bremhash
                TSC
                CLC
                ADC     #4
                TCS
                DO      8+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+brelse_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+brelse_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      8+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+brelse_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+brelse_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+brelse_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+brelse_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr1
                LDY     #6
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #8
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                DO      8+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+brelse_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+brelse_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #512
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_fpr0]
_vreclaim_L58
                LDA     [_fcc_fpr0]
                TAX
                AND     #2048
                BEQ     _vreclaim_L60
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #bfreelist+100
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRA     _vreclaim_L61
_vreclaim_L60
                LDA     [_fcc_fpr0]
                TAX
                AND     #8192
                BEQ     _vreclaim_L62
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #bfreelist
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRA     _vreclaim_L63
_vreclaim_L62
                LDA     [_fcc_fpr0]
                TAX
                AND     #128
                BEQ     _vreclaim_L64
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #bfreelist+100
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRA     _vreclaim_L65
_vreclaim_L64
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #bfreelist+50
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_vreclaim_L65
_vreclaim_L63
_vreclaim_L61
                DO      8+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+brelse_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+brelse_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #2048
                TAX
                ORA     #128
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                BEQ     _vreclaim_L66
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+brelse_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+brelse_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_binsheadfree
                TSC
                CLC
                ADC     #8
                TCS
                BRA     _vreclaim_L67
_vreclaim_L66
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+brelse_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+brelse_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_binstailfree
                TSC
                CLC
                ADC     #8
                TCS
_vreclaim_L67
                DO      8+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+brelse_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+brelse_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+brelse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+brelse_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #64
                TAX
                ORA     #8
                TAX
                ORA     #256
                TAX
                ORA     #128
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_fpr0]
                TAY
                TSC
                CLC
                ADC     #brelse_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
brelse_FRAMESIZE   EQU     4
brelse_STKGUARD    EQU     0
                FGX2_EXPORT biowait
biowait            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #biowait_FRAMESIZE
                DO      biowait_STKGUARD
                BCC     biowait_stkovf
                CMP     _fcc_stkfloor
                BCS     biowait_stkok
biowait_stkovf       JMP     _fcc_stkoflow
                FIN
biowait_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
_vreclaim_L68
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                DO      8+biowait_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+biowait_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+biowait_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+biowait_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+biowait_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+biowait_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #2
                BNE     _vreclaim_L69
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_sleep
                TSC
                CLC
                ADC     #4
                TCS
                BRA     _vreclaim_L68
_vreclaim_L69
                LDA     [_fcc_fpr0]
                TAX
                AND     #4
                BNE     _vreclaim_L70
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #biowait_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L70
                LDY     #20
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                BEQ     _vreclaim_L71
                LDY     #20
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                BRA     _vreclaim_L72
_vreclaim_L71
                LDA     #5
_vreclaim_L72
                TAY
                TSC
                CLC
                ADC     #biowait_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
biowait_FRAMESIZE   EQU     0
biowait_STKGUARD    EQU     0
                FGX2_EXPORT biodone
biodone            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #biodone_FRAMESIZE
                DO      biodone_STKGUARD
                BCC     biodone_stkovf
                CMP     _fcc_stkfloor
                BCS     biodone_stkok
biodone_stkovf       JMP     _fcc_stkoflow
                FIN
biodone_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+biodone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+biodone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+biodone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+biodone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+biodone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+biodone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #2
                BEQ     _vreclaim_L73
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L73
                DO      8+biodone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+biodone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+biodone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+biodone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+biodone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+biodone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #2
                STA     [_fcc_fpr0]
                LDA     [_fcc_fpr0]
                TAX
                AND     #1
                BEQ     *+5
                BRL     _vreclaim_L74
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
                BRL     _vreclaim_L74
                DO      8+biodone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+biodone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+biodone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+biodone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+biodone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+biodone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDY     #50
                LDA     [_fcc_fpr0],Y
                DEC
                LDY     #50
                STA     [_fcc_fpr0],Y
                LDA     [_fcc_fpr0]
                TAX
                AND     #1024
                BEQ     _vreclaim_L75
                LDY     #50
                LDA     [_fcc_fpr0],Y
                TAX
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vreclaim_L76
                EOR     #$8000
_vreclaim_L76
                BMI     _vreclaim_L75
                LDY     #50
                LDA     [_fcc_fpr0],Y
                BPL     _vreclaim_L77
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L77
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #1024
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                CLC
                ADC     #50
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_wakeup
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L75
_vreclaim_L74
                DO      8+biodone_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+biodone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+biodone_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+biodone_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+biodone_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+biodone_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #256
                BEQ     _vreclaim_L78
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                TSC
                CLC
                ADC     #4
                TCS
                TAY
                TSC
                CLC
                ADC     #biodone_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L78
                LDA     [_fcc_fpr0]
                TAX
                AND     #64
                BEQ     _vreclaim_L79
                LDA     [_fcc_fpr0]
                PHA
                LDA     #64
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
_vreclaim_L79
                TAY
                TSC
                CLC
                ADC     #biodone_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
biodone_FRAMESIZE   EQU     4
biodone_STKGUARD    EQU     0
                FGX2_EXPORT bread
bread            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #bread_FRAMESIZE
                DO      bread_STKGUARD
                BCC     bread_stkovf
                CMP     _fcc_stkfloor
                BCS     bread_stkok
bread_stkovf       JMP     _fcc_stkoflow
                FIN
bread_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+bread_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bread_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bread_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      10+bread_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bread_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bread_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      12+bread_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bread_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bread_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+bread_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bread_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bread_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                DO      16+bread_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+bread_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+bread_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+bread_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+bread_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+bread_FRAMESIZE,S   ; fccstk d=0 b=14 fs
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
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #2
                TAX
                ORA     #512
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                BEQ     _vreclaim_L80
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #bread_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L80
                LDA     [_fcc_fpr0]
                TAX
                ORA     #1
                STA     [_fcc_fpr0]
                LDA     #0
                LDY     #36
                STA     [_fcc_fpr0],Y
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
                LDY     #116
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #118
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
                PEA     _vreclaim_L81-1
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
_vreclaim_L81
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL biowait
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #bread_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bread_FRAMESIZE   EQU     4
bread_STKGUARD    EQU     1
                FGX2_EXPORT bwrite
bwrite            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #bwrite_FRAMESIZE
                DO      bwrite_STKGUARD
                BCC     bwrite_stkovf
                CMP     _fcc_stkfloor
                BCS     bwrite_stkok
bwrite_stkovf       JMP     _fcc_stkoflow
                FIN
bwrite_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bwrite_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bwrite_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #256
                STA     3,S   ; fccstk d=0 b=3
                DO      8+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bwrite_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bwrite_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #512
                STA     5,S   ; fccstk d=0 b=5
                DO      8+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bwrite_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bwrite_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #1
                TAX
                ORA     #2
                TAX
                ORA     #4
                TAX
                ORA     #512
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     5,S   ; fccstk d=0 b=5
                BEQ     _vreclaim_L82
                DO      8+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bwrite_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bwrite_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bwrite_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bwrite_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL reassignbuf
                TSC
                CLC
                ADC     #8
                TCS
_vreclaim_L82
                DO      8+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bwrite_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bwrite_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                LDY     #36
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #6+bwrite_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
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
                CLC
                ADC     #50
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                DO      8+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bwrite_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bwrite_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDY     #116
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #118
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bwrite_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bwrite_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vreclaim_L83-1
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
_vreclaim_L83
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                BEQ     _vreclaim_L84
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #bwrite_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L84
                DO      8+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bwrite_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bwrite_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL biowait
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     1,S   ; fccstk d=0 b=1
                DO      8+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bwrite_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bwrite_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                TSC
                CLC
                ADC     #4
                TCS
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #bwrite_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bwrite_FRAMESIZE   EQU     6
bwrite_STKGUARD    EQU     1
                FGX2_EXPORT bdwrite
bdwrite            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #bdwrite_FRAMESIZE
                DO      bdwrite_STKGUARD
                BCC     bdwrite_stkovf
                CMP     _fcc_stkfloor
                BCS     bdwrite_stkok
bdwrite_stkovf       JMP     _fcc_stkoflow
                FIN
bdwrite_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+bdwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bdwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bdwrite_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bdwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bdwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bdwrite_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #512
                BNE     _vreclaim_L85
                LDA     [_fcc_fpr0]
                TAX
                ORA     #512
                STA     [_fcc_fpr0]
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+bdwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bdwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bdwrite_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+bdwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bdwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bdwrite_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL reassignbuf
                TSC
                CLC
                ADC     #8
                TCS
_vreclaim_L85
                DO      8+bdwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bdwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bdwrite_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bdwrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bdwrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bdwrite_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #2
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                TSC
                CLC
                ADC     #4
                TCS
                TAY
                TSC
                CLC
                ADC     #bdwrite_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bdwrite_FRAMESIZE   EQU     0
bdwrite_STKGUARD    EQU     0
                FGX2_EXPORT bawrite
bawrite            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #bawrite_FRAMESIZE
                DO      bawrite_STKGUARD
                BCC     bawrite_stkovf
                CMP     _fcc_stkfloor
                BCS     bawrite_stkok
bawrite_stkovf       JMP     _fcc_stkoflow
                FIN
bawrite_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+bawrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bawrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bawrite_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bawrite_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bawrite_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bawrite_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #256
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bwrite
                TSC
                CLC
                ADC     #4
                TCS
                TAY
                TSC
                CLC
                ADC     #bawrite_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bawrite_FRAMESIZE   EQU     0
bawrite_STKGUARD    EQU     0
                FGX2_EXPORT bgetvp
bgetvp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #bgetvp_FRAMESIZE
                DO      bgetvp_STKGUARD
                BCC     bgetvp_stkovf
                CMP     _fcc_stkfloor
                BCS     bgetvp_stkok
bgetvp_stkovf       JMP     _fcc_stkoflow
                FIN
bgetvp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+bgetvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bgetvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bgetvp_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+bgetvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bgetvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bgetvp_FRAMESIZE,S   ; fccstk d=0 b=10 fs
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
                BEQ     _vreclaim_L86
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L86
                DO      12+bgetvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bgetvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bgetvp_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+bgetvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bgetvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bgetvp_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                DO      8+bgetvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bgetvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bgetvp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+bgetvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bgetvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bgetvp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
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
                LDA     _fcc_fpr1+2
                DO      8+bgetvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bgetvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bgetvp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bgetvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bgetvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bgetvp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #3
                BEQ     _vreclaim_L88
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #4
                BNE     _vreclaim_L87
_vreclaim_L88
                DO      12+bgetvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bgetvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bgetvp_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+bgetvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bgetvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bgetvp_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
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
                LDY     #12
                LDA     [_fcc_fpr1],Y
                LDY     #22
                STA     [_fcc_fpr0],Y
                BRA     _vreclaim_L89
_vreclaim_L87
                DO      12+bgetvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bgetvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bgetvp_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+bgetvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bgetvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bgetvp_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     #65535
                LDY     #22
                STA     [_fcc_fpr0],Y
_vreclaim_L89
                DO      8+bgetvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bgetvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bgetvp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bgetvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bgetvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bgetvp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                INC
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_fpr0
                CLC
                ADC     #42
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      16+bgetvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+bgetvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+bgetvp_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+bgetvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+bgetvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+bgetvp_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_bufinsvn
                TSC
                CLC
                ADC     #8
                TCS
                TAY
                TSC
                CLC
                ADC     #bgetvp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bgetvp_FRAMESIZE   EQU     0
bgetvp_STKGUARD    EQU     0
                FGX2_EXPORT brelvp
brelvp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #brelvp_FRAMESIZE
                DO      brelvp_STKGUARD
                BCC     brelvp_stkovf
                CMP     _fcc_stkfloor
                BCS     brelvp_stkok
brelvp_stkovf       JMP     _fcc_stkoflow
                FIN
brelvp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+brelvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+brelvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+brelvp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+brelvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+brelvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+brelvp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vreclaim_L91
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L91
                LDA     #1
                BRA     _vreclaim_L92
_vreclaim_L91
                LDA     #0
_vreclaim_L92
                CMP     #0
                BEQ     _vreclaim_L90
                TAY
                TSC
                CLC
                ADC     #brelvp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L90
                DO      8+brelvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+brelvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+brelvp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+brelvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+brelvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+brelvp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_bufremvn
                TSC
                CLC
                ADC     #4
                TCS
                DO      8+brelvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+brelvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+brelvp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+brelvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+brelvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+brelvp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                DO      8+brelvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+brelvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+brelvp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+brelvp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+brelvp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+brelvp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                BEQ     _vreclaim_L93
                LDY     #4
                LDA     [_fcc_fpr0],Y
                SEC
                SBC     #1
                LDY     #4
                STA     [_fcc_fpr0],Y
_vreclaim_L93
                TAY
                TSC
                CLC
                ADC     #brelvp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
brelvp_FRAMESIZE   EQU     4
brelvp_STKGUARD    EQU     0
                FGX2_EXPORT reassignbuf
reassignbuf            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #reassignbuf_FRAMESIZE
                DO      reassignbuf_STKGUARD
                BCC     reassignbuf_stkovf
                CMP     _fcc_stkfloor
                BCS     reassignbuf_stkok
reassignbuf_stkovf       JMP     _fcc_stkoflow
                FIN
reassignbuf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+reassignbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+reassignbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+reassignbuf_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+reassignbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+reassignbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+reassignbuf_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vreclaim_L95
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L95
                LDA     #1
                BRA     _vreclaim_L96
_vreclaim_L95
                LDA     #0
_vreclaim_L96
                CMP     #0
                BEQ     _vreclaim_L94
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L94
                DO      8+reassignbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+reassignbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+reassignbuf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+reassignbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+reassignbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+reassignbuf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_bufremvn
                TSC
                CLC
                ADC     #4
                TCS
                DO      8+reassignbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+reassignbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+reassignbuf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+reassignbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+reassignbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+reassignbuf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #512
                BEQ     _vreclaim_L97
                DO      12+reassignbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+reassignbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+reassignbuf_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+reassignbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+reassignbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+reassignbuf_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                CLC
                ADC     #46
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+reassignbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+reassignbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+reassignbuf_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+reassignbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+reassignbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+reassignbuf_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_bufinsvn
                TSC
                CLC
                ADC     #8
                TCS
                BRA     _vreclaim_L98
_vreclaim_L97
                DO      12+reassignbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+reassignbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+reassignbuf_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+reassignbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+reassignbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+reassignbuf_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                CLC
                ADC     #42
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+reassignbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+reassignbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+reassignbuf_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+reassignbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+reassignbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+reassignbuf_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_bufinsvn
                TSC
                CLC
                ADC     #8
                TCS
_vreclaim_L98
                TAY
                TSC
                CLC
                ADC     #reassignbuf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
reassignbuf_FRAMESIZE   EQU     0
reassignbuf_STKGUARD    EQU     0
                FGX2_EXPORT vflushbuf
vflushbuf            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vflushbuf_FRAMESIZE
                DO      vflushbuf_STKGUARD
                BCC     vflushbuf_stkovf
                CMP     _fcc_stkfloor
                BCS     vflushbuf_stkok
vflushbuf_stkovf       JMP     _fcc_stkoflow
                FIN
vflushbuf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
vflushbuf_uL_loop
                DO      8+vflushbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vflushbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vflushbuf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vflushbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vflushbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vflushbuf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #46
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #48
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
_vreclaim_L99
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
                BRL     _vreclaim_L101
                LDY     #42
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #44
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
                LDA     [_fcc_fpr0]
                TAX
                AND     #8
                CMP     #0
                BEQ     _vreclaim_L102
                BRL     _vreclaim_L100
_vreclaim_L102
                LDA     [_fcc_fpr0]
                TAX
                AND     #512
                BNE     _vreclaim_L103
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L103
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_bremfree
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #8
                STA     [_fcc_fpr0]
                DO      10+vflushbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vflushbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vflushbuf_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAX
                AND     #2
                BNE     _vreclaim_L104
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bawrite
                TSC
                CLC
                ADC     #4
                TCS
                BRA     _vreclaim_L105
_vreclaim_L104
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bwrite
                TSC
                CLC
                ADC     #4
                TCS
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     vflushbuf_uL_loop
_vreclaim_L105
_vreclaim_L100
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _vreclaim_L99
_vreclaim_L101
                DO      10+vflushbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vflushbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vflushbuf_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAX
                AND     #2
                CMP     #0
                BNE     _vreclaim_L106
                TAY
                TSC
                CLC
                ADC     #vflushbuf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L106
_vreclaim_L107
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                DO      8+vflushbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vflushbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vflushbuf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vflushbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vflushbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vflushbuf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #50
                LDA     [_fcc_fpr0],Y
                CMP     #0
                BEQ     _vreclaim_L108
                LDA     [_fcc_fpr0]
                TAX
                ORA     #1024
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                CLC
                ADC     #50
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_sleep
                TSC
                CLC
                ADC     #4
                TCS
                BRA     _vreclaim_L107
_vreclaim_L108
                LDY     #46
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #48
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vreclaim_L109
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     vflushbuf_uL_loop
_vreclaim_L109
                TAY
                TSC
                CLC
                ADC     #vflushbuf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vflushbuf_FRAMESIZE   EQU     8
vflushbuf_STKGUARD    EQU     0
                FGX2_EXPORT bflush
bflush            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #bflush_FRAMESIZE
                DO      bflush_STKGUARD
                BCC     bflush_stkovf
                CMP     _fcc_stkfloor
                BCS     bflush_stkok
bflush_stkovf       JMP     _fcc_stkoflow
                FIN
bflush_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
bflush_uL_loop
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #bfreelist
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
_vreclaim_L110
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #bfreelist+150
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_ltu16
                CMP     #0
                BNE     *+5
                BRL     _vreclaim_L112
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #12
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
_vreclaim_L113
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
                BNE     _vreclaim_L116
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L116
                LDA     #0
                BRA     _vreclaim_L117
_vreclaim_L116
                LDA     #1
_vreclaim_L117
                CMP     #0
                BNE     *+5
                BRL     _vreclaim_L115
                LDA     [_fcc_fpr0]
                TAX
                AND     #512
                CMP     #0
                BNE     _vreclaim_L118
                BRA     _vreclaim_L114
_vreclaim_L118
                DO      6+bflush_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bflush_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bflush_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                CMP     #65535
                BEQ     _vreclaim_L119
                LDY     #22
                LDA     [_fcc_fpr0],Y
                PHA
                DO      8+bflush_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bflush_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bflush_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _vreclaim_L119
                BRA     _vreclaim_L114
_vreclaim_L119
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_bremfree
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #8
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bwrite
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     bflush_uL_loop
_vreclaim_L114
                LDY     #10
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #12
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
                BRL     _vreclaim_L113
_vreclaim_L115
_vreclaim_L111
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     5,S   ; fccstk d=0 b=5
                CLC
                ADC     #50
                STA     5,S   ; fccstk d=0 b=5
                BRL     _vreclaim_L110
_vreclaim_L112
                TAY
                TSC
                CLC
                ADC     #bflush_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bflush_FRAMESIZE   EQU     8
bflush_STKGUARD    EQU     0
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
                STA     13,S   ; fccstk d=0 b=13
_vreclaim_L120
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                DO      8+vinvalbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vinvalbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vinvalbuf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vinvalbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vinvalbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vinvalbuf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #46
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #48
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
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vreclaim_L123
                BRA     _vreclaim_L124
_vreclaim_L123
                DO      8+vinvalbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vinvalbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vinvalbuf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vinvalbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vinvalbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vinvalbuf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #42
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #44
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
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vreclaim_L125
                BRA     _vreclaim_L126
_vreclaim_L125
                BRL     _vreclaim_L122
_vreclaim_L126
_vreclaim_L124
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_vreclaim_L127
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
                BRL     _vreclaim_L129
                LDY     #42
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #44
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
                LDA     [_fcc_fpr0]
                TAX
                AND     #8
                BEQ     _vreclaim_L130
                LDA     [_fcc_fpr0]
                TAX
                ORA     #64
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_sleep
                TSC
                CLC
                ADC     #4
                TCS
                BRL     _vreclaim_L129
_vreclaim_L130
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_bremfree
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #8
                STA     [_fcc_fpr0]
                DO      10+vinvalbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+vinvalbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+vinvalbuf_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                CMP     #0
                BEQ     _vreclaim_L131
                LDA     [_fcc_fpr0]
                TAX
                AND     #512
                BEQ     _vreclaim_L131
                LDA     13,S   ; fccstk d=0 b=13
                INC
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bwrite
                TSC
                CLC
                ADC     #4
                TCS
                BRL     _vreclaim_L129
_vreclaim_L131
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
                DO      8+vinvalbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vinvalbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vinvalbuf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+vinvalbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vinvalbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vinvalbuf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vreclaim_L133
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L133
                LDA     #0
                BRA     _vreclaim_L134
_vreclaim_L133
                LDA     #1
_vreclaim_L134
                CMP     #0
                BEQ     _vreclaim_L132
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL reassignbuf
                TSC
                CLC
                ADC     #8
                TCS
                BRA     _vreclaim_L135
_vreclaim_L132
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #2048
                STA     [_fcc_fpr0]
_vreclaim_L135
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L128
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _vreclaim_L127
_vreclaim_L129
_vreclaim_L121
                BRL     _vreclaim_L120
_vreclaim_L122
                DO      8+vinvalbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vinvalbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vinvalbuf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vinvalbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vinvalbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vinvalbuf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #46
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #48
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     _vreclaim_L137
                DO      8+vinvalbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vinvalbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vinvalbuf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vinvalbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vinvalbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vinvalbuf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #42
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #44
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vreclaim_L136
_vreclaim_L137
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S6
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L136
                LDA     13,S   ; fccstk d=0 b=13
                TAY
                TSC
                CLC
                ADC     #vinvalbuf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vinvalbuf_FRAMESIZE   EQU     14
vinvalbuf_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_note
_vreclaim_note            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_note_FRAMESIZE
                DO      _vreclaim_note_STKGUARD
                BCC     _vreclaim_note_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_note_stkok
_vreclaim_note_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_note_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     _vreclaim_n_trace
                TAX
                SEC
                SBC     #16
                BVC     _vreclaim_L139
                EOR     #$8000
_vreclaim_L139
                BPL     _vreclaim_L138
                LDA     #_vreclaim_trace
                PHA
                LDA     _vreclaim_n_trace
                STA     _fcc_tmp_b
                INC
                STA     _vreclaim_n_trace
                LDA     _fcc_tmp_b
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                DO      8+_vreclaim_note_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_note_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_note_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
_vreclaim_L138
                TAY
                TSC
                CLC
                ADC     #_vreclaim_note_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_note_FRAMESIZE   EQU     0
_vreclaim_note_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_fs_nop
_vreclaim_fs_nop            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_fs_nop_FRAMESIZE
                DO      _vreclaim_fs_nop_STKGUARD
                BCC     _vreclaim_fs_nop_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_fs_nop_stkok
_vreclaim_fs_nop_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_fs_nop_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_vreclaim_fs_nop_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_fs_nop_FRAMESIZE   EQU     0
_vreclaim_fs_nop_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_fs_lock
_vreclaim_fs_lock            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_fs_lock_FRAMESIZE
                DO      _vreclaim_fs_lock_STKGUARD
                BCC     _vreclaim_fs_lock_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_fs_lock_stkok
_vreclaim_fs_lock_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_fs_lock_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #1
                PHA
                FGX2_FARCALL _vreclaim_note
                TAY
                PLA
                TYA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_vreclaim_fs_lock_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_fs_lock_FRAMESIZE   EQU     0
_vreclaim_fs_lock_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_fs_unlock
_vreclaim_fs_unlock            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_fs_unlock_FRAMESIZE
                DO      _vreclaim_fs_unlock_STKGUARD
                BCC     _vreclaim_fs_unlock_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_fs_unlock_stkok
_vreclaim_fs_unlock_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_fs_unlock_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #2
                PHA
                FGX2_FARCALL _vreclaim_note
                TAY
                PLA
                TYA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_vreclaim_fs_unlock_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_fs_unlock_FRAMESIZE   EQU     0
_vreclaim_fs_unlock_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_fs_close
_vreclaim_fs_close            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_fs_close_FRAMESIZE
                DO      _vreclaim_fs_close_STKGUARD
                BCC     _vreclaim_fs_close_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_fs_close_stkok
_vreclaim_fs_close_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_fs_close_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #3
                PHA
                FGX2_FARCALL _vreclaim_note
                TAY
                PLA
                TYA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_vreclaim_fs_close_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_fs_close_FRAMESIZE   EQU     0
_vreclaim_fs_close_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_fs_inactive
_vreclaim_fs_inactive            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_fs_inactive_FRAMESIZE
                DO      _vreclaim_fs_inactive_STKGUARD
                BCC     _vreclaim_fs_inactive_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_fs_inactive_stkok
_vreclaim_fs_inactive_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_fs_inactive_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #4
                PHA
                FGX2_FARCALL _vreclaim_note
                TAY
                PLA
                TYA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_vreclaim_fs_inactive_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_fs_inactive_FRAMESIZE   EQU     0
_vreclaim_fs_inactive_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_fs_reclaim
_vreclaim_fs_reclaim            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_fs_reclaim_FRAMESIZE
                DO      _vreclaim_fs_reclaim_STKGUARD
                BCC     _vreclaim_fs_reclaim_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_fs_reclaim_stkok
_vreclaim_fs_reclaim_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_fs_reclaim_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #5
                PHA
                FGX2_FARCALL _vreclaim_note
                TAY
                PLA
                TYA
                LDA     _vreclaim_fs_reclaim_fails
                TAY
                TSC
                CLC
                ADC     #_vreclaim_fs_reclaim_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_fs_reclaim_FRAMESIZE   EQU     0
_vreclaim_fs_reclaim_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_fs_strategy
_vreclaim_fs_strategy            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_fs_strategy_FRAMESIZE
                DO      _vreclaim_fs_strategy_STKGUARD
                BCC     _vreclaim_fs_strategy_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_fs_strategy_stkok
_vreclaim_fs_strategy_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_fs_strategy_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_vreclaim_fs_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_fs_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_fs_strategy_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_fs_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_fs_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_fs_strategy_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bio_strategy
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_vreclaim_fs_strategy_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_fs_strategy_FRAMESIZE   EQU     0
_vreclaim_fs_strategy_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_chkvnlock
_vreclaim_chkvnlock            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_chkvnlock_FRAMESIZE
                DO      _vreclaim_chkvnlock_STKGUARD
                BCC     _vreclaim_chkvnlock_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_chkvnlock_stkok
_vreclaim_chkvnlock_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_chkvnlock_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
_vreclaim_L140
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                DO      8+_vreclaim_chkvnlock_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_chkvnlock_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_chkvnlock_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_chkvnlock_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_chkvnlock_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_chkvnlock_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #256
                BEQ     _vreclaim_L141
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
                STA     1,S   ; fccstk d=0 b=1
                BRA     _vreclaim_L140
_vreclaim_L141
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #_vreclaim_chkvnlock_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_chkvnlock_FRAMESIZE   EQU     2
_vreclaim_chkvnlock_STKGUARD    EQU     0
                FGX2_EXPORT dead_lookup
dead_lookup            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dead_lookup_FRAMESIZE
                DO      dead_lookup_STKGUARD
                BCC     dead_lookup_stkovf
                CMP     _fcc_stkfloor
                BCS     dead_lookup_stkok
dead_lookup_stkovf       JMP     _fcc_stkoflow
                FIN
dead_lookup_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #20
                TAY
                TSC
                CLC
                ADC     #dead_lookup_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dead_lookup_FRAMESIZE   EQU     0
dead_lookup_STKGUARD    EQU     0
                FGX2_EXPORT dead_open
dead_open            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dead_open_FRAMESIZE
                DO      dead_open_STKGUARD
                BCC     dead_open_stkovf
                CMP     _fcc_stkfloor
                BCS     dead_open_stkok
dead_open_stkovf       JMP     _fcc_stkoflow
                FIN
dead_open_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #dead_open_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dead_open_FRAMESIZE   EQU     0
dead_open_STKGUARD    EQU     0
                FGX2_EXPORT dead_read
dead_read            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dead_read_FRAMESIZE
                DO      dead_read_STKGUARD
                BCC     dead_read_stkovf
                CMP     _fcc_stkfloor
                BCS     dead_read_stkok
dead_read_stkovf       JMP     _fcc_stkoflow
                FIN
dead_read_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+dead_read_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+dead_read_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+dead_read_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+dead_read_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dead_read_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dead_read_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_chkvnlock
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BEQ     _vreclaim_L142
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S7
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L142
                DO      8+dead_read_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+dead_read_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+dead_read_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+dead_read_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dead_read_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dead_read_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #4
                BEQ     _vreclaim_L143
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #dead_read_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L143
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #dead_read_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dead_read_FRAMESIZE   EQU     0
dead_read_STKGUARD    EQU     0
                FGX2_EXPORT dead_write
dead_write            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dead_write_FRAMESIZE
                DO      dead_write_STKGUARD
                BCC     dead_write_stkovf
                CMP     _fcc_stkfloor
                BCS     dead_write_stkok
dead_write_stkovf       JMP     _fcc_stkoflow
                FIN
dead_write_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+dead_write_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+dead_write_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+dead_write_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+dead_write_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dead_write_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dead_write_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_chkvnlock
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BEQ     _vreclaim_L144
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L144
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #dead_write_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dead_write_FRAMESIZE   EQU     0
dead_write_STKGUARD    EQU     0
                FGX2_EXPORT dead_ioctl
dead_ioctl            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dead_ioctl_FRAMESIZE
                DO      dead_ioctl_STKGUARD
                BCC     dead_ioctl_stkovf
                CMP     _fcc_stkfloor
                BCS     dead_ioctl_stkok
dead_ioctl_stkovf       JMP     _fcc_stkoflow
                FIN
dead_ioctl_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+dead_ioctl_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+dead_ioctl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+dead_ioctl_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+dead_ioctl_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dead_ioctl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dead_ioctl_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_chkvnlock
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BNE     _vreclaim_L145
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #dead_ioctl_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L145
                DO      8+dead_ioctl_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+dead_ioctl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+dead_ioctl_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+dead_ioctl_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dead_ioctl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dead_ioctl_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDY     #40
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #42
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      24+dead_ioctl_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+dead_ioctl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+dead_ioctl_FRAMESIZE,S   ; fccstk d=4 b=20 fs
                FIN
                STA     _fcc_fpr0+2
                DO      22+dead_ioctl_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+dead_ioctl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+dead_ioctl_FRAMESIZE,S   ; fccstk d=4 b=18 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      24+dead_ioctl_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+dead_ioctl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+dead_ioctl_FRAMESIZE,S   ; fccstk d=8 b=16 fs
                FIN
                PHA
                DO      24+dead_ioctl_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+dead_ioctl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+dead_ioctl_FRAMESIZE,S   ; fccstk d=10 b=14 fs
                FIN
                STA     _fcc_fpr0+2
                DO      22+dead_ioctl_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+dead_ioctl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+dead_ioctl_FRAMESIZE,S   ; fccstk d=10 b=12 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      24+dead_ioctl_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+dead_ioctl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+dead_ioctl_FRAMESIZE,S   ; fccstk d=14 b=10 fs
                FIN
                PHA
                DO      24+dead_ioctl_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+dead_ioctl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+dead_ioctl_FRAMESIZE,S   ; fccstk d=16 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      22+dead_ioctl_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+dead_ioctl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+dead_ioctl_FRAMESIZE,S   ; fccstk d=16 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     17,S
                STA     _fcc_fpr0
                LDA     19,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vreclaim_L146-1
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
_vreclaim_L146
                TAY
                TSC
                CLC
                ADC     #20
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #dead_ioctl_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dead_ioctl_FRAMESIZE   EQU     0
dead_ioctl_STKGUARD    EQU     1
                FGX2_EXPORT dead_select
dead_select            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dead_select_FRAMESIZE
                DO      dead_select_STKGUARD
                BCC     dead_select_stkovf
                CMP     _fcc_stkfloor
                BCS     dead_select_stkok
dead_select_stkovf       JMP     _fcc_stkoflow
                FIN
dead_select_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #dead_select_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dead_select_FRAMESIZE   EQU     0
dead_select_STKGUARD    EQU     0
                FGX2_EXPORT dead_strategy
dead_strategy            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dead_strategy_FRAMESIZE
                DO      dead_strategy_STKGUARD
                BCC     dead_strategy_stkovf
                CMP     _fcc_stkfloor
                BCS     dead_strategy_stkok
dead_strategy_stkovf       JMP     _fcc_stkoflow
                FIN
dead_strategy_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+dead_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+dead_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+dead_strategy_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+dead_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dead_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dead_strategy_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vreclaim_L149
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L149
                LDA     #1
                BRA     _vreclaim_L150
_vreclaim_L149
                LDA     #0
_vreclaim_L150
                CMP     #0
                BNE     _vreclaim_L148
                DO      8+dead_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+dead_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+dead_strategy_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+dead_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dead_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dead_strategy_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_chkvnlock
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BNE     _vreclaim_L147
_vreclaim_L148
                DO      8+dead_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+dead_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+dead_strategy_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+dead_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dead_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dead_strategy_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #4
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL biodone
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #dead_strategy_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L147
                DO      8+dead_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+dead_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+dead_strategy_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+dead_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dead_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dead_strategy_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDY     #116
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #118
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+dead_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+dead_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+dead_strategy_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+dead_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+dead_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+dead_strategy_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vreclaim_L151-1
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
_vreclaim_L151
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #dead_strategy_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dead_strategy_FRAMESIZE   EQU     0
dead_strategy_STKGUARD    EQU     1
                FGX2_EXPORT dead_lock
dead_lock            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dead_lock_FRAMESIZE
                DO      dead_lock_STKGUARD
                BCC     dead_lock_stkovf
                CMP     _fcc_stkfloor
                BCS     dead_lock_stkok
dead_lock_stkovf       JMP     _fcc_stkoflow
                FIN
dead_lock_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+dead_lock_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+dead_lock_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+dead_lock_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+dead_lock_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dead_lock_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dead_lock_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_chkvnlock
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BNE     _vreclaim_L152
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #dead_lock_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L152
                DO      8+dead_lock_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+dead_lock_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+dead_lock_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+dead_lock_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dead_lock_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dead_lock_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      12+dead_lock_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+dead_lock_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+dead_lock_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+dead_lock_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+dead_lock_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+dead_lock_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vreclaim_L153-1
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
_vreclaim_L153
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #dead_lock_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dead_lock_FRAMESIZE   EQU     0
dead_lock_STKGUARD    EQU     1
                FGX2_EXPORT dead_bmap
dead_bmap            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dead_bmap_FRAMESIZE
                DO      dead_bmap_STKGUARD
                BCC     dead_bmap_stkovf
                CMP     _fcc_stkfloor
                BCS     dead_bmap_stkok
dead_bmap_stkovf       JMP     _fcc_stkoflow
                FIN
dead_bmap_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+dead_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+dead_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+dead_bmap_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+dead_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dead_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dead_bmap_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_chkvnlock
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BNE     _vreclaim_L154
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #dead_bmap_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L154
                DO      8+dead_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+dead_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+dead_bmap_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+dead_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dead_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dead_bmap_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDY     #112
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #114
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      24+dead_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+dead_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+dead_bmap_FRAMESIZE,S   ; fccstk d=4 b=20 fs
                FIN
                STA     _fcc_fpr0+2
                DO      22+dead_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+dead_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+dead_bmap_FRAMESIZE,S   ; fccstk d=4 b=18 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      24+dead_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+dead_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+dead_bmap_FRAMESIZE,S   ; fccstk d=8 b=16 fs
                FIN
                STA     _fcc_fpr0+2
                DO      22+dead_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+dead_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+dead_bmap_FRAMESIZE,S   ; fccstk d=8 b=14 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      24+dead_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+dead_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+dead_bmap_FRAMESIZE,S   ; fccstk d=12 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      22+dead_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+dead_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+dead_bmap_FRAMESIZE,S   ; fccstk d=12 b=10 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      24+dead_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+dead_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+dead_bmap_FRAMESIZE,S   ; fccstk d=16 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      22+dead_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+dead_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+dead_bmap_FRAMESIZE,S   ; fccstk d=16 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     17,S
                STA     _fcc_fpr0
                LDA     19,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vreclaim_L155-1
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
_vreclaim_L155
                TAY
                TSC
                CLC
                ADC     #20
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #dead_bmap_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dead_bmap_FRAMESIZE   EQU     0
dead_bmap_STKGUARD    EQU     1
                FGX2_EXPORT dead_print
dead_print            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dead_print_FRAMESIZE
                DO      dead_print_STKGUARD
                BCC     dead_print_stkovf
                CMP     _fcc_stkfloor
                BCS     dead_print_stkok
dead_print_stkovf       JMP     _fcc_stkoflow
                FIN
dead_print_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #dead_print_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dead_print_FRAMESIZE   EQU     0
dead_print_STKGUARD    EQU     0
                FGX2_EXPORT dead_ebadf
dead_ebadf            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dead_ebadf_FRAMESIZE
                DO      dead_ebadf_STKGUARD
                BCC     dead_ebadf_stkovf
                CMP     _fcc_stkfloor
                BCS     dead_ebadf_stkok
dead_ebadf_stkovf       JMP     _fcc_stkoflow
                FIN
dead_ebadf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #dead_ebadf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dead_ebadf_FRAMESIZE   EQU     0
dead_ebadf_STKGUARD    EQU     0
                FGX2_EXPORT dead_badop
dead_badop            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dead_badop_FRAMESIZE
                DO      dead_badop_STKGUARD
                BCC     dead_badop_stkovf
                CMP     _fcc_stkfloor
                BCS     dead_badop_stkok
dead_badop_stkovf       JMP     _fcc_stkoflow
                FIN
dead_badop_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #dead_badop_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dead_badop_FRAMESIZE   EQU     0
dead_badop_STKGUARD    EQU     0
                FGX2_EXPORT dead_nullop
dead_nullop            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dead_nullop_FRAMESIZE
                DO      dead_nullop_STKGUARD
                BCC     dead_nullop_stkovf
                CMP     _fcc_stkfloor
                BCS     dead_nullop_stkok
dead_nullop_stkovf       JMP     _fcc_stkoflow
                FIN
dead_nullop_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #dead_nullop_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dead_nullop_FRAMESIZE   EQU     0
dead_nullop_STKGUARD    EQU     0
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
                BNE     _vreclaim_L156
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
_vreclaim_L156
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
                BNE     _vreclaim_L157
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
_vreclaim_L157
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
                BNE     _vreclaim_L158
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
_vreclaim_L158
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
                BNE     _vreclaim_L159
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
_vreclaim_L159
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
                BNE     _vreclaim_L160
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
_vreclaim_L160
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
                BNE     _vreclaim_L161
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
_vreclaim_L161
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
                BNE     _vreclaim_L162
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
_vreclaim_L162
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
                BNE     _vreclaim_L163
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
_vreclaim_L163
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
                STA     _vreclaim_vfs_cacheops
                LDA     _fcc_fpr0+2
                STA     _vreclaim_vfs_cacheops+2
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
                STA     _vreclaim_vfs_specops
                LDA     _fcc_fpr0+2
                STA     _vreclaim_vfs_specops+2
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
                FGX2_EXPORT _vreclaim_zerobytes
_vreclaim_zerobytes            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_zerobytes_FRAMESIZE
                DO      _vreclaim_zerobytes_STKGUARD
                BCC     _vreclaim_zerobytes_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_zerobytes_stkok
_vreclaim_zerobytes_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_zerobytes_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+_vreclaim_zerobytes_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_zerobytes_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_zerobytes_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img0
                DO      6+_vreclaim_zerobytes_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_zerobytes_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_zerobytes_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+_vreclaim_zerobytes_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_zerobytes_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_zerobytes_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
_vreclaim_L164
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
                BCS     _vreclaim_L165
                LDA     #0
                SEP     #$20
                MX      %10
                STA     [_fcc_img1]
                REP     #$20
                MX      %00
                INC     _fcc_img1
                BRA     _vreclaim_L164
_vreclaim_L165
                TAY
                TSC
                CLC
                ADC     #_vreclaim_zerobytes_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_zerobytes_FRAMESIZE   EQU     0
_vreclaim_zerobytes_STKGUARD    EQU     0
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
_vreclaim_L166
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #8
                BVC     _vreclaim_L169
                EOR     #$8000
_vreclaim_L169
                BPL     _vreclaim_L168
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
_vreclaim_L167
                INC     _fcc_img0
                BRA     _vreclaim_L166
_vreclaim_L168
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
                FGX2_FARCALL _vreclaim_zerobytes
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
                FGX2_FARCALL _vreclaim_zerobytes
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
_vreclaim_L170
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                SEC
                SBC     #64
                BVC     _vreclaim_L173
                EOR     #$8000
_vreclaim_L173
                BPL     _vreclaim_L172
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
_vreclaim_L171
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRA     _vreclaim_L170
_vreclaim_L172
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
                BEQ     _vreclaim_L174
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
                BRA     _vreclaim_L175
_vreclaim_L174
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
_vreclaim_L175
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
                BNE     _vreclaim_L177
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L177
                LDA     #1
                BRA     _vreclaim_L178
_vreclaim_L177
                LDA     #0
_vreclaim_L178
                CMP     #0
                BEQ     _vreclaim_L176
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
_vreclaim_L176
                LDY     #2
                LDA     [_fcc_fpr0],Y
                BEQ     _vreclaim_L179
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S10
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L179
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
                BEQ     _vreclaim_L180
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L180
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
                LDA     _vreclaim_vfs_cacheops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _vreclaim_vfs_cacheops
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vreclaim_L181
                SEP     #$20
                MX      %10
                LDA     _vreclaim_vfs_cacheops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _vreclaim_vfs_cacheops
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
                PEA     _vreclaim_L182-1
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
_vreclaim_L182
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
_vreclaim_L181
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
                BVC     _vreclaim_L184
                EOR     #$8000
_vreclaim_L184
                BMI     _vreclaim_L183
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S11
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L183
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
                BEQ     _vreclaim_L185
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
_vreclaim_L185
                LDY     #2
                LDA     [_fcc_fpr0],Y
                BNE     _vreclaim_L186
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vremfree
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L186
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
                BVC     _vreclaim_L188
                EOR     #$8000
_vreclaim_L188
                BMI     _vreclaim_L187
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S12
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L187
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
                BVC     _vreclaim_L190
                EOR     #$8000
_vreclaim_L190
                BPL     _vreclaim_L189
                TAY
                TSC
                CLC
                ADC     #vrele_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L189
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
                PEA     _vreclaim_L191-1
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
_vreclaim_L191
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
                BVC     _vreclaim_L193
                EOR     #$8000
_vreclaim_L193
                BMI     _vreclaim_L192
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S13
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L192
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
                BRL     _vreclaim_L194
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
                BEQ     _vreclaim_L195
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
_vreclaim_L195
_vreclaim_L194
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
                BNE     _vreclaim_L197
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L197
                LDA     #1
                BRA     _vreclaim_L198
_vreclaim_L197
                LDA     #0
_vreclaim_L198
                CMP     #0
                BEQ     _vreclaim_L196
                TAY
                TSC
                CLC
                ADC     #insmntque_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L196
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
                BEQ     _vreclaim_L199
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
_vreclaim_L199
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
                FGX2_EXPORT _vreclaim_specalloc
_vreclaim_specalloc            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_specalloc_FRAMESIZE
                DO      _vreclaim_specalloc_STKGUARD
                BCC     _vreclaim_specalloc_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_specalloc_stkok
_vreclaim_specalloc_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_specalloc_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_img0
_vreclaim_L200
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #64
                BVC     _vreclaim_L203
                EOR     #$8000
_vreclaim_L203
                BMI     *+5
                BRL     _vreclaim_L202
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
                BNE     _vreclaim_L205
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L205
                LDA     #1
                BRA     _vreclaim_L206
_vreclaim_L205
                LDA     #0
_vreclaim_L206
                CMP     #0
                BNE     *+5
                BRL     _vreclaim_L204
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
                DO      8+_vreclaim_specalloc_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_specalloc_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_specalloc_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_specalloc_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_specalloc_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_specalloc_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                ADC     #_vreclaim_specalloc_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L204
_vreclaim_L201
                INC     _fcc_img0
                BRL     _vreclaim_L200
_vreclaim_L202
                LDA     _fcc_img0
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S14
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
                ADC     #_vreclaim_specalloc_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_specalloc_FRAMESIZE   EQU     2
_vreclaim_specalloc_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_specfree
_vreclaim_specfree            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_specfree_FRAMESIZE
                DO      _vreclaim_specfree_STKGUARD
                BCC     _vreclaim_specfree_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_specfree_stkok
_vreclaim_specfree_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_specfree_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_vreclaim_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_specfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_specfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_specfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_specfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_specfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_specfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_specfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_specfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_specfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_specfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #65535
                LDY     #12
                STA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #_vreclaim_specfree_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_specfree_FRAMESIZE   EQU     0
_vreclaim_specfree_STKGUARD    EQU     0
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
                BEQ     _vreclaim_L207
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #4
                BEQ     _vreclaim_L207
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
_vreclaim_L207
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
_vreclaim_L208
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
                BRL     _vreclaim_L210
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
                BNE     _vreclaim_L212
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
                BEQ     _vreclaim_L211
_vreclaim_L212
                BRA     _vreclaim_L209
_vreclaim_L211
                LDY     #2
                LDA     [_fcc_fpr0],Y
                BNE     _vreclaim_L213
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
_vreclaim_L213
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
                BEQ     _vreclaim_L214
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     checkalias_uL_loop
_vreclaim_L214
                BRA     _vreclaim_L210
_vreclaim_L209
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
                BRL     _vreclaim_L208
_vreclaim_L210
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vreclaim_L217
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L217
                LDA     #1
                BRA     _vreclaim_L218
_vreclaim_L217
                LDA     #0
_vreclaim_L218
                CMP     #0
                BNE     _vreclaim_L216
                LDY     #58
                LDA     [_fcc_fpr0],Y
                BNE     *+5
                BRL     _vreclaim_L215
_vreclaim_L216
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
                FGX2_FARCALL _vreclaim_specalloc
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
                BNE     _vreclaim_L220
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L220
                LDA     #0
                BRA     _vreclaim_L221
_vreclaim_L220
                LDA     #1
_vreclaim_L221
                CMP     #0
                BEQ     _vreclaim_L219
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
_vreclaim_L219
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
_vreclaim_L215
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
                LDA     _vreclaim_vfs_specops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _vreclaim_vfs_specops
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vreclaim_L223
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L223
                LDA     #1
                BRA     _vreclaim_L224
_vreclaim_L223
                LDA     #0
_vreclaim_L224
                CMP     #0
                BEQ     _vreclaim_L222
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
_vreclaim_L222
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
                LDA     _vreclaim_vfs_specops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _vreclaim_vfs_specops
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
                BEQ     _vreclaim_L225
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
_vreclaim_L225
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
                BEQ     _vreclaim_L226
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
_vreclaim_L226
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
_vreclaim_L227
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
                BRL     _vreclaim_L229
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
                BNE     _vreclaim_L231
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
                BEQ     _vreclaim_L230
_vreclaim_L231
                BRA     _vreclaim_L228
_vreclaim_L230
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
_vreclaim_L228
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
                BRL     _vreclaim_L227
_vreclaim_L229
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
                BVC     _vreclaim_L233
                EOR     #$8000
_vreclaim_L233
                BPL     _vreclaim_L232
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
_vreclaim_L232
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
                BNE     _vreclaim_L234
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
_vreclaim_L234
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
_vreclaim_L235
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
                BRL     _vreclaim_L237
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
                BNE     _vreclaim_L239
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #3
                BEQ     _vreclaim_L238
_vreclaim_L239
                BRA     _vreclaim_L236
_vreclaim_L238
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
                BEQ     _vreclaim_L240
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
_vreclaim_L240
_vreclaim_L236
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
                BRL     _vreclaim_L235
_vreclaim_L237
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
                BVC     _vreclaim_L242
                EOR     #$8000
_vreclaim_L242
                BPL     _vreclaim_L241
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
_vreclaim_L241
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
                BNE     _vreclaim_L243
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
_vreclaim_L243
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
_vreclaim_L244
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
                BRL     _vreclaim_L246
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
                BNE     _vreclaim_L248
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
                BEQ     _vreclaim_L247
_vreclaim_L248
                BRA     _vreclaim_L245
_vreclaim_L247
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                BNE     _vreclaim_L249
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
_vreclaim_L249
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
_vreclaim_L245
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
                BRL     _vreclaim_L244
_vreclaim_L246
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
                PEA     _vreclaim_L250-1
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
_vreclaim_L250
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
                BEQ     _vreclaim_L251
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vref
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L251
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
                BEQ     _vreclaim_L252
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S15
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L252
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
                PEA     _vreclaim_L253-1
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
_vreclaim_L253
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
                BEQ     _vreclaim_L254
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
_vreclaim_L254
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
                PEA     _vreclaim_L255-1
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
_vreclaim_L255
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     5,S   ; fccstk d=0 b=5
                BNE     *+5
                BRL     _vreclaim_L256
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
                BEQ     _vreclaim_L257
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
                PEA     _vreclaim_L258-1
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
_vreclaim_L258
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
_vreclaim_L257
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
                PEA     _vreclaim_L259-1
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
_vreclaim_L259
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
_vreclaim_L256
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
                PEA     _vreclaim_L261-1
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
_vreclaim_L261
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BEQ     _vreclaim_L260
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L260
                LDA     5,S   ; fccstk d=0 b=5
                BEQ     _vreclaim_L262
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
_vreclaim_L262
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
                BEQ     _vreclaim_L263
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
_vreclaim_L263
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
                BEQ     _vreclaim_L264
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
_vreclaim_L264
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
                BEQ     _vreclaim_L266
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #4
                BEQ     *+5
                BRL     _vreclaim_L265
_vreclaim_L266
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
                BNE     _vreclaim_L268
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L268
                LDA     #1
                BRA     _vreclaim_L269
_vreclaim_L268
                LDA     #0
_vreclaim_L269
                CMP     #0
                BEQ     _vreclaim_L267
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S17
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L267
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
                BNE     _vreclaim_L271
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L271
                LDA     #1
                BRA     _vreclaim_L272
_vreclaim_L271
                LDA     #0
_vreclaim_L272
                CMP     #0
                BEQ     _vreclaim_L270
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
                BRL     _vreclaim_L273
_vreclaim_L270
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
_vreclaim_L274
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
                BRL     _vreclaim_L276
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
                BNE     _vreclaim_L278
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L278
                LDA     #0
                BRA     _vreclaim_L279
_vreclaim_L278
                LDA     #1
_vreclaim_L279
                CMP     #0
                BEQ     _vreclaim_L277
                BRA     _vreclaim_L275
_vreclaim_L277
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
                BRA     _vreclaim_L276
_vreclaim_L275
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
                BRL     _vreclaim_L274
_vreclaim_L276
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vreclaim_L281
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L281
                LDA     #1
                BRA     _vreclaim_L282
_vreclaim_L281
                LDA     #0
_vreclaim_L282
                CMP     #0
                BEQ     _vreclaim_L280
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S18
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L280
_vreclaim_L273
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
                BRL     _vreclaim_L283
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
_vreclaim_L284
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
                BRL     _vreclaim_L286
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
                BNE     _vreclaim_L288
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
                BEQ     _vreclaim_L287
_vreclaim_L288
                BRA     _vreclaim_L285
_vreclaim_L287
                INC     _fcc_img0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
_vreclaim_L285
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
                BRL     _vreclaim_L284
_vreclaim_L286
                LDA     _fcc_img0
                STA     9,S   ; fccstk d=0 b=9
                BNE     _vreclaim_L289
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S19
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L289
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CMP     #1
                BNE     _vreclaim_L290
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
_vreclaim_L290
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
_vreclaim_L283
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
                FGX2_FARCALL _vreclaim_specfree
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
_vreclaim_L265
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
                BRL     _vreclaim_L291
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
                BEQ     _vreclaim_L292
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
                BRA     _vreclaim_L293
_vreclaim_L292
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
_vreclaim_L293
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
_vreclaim_L291
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
                BEQ     _vreclaim_L294
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vreclaim_S20
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L294
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
_vreclaim_L295
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
                BRL     _vreclaim_L297
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
                BNE     _vreclaim_L299
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L299
                LDA     #0
                BRA     _vreclaim_L300
_vreclaim_L299
                LDA     #1
_vreclaim_L300
                CMP     #0
                BEQ     _vreclaim_L298
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     vflush_uL_loop
_vreclaim_L298
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
                BNE     _vreclaim_L302
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L302
                LDA     #1
                BRA     _vreclaim_L303
_vreclaim_L302
                LDA     #0
_vreclaim_L303
                CMP     #0
                BEQ     _vreclaim_L301
                BRL     _vreclaim_L296
_vreclaim_L301
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
                BEQ     _vreclaim_L304
                LDA     [_fcc_fpr0]
                TAX
                AND     #4
                CMP     #0
                BEQ     _vreclaim_L304
                BRL     _vreclaim_L296
_vreclaim_L304
                LDY     #2
                LDA     [_fcc_fpr0],Y
                BNE     _vreclaim_L305
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
                BRL     _vreclaim_L296
_vreclaim_L305
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
                BNE     *+5
                BRL     _vreclaim_L306
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #3
                BEQ     _vreclaim_L307
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #4
                BEQ     _vreclaim_L307
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vgone
                TSC
                CLC
                ADC     #4
                TCS
                BRL     _vreclaim_L308
_vreclaim_L307
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
                LDA     _vreclaim_vfs_specops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _vreclaim_vfs_specops
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vreclaim_L310
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L310
                LDA     #1
                BRA     _vreclaim_L311
_vreclaim_L310
                LDA     #0
_vreclaim_L311
                CMP     #0
                BEQ     _vreclaim_L309
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
                BRA     _vreclaim_L296
_vreclaim_L309
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _vreclaim_vfs_specops+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _vreclaim_vfs_specops
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
_vreclaim_L308
                BRA     _vreclaim_L296
_vreclaim_L306
                LDA     9,S   ; fccstk d=0 b=9
                CLC
                ADC     #1
                STA     9,S   ; fccstk d=0 b=9
_vreclaim_L296
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _vreclaim_L295
_vreclaim_L297
                LDA     9,S   ; fccstk d=0 b=9
                BEQ     _vreclaim_L312
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
_vreclaim_L312
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
                BMI     _vreclaim_L314
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
                BVC     _vreclaim_L315
                EOR     #$8000
_vreclaim_L315
                BMI     _vreclaim_L313
_vreclaim_L314
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
_vreclaim_L313
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
                BVC     _vreclaim_L318
                EOR     #$8000
_vreclaim_L318
                BMI     _vreclaim_L317
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
                BVC     _vreclaim_L319
                EOR     #$8000
_vreclaim_L319
                BPL     _vreclaim_L316
_vreclaim_L317
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
_vreclaim_L316
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
                BNE     _vreclaim_L321
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L321
                LDA     #1
                BRA     _vreclaim_L322
_vreclaim_L321
                LDA     #0
_vreclaim_L322
                CMP     #0
                BEQ     _vreclaim_L320
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
_vreclaim_L320
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
_vreclaim_L323
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                SEC
                SBC     #158
                BVC     _vreclaim_L326
                EOR     #$8000
_vreclaim_L326
                BPL     _vreclaim_L325
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
_vreclaim_L324
                INC     _fcc_img0
                BRA     _vreclaim_L323
_vreclaim_L325
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
                BNE     _vreclaim_L329
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L329
                LDA     #1
                BRA     _vreclaim_L330
_vreclaim_L329
                LDA     #0
_vreclaim_L330
                CMP     #0
                BNE     _vreclaim_L328
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
                BNE     _vreclaim_L331
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L331
                LDA     #1
                BRA     _vreclaim_L332
_vreclaim_L331
                LDA     #0
_vreclaim_L332
                CMP     #0
                BEQ     _vreclaim_L327
_vreclaim_L328
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
_vreclaim_L327
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
                LDA     _vreclaim_vfs_cacheops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _vreclaim_vfs_cacheops
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vreclaim_L333
                SEP     #$20
                MX      %10
                LDA     _vreclaim_vfs_cacheops+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _vreclaim_vfs_cacheops
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
                PEA     _vreclaim_L334-1
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
_vreclaim_L334
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
_vreclaim_L333
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
                PEA     _vreclaim_L335-1
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
_vreclaim_L335
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                STA     5,S   ; fccstk d=0 b=5
                CMP     #0
                BEQ     _vreclaim_L336
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
_vreclaim_L336
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
                BNE     _vreclaim_L338
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L338
                LDA     #0
                BRA     _vreclaim_L339
_vreclaim_L338
                LDA     #1
_vreclaim_L339
                CMP     #0
                BNE     *+5
                BRL     _vreclaim_L337
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
                BNE     _vreclaim_L340
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L340
                LDA     #0
                BRA     _vreclaim_L341
_vreclaim_L340
                LDA     #1
_vreclaim_L341
                CMP     #0
                BNE     *+5
                BRL     _vreclaim_L337
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
_vreclaim_L337
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vreclaim_L343
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L343
                LDA     #0
                BRA     _vreclaim_L344
_vreclaim_L343
                LDA     #1
_vreclaim_L344
                CMP     #0
                BEQ     _vreclaim_L342
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
_vreclaim_L342
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
                FGX2_EXPORT _vreclaim_nchbucket
_vreclaim_nchbucket            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_nchbucket_FRAMESIZE
                DO      _vreclaim_nchbucket_STKGUARD
                BCC     _vreclaim_nchbucket_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_nchbucket_stkok
_vreclaim_nchbucket_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_nchbucket_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_vreclaim_nchbucket_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nchbucket_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nchbucket_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_vreclaim_nchbucket_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nchbucket_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nchbucket_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                ADC     #_vreclaim_nchbucket_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_nchbucket_FRAMESIZE   EQU     0
_vreclaim_nchbucket_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_ncinshash
_vreclaim_ncinshash            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_ncinshash_FRAMESIZE
                DO      _vreclaim_ncinshash_STKGUARD
                BCC     _vreclaim_ncinshash_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_ncinshash_stkok
_vreclaim_ncinshash_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_ncinshash_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_vreclaim_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+_vreclaim_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+_vreclaim_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
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
                DO      8+_vreclaim_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+_vreclaim_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+_vreclaim_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
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
                DO      12+_vreclaim_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_vreclaim_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
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
                DO      8+_vreclaim_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      12+_vreclaim_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_vreclaim_ncinshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_ncinshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_ncinshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
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
                ADC     #_vreclaim_ncinshash_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_ncinshash_FRAMESIZE   EQU     0
_vreclaim_ncinshash_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_ncremhash
_vreclaim_ncremhash            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_ncremhash_FRAMESIZE
                DO      _vreclaim_ncremhash_STKGUARD
                BCC     _vreclaim_ncremhash_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_ncremhash_stkok
_vreclaim_ncremhash_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_ncremhash_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_vreclaim_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_ncremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_ncremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_ncremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                ADC     #_vreclaim_ncremhash_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_ncremhash_FRAMESIZE   EQU     0
_vreclaim_ncremhash_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_nclru_totail
_vreclaim_nclru_totail            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_nclru_totail_FRAMESIZE
                DO      _vreclaim_nclru_totail_STKGUARD
                BCC     _vreclaim_nclru_totail_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_nclru_totail_stkok
_vreclaim_nclru_totail_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_nclru_totail_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                BNE     _vreclaim_L346
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L346
                LDA     #1
                BRA     _vreclaim_L347
_vreclaim_L346
                LDA     #0
_vreclaim_L347
                CMP     #0
                BEQ     _vreclaim_L345
                TAY
                TSC
                CLC
                ADC     #_vreclaim_nclru_totail_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L345
                DO      8+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_nclru_totail_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_totail_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_totail_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                ADC     #_vreclaim_nclru_totail_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_nclru_totail_FRAMESIZE   EQU     0
_vreclaim_nclru_totail_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_nclru_remove
_vreclaim_nclru_remove            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_nclru_remove_FRAMESIZE
                DO      _vreclaim_nclru_remove_STKGUARD
                BCC     _vreclaim_nclru_remove_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_nclru_remove_stkok
_vreclaim_nclru_remove_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_nclru_remove_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_vreclaim_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                BEQ     _vreclaim_L348
                DO      8+_vreclaim_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                BRA     _vreclaim_L349
_vreclaim_L348
                DO      8+_vreclaim_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_nclru_remove_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_remove_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_remove_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
_vreclaim_L349
                TAY
                TSC
                CLC
                ADC     #_vreclaim_nclru_remove_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_nclru_remove_FRAMESIZE   EQU     0
_vreclaim_nclru_remove_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_nclru_tohead
_vreclaim_nclru_tohead            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_nclru_tohead_FRAMESIZE
                DO      _vreclaim_nclru_tohead_STKGUARD
                BCC     _vreclaim_nclru_tohead_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_nclru_tohead_stkok
_vreclaim_nclru_tohead_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_nclru_tohead_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_vreclaim_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                BEQ     _vreclaim_L350
                SEP     #$20
                MX      %10
                LDA     nchhead+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     nchhead
                STA     _fcc_fpr0
                DO      8+_vreclaim_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                BRA     _vreclaim_L351
_vreclaim_L350
                DO      8+_vreclaim_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #8
                STA     _fcc_fpr0
                STA     nchtail
                LDA     _fcc_fpr0+2
                STA     nchtail+2
_vreclaim_L351
                DO      8+_vreclaim_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_nclru_tohead_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_nclru_tohead_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_nclru_tohead_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                STA     nchhead
                LDA     _fcc_fpr0+2
                STA     nchhead+2
                TAY
                TSC
                CLC
                ADC     #_vreclaim_nclru_tohead_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_nclru_tohead_FRAMESIZE   EQU     0
_vreclaim_nclru_tohead_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_ncdetach
_vreclaim_ncdetach            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_ncdetach_FRAMESIZE
                DO      _vreclaim_ncdetach_STKGUARD
                BCC     _vreclaim_ncdetach_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_ncdetach_stkok
_vreclaim_ncdetach_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_ncdetach_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_vreclaim_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_ncremhash
                TSC
                CLC
                ADC     #4
                TCS
                DO      8+_vreclaim_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      8+_vreclaim_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+_vreclaim_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      8+_vreclaim_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_vreclaim_ncdetach_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_ncdetach_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_ncdetach_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                ADC     #_vreclaim_ncdetach_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_ncdetach_FRAMESIZE   EQU     0
_vreclaim_ncdetach_STKGUARD    EQU     0
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
_vreclaim_L352
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #16
                BVC     _vreclaim_L355
                EOR     #$8000
_vreclaim_L355
                BPL     _vreclaim_L354
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
_vreclaim_L353
                INC     _fcc_img0
                BRA     _vreclaim_L352
_vreclaim_L354
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
                BNE     _vreclaim_L357
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L357
                LDA     #1
                BRA     _vreclaim_L358
_vreclaim_L357
                LDA     #0
_vreclaim_L358
                CMP     #0
                BEQ     _vreclaim_L356
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
_vreclaim_L356
                LDA     #64
                TAX
                SEC
                SBC     #1
                STA     1,S   ; fccstk d=0 b=1
_vreclaim_L359
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                BPL     *+5
                BRL     _vreclaim_L361
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
                FGX2_FARCALL _vreclaim_nclru_tohead
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L360
                LDA     1,S   ; fccstk d=0 b=1
                SEC
                SBC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRL     _vreclaim_L359
_vreclaim_L361
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
_vreclaim_L362
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
                BVC     _vreclaim_L365
                EOR     #$8000
_vreclaim_L365
                BMI     *+5
                BRL     _vreclaim_L364
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
_vreclaim_L363
                INC     _fcc_img0
                BRL     _vreclaim_L362
_vreclaim_L364
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
                FGX2_EXPORT _vreclaim_namecmp
_vreclaim_namecmp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_namecmp_FRAMESIZE
                DO      _vreclaim_namecmp_STKGUARD
                BCC     _vreclaim_namecmp_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_namecmp_stkok
_vreclaim_namecmp_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_namecmp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      14+_vreclaim_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_vreclaim_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_vreclaim_namecmp_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_img0
                DO      6+_vreclaim_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_namecmp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+_vreclaim_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_namecmp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
                DO      10+_vreclaim_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_vreclaim_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_vreclaim_namecmp_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img3
                DO      12+_vreclaim_namecmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_vreclaim_namecmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_vreclaim_namecmp_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img4
_vreclaim_L366
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                DEC
                STA     _fcc_img0
                LDA     _fcc_tmp_b
                BEQ     _vreclaim_L367
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
                BEQ     _vreclaim_L368
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #_vreclaim_namecmp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L368
                BRA     _vreclaim_L366
_vreclaim_L367
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_vreclaim_namecmp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_namecmp_FRAMESIZE   EQU     0
_vreclaim_namecmp_STKGUARD    EQU     0
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
                BEQ     _vreclaim_L369
                TAY
                TSC
                CLC
                ADC     #cache_purge_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L369
                LDA     #0
                STA     _fcc_img0
_vreclaim_L370
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #16
                BVC     _vreclaim_L373
                EOR     #$8000
_vreclaim_L373
                BMI     *+5
                BRL     _vreclaim_L372
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
_vreclaim_L374
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
                BNE     _vreclaim_L377
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L377
                LDA     #0
                BRA     _vreclaim_L378
_vreclaim_L377
                LDA     #1
_vreclaim_L378
                CMP     #0
                BEQ     _vreclaim_L376
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
_vreclaim_L375
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
                BRL     _vreclaim_L374
_vreclaim_L376
_vreclaim_L371
                INC     _fcc_img0
                BRL     _vreclaim_L370
_vreclaim_L372
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
_vreclaim_L379
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                SEC
                SBC     #16
                BVC     _vreclaim_L382
                EOR     #$8000
_vreclaim_L382
                BMI     *+5
                BRL     _vreclaim_L381
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
_vreclaim_L383
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
                BNE     _vreclaim_L386
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L386
                LDA     #0
                BRA     _vreclaim_L387
_vreclaim_L386
                LDA     #1
_vreclaim_L387
                CMP     #0
                BNE     *+5
                BRL     _vreclaim_L385
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
                BNE     _vreclaim_L390
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L390
                LDA     #1
                BRA     _vreclaim_L391
_vreclaim_L390
                LDA     #0
_vreclaim_L391
                CMP     #0
                BNE     _vreclaim_L389
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
                BNE     _vreclaim_L392
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L392
                LDA     #0
                BRA     _vreclaim_L393
_vreclaim_L392
                LDA     #1
_vreclaim_L393
                CMP     #0
                BEQ     _vreclaim_L388
_vreclaim_L389
                BRL     _vreclaim_L384
_vreclaim_L388
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
                FGX2_FARCALL _vreclaim_ncdetach
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
                FGX2_FARCALL _vreclaim_nclru_remove
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
                FGX2_FARCALL _vreclaim_nclru_tohead
                TSC
                CLC
                ADC     #4
                TCS
_vreclaim_L384
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRL     _vreclaim_L383
_vreclaim_L385
_vreclaim_L380
                LDA     13,S   ; fccstk d=0 b=13
                CLC
                ADC     #1
                STA     13,S   ; fccstk d=0 b=13
                BRL     _vreclaim_L379
_vreclaim_L381
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
                BNE     _vreclaim_L394
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
_vreclaim_L394
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
                BVC     _vreclaim_L396
                EOR     #$8000
_vreclaim_L396
                BPL     _vreclaim_L395
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
_vreclaim_L395
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
                FGX2_FARCALL _vreclaim_nchbucket
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
_vreclaim_L397
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
                BNE     _vreclaim_L400
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L400
                LDA     #0
                BRA     _vreclaim_L401
_vreclaim_L400
                LDA     #1
_vreclaim_L401
                CMP     #0
                BNE     *+5
                BRL     _vreclaim_L399
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
                BNE     _vreclaim_L403
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L403
                LDA     #1
                BRA     _vreclaim_L404
_vreclaim_L403
                LDA     #0
_vreclaim_L404
                CMP     #0
                BNE     *+5
                BRL     _vreclaim_L402
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
                BRL     _vreclaim_L402
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
                BNE     _vreclaim_L402
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
                FGX2_FARCALL _vreclaim_namecmp
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                CMP     #0
                BNE     _vreclaim_L402
                BRA     _vreclaim_L399
_vreclaim_L402
_vreclaim_L398
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
                BRL     _vreclaim_L397
_vreclaim_L399
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
                BNE     _vreclaim_L406
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L406
                LDA     #1
                BRA     _vreclaim_L407
_vreclaim_L406
                LDA     #0
_vreclaim_L407
                CMP     #0
                BEQ     _vreclaim_L405
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
_vreclaim_L405
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
                BNE     _vreclaim_L408
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
                BRL     _vreclaim_L409
_vreclaim_L408
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
                BNE     _vreclaim_L411
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L411
                LDA     #1
                BRA     _vreclaim_L412
_vreclaim_L411
                LDA     #0
_vreclaim_L412
                CMP     #0
                BEQ     _vreclaim_L410
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
                FGX2_FARCALL _vreclaim_nclru_totail
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
                BRL     _vreclaim_L413
_vreclaim_L410
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
                BEQ     _vreclaim_L414
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
                BRL     _vreclaim_L415
_vreclaim_L414
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
                FGX2_FARCALL _vreclaim_nclru_totail
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
_vreclaim_L415
_vreclaim_L413
_vreclaim_L409
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_nclru_remove
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
                FGX2_FARCALL _vreclaim_ncdetach
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
                FGX2_FARCALL _vreclaim_nclru_tohead
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
                BNE     _vreclaim_L416
                TAY
                TSC
                CLC
                ADC     #cache_enter_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L416
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
                BVC     _vreclaim_L418
                EOR     #$8000
_vreclaim_L418
                BPL     _vreclaim_L417
                TAY
                TSC
                CLC
                ADC     #cache_enter_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L417
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
                BNE     _vreclaim_L420
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L420
                LDA     #1
                BRA     _vreclaim_L421
_vreclaim_L420
                LDA     #0
_vreclaim_L421
                CMP     #0
                BEQ     _vreclaim_L419
                TAY
                TSC
                CLC
                ADC     #cache_enter_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L419
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_nclru_remove
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
                FGX2_FARCALL _vreclaim_ncremhash
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
                BEQ     _vreclaim_L422
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
                BRA     _vreclaim_L423
_vreclaim_L422
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
_vreclaim_L423
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
_vreclaim_L424
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
                BVC     _vreclaim_L427
                EOR     #$8000
_vreclaim_L427
                BPL     _vreclaim_L426
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
_vreclaim_L425
                INC     _fcc_img0
                BRL     _vreclaim_L424
_vreclaim_L426
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
                FGX2_FARCALL _vreclaim_nchbucket
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
                FGX2_FARCALL _vreclaim_ncinshash
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
                FGX2_EXPORT _vreclaim_blkcount
_vreclaim_blkcount            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_blkcount_FRAMESIZE
                DO      _vreclaim_blkcount_STKGUARD
                BCC     _vreclaim_blkcount_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_blkcount_stkok
_vreclaim_blkcount_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_blkcount_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
                DO      6+_vreclaim_blkcount_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_vreclaim_blkcount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_vreclaim_blkcount_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+_vreclaim_blkcount_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_vreclaim_blkcount_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_vreclaim_blkcount_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
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
_vreclaim_L428
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
                BRL     _vreclaim_L430
                LDY     #46
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #48
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
                BNE     _vreclaim_L433
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L433
                LDA     #1
                BRA     _vreclaim_L434
_vreclaim_L433
                LDA     #0
_vreclaim_L434
                CMP     #0
                BNE     _vreclaim_L432
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #46
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #48
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
                BNE     _vreclaim_L435
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L435
                LDA     #0
                BRA     _vreclaim_L436
_vreclaim_L435
                LDA     #1
_vreclaim_L436
                CMP     #0
                BEQ     _vreclaim_L431
_vreclaim_L432
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_vreclaim_blkcount_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L431
                LDA     _fcc_img0
                INC
                STA     _fcc_img0
                PHA
                LDA     #16
                TAX
                CLC
                ADC     #4
                STA     _fcc_tmp_b
                PLA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vreclaim_L438
                EOR     #$8000
_vreclaim_L438
                BPL     _vreclaim_L437
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_vreclaim_blkcount_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_L437
_vreclaim_L429
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #42
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #44
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
                BRL     _vreclaim_L428
_vreclaim_L430
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #_vreclaim_blkcount_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_blkcount_FRAMESIZE   EQU     6
_vreclaim_blkcount_STKGUARD    EQU     0
                FGX2_EXPORT _vreclaim_reset
_vreclaim_reset            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_vreclaim_reset_FRAMESIZE
                DO      _vreclaim_reset_STKGUARD
                BCC     _vreclaim_reset_stkovf
                CMP     _fcc_stkfloor
                BCS     _vreclaim_reset_stkok
_vreclaim_reset_stkovf       JMP     _fcc_stkoflow
                FIN
_vreclaim_reset_stkok        TCS
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
                LDA     #fixarena
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bufinit
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
                LDA     #_vreclaim_vn_arena
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
                STA     mnt_a+20
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     mnt_a+22
                TYA
                LDA     #0
                STA     _vreclaim_n_trace
                LDA     #0
                STA     _vreclaim_fake_reads
                LDA     #0
                STA     _vreclaim_fake_writes
                LDA     #0
                STA     _vreclaim_fs_reclaim_fails
                TAY
                TSC
                CLC
                ADC     #_vreclaim_reset_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vreclaim_reset_FRAMESIZE   EQU     0
_vreclaim_reset_STKGUARD    EQU     0
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
                FGX2_FARCALL _vreclaim_reset
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
                BEQ     _vreclaim_L439
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
_vreclaim_L439
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
                LDA     #4
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
                LDA     _vreclaim_n_trace
                TAX
                CMP     #5
                BEQ     _vreclaim_L440
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
_vreclaim_L440
                LDA     #0
                ASL
                TAX
                LDA:    _vreclaim_trace,X
                TAX
                CMP     #1
                BEQ     _vreclaim_L441
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
_vreclaim_L441
                LDA     #1
                ASL
                TAX
                LDA:    _vreclaim_trace,X
                TAX
                CMP     #2
                BEQ     _vreclaim_L442
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
_vreclaim_L442
                LDA     #2
                ASL
                TAX
                LDA:    _vreclaim_trace,X
                TAX
                CMP     #3
                BEQ     _vreclaim_L443
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
_vreclaim_L443
                LDA     #3
                ASL
                TAX
                LDA:    _vreclaim_trace,X
                TAX
                CMP     #4
                BEQ     _vreclaim_L444
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
_vreclaim_L444
                LDA     #4
                ASL
                TAX
                LDA:    _vreclaim_trace,X
                TAX
                CMP     #5
                BEQ     _vreclaim_L445
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
_vreclaim_L445
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
                LDA     #dead_vnodeops
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vreclaim_L447
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L447
                LDA     #0
                BRA     _vreclaim_L448
_vreclaim_L447
                LDA     #1
_vreclaim_L448
                CMP     #0
                BEQ     _vreclaim_L446
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
_vreclaim_L446
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #58
                LDA     [_fcc_fpr0],Y
                BEQ     _vreclaim_L449
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
_vreclaim_L449
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #256
                BEQ     _vreclaim_L450
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
_vreclaim_L450
                LDA     _vreclaim_n_trace
                STA     19,S   ; fccstk d=0 b=19
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
                LDY     #20
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #22
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
                LDA     13,S   ; fccstk d=10 b=3
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=10 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     11,S
                STA     _fcc_fpr0
                LDA     13,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vreclaim_L452-1
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
_vreclaim_L452
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                TAX
                CMP     #9
                BEQ     _vreclaim_L451
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
_vreclaim_L451
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
                LDY     #32
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #34
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
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     17,S   ; fccstk d=14 b=3
                STA     _fcc_fpr0+2
                LDA     15,S   ; fccstk d=14 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     15,S
                STA     _fcc_fpr0
                LDA     17,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vreclaim_L454-1
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
_vreclaim_L454
                TAY
                TSC
                CLC
                ADC     #18
                TCS
                TYA
                TAX
                CMP     #5
                BEQ     _vreclaim_L453
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
_vreclaim_L453
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
                LDA     13,S   ; fccstk d=10 b=3
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=10 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     11,S
                STA     _fcc_fpr0
                LDA     13,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vreclaim_L456-1
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
_vreclaim_L456
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BEQ     _vreclaim_L455
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
_vreclaim_L455
                LDA     _vreclaim_n_trace
                TAX
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _vreclaim_L457
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
_vreclaim_L457
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #4
                LDY     #52
                STA     [_fcc_fpr0],Y
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
                LDY     #32
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #34
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
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     17,S   ; fccstk d=14 b=3
                STA     _fcc_fpr0+2
                LDA     15,S   ; fccstk d=14 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     15,S
                STA     _fcc_fpr0
                LDA     17,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vreclaim_L459-1
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
_vreclaim_L459
                TAY
                TSC
                CLC
                ADC     #18
                TCS
                TYA
                BEQ     _vreclaim_L458
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
_vreclaim_L458
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
                FGX2_FARCALL _vreclaim_reset
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
                BEQ     _vreclaim_L460
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
_vreclaim_L460
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
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
                LDA     _vreclaim_n_trace
                TAX
                CMP     #4
                BEQ     _vreclaim_L461
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
_vreclaim_L461
                LDA     #0
                STA     17,S   ; fccstk d=0 b=17
_vreclaim_L462
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                LDA     _vreclaim_n_trace
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vreclaim_L465
                EOR     #$8000
_vreclaim_L465
                BPL     _vreclaim_L464
                LDA     17,S   ; fccstk d=0 b=17
                ASL
                TAX
                LDA:    _vreclaim_trace,X
                TAX
                CMP     #3
                BNE     _vreclaim_L466
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
_vreclaim_L466
_vreclaim_L463
                LDA     17,S   ; fccstk d=0 b=17
                CLC
                ADC     #1
                STA     17,S   ; fccstk d=0 b=17
                BRA     _vreclaim_L462
_vreclaim_L464
                FGX2_FARCALL _vreclaim_reset
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
                BEQ     _vreclaim_L467
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
_vreclaim_L467
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
                BEQ     _vreclaim_L468
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
_vreclaim_L468
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
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
                SEP     #$20
                MX      %10
                LDA     vnode_free_head+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_free_head
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vreclaim_L470
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L470
                LDA     #1
                BRA     _vreclaim_L471
_vreclaim_L470
                LDA     #0
_vreclaim_L471
                CMP     #0
                BEQ     _vreclaim_L469
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
_vreclaim_L469
                LDA     freevnodes
                STA     19,S   ; fccstk d=0 b=19
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
                LDA     freevnodes
                TAX
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _vreclaim_L472
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
_vreclaim_L472
                SEP     #$20
                MX      %10
                LDA     vnode_free_head+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_free_head
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vreclaim_L474
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L474
                LDA     #0
                BRA     _vreclaim_L475
_vreclaim_L474
                LDA     #1
_vreclaim_L475
                CMP     #0
                BEQ     _vreclaim_L473
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
_vreclaim_L473
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #8
                BEQ     _vreclaim_L476
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
_vreclaim_L476
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
                BNE     _vreclaim_L478
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L478
                LDA     #0
                BRA     _vreclaim_L479
_vreclaim_L478
                LDA     #1
_vreclaim_L479
                CMP     #0
                BEQ     _vreclaim_L477
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
_vreclaim_L477
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
                BNE     _vreclaim_L481
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L481
                LDA     #1
                BRA     _vreclaim_L482
_vreclaim_L481
                LDA     #0
_vreclaim_L482
                CMP     #0
                BEQ     _vreclaim_L480
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
_vreclaim_L480
                LDA     #0
                STA     19,S   ; fccstk d=0 b=19
                SEP     #$20
                MX      %10
                LDA     vnode_free_head+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vnode_free_head
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
_vreclaim_L483
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _vreclaim_L485
                LDA     19,S   ; fccstk d=0 b=19
                INC
                STA     19,S   ; fccstk d=0 b=19
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
                BVC     _vreclaim_L487
                EOR     #$8000
_vreclaim_L487
                BPL     _vreclaim_L486
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
_vreclaim_L486
_vreclaim_L484
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
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                BRA     _vreclaim_L483
_vreclaim_L485
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                LDA     freevnodes
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _vreclaim_L488
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
_vreclaim_L488
                FGX2_FARCALL _vreclaim_reset
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
                BEQ     _vreclaim_L489
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
_vreclaim_L489
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #256
                STA     [_fcc_fpr0]
                LDA     _vreclaim_n_trace
                STA     19,S   ; fccstk d=0 b=19
                LDA     _vreclaim_nslept
                STA     17,S   ; fccstk d=0 b=17
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
                LDA     _vreclaim_nslept
                TAX
                LDA     17,S   ; fccstk d=0 b=17
                TAY
                TYA
                INC
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _vreclaim_L490
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
_vreclaim_L490
                LDA     _vreclaim_n_trace
                TAX
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _vreclaim_L491
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
_vreclaim_L491
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #512
                BNE     _vreclaim_L492
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
_vreclaim_L492
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #256
                TAX
                ORA     #512
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_fpr0]
                FGX2_FARCALL _vreclaim_reset
                LDA     #_vreclaim_fake_disk
                PHA
                LDA     #20
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #119
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
                BEQ     _vreclaim_L493
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
_vreclaim_L493
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
                LDA     #20
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
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
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #136
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bdwrite
                TSC
                CLC
                ADC     #4
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #46
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_blkcount
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                CMP     #1
                BEQ     _vreclaim_L494
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
_vreclaim_L494
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #1
                BEQ     _vreclaim_L495
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
_vreclaim_L495
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
                LDA     _vreclaim_fake_writes
                STA     19,S   ; fccstk d=0 b=19
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
                LDA     _vreclaim_fake_writes
                TAX
                LDA     19,S   ; fccstk d=0 b=19
                TAY
                TYA
                INC
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _vreclaim_L496
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
_vreclaim_L496
                LDA     #20
                TAX
                LDA:    _vreclaim_fake_disk,X
                AND     #$00FF
                PHA
                LDA     #136
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _vreclaim_L497
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
_vreclaim_L497
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #46
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_blkcount
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BEQ     _vreclaim_L498
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
_vreclaim_L498
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #42
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _vreclaim_blkcount
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BEQ     _vreclaim_L499
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
_vreclaim_L499
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                BEQ     _vreclaim_L500
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
_vreclaim_L500
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
                BEQ     _vreclaim_L501
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
_vreclaim_L501
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
                BNE     _vreclaim_L503
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L503
                LDA     #0
                BRA     _vreclaim_L504
_vreclaim_L503
                LDA     #1
_vreclaim_L504
                CMP     #0
                BEQ     _vreclaim_L502
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
_vreclaim_L502
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
                LDA     _vreclaim_fake_reads
                STA     19,S   ; fccstk d=0 b=19
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
                LDA     #20
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     15,S   ; fccstk d=8 b=7
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=8 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BEQ     _vreclaim_L505
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
_vreclaim_L505
                LDA     _vreclaim_fake_reads
                TAX
                LDA     19,S   ; fccstk d=0 b=19
                TAY
                TYA
                INC
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _vreclaim_L506
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
_vreclaim_L506
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
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
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                PHA
                LDA     #136
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _vreclaim_L507
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
_vreclaim_L507
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                TSC
                CLC
                ADC     #4
                TCS
                FGX2_FARCALL _vreclaim_reset
                LDA     #_vreclaim_fake_disk
                PHA
                LDA     #21
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #17
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
                BEQ     _vreclaim_L508
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
_vreclaim_L508
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
                LDA     #21
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
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
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #34
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bdwrite
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #0
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vinvalbuf
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                BEQ     _vreclaim_L509
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
_vreclaim_L509
                LDA     _vreclaim_fake_writes
                BEQ     _vreclaim_L510
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
_vreclaim_L510
                LDA     #21
                TAX
                LDA:    _vreclaim_fake_disk,X
                AND     #$00FF
                PHA
                LDA     #17
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _vreclaim_L511
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
_vreclaim_L511
                FGX2_FARCALL _vreclaim_reset
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
                BEQ     _vreclaim_L512
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
_vreclaim_L512
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
                BEQ     _vreclaim_L513
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
_vreclaim_L513
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
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
                CMP     #16
                BEQ     _vreclaim_L514
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
_vreclaim_L514
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #1
                BEQ     _vreclaim_L515
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
_vreclaim_L515
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #8
                BEQ     _vreclaim_L516
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
_vreclaim_L516
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
                BEQ     _vreclaim_L517
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
_vreclaim_L517
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #8
                BEQ     _vreclaim_L518
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
_vreclaim_L518
                LDA     mnt_a+18
                STA     _fcc_fpr0+2
                LDA     mnt_a+16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _vreclaim_L520
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _vreclaim_L520
                LDA     #0
                BRA     _vreclaim_L521
_vreclaim_L520
                LDA     #1
_vreclaim_L521
                CMP     #0
                BEQ     _vreclaim_L519
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
_vreclaim_L519
                FGX2_FARCALL _vreclaim_reset
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
                BEQ     _vreclaim_L522
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
_vreclaim_L522
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
                BEQ     _vreclaim_L523
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
_vreclaim_L523
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
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
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #4
                STA     [_fcc_fpr0]
                LDA     #1
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
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
                BEQ     _vreclaim_L524
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
_vreclaim_L524
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #1
                BEQ     _vreclaim_L525
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
_vreclaim_L525
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #1
                BEQ     _vreclaim_L526
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
_vreclaim_L526
                LDA     _vreclaim_nslept
                TAX
                CMP     #1
                BEQ     _vreclaim_L527
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
_vreclaim_L527
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
main_FRAMESIZE   EQU     20
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 287
