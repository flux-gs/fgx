                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from aud_shr_or.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT side
side            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #side_FRAMESIZE
                DO      side_STKGUARD
                BCC     side_stkovf
                CMP     _fcc_stkfloor
                BCS     side_stkok
side_stkovf       JMP     _fcc_stkoflow
                FIN
side_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+side_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+side_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+side_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+side_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+side_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+side_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #99
                STA     [_fcc_fpr0]
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #side_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
side_FRAMESIZE   EQU     0
side_STKGUARD    EQU     0
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
                LDA     #168
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shrs16
                TAX
                CMP     #42
                BNE     _aud_shr_or_L0
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #40
                STA     5,S   ; fccstk d=0 b=5
_aud_shr_or_L0
                LDA     #1
                BNE     _aud_shr_or_L2
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL side
                PLY
                PLY
                CMP     #0
                BEQ     _aud_shr_or_L1
_aud_shr_or_L2
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #1
                STA     5,S   ; fccstk d=0 b=5
_aud_shr_or_L1
                LDA     3,S   ; fccstk d=0 b=3
                BNE     _aud_shr_or_L3
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #1
                STA     5,S   ; fccstk d=0 b=5
_aud_shr_or_L3
                LDA     5,S   ; fccstk d=0 b=5
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
                FGX2_RELOC_COUNT 4
