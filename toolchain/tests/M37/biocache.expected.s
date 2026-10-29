                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from biocache.c
;---------------------------------------

                MX      %00
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
                LDA     _biocache_stub_slept
                INC
                STA     _biocache_stub_slept
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
                LDA     _biocache_stub_panic
                INC
                STA     _biocache_stub_panic
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
                FGX2_EXPORT bio_strategy
bio_strategy            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #bio_strategy_FRAMESIZE-4
                DO      bio_strategy_STKGUARD
                BCC     bio_strategy_stkovf
                CMP     _fcc_stkfloor
                BCS     bio_strategy_stkok
bio_strategy_stkovf       JMP     _fcc_stkoflow
                FIN
bio_strategy_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img16
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
                STA     _fcc_img17
                LDY     #34
                LDA     [_fcc_img16],Y
                STA     _fcc_long_hi
                LDY     #32
                LDA     [_fcc_img16],Y
                STA     1,S   ; fccstk d=0 b=1
                BMI     _biocache_L1
                LDA     1,S   ; fccstk d=0 b=1
                SEC
                SBC     #64
                BVC     _biocache_L2
                EOR     #$8000
_biocache_L2
                BMI     _biocache_L0
_biocache_L1
                LDA     [_fcc_img16]
                TAX
                ORA     #4
                STA     [_fcc_img16]
                LDA     #5
                SEP     #$20
                MX      %10
                LDY     #20
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL biodone
                PLY
                PLY
                TAY
                TSC
                CLC
                ADC     #bio_strategy_FRAMESIZE-4
                TCS
                BRL     bio_strategy_bandx
_biocache_L0
                LDA     [_fcc_img16]
                AND     #1
                BEQ     _biocache_L3
                LDA     _biocache_fake_reads
                INC
                STA     _biocache_fake_reads
                LDY     #24
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA:    _biocache_fake_disk,X
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                BRA     _biocache_L4
_biocache_L3
                LDA     _biocache_fake_writes
                INC
                STA     _biocache_fake_writes
                LDA     #_biocache_fake_disk
                PHA
                LDA     3,S   ; fccstk d=2 b=1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDY     #24
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
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
_biocache_L4
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL biodone
                PLY
                PLY
                TAY
                TSC
                CLC
                ADC     #bio_strategy_FRAMESIZE-4
                TCS
bio_strategy_bandx
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
bio_strategy_FRAMESIZE   EQU     6
bio_strategy_STKGUARD    EQU     0
                FGX2_EXPORT _biocache_fake_nop
_biocache_fake_nop            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_biocache_fake_nop_FRAMESIZE
                DO      _biocache_fake_nop_STKGUARD
                BCC     _biocache_fake_nop_stkovf
                CMP     _fcc_stkfloor
                BCS     _biocache_fake_nop_stkok
_biocache_fake_nop_stkovf       JMP     _fcc_stkoflow
                FIN
_biocache_fake_nop_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_biocache_fake_nop_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_fake_nop_FRAMESIZE   EQU     0
_biocache_fake_nop_STKGUARD    EQU     0
                FGX2_EXPORT _biocache_fake_strategy
_biocache_fake_strategy            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_biocache_fake_strategy_FRAMESIZE
                DO      _biocache_fake_strategy_STKGUARD
                BCC     _biocache_fake_strategy_stkovf
                CMP     _fcc_stkfloor
                BCS     _biocache_fake_strategy_stkok
_biocache_fake_strategy_stkovf       JMP     _fcc_stkoflow
                FIN
_biocache_fake_strategy_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_biocache_fake_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_biocache_fake_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_biocache_fake_strategy_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_biocache_fake_strategy_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_biocache_fake_strategy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_biocache_fake_strategy_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bio_strategy
                PLY
                PLY
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_biocache_fake_strategy_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_fake_strategy_FRAMESIZE   EQU     0
_biocache_fake_strategy_STKGUARD    EQU     0
                FGX2_EXPORT _biocache_bufhashof
_biocache_bufhashof            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_biocache_bufhashof_FRAMESIZE
                DO      _biocache_bufhashof_STKGUARD
                BCC     _biocache_bufhashof_stkovf
                CMP     _fcc_stkfloor
                BCS     _biocache_bufhashof_stkok
_biocache_bufhashof_stkovf       JMP     _fcc_stkoflow
                FIN
_biocache_bufhashof_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_biocache_bufhashof_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_biocache_bufhashof_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_biocache_bufhashof_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_biocache_bufhashof_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_biocache_bufhashof_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_biocache_bufhashof_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shrs16
                PHA
                DO      14+_biocache_bufhashof_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_biocache_bufhashof_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_biocache_bufhashof_FRAMESIZE,S   ; fccstk d=2 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      12+_biocache_bufhashof_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_biocache_bufhashof_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_biocache_bufhashof_FRAMESIZE,S   ; fccstk d=2 b=10 fs
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
                ADC     #_biocache_bufhashof_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_bufhashof_FRAMESIZE   EQU     0
_biocache_bufhashof_STKGUARD    EQU     0
                FGX2_EXPORT _biocache_bremhash
_biocache_bremhash            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_biocache_bremhash_FRAMESIZE
                DO      _biocache_bremhash_STKGUARD
                BCC     _biocache_bremhash_stkovf
                CMP     _fcc_stkfloor
                BCS     _biocache_bremhash_stkok
_biocache_bremhash_stkovf       JMP     _fcc_stkoflow
                FIN
_biocache_bremhash_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_biocache_bremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_biocache_bremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_biocache_bremhash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+_biocache_bremhash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_biocache_bremhash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_biocache_bremhash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                LDY     #6
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr1+2
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
                LDY     #2
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr1+2
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
                ADC     #_biocache_bremhash_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_bremhash_FRAMESIZE   EQU     0
_biocache_bremhash_STKGUARD    EQU     0
                FGX2_EXPORT _biocache_binshash
_biocache_binshash            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_biocache_binshash_FRAMESIZE
                DO      _biocache_binshash_STKGUARD
                BCC     _biocache_binshash_stkovf
                CMP     _fcc_stkfloor
                BCS     _biocache_binshash_stkok
_biocache_binshash_stkovf       JMP     _fcc_stkoflow
                FIN
_biocache_binshash_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_biocache_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_biocache_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_biocache_binshash_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+_biocache_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_biocache_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_biocache_binshash_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                DO      10+_biocache_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_biocache_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_biocache_binshash_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img2
                DO      12+_biocache_binshash_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_biocache_binshash_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_biocache_binshash_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img3
                LDY     #2
                LDA     [_fcc_img2],Y
                PHA
                INY
                INY
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr1+2
                PLA
                STA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img2
                LDY     #6
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img3
                LDY     #8
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_img2],Y
                PHA
                INY
                INY
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img0
                LDY     #6
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img1
                LDY     #8
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img0
                LDY     #2
                STA     [_fcc_img2],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img1
                LDY     #4
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
                ADC     #_biocache_binshash_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_binshash_FRAMESIZE   EQU     0
_biocache_binshash_STKGUARD    EQU     0
                FGX2_EXPORT _biocache_bremfree
_biocache_bremfree            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_biocache_bremfree_FRAMESIZE
                DO      _biocache_bremfree_STKGUARD
                BCC     _biocache_bremfree_stkovf
                CMP     _fcc_stkfloor
                BCS     _biocache_bremfree_stkok
_biocache_bremfree_stkovf       JMP     _fcc_stkoflow
                FIN
_biocache_bremfree_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_biocache_bremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_biocache_bremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_biocache_bremfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+_biocache_bremfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_biocache_bremfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_biocache_bremfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                LDY     #14
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr1+2
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
                LDY     #10
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr1+2
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
                ADC     #_biocache_bremfree_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_bremfree_FRAMESIZE   EQU     0
_biocache_bremfree_STKGUARD    EQU     0
                FGX2_EXPORT _biocache_binsheadfree
_biocache_binsheadfree            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_biocache_binsheadfree_FRAMESIZE
                DO      _biocache_binsheadfree_STKGUARD
                BCC     _biocache_binsheadfree_stkovf
                CMP     _fcc_stkfloor
                BCS     _biocache_binsheadfree_stkok
_biocache_binsheadfree_stkovf       JMP     _fcc_stkoflow
                FIN
_biocache_binsheadfree_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+_biocache_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_biocache_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_biocache_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img0
                DO      12+_biocache_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_biocache_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_biocache_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img1
                DO      6+_biocache_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_biocache_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_biocache_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img2
                DO      8+_biocache_binsheadfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_biocache_binsheadfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_biocache_binsheadfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img3
                LDY     #10
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img2
                LDY     #14
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img3
                LDY     #16
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDY     #10
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr1+2
                PLA
                STA     _fcc_fpr1
                LDY     #10
                STA     [_fcc_img2],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #12
                STA     [_fcc_img2],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img2
                LDY     #10
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img3
                LDY     #12
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img0
                LDY     #14
                STA     [_fcc_img2],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img1
                LDY     #16
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
                ADC     #_biocache_binsheadfree_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_binsheadfree_FRAMESIZE   EQU     0
_biocache_binsheadfree_STKGUARD    EQU     0
                FGX2_EXPORT _biocache_binstailfree
_biocache_binstailfree            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_biocache_binstailfree_FRAMESIZE
                DO      _biocache_binstailfree_STKGUARD
                BCC     _biocache_binstailfree_stkovf
                CMP     _fcc_stkfloor
                BCS     _biocache_binstailfree_stkok
_biocache_binstailfree_stkovf       JMP     _fcc_stkoflow
                FIN
