                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from vspf.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                TSC
                SEC
                SBC     #main_FRAMESIZE-2
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
                LDA     #7
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vspf_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vspf_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fmtit
                TSC
                CLC
                ADC     #10
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_vspf_S2
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
                FGX2_FARCALL strcmp
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BNE     _vspf_L0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #20
                STA     1,S   ; fccstk d=0 b=1
_vspf_L0
                LDA     #0
                STA     _fcc_img16
_vspf_L1
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #8
                BVC     _vspf_L4
                EOR     #$8000
_vspf_L4
                BPL     _vspf_L3
                LDA     #ov
                PHA
                LDA     _fcc_img16
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #65
                CLC
                ADC     _fcc_img16
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
_vspf_L2
                INC     _fcc_img16
                BRA     _vspf_L1
_vspf_L3
                LDA     #5
                PHA
                LDA     #2
                CLC
                ADC     #ov
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ov
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bcopy
                TSC
                CLC
                ADC     #10
                TCS
                LDA     #2
                TAX
                LDA:    ov,X
                AND     #$00FF
                TAX
                CMP     #65
                BNE     _vspf_L5
                LDA     #6
                TAX
                LDA:    ov,X
                AND     #$00FF
                TAX
                CMP     #69
                BNE     _vspf_L5
                LDA     #7
                TAX
                LDA:    ov,X
                AND     #$00FF
                TAX
                CMP     #72
                BNE     _vspf_L5
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #11
                STA     1,S   ; fccstk d=0 b=1
_vspf_L5
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
                LDA     #ov
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #5
                CLC
                ADC     #ov
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
                FGX2_FARCALL bcopy
                TSC
                CLC
                ADC     #10
                TCS
                LDA     #0
                TAX
                LDA:    ov,X
                AND     #$00FF
                TAX
                CMP     #68
                BNE     _vspf_L6
                LDA     #1
                TAX
                LDA:    ov,X
                AND     #$00FF
                TAX
                CMP     #69
                BNE     _vspf_L6
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #11
                STA     1,S   ; fccstk d=0 b=1
_vspf_L6
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_EXPORT fmtit
fmtit            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #fmtit_FRAMESIZE
                DO      fmtit_STKGUARD
                BCC     fmtit_stkovf
                CMP     _fcc_stkfloor
                BCS     fmtit_stkok
fmtit_stkovf       JMP     _fcc_stkoflow
                FIN
fmtit_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #10+fmtit_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+fmtit_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+fmtit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+fmtit_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+fmtit_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+fmtit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+fmtit_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
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
                FGX2_FARCALL vsprintf
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #fmtit_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
fmtit_FRAMESIZE   EQU     0
fmtit_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
