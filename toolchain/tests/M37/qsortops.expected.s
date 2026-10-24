                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from qsortops.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT icmp
icmp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #icmp_FRAMESIZE
                DO      icmp_STKGUARD
                BCC     icmp_stkovf
                CMP     _fcc_stkfloor
                BCS     icmp_stkok
icmp_stkovf       JMP     _fcc_stkoflow
                FIN
icmp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+icmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+icmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+icmp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+icmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+icmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+icmp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                DO      14+icmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+icmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+icmp_FRAMESIZE,S   ; fccstk d=2 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      12+icmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+icmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+icmp_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #icmp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
icmp_FRAMESIZE   EQU     0
icmp_STKGUARD    EQU     0
                FGX2_EXPORT rcmp
rcmp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #rcmp_FRAMESIZE
                DO      rcmp_STKGUARD
                BCC     rcmp_stkovf
                CMP     _fcc_stkfloor
                BCS     rcmp_stkok
rcmp_stkovf       JMP     _fcc_stkoflow
                FIN
rcmp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+rcmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+rcmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+rcmp_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+rcmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+rcmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+rcmp_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                DO      10+rcmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+rcmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+rcmp_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+rcmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+rcmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+rcmp_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #rcmp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
rcmp_FRAMESIZE   EQU     0
rcmp_STKGUARD    EQU     0
                FGX2_EXPORT scmp
scmp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #scmp_FRAMESIZE
                DO      scmp_STKGUARD
                BCC     scmp_stkovf
                CMP     _fcc_stkfloor
                BCS     scmp_stkok
scmp_stkovf       JMP     _fcc_stkoflow
                FIN
scmp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+scmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+scmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+scmp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+scmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+scmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+scmp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                DO      14+scmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+scmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+scmp_FRAMESIZE,S   ; fccstk d=2 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      12+scmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+scmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+scmp_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #scmp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
scmp_FRAMESIZE   EQU     0
scmp_STKGUARD    EQU     0
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
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #iv
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #9
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #iv
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #1
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #iv
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #8
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #iv
                PHA
                LDA     #3
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
                PLA
                LDA     #iv
                PHA
                LDA     #4
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #5
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #iv
                PHA
                LDA     #5
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #3
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #iv
                PHA
                LDA     #6
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #7
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                SEP     #$20
                MX      %10
                LDA     _qsortops_FA0+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _qsortops_FA0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #2
                PHA
                LDA     #7
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #iv
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL qsort
                TSC
                CLC
                ADC     #12
                TCS
                LDA     #1
                STA     5,S   ; fccstk d=0 b=5
                LDA     #1
                STA     3,S   ; fccstk d=0 b=3
                STA     _fcc_img0
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_img1
_qsortops_L1
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #7
                BVC     _qsortops_L4
                EOR     #$8000
_qsortops_L4
                BMI     *+5
                BRL     _qsortops_L3
                LDA     _fcc_img0
                TAX
                TXA
                DEC
                ASL
                TAX
                LDA:    iv,X
                PHA
                LDA     _fcc_img0
                ASL
                TAX
                LDA:    iv,X
                STA     _fcc_tmp_b
                PLA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _qsortops_L6
                EOR     #$8000
_qsortops_L6
                BMI     *+5
                BRL     _qsortops_L5
                LDA     #0
                STA     _fcc_img1
_qsortops_L5
_qsortops_L2
                INC     _fcc_img0
                BRL     _qsortops_L1
_qsortops_L3
                LDA     _fcc_img0
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_img1
                STA     5,S   ; fccstk d=0 b=5
                CMP     #0
                BNE     *+5
                BRL     _qsortops_L10
                LDA     #0
                ASL
                TAX
                LDA:    iv,X
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _qsortops_L10
                LDA     #1
                BRL     _qsortops_L11
_qsortops_L10
                LDA     #0
_qsortops_L11
                CMP     #0
                BNE     *+5
                BRL     _qsortops_L8
                LDA     #6
                ASL
                TAX
                LDA:    iv,X
                TAX
                TXA
                CMP     #9
                BEQ     *+5
                BRL     _qsortops_L8
                LDA     #1
                BRL     _qsortops_L9
_qsortops_L8
                LDA     #0
_qsortops_L9
                CMP     #0
                BNE     *+5
                BRL     _qsortops_L7
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #14
                STA     1,S   ; fccstk d=0 b=1
_qsortops_L7
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #rv
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #3
                STA     [_fcc_fpr0]
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #rv
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #30
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #rv
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #1
                STA     [_fcc_fpr0]
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #rv
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #10
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     #2
                ASL
                ASL
                CLC
                ADC     #rv
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #2
                STA     [_fcc_fpr0]
                LDA     #2
                ASL
                ASL
                CLC
                ADC     #rv
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #20
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     #3
                ASL
                ASL
                CLC
                ADC     #rv
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
                LDA     #3
                ASL
                ASL
                CLC
                ADC     #rv
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #0
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _qsortops_FA12+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _qsortops_FA12
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #4
                PHA
                LDA     #4
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #rv
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL qsort
                TSC
                CLC
                ADC     #12
                TCS
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #rv
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _qsortops_L18
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #rv
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #10
                BEQ     *+5
                BRL     _qsortops_L18
                LDA     #1
                BRL     _qsortops_L19
_qsortops_L18
                LDA     #0
_qsortops_L19
                CMP     #0
                BNE     *+5
                BRL     _qsortops_L16
                LDA     #2
                ASL
                ASL
                CLC
                ADC     #rv
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #20
                BEQ     *+5
                BRL     _qsortops_L16
                LDA     #1
                BRL     _qsortops_L17
_qsortops_L16
                LDA     #0
_qsortops_L17
                CMP     #0
                BNE     *+5
                BRL     _qsortops_L14
                LDA     #3
                ASL
                ASL
                CLC
                ADC     #rv
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #30
                BEQ     *+5
                BRL     _qsortops_L14
                LDA     #1
                BRL     _qsortops_L15
_qsortops_L14
                LDA     #0
_qsortops_L15
                CMP     #0
                BNE     *+5
                BRL     _qsortops_L13
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #14
                STA     1,S   ; fccstk d=0 b=1
_qsortops_L13
                SEP     #$20
                MX      %10
                LDA     _qsortops_FA20+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _qsortops_FA20
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #2
                PHA
                LDA     #7
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #iv
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL qsort
                TSC
                CLC
                ADC     #12
                TCS
                LDA     #0
                ASL
                TAX
                LDA:    iv,X
                TAX
                TXA
                CMP     #9
                BEQ     *+5
                BRL     _qsortops_L22
                LDA     #6
                ASL
                TAX
                LDA:    iv,X
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _qsortops_L22
                LDA     #1
                BRL     _qsortops_L23
_qsortops_L22
                LDA     #0
_qsortops_L23
                CMP     #0
                BNE     *+5
                BRL     _qsortops_L21
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #14
                STA     1,S   ; fccstk d=0 b=1
_qsortops_L21
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