_biocache_binstailfree_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+_biocache_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_biocache_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_biocache_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img0
                DO      12+_biocache_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_biocache_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_biocache_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img1
                DO      6+_biocache_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_biocache_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_biocache_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img2
                DO      8+_biocache_binstailfree_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_biocache_binstailfree_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_biocache_binstailfree_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img3
                LDY     #14
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img2
                LDY     #10
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img3
                LDY     #12
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDY     #14
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr1+2
                PLA
                STA     _fcc_fpr1
                LDY     #14
                STA     [_fcc_img2],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #16
                STA     [_fcc_img2],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img2
                LDY     #14
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img3
                LDY     #16
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img0
                LDY     #10
                STA     [_fcc_img2],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img1
                LDY     #12
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
                ADC     #_biocache_binstailfree_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_binstailfree_FRAMESIZE   EQU     0
_biocache_binstailfree_STKGUARD    EQU     0
                FGX2_EXPORT _biocache_bufinsvn
_biocache_bufinsvn            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_biocache_bufinsvn_FRAMESIZE
                DO      _biocache_bufinsvn_STKGUARD
                BCC     _biocache_bufinsvn_stkovf
                CMP     _fcc_stkfloor
                BCS     _biocache_bufinsvn_stkok
_biocache_bufinsvn_stkovf       JMP     _fcc_stkoflow
                FIN
_biocache_bufinsvn_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_biocache_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_biocache_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_biocache_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+_biocache_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_biocache_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_biocache_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                LDA     _fcc_img0
                DO      10+_biocache_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_biocache_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_biocache_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_ptr
                DO      12+_biocache_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_biocache_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_biocache_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=12 fs
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
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #44
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img0
                DO      12+_biocache_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_biocache_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_biocache_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+_biocache_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_biocache_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_biocache_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr1
                LDY     #46
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #48
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDY     #42
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _biocache_L5
                LDY     #42
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img1
                STA     _fcc_fpr1+2
                LDA     _fcc_img0
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
_biocache_L5
                DO      12+_biocache_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_biocache_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_biocache_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_biocache_bufinsvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_biocache_bufinsvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_biocache_bufinsvn_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
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
                TAY
                TSC
                CLC
                ADC     #_biocache_bufinsvn_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_bufinsvn_FRAMESIZE   EQU     0
_biocache_bufinsvn_STKGUARD    EQU     0
                FGX2_EXPORT _biocache_bufremvn
_biocache_bufremvn            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_biocache_bufremvn_FRAMESIZE
                DO      _biocache_bufremvn_STKGUARD
                BCC     _biocache_bufremvn_stkovf
                CMP     _fcc_stkfloor
                BCS     _biocache_bufremvn_stkok
_biocache_bufremvn_stkovf       JMP     _fcc_stkoflow
                FIN
_biocache_bufremvn_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_biocache_bufremvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_biocache_bufremvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_biocache_bufremvn_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+_biocache_bufremvn_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_biocache_bufremvn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_biocache_bufremvn_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                LDY     #46
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L7
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L7
                LDA     #1
                BRA     _biocache_L8
_biocache_L7
                LDA     #0
_biocache_L8
                CMP     #0
                BEQ     _biocache_L6
                TAY
                TSC
                CLC
                ADC     #_biocache_bufremvn_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_L6
                LDY     #42
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _biocache_L9
                LDY     #46
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr1+2
                PLA
                STA     _fcc_fpr1
                LDY     #46
                STA     [_fcc_img2],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #48
                STA     [_fcc_img2],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
_biocache_L9
                LDY     #46
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
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
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #42
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #44
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #46
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #48
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
                ADC     #_biocache_bufremvn_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_bufremvn_FRAMESIZE   EQU     4
_biocache_bufremvn_STKGUARD    EQU     0
                FGX2_EXPORT bufinit
bufinit            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img20
                TSC
                SEC
                SBC     #bufinit_FRAMESIZE-10
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
                STA     _fcc_img20
_biocache_L10
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img20
                TAX
                SEC
                SBC     #3
                BVC     _biocache_L13
                EOR     #$8000
_biocache_L13
                BPL     _biocache_L12
                LDA     _fcc_img20
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     _fcc_img18
                LDY     #10
                STA     [_fcc_img18],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img19
                LDY     #12
                STA     [_fcc_img18],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img19
                STA     _fcc_fpr1+2
                LDA     _fcc_img18
                STA     _fcc_fpr1
                LDY     #14
                STA     [_fcc_img18],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #16
                STA     [_fcc_img18],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
_biocache_L11
                INC     _fcc_img20
                BRA     _biocache_L10
_biocache_L12
                LDA     #0
                STA     _fcc_img20
_biocache_L14
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img20
                TAX
                SEC
                SBC     #16
                BVC     _biocache_L17
                EOR     #$8000
_biocache_L17
                BPL     _biocache_L16
                LDA     _fcc_img20
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     _fcc_img18
                LDY     #2
                STA     [_fcc_img18],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img19
                LDY     #4
                STA     [_fcc_img18],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img19
                STA     _fcc_fpr1+2
                LDA     _fcc_img18
                STA     _fcc_fpr1
                LDY     #6
                STA     [_fcc_img18],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #8
                STA     [_fcc_img18],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
_biocache_L15
                INC     _fcc_img20
                BRA     _biocache_L14
_biocache_L16
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     #0
                STA     _fcc_img20
_biocache_L18
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img20
                TAX
                SEC
                SBC     #16
                BVC     _biocache_L21
                EOR     #$8000
_biocache_L21
                BMI     *+5
                BRL     _biocache_L20
                LDA     _fcc_img20
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #2048
                STA     [_fcc_img16]
                LDA     #0
                LDY     #22
                STA     [_fcc_img16],Y
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #38
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #40
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
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
                JSR     _fcc_long_from_int
                LDY     #32
                STA     [_fcc_img16],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #34
                STA     [_fcc_img16],Y
                TXA
                LDA     #1024
                LDY     #18
                STA     [_fcc_img16],Y
                LDA     #0
                SEP     #$20
                MX      %10
                LDY     #20
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     #0
                LDY     #36
                STA     [_fcc_img16],Y
                LDA     _fcc_img16
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
                LDA     _fcc_img20
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
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #26
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img16
                LDY     #2
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img17
                LDY     #4
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img16
                LDY     #6
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img17
                LDY     #8
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
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
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img18
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _biocache_binstailfree
                PLY
                PLY
                PLY
                PLY
_biocache_L19
                INC     _fcc_img20
                BRL     _biocache_L18
_biocache_L20
                TAY
                TSC
                CLC
                ADC     #bufinit_FRAMESIZE-10
                TCS
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
bufinit_FRAMESIZE   EQU     20
bufinit_STKGUARD    EQU     0
                FGX2_EXPORT incore
incore            ENT
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
                SBC     #incore_FRAMESIZE-16
                DO      incore_STKGUARD
                BCC     incore_stkovf
                CMP     _fcc_stkfloor
                BCS     incore_stkok
incore_stkovf       JMP     _fcc_stkoflow
                FIN
incore_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img20
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
                STA     _fcc_img21
                DO      10+incore_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+incore_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+incore_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img22
                DO      12+incore_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+incore_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+incore_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img23
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
                LDA     _fcc_img23
                STA     _fcc_long_hi
                LDA     _fcc_img22
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img20
                PEI     _fcc_img21
                PEI     _fcc_img20
                FGX2_FARCALL _biocache_bufhashof
                PLY
                PLY
                PLY
                PLY
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDY     #2
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
_biocache_L22
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
                BNE     _biocache_L25
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L25
                LDA     #0
                BRA     _biocache_L26
_biocache_L25
                LDA     #1
_biocache_L26
                CMP     #0
                BNE     *+5
                BRL     _biocache_L24
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
                LDA     _fcc_img23
                STA     _fcc_long_hi
                LDA     _fcc_img22
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
                BEQ     _biocache_L27
                LDY     #38
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img21
                STA     _fcc_fpr1+2
                LDA     _fcc_img20
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L28
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L28
                LDA     #1
                BRA     _biocache_L29
_biocache_L28
                LDA     #0
_biocache_L29
                CMP     #0
                BEQ     _biocache_L27
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #2048
                CMP     #0
                BNE     _biocache_L27
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #incore_FRAMESIZE-16
                TCS
                BRA     incore_bandx
_biocache_L27
_biocache_L23
                LDY     #2
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                BRL     _biocache_L22
_biocache_L24
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #incore_FRAMESIZE-16
                TCS
incore_bandx
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
incore_FRAMESIZE   EQU     24
incore_STKGUARD    EQU     0
                FGX2_EXPORT _biocache_getnewbuf
_biocache_getnewbuf            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #_biocache_getnewbuf_FRAMESIZE-8
                DO      _biocache_getnewbuf_STKGUARD
                BCC     _biocache_getnewbuf_stkovf
                CMP     _fcc_stkfloor
                BCS     _biocache_getnewbuf_stkok
_biocache_getnewbuf_stkovf       JMP     _fcc_stkoflow
                FIN
_biocache_getnewbuf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
_biocache_getnewbuf_uL_again
_biocache_L30
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDY     #10
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img19
                STA     _fcc_fpr1+2
                LDA     _fcc_img18
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L34
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L34
                LDA     #1
                BRA     _biocache_L35
_biocache_L34
                LDA     #0
_biocache_L35
                CMP     #0
                BEQ     _biocache_L33
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
_biocache_L33
                LDY     #10
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img19
                STA     _fcc_fpr1+2
                LDA     _fcc_img18
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L37
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L37
                LDA     #0
                BRA     _biocache_L38
_biocache_L37
                LDA     #1
_biocache_L38
                CMP     #0
                BEQ     _biocache_L36
                BRA     _biocache_L32
_biocache_L36
                LDA     [_fcc_img18]
                TAX
                ORA     #64
                STA     [_fcc_img18]
                LDA     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img18
                FGX2_FARCALL kc_sleep
                PLY
                PLY
_biocache_L31
                BRL     _biocache_L30
_biocache_L32
                LDY     #10
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _biocache_bremfree
                PLY
                PLY
                LDA     [_fcc_img16]
                ORA     #8
                STA     [_fcc_img16]
                LDA     [_fcc_img16]
                TAX
                AND     #512
                CMP     #0
                BEQ     _biocache_L39
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL bwrite
                PLY
                PLY
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     _biocache_getnewbuf_uL_again
_biocache_L39
                LDY     #38
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _biocache_L40
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL brelvp
                PLY
                PLY
