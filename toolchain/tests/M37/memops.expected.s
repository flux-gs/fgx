                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from memops.c
;---------------------------------------

                MX      %00
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
                STA     11,S   ; fccstk d=0 b=11
                LDA     #8
                PHA
                LDA     #65
                PHA
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
                FGX2_FARCALL memset
                TSC
                CLC
                ADC     #8
                TCS
                LDA     #8
                PHA
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
                LDA     #gbuf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL memcpy
                TSC
                CLC
                ADC     #10
                TCS
                LDA     #2
                PHA
                LDA     #66
                PHA
                LDA     #4
                CLC
                ADC     #gbuf
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
                FGX2_FARCALL memset
                TSC
                CLC
                ADC     #8
                TCS
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
                STA     _fcc_img0
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_img1
_memops_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #8
                BVC     _memops_L3
                EOR     #$8000
_memops_L3
                BPL     _memops_L2
                LDA     _fcc_img0
                TAX
                LDA:    gbuf,X
                AND     #$00FF
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_memops_S0
                STA     _fcc_fpr0
                LDA     _fcc_img0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _memops_L4
                LDA     _fcc_img1
                TAX
                CLC
                ADC     #5
                STA     _fcc_img1
_memops_L4
_memops_L1
                INC     _fcc_img0
                BRA     _memops_L0
_memops_L2
                LDA     _fcc_img0
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_img1
                STA     11,S   ; fccstk d=0 b=11
                LDA     #0
                PHA
                LDA     #90
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gbuf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL memset
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gbuf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _memops_L6
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _memops_L6
                LDA     #1
                BRA     _memops_L7
_memops_L6
                LDA     #0
_memops_L7
                CMP     #0
                BEQ     _memops_L5
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                CLC
                ADC     #2
                STA     11,S   ; fccstk d=0 b=11
_memops_L5
                LDA     11,S   ; fccstk d=0 b=11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
