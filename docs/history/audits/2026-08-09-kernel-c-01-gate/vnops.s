                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from docs/history/audits/2026-08-09-kernel-c-01-gate/vnops.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT vop_bmap
vop_bmap            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vop_bmap_FRAMESIZE
                DO      vop_bmap_STKGUARD
                BCC     vop_bmap_stkovf
                CMP     _fcc_stkfloor
                BCS     vop_bmap_stkok
vop_bmap_stkovf       JMP     _fcc_stkoflow
                FIN
vop_bmap_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vop_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vop_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vop_bmap_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vop_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vop_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vop_bmap_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      20+vop_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+vop_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+vop_bmap_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_fpr0+2
                DO      18+vop_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+vop_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+vop_bmap_FRAMESIZE,S   ; fccstk d=4 b=14 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      20+vop_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+vop_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+vop_bmap_FRAMESIZE,S   ; fccstk d=8 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      18+vop_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+vop_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+vop_bmap_FRAMESIZE,S   ; fccstk d=8 b=10 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      20+vop_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+vop_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+vop_bmap_FRAMESIZE,S   ; fccstk d=12 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      18+vop_bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+vop_bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+vop_bmap_FRAMESIZE,S   ; fccstk d=12 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     13,S
                STA     _fcc_fpr0
                LDA     15,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vnops_L0-1
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
_vnops_L0
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #vop_bmap_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vop_bmap_FRAMESIZE   EQU     0
vop_bmap_STKGUARD    EQU     1
                FGX2_EXPORT vop_read
vop_read            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vop_read_FRAMESIZE
                DO      vop_read_STKGUARD
                BCC     vop_read_stkovf
                CMP     _fcc_stkfloor
                BCS     vop_read_stkok
vop_read_stkovf       JMP     _fcc_stkoflow
                FIN
vop_read_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+vop_read_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+vop_read_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+vop_read_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+vop_read_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vop_read_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vop_read_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      18+vop_read_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+vop_read_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+vop_read_FRAMESIZE,S   ; fccstk d=4 b=14 fs
                FIN
                PHA
                DO      18+vop_read_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+vop_read_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+vop_read_FRAMESIZE,S   ; fccstk d=6 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      16+vop_read_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+vop_read_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+vop_read_FRAMESIZE,S   ; fccstk d=6 b=10 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      18+vop_read_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+vop_read_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+vop_read_FRAMESIZE,S   ; fccstk d=10 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      16+vop_read_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+vop_read_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+vop_read_FRAMESIZE,S   ; fccstk d=10 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     11,S
                STA     _fcc_fpr0
                LDA     13,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _vnops_L1-1
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
_vnops_L1
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #vop_read_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vop_read_FRAMESIZE   EQU     0
vop_read_STKGUARD    EQU     1
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
                LDA     #256
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                CMP     #0
                BNE     *+5
                BRL     _vnops_L2
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
_vnops_L2
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
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_eq16
                CMP     #0
                BNE     *+5
                BRL     _vnops_L3
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
                BRL     _vnops_L4
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _vnops_L4
                LDA     #0
                BRL     _vnops_L5
_vnops_L4
                LDA     #1
_vnops_L5
                CMP     #0
                BNE     *+5
                BRL     _vnops_L6
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
                STA     _fcc_fpr1+2
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
                BRL     _vnops_L7
_vnops_L6
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
                STA     vfreeh
                LDA     _fcc_fpr0+2
                STA     vfreeh+2
_vnops_L7
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
                BEQ     *+5
                BRL     _vnops_L8
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _vnops_L8
                LDA     #0
                BRL     _vnops_L9
_vnops_L8
                LDA     #1
_vnops_L9
                CMP     #0
                BNE     *+5
                BRL     _vnops_L10
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
                STA     _fcc_fpr1+2
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
                LDY     #16
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #18
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                BRL     _vnops_L11
_vnops_L10
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
                STA     vfreet
                LDA     _fcc_fpr0+2
                STA     vfreet+2
_vnops_L11
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
                LDA     _fcc_fpr1+2
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
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
_vnops_L3
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
                STA     _fcc_fpr1+2
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
                STA     _fcc_fpr1
                LDY     #2
                LDA     [_fcc_fpr1],Y
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
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
                STA     _fcc_fpr1+2
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
                STA     _fcc_fpr1
                LDY     #2
                LDA     [_fcc_fpr1],Y
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                LDY     #2
                STA     [_fcc_fpr0],Y
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
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_gts16
                CMP     #0
                BNE     *+5
                BRL     _vnops_L12
                TAY
                TSC
                CLC
                ADC     #vput_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vnops_L12
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
                PEA     _vnops_L13-1
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
_vnops_L13
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
                LDA     _fcc_fpr1+2
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
                SEP     #$20
                MX      %10
                LDA     vfreet+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     vfreet
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
                SEP     #$20
                MX      %10
                LDA     vfreet+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vfreet
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _vnops_L14
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _vnops_L14
                LDA     #0
                BRL     _vnops_L15
_vnops_L14
                LDA     #1
_vnops_L15
                CMP     #0
                BNE     *+5
                BRL     _vnops_L16
                SEP     #$20
                MX      %10
                LDA     vfreet+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     vfreet
                STA     _fcc_fpr0
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
                STA     _fcc_fpr1+2
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
                BRL     _vnops_L17
_vnops_L16
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
                STA     vfreeh
                LDA     _fcc_fpr0+2
                STA     vfreeh+2
_vnops_L17
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
                STA     vfreet
                LDA     _fcc_fpr0+2
                STA     vfreet+2
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
                FGX2_RELOC_COUNT 5