_biocache_L40
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _biocache_bremhash
                PLY
                PLY
                LDA     _fcc_img16
                LDY     #2
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img17
                LDY     #4
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img16
                LDY     #6
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img17
                LDY     #8
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     #8
                STA     [_fcc_img16]
                LDA     #0
                SEP     #$20
                MX      %10
                LDY     #20
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     #0
                LDY     #36
                STA     [_fcc_img16],Y
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #_biocache_getnewbuf_FRAMESIZE-8
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
_biocache_getnewbuf_FRAMESIZE   EQU     16
_biocache_getnewbuf_STKGUARD    EQU     0
                FGX2_EXPORT getblk
getblk            ENT
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
                SBC     #getblk_FRAMESIZE-16
                DO      getblk_STKGUARD
                BCC     getblk_stkovf
                CMP     _fcc_stkfloor
                BCS     getblk_stkok
getblk_stkovf       JMP     _fcc_stkoflow
                FIN
getblk_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img18
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
                STA     _fcc_img19
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
                STA     _fcc_img22
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
                STA     _fcc_img23
                LDY     #22
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L42
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L42
                LDA     #1
                BRA     _biocache_L43
_biocache_L42
                LDA     #0
_biocache_L43
                CMP     #0
                BEQ     _biocache_L41
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_biocache_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                PLY
                PLY
_biocache_L41
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
                LDA     _fcc_img23
                STA     _fcc_long_hi
                LDA     _fcc_img22
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img18
                FGX2_FARCALL _biocache_bufhashof
                PLY
                PLY
                PLY
                PLY
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
                STA     _fcc_img21
                LDA     _fcc_fpr0
                STA     _fcc_img20
getblk_uL_loop
                LDY     #2
                LDA     [_fcc_img20],Y
                PHA
                INY
                INY
                LDA     [_fcc_img20],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
_biocache_L44
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
                BNE     _biocache_L47
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L47
                LDA     #0
                BRA     _biocache_L48
_biocache_L47
                LDA     #1
_biocache_L48
                CMP     #0
                BNE     *+5
                BRL     _biocache_L46
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
                LDA     _fcc_img23
                STA     _fcc_long_hi
                LDA     _fcc_img22
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
                BNE     _biocache_L50
                LDY     #38
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img19
                STA     _fcc_fpr1+2
                LDA     _fcc_img18
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L51
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L51
                LDA     #0
                BRA     _biocache_L52
_biocache_L51
                LDA     #1
_biocache_L52
                CMP     #0
                BNE     _biocache_L50
                LDA     [_fcc_img16]
                TAX
                AND     #2048
                CMP     #0
                BEQ     _biocache_L49
_biocache_L50
                BRA     _biocache_L45
_biocache_L49
                LDA     [_fcc_img16]
                TAX
                AND     #8
                CMP     #0
                BEQ     _biocache_L53
                LDA     [_fcc_img16]
                TAX
                ORA     #64
                STA     [_fcc_img16]
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL kc_sleep
                PLY
                PLY
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     getblk_uL_loop
_biocache_L53
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _biocache_bremfree
                PLY
                PLY
                LDA     [_fcc_img16]
                TAX
                ORA     #8
                STA     [_fcc_img16]
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #getblk_FRAMESIZE-16
                TCS
                BRL     getblk_bandx
_biocache_L45
                LDY     #2
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                BRL     _biocache_L44
_biocache_L46
                FGX2_FARCALL _biocache_getnewbuf
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img18
                FGX2_FARCALL bgetvp
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_img23
                STA     _fcc_long_hi
                LDA     _fcc_img22
                LDY     #28
                STA     [_fcc_img16],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #30
                STA     [_fcc_img16],Y
                TXA
                LDA     _fcc_img23
                STA     _fcc_long_hi
                LDA     _fcc_img22
                LDY     #32
                STA     [_fcc_img16],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #34
                STA     [_fcc_img16],Y
                TXA
                LDA     _fcc_img20
                PEI     _fcc_img21
                PEI     _fcc_img20
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _biocache_binshash
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #getblk_FRAMESIZE-16
                TCS
getblk_bandx
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
getblk_FRAMESIZE   EQU     24
getblk_STKGUARD    EQU     0
                FGX2_EXPORT brelse
brelse            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #brelse_FRAMESIZE-8
                DO      brelse_STKGUARD
                BCC     brelse_stkovf
                CMP     _fcc_stkfloor
                BCS     brelse_stkok
brelse_stkovf       JMP     _fcc_stkoflow
                FIN
brelse_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img16
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
                STA     _fcc_img17
                LDA     [_fcc_img16]
                TAX
                AND     #64
                BEQ     _biocache_L54
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL kc_wakeup
                PLY
                PLY
_biocache_L54
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
                BEQ     _biocache_L55
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
                PLY
                PLY
_biocache_L55
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
                BEQ     _biocache_L56
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
                PLY
                PLY
_biocache_L56
                LDA     [_fcc_img16]
                AND     #4
                BEQ     _biocache_L57
                LDA     [_fcc_img16]
                ORA     #2048
                STA     [_fcc_img16]
_biocache_L57
                LDA     [_fcc_img16]
                TAX
                AND     #2048
                BEQ     _biocache_L58
                LDY     #38
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _biocache_L59
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL brelvp
                PLY
                PLY
_biocache_L59
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _biocache_bremhash
                PLY
                PLY
                LDA     _fcc_img16
                LDY     #2
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img17
                LDY     #4
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img16
                LDY     #6
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img17
                LDY     #8
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     [_fcc_img16]
                PHA
                LDA     #512
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_img16]
_biocache_L58
                LDA     [_fcc_img16]
                AND     #2048
                BEQ     _biocache_L60
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                BRA     _biocache_L61
_biocache_L60
                LDA     [_fcc_img16]
                AND     #8192
                BEQ     _biocache_L62
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                BRA     _biocache_L63
_biocache_L62
                LDA     [_fcc_img16]
                AND     #128
                BEQ     _biocache_L64
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                BRA     _biocache_L65
_biocache_L64
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
_biocache_L65
_biocache_L63
_biocache_L61
                LDA     [_fcc_img16]
                PHA
                LDA     #2048
                TAX
                ORA     #128
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                BEQ     _biocache_L66
                LDA     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img18
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _biocache_binsheadfree
                PLY
                PLY
                PLY
                PLY
                BRA     _biocache_L67
_biocache_L66
                LDA     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img18
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _biocache_binstailfree
                PLY
                PLY
                PLY
                PLY
_biocache_L67
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #64
                ORA     #8
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
                ADC     #brelse_FRAMESIZE-8
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
brelse_FRAMESIZE   EQU     12
brelse_STKGUARD    EQU     0
                FGX2_EXPORT biowait
biowait            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #biowait_FRAMESIZE-4
                DO      biowait_STKGUARD
                BCC     biowait_stkovf
                CMP     _fcc_stkfloor
                BCS     biowait_stkok
biowait_stkovf       JMP     _fcc_stkoflow
                FIN
biowait_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img16
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
                STA     _fcc_img17
_biocache_L68
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     [_fcc_img16]
                TAX
                AND     #2
                CMP     #0
                BNE     _biocache_L69
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL kc_sleep
                PLY
                PLY
                BRA     _biocache_L68
_biocache_L69
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #4
                BNE     _biocache_L70
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #biowait_FRAMESIZE-4
                TCS
                BRA     biowait_bandx
_biocache_L70
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDY     #20
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                BEQ     _biocache_L71
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDY     #20
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                BRA     _biocache_L72
_biocache_L71
                LDA     #5
_biocache_L72
                TAY
                TSC
                CLC
                ADC     #biowait_FRAMESIZE-4
                TCS
biowait_bandx
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
biowait_FRAMESIZE   EQU     4
biowait_STKGUARD    EQU     0
                FGX2_EXPORT biodone
biodone            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #biodone_FRAMESIZE-8
                DO      biodone_STKGUARD
                BCC     biodone_stkovf
                CMP     _fcc_stkfloor
                BCS     biodone_stkok
biodone_stkovf       JMP     _fcc_stkoflow
                FIN
biodone_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img16
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
                STA     _fcc_img17
                LDA     [_fcc_img16]
                TAX
                AND     #2
                BEQ     _biocache_L73
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_biocache_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                PLY
                PLY
_biocache_L73
                LDA     [_fcc_img16]
                ORA     #2
                STA     [_fcc_img16]
                LDA     [_fcc_img16]
                AND     #1
                BEQ     *+5
                BRL     _biocache_L74
                LDY     #38
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _biocache_L74
                LDY     #38
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDY     #50
                LDA     [_fcc_img18],Y
                DEC
                LDY     #50
                STA     [_fcc_img18],Y
                LDA     [_fcc_img18]
                AND     #1024
                BEQ     _biocache_L75
                LDY     #50
                LDA     [_fcc_img18],Y
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _biocache_L76
                EOR     #$8000
_biocache_L76
                BMI     _biocache_L75
                LDY     #50
                LDA     [_fcc_img18],Y
                BPL     _biocache_L77
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_biocache_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                PLY
                PLY
_biocache_L77
                LDA     [_fcc_img18]
                PHA
                LDA     #1024
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_img18]
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                CLC
                ADC     #50
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_wakeup
                PLY
                PLY
_biocache_L75
_biocache_L74
                LDA     [_fcc_img16]
                TAX
                AND     #256
                BEQ     _biocache_L78
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL brelse
                PLY
                PLY
                TAY
                TSC
                CLC
                ADC     #biodone_FRAMESIZE-8
                TCS
                BRA     biodone_bandx
_biocache_L78
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #64
                BEQ     _biocache_L79
                LDA     [_fcc_img16]
                PHA
                LDA     #64
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_img16]
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL kc_wakeup
                PLY
                PLY
_biocache_L79
                TAY
                TSC
                CLC
                ADC     #biodone_FRAMESIZE-8
                TCS
biodone_bandx
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
biodone_FRAMESIZE   EQU     12
biodone_STKGUARD    EQU     0
                FGX2_EXPORT bread
bread            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #bread_FRAMESIZE-4
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
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
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
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #2
                TAX
                ORA     #512
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                BEQ     _biocache_L80
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #bread_FRAMESIZE-4
                TCS
                BRA     bread_bandx
_biocache_L80
                LDA     [_fcc_img16]
                TAX
                ORA     #1
                STA     [_fcc_img16]
                LDA     #0
                LDY     #36
                STA     [_fcc_img16],Y
                LDY     #38
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #22
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #116
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
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
                PEA     _biocache_L81-1
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
_biocache_L81
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL biowait
                PLY
                PLY
                TAY
                TSC
                CLC
                ADC     #bread_FRAMESIZE-4
                TCS
bread_bandx
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
bread_FRAMESIZE   EQU     8
bread_STKGUARD    EQU     1
                FGX2_EXPORT bwrite
bwrite            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #bwrite_FRAMESIZE-4
                DO      bwrite_STKGUARD
                BCC     bwrite_stkovf
                CMP     _fcc_stkfloor
                BCS     bwrite_stkok
bwrite_stkovf       JMP     _fcc_stkoflow
                FIN
bwrite_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img16
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
                STA     _fcc_img17
                LDA     [_fcc_img16]
                AND     #256
                STA     3,S   ; fccstk d=0 b=3
                LDA     [_fcc_img16]
                AND     #512
                STA     5,S   ; fccstk d=0 b=5
                LDA     [_fcc_img16]
                PHA
                LDA     #1
                ORA     #2
                ORA     #4
                TAX
                ORA     #512
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     [_fcc_img16]
                LDA     5,S   ; fccstk d=0 b=5
                BEQ     _biocache_L82
                LDY     #38
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL reassignbuf
                PLY
                PLY
                PLY
                PLY
_biocache_L82
                LDA     #0
                LDY     #36
                STA     [_fcc_img16],Y
                LDY     #38
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                CLC
                ADC     #50
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                LDY     #38
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #22
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #116
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
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
                PEA     _biocache_L83-1
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
_biocache_L83
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                BEQ     _biocache_L84
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #bwrite_FRAMESIZE-4
                TCS
                BRA     bwrite_bandx
_biocache_L84
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL biowait
                PLY
                PLY
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL brelse
                PLY
                PLY
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #bwrite_FRAMESIZE-4
                TCS
bwrite_bandx
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
bwrite_FRAMESIZE   EQU     10
bwrite_STKGUARD    EQU     1
                FGX2_EXPORT bdwrite
bdwrite            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #bdwrite_FRAMESIZE-4
                DO      bdwrite_STKGUARD
                BCC     bdwrite_stkovf
                CMP     _fcc_stkfloor
                BCS     bdwrite_stkok
bdwrite_stkovf       JMP     _fcc_stkoflow
                FIN
bdwrite_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img16
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
                STA     _fcc_img17
                LDA     [_fcc_img16]
                AND     #512
                BNE     _biocache_L85
                LDA     [_fcc_img16]
                TAX
                ORA     #512
                STA     [_fcc_img16]
                LDY     #38
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL reassignbuf
                PLY
                PLY
                PLY
                PLY
_biocache_L85
                LDA     [_fcc_img16]
                TAX
                ORA     #2
                STA     [_fcc_img16]
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL brelse
                PLY
                PLY
                TAY
                TSC
                CLC
                ADC     #bdwrite_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
bdwrite_FRAMESIZE   EQU     4
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
                PLY
                PLY
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
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #bgetvp_FRAMESIZE-8
                DO      bgetvp_STKGUARD
                BCC     bgetvp_stkovf
                CMP     _fcc_stkfloor
                BCS     bgetvp_stkok
bgetvp_stkovf       JMP     _fcc_stkoflow
                FIN
bgetvp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img16
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
                STA     _fcc_img17
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
                STA     _fcc_img18
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
                STA     _fcc_img19
                LDY     #38
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _biocache_L86
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_biocache_S3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                PLY
                PLY
_biocache_L86
                LDA     _fcc_img16
                LDY     #38
                STA     [_fcc_img18],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_img17
                LDY     #40
                STA     [_fcc_img18],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDY     #52
                LDA     [_fcc_img16],Y
                TAX
                CMP     #3
                BEQ     _biocache_L88
                LDY     #52
                LDA     [_fcc_img16],Y
                TAX
                CMP     #4
                BNE     _biocache_L87
_biocache_L88
                LDY     #54
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr1+2
                PLA
                STA     _fcc_fpr1
                LDY     #12
                LDA     [_fcc_fpr1],Y
                LDY     #22
                STA     [_fcc_img18],Y
                BRA     _biocache_L89
_biocache_L87
                LDA     #65535
                LDY     #22
                STA     [_fcc_img18],Y
_biocache_L89
                LDY     #4
                LDA     [_fcc_img16],Y
                INC
                LDY     #4
                STA     [_fcc_img16],Y
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                CLC
                ADC     #42
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img18
                FGX2_FARCALL _biocache_bufinsvn
                PLY
                PLY
                PLY
                PLY
                TAY
                TSC
                CLC
                ADC     #bgetvp_FRAMESIZE-8
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
bgetvp_FRAMESIZE   EQU     8
bgetvp_STKGUARD    EQU     0
                FGX2_EXPORT brelvp
brelvp            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #brelvp_FRAMESIZE-8
                DO      brelvp_STKGUARD
                BCC     brelvp_stkovf
                CMP     _fcc_stkfloor
                BCS     brelvp_stkok
brelvp_stkovf       JMP     _fcc_stkoflow
                FIN
brelvp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img16
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
                STA     _fcc_img17
                LDY     #38
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L91
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L91
                LDA     #1
                BRA     _biocache_L92
_biocache_L91
                LDA     #0
_biocache_L92
                CMP     #0
                BEQ     _biocache_L90
                TAY
                TSC
                CLC
                ADC     #brelvp_FRAMESIZE-8
                TCS
                BRA     brelvp_bandx
_biocache_L90
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _biocache_bufremvn
                PLY
                PLY
                LDY     #38
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #38
                STA     [_fcc_img16],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #40
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                BEQ     _biocache_L93
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                SEC
                SBC     #1
                LDY     #4
                STA     [_fcc_fpr0],Y
_biocache_L93
                TAY
                TSC
                CLC
                ADC     #brelvp_FRAMESIZE-8
                TCS
brelvp_bandx
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
brelvp_FRAMESIZE   EQU     12
brelvp_STKGUARD    EQU     0
                FGX2_EXPORT reassignbuf
reassignbuf            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #reassignbuf_FRAMESIZE-8
                DO      reassignbuf_STKGUARD
                BCC     reassignbuf_stkovf
                CMP     _fcc_stkfloor
                BCS     reassignbuf_stkok
reassignbuf_stkovf       JMP     _fcc_stkoflow
                FIN
reassignbuf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img16
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
                STA     _fcc_img17
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
                STA     _fcc_img18
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
                STA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L95
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L95
                LDA     #1
                BRA     _biocache_L96
_biocache_L95
                LDA     #0
_biocache_L96
                CMP     #0
                BEQ     _biocache_L94
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_biocache_S4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                PLY
                PLY
_biocache_L94
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _biocache_bufremvn
                PLY
                PLY
                LDA     [_fcc_img16]
                TAX
                AND     #512
                BEQ     _biocache_L97
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                CLC
                ADC     #46
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _biocache_bufinsvn
                PLY
                PLY
                PLY
                PLY
                BRA     _biocache_L98
_biocache_L97
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                CLC
                ADC     #42
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _biocache_bufinsvn
                PLY
                PLY
                PLY
                PLY
_biocache_L98
                TAY
                TSC
                CLC
                ADC     #reassignbuf_FRAMESIZE-8
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
reassignbuf_FRAMESIZE   EQU     8
reassignbuf_STKGUARD    EQU     0
                FGX2_EXPORT vflushbuf
vflushbuf            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img20
                PEI     _fcc_img21
                TSC
                SEC
                SBC     #vflushbuf_FRAMESIZE-12
                DO      vflushbuf_STKGUARD
                BCC     vflushbuf_stkovf
                CMP     _fcc_stkfloor
                BCS     vflushbuf_stkok
vflushbuf_stkovf       JMP     _fcc_stkoflow
                FIN
vflushbuf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img18
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
                STA     _fcc_img19
vflushbuf_uL_loop
                LDY     #46
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
_biocache_L99
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
                BRL     _biocache_L101
                LDY     #42
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img21
                LDA     _fcc_fpr0
                STA     _fcc_img20
                LDA     [_fcc_img16]
                TAX
                AND     #8
                CMP     #0
                BEQ     _biocache_L102
                BRA     _biocache_L100
_biocache_L102
                LDA     [_fcc_img16]
                TAX
                AND     #512
                BNE     _biocache_L103
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_biocache_S5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                PLY
                PLY
_biocache_L103
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _biocache_bremfree
                PLY
                PLY
                LDA     [_fcc_img16]
                ORA     #8
                STA     [_fcc_img16]
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
                BNE     _biocache_L104
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL bawrite
                PLY
                PLY
                BRA     _biocache_L105
_biocache_L104
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL bwrite
                PLY
                PLY
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     vflushbuf_uL_loop
_biocache_L105
_biocache_L100
                LDA     _fcc_img21
                STA     _fcc_fpr0+2
                LDA     _fcc_img20
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                BRL     _biocache_L99
_biocache_L101
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
                BNE     _biocache_L106
                TAY
                TSC
                CLC
                ADC     #vflushbuf_FRAMESIZE-12
                TCS
                BRA     vflushbuf_bandx
_biocache_L106
_biocache_L107
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDY     #50
                LDA     [_fcc_img18],Y
                CMP     #0
                BEQ     _biocache_L108
                LDA     [_fcc_img18]
                TAX
                ORA     #1024
                STA     [_fcc_img18]
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                CLC
                ADC     #50
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_sleep
                PLY
                PLY
                BRA     _biocache_L107
_biocache_L108
                LDY     #46
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _biocache_L109
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     vflushbuf_uL_loop
_biocache_L109
                TAY
                TSC
                CLC
                ADC     #vflushbuf_FRAMESIZE-12
                TCS
vflushbuf_bandx
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
vflushbuf_FRAMESIZE   EQU     20
vflushbuf_STKGUARD    EQU     0
                FGX2_EXPORT bflush
bflush            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                TSC
                SEC
                SBC     #bflush_FRAMESIZE-6
                DO      bflush_STKGUARD
                BCC     bflush_stkovf
                CMP     _fcc_stkfloor
                BCS     bflush_stkok
bflush_stkovf       JMP     _fcc_stkoflow
                FIN
bflush_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img18
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
_biocache_L110
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
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
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_fpr1+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr1
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ltu
                CMP     #0
                BNE     *+5
                BRL     _biocache_L112
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
_biocache_L113
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L116
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L116
                LDA     #0
                BRA     _biocache_L117
_biocache_L116
                LDA     #1
_biocache_L117
                CMP     #0
                BEQ     _biocache_L115
                LDA     [_fcc_img16]
                TAX
                AND     #512
                CMP     #0
                BNE     _biocache_L118
                BRA     _biocache_L114
_biocache_L118
                LDA     _fcc_img18
                TAX
                CMP     #65535
                BEQ     _biocache_L119
                LDY     #22
                LDA     [_fcc_img16],Y
                TAX
                LDA     _fcc_img18
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _biocache_L119
                BRA     _biocache_L114
_biocache_L119
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _biocache_bremfree
                PLY
                PLY
                LDA     [_fcc_img16]
                TAX
                ORA     #8
                STA     [_fcc_img16]
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL bwrite
                PLY
                PLY
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRL     bflush_uL_loop
_biocache_L114
                LDY     #10
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                BRL     _biocache_L113
_biocache_L115
_biocache_L111
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     5,S   ; fccstk d=0 b=5
                CLC
                ADC     #50
                STA     5,S   ; fccstk d=0 b=5
                BRL     _biocache_L110
_biocache_L112
                TAY
                TSC
                CLC
                ADC     #bflush_FRAMESIZE-6
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
bflush_FRAMESIZE   EQU     14
bflush_STKGUARD    EQU     0
                FGX2_EXPORT vinvalbuf
vinvalbuf            ENT
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
                SBC     #vinvalbuf_FRAMESIZE-16
                DO      vinvalbuf_STKGUARD
                BCC     vinvalbuf_stkovf
                CMP     _fcc_stkfloor
                BCS     vinvalbuf_stkok
vinvalbuf_stkovf       JMP     _fcc_stkoflow
                FIN
vinvalbuf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                STA     _fcc_img18
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
                STA     _fcc_img19
                LDA     #0
                STA     13,S   ; fccstk d=0 b=13
_biocache_L120
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDY     #46
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img21
                LDA     _fcc_fpr0
                STA     _fcc_img20
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _biocache_L123
                BRA     _biocache_L124
_biocache_L123
                LDY     #42
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img21
                LDA     _fcc_fpr0
                STA     _fcc_img20
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _biocache_L125
                BRA     _biocache_L126
_biocache_L125
                BRL     _biocache_L122
_biocache_L126
_biocache_L124
                LDA     _fcc_img21
                STA     _fcc_fpr0+2
                LDA     _fcc_img20
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
_biocache_L127
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
                BRL     _biocache_L129
                LDY     #42
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img23
                LDA     _fcc_fpr0
                STA     _fcc_img22
                LDA     [_fcc_img16]
                TAX
                AND     #8
                CMP     #0
                BEQ     _biocache_L130
                LDA     [_fcc_img16]
                TAX
                ORA     #64
                STA     [_fcc_img16]
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL kc_sleep
                PLY
                PLY
                BRL     _biocache_L129
_biocache_L130
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _biocache_bremfree
                PLY
                PLY
                LDA     [_fcc_img16]
                TAX
                ORA     #8
                STA     [_fcc_img16]
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
                BEQ     _biocache_L131
                LDA     [_fcc_img16]
                TAX
                AND     #512
                BEQ     _biocache_L131
                LDA     13,S   ; fccstk d=0 b=13
                CLC
                ADC     #1
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL bwrite
                PLY
                PLY
                BRA     _biocache_L129
_biocache_L131
                LDY     #38
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img19
                STA     _fcc_fpr1+2
                LDA     _fcc_img18
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L133
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L133
                LDA     #0
                BRA     _biocache_L134
_biocache_L133
                LDA     #1
_biocache_L134
                CMP     #0
                BEQ     _biocache_L132
                LDY     #38
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL reassignbuf
                PLY
                PLY
                PLY
                PLY
                BRA     _biocache_L135
_biocache_L132
                LDA     [_fcc_img16]
                TAX
                ORA     #2048
                STA     [_fcc_img16]
_biocache_L135
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL brelse
                PLY
                PLY
_biocache_L128
                LDA     _fcc_img23
                STA     _fcc_fpr0+2
                LDA     _fcc_img22
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                BRL     _biocache_L127
_biocache_L129
_biocache_L121
                BRL     _biocache_L120
_biocache_L122
                LDY     #46
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     _biocache_L137
                LDY     #42
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _biocache_L136
_biocache_L137
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_biocache_S6
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kc_panic
                PLY
                PLY
_biocache_L136
                LDA     13,S   ; fccstk d=0 b=13
                TAY
                TSC
                CLC
                ADC     #vinvalbuf_FRAMESIZE-16
                TCS
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
vinvalbuf_FRAMESIZE   EQU     30
vinvalbuf_STKGUARD    EQU     0
                FGX2_EXPORT _biocache_flistlen
_biocache_flistlen            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_biocache_flistlen_FRAMESIZE
                DO      _biocache_flistlen_STKGUARD
                BCC     _biocache_flistlen_stkovf
                CMP     _fcc_stkfloor
                BCS     _biocache_flistlen_stkok
_biocache_flistlen_stkovf       JMP     _fcc_stkoflow
                FIN
_biocache_flistlen_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
                DO      6+_biocache_flistlen_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_biocache_flistlen_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_biocache_flistlen_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
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
                STA     _fcc_img4
                LDA     _fcc_fpr0
                STA     _fcc_img3
                LDY     #10
                LDA     [_fcc_img3],Y
                PHA
                INY
                INY
                LDA     [_fcc_img3],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img4
                STA     _fcc_fpr1+2
                LDA     _fcc_img3
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L139
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L139
                LDA     #0
                BRA     _biocache_L140
_biocache_L139
                LDA     #1
_biocache_L140
                CMP     #0
                BEQ     _biocache_L138
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_biocache_flistlen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_L138
                LDY     #10
                LDA     [_fcc_img3],Y
                PHA
                INY
                INY
                LDA     [_fcc_img3],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
_biocache_L141
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr0
                LDA     _fcc_img4
                STA     _fcc_fpr1+2
                LDA     _fcc_img3
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L144
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L144
                LDA     #0
                BRA     _biocache_L145
_biocache_L144
                LDA     #1
_biocache_L145
                CMP     #0
                BNE     *+5
                BRL     _biocache_L143
                LDY     #10
                LDA     [_fcc_img1],Y
                PHA
                INY
                INY
                LDA     [_fcc_img1],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img2
                STA     _fcc_fpr1+2
                LDA     _fcc_img1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L147
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L147
                LDA     #0
                BRA     _biocache_L148
_biocache_L147
                LDA     #1
_biocache_L148
                CMP     #0
                BEQ     _biocache_L146
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_biocache_flistlen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_L146
                LDA     _fcc_img0
                INC
                STA     _fcc_img0
                PHA
                LDA     #16
                CLC
                ADC     #4
                STA     _fcc_tmp_b
                PLA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _biocache_L150
                EOR     #$8000
_biocache_L150
                BPL     _biocache_L149
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_biocache_flistlen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_L149
_biocache_L142
                LDY     #10
                LDA     [_fcc_img1],Y
                PHA
                INY
                INY
                LDA     [_fcc_img1],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                BRL     _biocache_L141
_biocache_L143
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #_biocache_flistlen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_flistlen_FRAMESIZE   EQU     10
_biocache_flistlen_STKGUARD    EQU     0
                FGX2_EXPORT _biocache_hashlen
_biocache_hashlen            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_biocache_hashlen_FRAMESIZE
                DO      _biocache_hashlen_STKGUARD
                BCC     _biocache_hashlen_stkovf
                CMP     _fcc_stkfloor
                BCS     _biocache_hashlen_stkok
_biocache_hashlen_stkovf       JMP     _fcc_stkoflow
                FIN
_biocache_hashlen_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
                DO      6+_biocache_hashlen_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_biocache_hashlen_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_biocache_hashlen_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
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
                STA     _fcc_img4
                LDA     _fcc_fpr0
                STA     _fcc_img3
                LDY     #2
                LDA     [_fcc_img3],Y
                PHA
                INY
                INY
                LDA     [_fcc_img3],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img4
                STA     _fcc_fpr1+2
                LDA     _fcc_img3
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L152
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L152
                LDA     #0
                BRA     _biocache_L153
_biocache_L152
                LDA     #1
_biocache_L153
                CMP     #0
                BEQ     _biocache_L151
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_biocache_hashlen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_L151
                LDY     #2
                LDA     [_fcc_img3],Y
                PHA
                INY
                INY
                LDA     [_fcc_img3],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
_biocache_L154
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr0
                LDA     _fcc_img4
                STA     _fcc_fpr1+2
                LDA     _fcc_img3
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L157
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L157
                LDA     #0
                BRA     _biocache_L158
_biocache_L157
                LDA     #1
_biocache_L158
                CMP     #0
                BNE     *+5
                BRL     _biocache_L156
                LDY     #2
                LDA     [_fcc_img1],Y
                PHA
                INY
                INY
                LDA     [_fcc_img1],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img2
                STA     _fcc_fpr1+2
                LDA     _fcc_img1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L160
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L160
                LDA     #0
                BRA     _biocache_L161
_biocache_L160
                LDA     #1
_biocache_L161
                CMP     #0
                BEQ     _biocache_L159
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_biocache_hashlen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_L159
                LDA     _fcc_img0
                INC
                STA     _fcc_img0
                PHA
                LDA     #16
                CLC
                ADC     #4
                STA     _fcc_tmp_b
                PLA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _biocache_L163
                EOR     #$8000
_biocache_L163
                BPL     _biocache_L162
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_biocache_hashlen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_L162
_biocache_L155
                LDY     #2
                LDA     [_fcc_img1],Y
                PHA
                INY
                INY
                LDA     [_fcc_img1],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                BRL     _biocache_L154
_biocache_L156
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #_biocache_hashlen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_hashlen_FRAMESIZE   EQU     10
_biocache_hashlen_STKGUARD    EQU     0
                FGX2_EXPORT _biocache_totalfree
_biocache_totalfree            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_biocache_totalfree_FRAMESIZE
                DO      _biocache_totalfree_STKGUARD
                BCC     _biocache_totalfree_stkovf
                CMP     _fcc_stkfloor
                BCS     _biocache_totalfree_stkok
_biocache_totalfree_stkovf       JMP     _fcc_stkoflow
                FIN
_biocache_totalfree_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                PHA
                FGX2_FARCALL _biocache_flistlen
                PLY
                PHA
                LDA     #1
                PHA
                FGX2_FARCALL _biocache_flistlen
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #2
                PHA
                FGX2_FARCALL _biocache_flistlen
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #_biocache_totalfree_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_totalfree_FRAMESIZE   EQU     0
_biocache_totalfree_STKGUARD    EQU     0
                FGX2_EXPORT _biocache_blklen
_biocache_blklen            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_biocache_blklen_FRAMESIZE
                DO      _biocache_blklen_STKGUARD
                BCC     _biocache_blklen_stkovf
                CMP     _fcc_stkfloor
                BCS     _biocache_blklen_stkok
_biocache_blklen_stkovf       JMP     _fcc_stkoflow
                FIN
_biocache_blklen_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
                DO      6+_biocache_blklen_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_biocache_blklen_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_biocache_blklen_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+_biocache_blklen_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_biocache_blklen_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_biocache_blklen_FRAMESIZE,S   ; fccstk d=0 b=8 fs
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
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
_biocache_L164
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _biocache_L166
                LDY     #46
                LDA     [_fcc_img1],Y
                PHA
                INY
                INY
                LDA     [_fcc_img1],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L168
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L168
                LDA     #1
                BRA     _biocache_L169
_biocache_L168
                LDA     #0
_biocache_L169
                CMP     #0
                BEQ     _biocache_L167
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_biocache_blklen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_L167
                LDY     #46
                LDA     [_fcc_img1],Y
                PHA
                INY
                INY
                LDA     [_fcc_img1],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img2
                STA     _fcc_fpr1+2
                LDA     _fcc_img1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L171
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L171
                LDA     #0
                BRA     _biocache_L172
_biocache_L171
                LDA     #1
_biocache_L172
                CMP     #0
                BEQ     _biocache_L170
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_biocache_blklen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_L170
                LDA     _fcc_img0
                INC
                STA     _fcc_img0
                PHA
                LDA     #16
                CLC
                ADC     #4
                STA     _fcc_tmp_b
                PLA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _biocache_L174
                EOR     #$8000
_biocache_L174
                BPL     _biocache_L173
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_biocache_blklen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_L173
_biocache_L165
                LDY     #42
                LDA     [_fcc_img1],Y
                PHA
                INY
                INY
                LDA     [_fcc_img1],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                BRL     _biocache_L164
_biocache_L166
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #_biocache_blklen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_blklen_FRAMESIZE   EQU     6
_biocache_blklen_STKGUARD    EQU     0
                FGX2_EXPORT _biocache_vnreset
_biocache_vnreset            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_biocache_vnreset_FRAMESIZE
                DO      _biocache_vnreset_STKGUARD
                BCC     _biocache_vnreset_stkovf
                CMP     _fcc_stkfloor
                BCS     _biocache_vnreset_stkok
_biocache_vnreset_stkovf       JMP     _fcc_stkoflow
                FIN
_biocache_vnreset_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
_biocache_L175
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #3
                BVC     _biocache_L178
                EOR     #$8000
_biocache_L178
                BMI     *+5
                BRL     _biocache_L177
                LDA     _fcc_img0
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
                LDA     _fcc_img0
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #fakeops
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
                LDA     _fcc_img0
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #0
                STA     [_fcc_fpr0]
                LDA     _fcc_img0
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #0
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_img0
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #0
                LDY     #50
                STA     [_fcc_fpr0],Y
                LDA     _fcc_img0
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
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
                LDA     _fcc_img0
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
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
_biocache_L176
                INC     _fcc_img0
                BRL     _biocache_L175
_biocache_L177
                TAY
                TSC
                CLC
                ADC     #_biocache_vnreset_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_biocache_vnreset_FRAMESIZE   EQU     2
_biocache_vnreset_STKGUARD    EQU     0
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
                LDA     #0
                STA     _fcc_img16
_biocache_L179
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #3
                BVC     _biocache_L182
                EOR     #$8000
_biocache_L182
                BMI     *+5
                BRL     _biocache_L181
                LDA     _fcc_img16
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #1
                LDY     #52
                STA     [_fcc_fpr0],Y
                LDA     _fcc_img16
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #fakeops
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
                LDA     _fcc_img16
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #0
                LDY     #4
                STA     [_fcc_fpr0],Y
_biocache_L180
                INC     _fcc_img16
                BRL     _biocache_L179
_biocache_L181
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
                PLY
                PLY
                FGX2_FARCALL _biocache_totalfree
                TAX
                CMP     #16
                BEQ     _biocache_L183
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L183
                LDA     #2
                PHA
                FGX2_FARCALL _biocache_flistlen
                PLY
                TAX
                CMP     #16
                BEQ     _biocache_L184
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L184
                LDA     #0
                STA     _fcc_img16
_biocache_L185
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #16
                BVC     _biocache_L188
                EOR     #$8000
_biocache_L188
                BPL     _biocache_L187
                LDA     _fcc_img16
                PHA
                FGX2_FARCALL _biocache_hashlen
                PLY
                CMP     #0
                BEQ     _biocache_L189
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L189
_biocache_L186
                INC     _fcc_img16
                BRA     _biocache_L185
_biocache_L187
                LDA     #0
                STA     _fcc_img16
_biocache_L190
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #16
                BVC     _biocache_L193
                EOR     #$8000
_biocache_L193
                BMI     *+5
                BRL     _biocache_L192
                LDA     _fcc_img16
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
                LDY     #24
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img16
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
                ADC     #fixarena
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
                BNE     _biocache_L195
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L195
                LDA     #0
                BRA     _biocache_L196
_biocache_L195
                LDA     #1
_biocache_L196
                CMP     #0
                BEQ     _biocache_L194
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L194
                LDA     _fcc_img16
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
                LDA     [_fcc_fpr0]
                TAX
                AND     #2048
                CMP     #0
                BNE     _biocache_L197
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L197
_biocache_L191
                INC     _fcc_img16
                BRL     _biocache_L190
_biocache_L192
                LDA     #100
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L199
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L199
                LDA     #1
                BRA     _biocache_L200
_biocache_L199
                LDA     #0
_biocache_L200
                CMP     #0
                BEQ     _biocache_L198
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L198
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #8
                BNE     _biocache_L201
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L201
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #38
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
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
                LDA     #vn
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L203
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L203
                LDA     #0
                BRA     _biocache_L204
_biocache_L203
                LDA     #1
_biocache_L204
                CMP     #0
                BEQ     _biocache_L202
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L202
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #30
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #28
                LDA     [_fcc_fpr0],Y
                LDX     #100
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _biocache_L205
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L205
                FGX2_FARCALL _biocache_totalfree
                PHA
                LDA     #16
                TAX
                DEC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biocache_L206
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L206
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #4
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #1
                BEQ     _biocache_L207
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L207
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #2048
                CMP     #0
                BEQ     _biocache_L208
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L208
                LDA     #100
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL incore
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BNE     _biocache_L209
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L209
                LDA     #101
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL incore
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BEQ     _biocache_L210
                LDA     #14
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L210
                LDA     #100
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+164
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL incore
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BEQ     _biocache_L211
                LDA     #15
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L211
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #8
                BEQ     _biocache_L212
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L212
                FGX2_FARCALL _biocache_totalfree
                TAX
                CMP     #16
                BEQ     _biocache_L213
                LDA     #17
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L213
                LDA     #100
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
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
                BNE     _biocache_L215
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L215
                LDA     #0
                BRA     _biocache_L216
_biocache_L215
                LDA     #1
_biocache_L216
                CMP     #0
                BEQ     _biocache_L214
                LDA     #18
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L214
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #4
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #1
                BEQ     _biocache_L217
                LDA     #19
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L217
                LDA     #101
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
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
                BNE     _biocache_L219
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L219
                LDA     #1
                BRA     _biocache_L220
_biocache_L219
                LDA     #0
_biocache_L220
                CMP     #0
                BEQ     _biocache_L218
                LDA     #20
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L218
                FGX2_FARCALL _biocache_totalfree
                PHA
                LDA     #16
                TAX
                DEC
                DEC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biocache_L221
                LDA     #21
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L221
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                LDA     #$FFFF
                STA     _fcc_img17
                LDA     #0
                STA     _fcc_img16
_biocache_L222
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                LDA     #16
                ASL
                ASL
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _biocache_L225
                EOR     #$8000
_biocache_L225
                BPL     _biocache_L224
                LDA     _fcc_img16
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+164
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_bufhashof
                PLY
                PLY
                PLY
                PLY
                PHA
                LDA     #7
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_bufhashof
                PLY
                PLY
                PLY
                PLY
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _biocache_L226
                LDA     _fcc_img16
                STA     _fcc_img17
                BRA     _biocache_L224
_biocache_L226
_biocache_L223
                INC     _fcc_img16
                BRL     _biocache_L222
_biocache_L224
                LDA     _fcc_img17
                CMP     #0
                BPL     _biocache_L227
                LDA     #38
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L227
                LDA     #7
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_img17
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+164
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
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
                BNE     _biocache_L229
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L229
                LDA     #1
                BRA     _biocache_L230
_biocache_L229
                LDA     #0
_biocache_L230
                CMP     #0
                BEQ     _biocache_L228
                LDA     #22
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L228
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #38
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1
                LDY     #38
                LDA     [_fcc_fpr1],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                PLA
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L232
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L232
                LDA     #1
                BRA     _biocache_L233
_biocache_L232
                LDA     #0
_biocache_L233
                CMP     #0
                BEQ     _biocache_L231
                LDA     #23
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L231
                LDA     #7
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL incore
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BNE     _biocache_L234
                LDA     #24
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L234
                LDA     _fcc_img17
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+164
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL incore
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BNE     _biocache_L235
                LDA     #25
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L235
                LDA     #7
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+164
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL incore
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BEQ     _biocache_L236
                LDA     _fcc_img17
                TAX
                CMP     #7
                BEQ     _biocache_L236
                LDA     #39
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L236
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                LDA     #55
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+328
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #2
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #4
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #1
                BEQ     _biocache_L237
                LDA     #26
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L237
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #2048
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                LDA     #55
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+328
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL incore
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BEQ     _biocache_L238
                LDA     #27
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L238
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #38
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L240
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L240
                LDA     #0
                BRA     _biocache_L241
_biocache_L240
                LDA     #1
_biocache_L241
                CMP     #0
                BEQ     _biocache_L239
                LDA     #28
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L239
                LDA     #2
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #4
                LDA     [_fcc_fpr0],Y
                BEQ     _biocache_L242
                LDA     #29
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L242
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
                LDY     #10
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L244
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L244
                LDA     #0
                BRA     _biocache_L245
_biocache_L244
                LDA     #1
_biocache_L245
                CMP     #0
                BEQ     _biocache_L243
                LDA     #30
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L243
                LDA     #0
                STA     _fcc_img16
_biocache_L246
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #16
                BVC     _biocache_L249
                EOR     #$8000
_biocache_L249
                BPL     _biocache_L248
                LDA     #200
                CLC
                ADC     _fcc_img16
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L251
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L251
                LDA     #1
                BRA     _biocache_L252
_biocache_L251
                LDA     #0
_biocache_L252
                CMP     #0
                BEQ     _biocache_L250
                LDA     #31
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L250
_biocache_L247
                INC     _fcc_img16
                BRA     _biocache_L246
_biocache_L248
                FGX2_FARCALL _biocache_totalfree
                CMP     #0
                BEQ     _biocache_L253
                LDA     #32
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L253
                LDA     _biocache_stub_slept
                CMP     #0
                BEQ     _biocache_L254
                LDA     #33
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L254
                LDA     #0
                STA     _fcc_img17
                LDA     #0
                STA     _fcc_img16
_biocache_L255
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #16
                BVC     _biocache_L258
                EOR     #$8000
_biocache_L258
                BPL     _biocache_L257
                LDA     _fcc_img16
                PHA
                FGX2_FARCALL _biocache_hashlen
                PLY
                CMP     #$FFFF
                BNE     _biocache_L259
                LDA     #40
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L259
                LDA     _fcc_img17
                PHA
                LDA     _fcc_img16
                PHA
                FGX2_FARCALL _biocache_hashlen
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img17
_biocache_L256
                INC     _fcc_img16
                BRA     _biocache_L255
_biocache_L257
                LDA     _fcc_img17
                TAX
                CMP     #16
                BEQ     _biocache_L260
                LDA     #34
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L260
                LDA     #0
                STA     _fcc_img16
_biocache_L261
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #16
                BVC     _biocache_L264
                EOR     #$8000
_biocache_L264
                BPL     _biocache_L263
                LDA     _fcc_img16
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
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
_biocache_L262
                INC     _fcc_img16
                BRA     _biocache_L261
_biocache_L263
                FGX2_FARCALL _biocache_totalfree
                TAX
                CMP     #16
                BEQ     _biocache_L265
                LDA     #35
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L265
                LDA     _biocache_stub_slept
                BEQ     _biocache_L266
                LDA     #36
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L266
                LDA     _biocache_stub_panic
                CMP     #0
                BEQ     _biocache_L267
                LDA     #37
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L267
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
                PLY
                PLY
                LDA     #0
                STA     _fcc_img16
_biocache_L268
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #64
                BVC     _biocache_L271
                EOR     #$8000
_biocache_L271
                BPL     _biocache_L270
                LDA     #_biocache_fake_disk
                PHA
                LDA     _fcc_img16
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     _fcc_img16
                CLC
                ADC     #1
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
_biocache_L269
                INC     _fcc_img16
                BRA     _biocache_L268
_biocache_L270
                LDA     #0
                STA     _biocache_fake_reads
                LDA     #0
                STA     _biocache_fake_writes
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
                LDA     #5
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BEQ     _biocache_L272
                LDA     #45
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L272
                LDA     _biocache_fake_reads
                TAX
                CMP     #1
                BEQ     _biocache_L273
                LDA     #46
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L273
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #24
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                PHA
                LDA     #6
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biocache_L274
                LDA     #47
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L274
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #2
                BNE     _biocache_L275
                LDA     #48
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L275
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
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
                LDA     #5
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BEQ     _biocache_L276
                LDA     #49
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L276
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
                BNE     _biocache_L278
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L278
                LDA     #0
                BRA     _biocache_L279
_biocache_L278
                LDA     #1
_biocache_L279
                CMP     #0
                BEQ     _biocache_L277
                LDA     #50
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L277
                LDA     _biocache_fake_reads
                TAX
                CMP     #1
                BEQ     _biocache_L280
                LDA     #51
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L280
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
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
                LDA     #6
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BEQ     _biocache_L281
                LDA     #52
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L281
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #24
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #99
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bwrite
                PLY
                PLY
                CMP     #0
                BEQ     _biocache_L282
                LDA     #53
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L282
                LDA     _biocache_fake_writes
                TAX
                CMP     #1
                BEQ     _biocache_L283
                LDA     #54
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L283
                LDA     #6
                TAX
                LDA:    _biocache_fake_disk,X
                AND     #$00FF
                PHA
                LDA     #99
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biocache_L284
                LDA     #55
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L284
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #8
                BEQ     _biocache_L285
                LDA     #56
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L285
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
                LDA     #7
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BEQ     _biocache_L286
                LDA     #57
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L286
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #24
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #77
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bdwrite
                PLY
                PLY
                LDA     _biocache_fake_writes
                TAX
                CMP     #1
                BEQ     _biocache_L287
                LDA     #58
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L287
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #512
                BNE     _biocache_L288
                LDA     #59
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L288
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
                LDA     #7
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BEQ     _biocache_L289
                LDA     #61
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L289
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
                BNE     _biocache_L291
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L291
                LDA     #0
                BRA     _biocache_L292
_biocache_L291
                LDA     #1
_biocache_L292
                CMP     #0
                BEQ     _biocache_L290
                LDA     #62
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L290
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #24
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                PHA
                LDA     #77
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biocache_L293
                LDA     #63
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L293
                LDA     #7
                TAX
                LDA:    _biocache_fake_disk,X
                AND     #$00FF
                PHA
                LDA     #8
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biocache_L294
                LDA     #64
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L294
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                LDA     #0
                STA     _fcc_img16
_biocache_L295
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #16
                BVC     _biocache_L298
                EOR     #$8000
_biocache_L298
                BPL     _biocache_L297
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
                LDA     #20
                CLC
                ADC     _fcc_img16
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+164
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BNE     _biocache_L299
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
_biocache_L299
_biocache_L296
                INC     _fcc_img16
                BRA     _biocache_L295
_biocache_L297
                LDA     _biocache_fake_writes
                TAX
                CMP     #2
                BEQ     _biocache_L300
                LDA     #65
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L300
                LDA     #7
                TAX
                LDA:    _biocache_fake_disk,X
                AND     #$00FF
                PHA
                LDA     #77
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biocache_L301
                LDA     #66
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L301
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
                PLY
                PLY
                LDA     #0
                STA     _biocache_fake_writes
                LDA     #_biocache_fake_disk
                PHA
                LDA     #9
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #9
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
                LDA     #9
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+328
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BEQ     _biocache_L302
                LDA     #67
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L302
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #24
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #55
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bdwrite
                PLY
                PLY
                LDA     #9
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+328
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #2048
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                AND     #512
                CMP     #0
                BEQ     _biocache_L303
                LDA     #68
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L303
                LDA     #0
                STA     _fcc_img16
_biocache_L304
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #16
                BVC     _biocache_L307
                EOR     #$8000
_biocache_L307
                BPL     _biocache_L306
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
                LDA     #30
                CLC
                ADC     _fcc_img16
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+164
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BNE     _biocache_L308
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
_biocache_L308
_biocache_L305
                INC     _fcc_img16
                BRA     _biocache_L304
_biocache_L306
                LDA     _biocache_fake_writes
                BEQ     _biocache_L309
                LDA     #69
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L309
                LDA     #9
                TAX
                LDA:    _biocache_fake_disk,X
                AND     #$00FF
                PHA
                LDA     #9
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biocache_L310
                LDA     #70
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L310
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
                PLY
                PLY
                LDA     #11
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #4660
                LDY     #22
                STA     [_fcc_fpr0],Y
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #2048
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                LDA     #12
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+164
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
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
                BNE     _biocache_L312
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L312
                LDA     #0
                BRA     _biocache_L313
_biocache_L312
                LDA     #1
_biocache_L313
                CMP     #0
                BEQ     _biocache_L311
                LDA     #73
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L311
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #22
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #65535
                BEQ     _biocache_L314
                LDA     #74
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L314
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
                PLY
                PLY
                FGX2_FARCALL _biocache_vnreset
                LDA     #0
                STA     _biocache_fake_reads
                LDA     #0
                STA     _biocache_fake_writes
                LDA     #1
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+42
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                TAX
                CMP     #1
                BEQ     _biocache_L315
                LDA     #75
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L315
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+46
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                CMP     #0
                BEQ     _biocache_L316
                LDA     #76
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L316
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #42
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L318
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L318
                LDA     #0
                BRA     _biocache_L319
_biocache_L318
                LDA     #1
_biocache_L319
                CMP     #0
                BEQ     _biocache_L317
                LDA     #77
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L317
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #46
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
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
                LDA     #vn+42
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L321
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L321
                LDA     #0
                BRA     _biocache_L322
_biocache_L321
                LDA     #1
_biocache_L322
                CMP     #0
                BEQ     _biocache_L320
                LDA     #78
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L320
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+42
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                TAX
                CMP     #1
                BEQ     _biocache_L323
                LDA     #79
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L323
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #38
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
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
                LDA     #vn
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L325
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L325
                LDA     #0
                BRA     _biocache_L326
_biocache_L325
                LDA     #1
_biocache_L326
                CMP     #0
                BEQ     _biocache_L324
                LDA     #80
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L324
                LDA     #2
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+164
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+42
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                TAX
                CMP     #1
                BEQ     _biocache_L327
                LDA     #81
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L327
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+206
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                TAX
                CMP     #1
                BEQ     _biocache_L328
                LDA     #82
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L328
                LDA     #1
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #24
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #90
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bdwrite
                PLY
                PLY
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+42
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                CMP     #0
                BEQ     _biocache_L329
                LDA     #83
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L329
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+46
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                TAX
                CMP     #1
                BEQ     _biocache_L330
                LDA     #84
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L330
                LDA     _biocache_fake_writes
                CMP     #0
                BEQ     _biocache_L331
                LDA     #85
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L331
                LDA     #1
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bdwrite
                PLY
                PLY
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+46
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                TAX
                CMP     #1
                BEQ     _biocache_L332
                LDA     #86
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L332
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+42
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                CMP     #0
                BEQ     _biocache_L333
                LDA     #87
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L333
                LDA     #1
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bwrite
                PLY
                PLY
                CMP     #0
                BEQ     _biocache_L334
                LDA     #88
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L334
                LDA     _biocache_fake_writes
                TAX
                CMP     #1
                BEQ     _biocache_L335
                LDA     #89
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L335
                LDA     #1
                TAX
                LDA:    _biocache_fake_disk,X
                AND     #$00FF
                PHA
                LDA     #90
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biocache_L336
                LDA     #90
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L336
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+46
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                CMP     #0
                BEQ     _biocache_L337
                LDA     #91
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L337
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+42
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                TAX
                CMP     #1
                BEQ     _biocache_L338
                LDA     #92
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L338
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #50
                LDA     [_fcc_fpr0],Y
                CMP     #0
                BEQ     _biocache_L339
                LDA     #93
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L339
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
                PLY
                PLY
                FGX2_FARCALL _biocache_vnreset
                LDA     #3
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                LDA     #4
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                LDA     #5
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+42
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                TAX
                CMP     #3
                BEQ     _biocache_L340
                LDA     #94
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L340
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #42
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr1+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L342
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L342
                LDA     #0
                BRA     _biocache_L343
_biocache_L342
                LDA     #1
_biocache_L343
                CMP     #0
                BEQ     _biocache_L341
                LDA     #95
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L341
                LDA     #4
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #2048
                STA     [_fcc_fpr0]
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+42
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                TAX
                CMP     #2
                BEQ     _biocache_L344
                LDA     #96
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L344
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #42
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr1+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L346
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L346
                LDA     #0
                BRA     _biocache_L347
_biocache_L346
                LDA     #1
_biocache_L347
                CMP     #0
                BEQ     _biocache_L345
                LDA     #97
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L345
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #38
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L349
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L349
                LDA     #0
                BRA     _biocache_L350
_biocache_L349
                LDA     #1
_biocache_L350
                CMP     #0
                BEQ     _biocache_L348
                LDA     #98
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L348
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #46
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _biocache_L352
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _biocache_L352
                LDA     #0
                BRA     _biocache_L353
_biocache_L352
                LDA     #1
_biocache_L353
                CMP     #0
                BEQ     _biocache_L351
                LDA     #99
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L351
                LDA     #3
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL incore
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BNE     _biocache_L354
                LDA     #100
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L354
                LDA     #5
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL incore
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BNE     _biocache_L355
                LDA     #101
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L355
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
                PLY
                PLY
                FGX2_FARCALL _biocache_vnreset
                LDA     #0
                STA     _biocache_fake_writes
                LDA     #6
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #24
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #17
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bdwrite
                PLY
                PLY
                LDA     #7
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #24
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
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
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bdwrite
                PLY
                PLY
                LDA     #8
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+164
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDY     #24
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #51
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bdwrite
                PLY
                PLY
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+46
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                TAX
                CMP     #2
                BEQ     _biocache_L356
                LDA     #102
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L356
                LDA     #2
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vflushbuf
                PLY
                PLY
                PLY
                LDA     _biocache_fake_writes
                TAX
                CMP     #2
                BEQ     _biocache_L357
                LDA     #103
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L357
                LDA     #6
                TAX
                LDA:    _biocache_fake_disk,X
                AND     #$00FF
                PHA
                LDA     #17
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biocache_L358
                LDA     #104
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L358
                LDA     #7
                TAX
                LDA:    _biocache_fake_disk,X
                AND     #$00FF
                PHA
                LDA     #34
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biocache_L359
                LDA     #105
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L359
                LDA     #8
                TAX
                LDA:    _biocache_fake_disk,X
                AND     #$00FF
                PHA
                LDA     #51
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _biocache_L360
                LDA     #106
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L360
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+46
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                CMP     #0
                BEQ     _biocache_L361
                LDA     #107
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L361
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+42
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                TAX
                CMP     #2
                BEQ     _biocache_L362
                LDA     #108
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L362
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+210
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                TAX
                CMP     #1
                BEQ     _biocache_L363
                LDA     #109
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L363
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #50
                LDA     [_fcc_fpr0],Y
                CMP     #0
                BEQ     _biocache_L364
                LDA     #110
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L364
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
                PLY
                PLY
                FGX2_FARCALL _biocache_vnreset
                LDA     #0
                STA     _biocache_fake_writes
                LDA     #9
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #24
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #68
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bdwrite
                PLY
                PLY
                LDA     #10
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                LDA     #1
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vinvalbuf
                PLY
                PLY
                PLY
                STA     _fcc_img17
                TAX
                CMP     #1
                BEQ     _biocache_L365
                LDA     #111
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L365
                LDA     _biocache_fake_writes
                TAX
                CMP     #1
                BEQ     _biocache_L366
                LDA     #112
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L366
                LDA     #9
                TAX
                LDA:    _biocache_fake_disk,X
                AND     #$00FF
                PHA
                LDA     #68
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biocache_L367
                LDA     #113
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L367
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+46
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                CMP     #0
                BEQ     _biocache_L368
                LDA     #114
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L368
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+42
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                CMP     #0
                BEQ     _biocache_L369
                LDA     #115
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L369
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
                ADC     #vn
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #4
                LDA     [_fcc_fpr0],Y
                BEQ     _biocache_L370
                LDA     #116
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L370
                FGX2_FARCALL _biocache_totalfree
                TAX
                CMP     #16
                BEQ     _biocache_L371
                LDA     #117
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L371
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
                PLY
                PLY
                FGX2_FARCALL _biocache_vnreset
                LDA     #_biocache_fake_disk
                PHA
                LDA     #11
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
                LDA     #0
                STA     _biocache_fake_reads
                LDA     #0
                STA     _biocache_fake_writes
                LDA     #11
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getblk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #24
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
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
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bdwrite
                PLY
                PLY
                LDA     #0
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL vinvalbuf
                PLY
                PLY
                PLY
                STA     _fcc_img17
                CMP     #0
                BEQ     _biocache_L372
                LDA     #118
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L372
                LDA     _biocache_fake_writes
                BEQ     _biocache_L373
                LDA     #119
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L373
                LDA     #11
                TAX
                LDA:    _biocache_fake_disk,X
                AND     #$00FF
                PHA
                LDA     #119
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biocache_L374
                LDA     #120
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L374
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+42
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                CMP     #0
                BEQ     _biocache_L375
                LDA     #121
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L375
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn+46
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _biocache_blklen
                PLY
                PLY
                CMP     #0
                BEQ     _biocache_L376
                LDA     #122
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L376
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
                LDA     #11
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vn
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BEQ     _biocache_L377
                LDA     #123
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L377
                LDA     _biocache_fake_reads
                TAX
                CMP     #1
                BEQ     _biocache_L378
                LDA     #124
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_biocache_L378
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDY     #24
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                PHA
                LDA     #119
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biocache_L379
                LDA     #125
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_biocache_L379
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                PLY
                PLY
                LDA     _biocache_stub_slept
                BEQ     _biocache_L380
                LDA     #71
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_biocache_L380
                LDA     _biocache_stub_panic
                BEQ     _biocache_L381
                LDA     #72
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_biocache_L381
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
main_FRAMESIZE   EQU     20
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 226
