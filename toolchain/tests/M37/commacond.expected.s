                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from commacond.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT next
next            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #next_FRAMESIZE
                DO      next_STKGUARD
                BCC     next_stkovf
                CMP     _fcc_stkfloor
                BCS     next_stkok
next_stkovf       JMP     _fcc_stkoflow
                FIN
next_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     fed
                STA     _fcc_tmp_b
                INC
                STA     fed
                LDA     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #next_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
next_FRAMESIZE   EQU     0
next_STKGUARD    EQU     0
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
                STA     5,S   ; fccstk d=0 b=5
                LDA     #3
                STA     fed
_commacond_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                FGX2_FARCALL next
                STA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #6
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_lts16
                CMP     #0
                BNE     *+5
                BRL     _commacond_L1
                LDA     5,S   ; fccstk d=0 b=5
                CLC
                ADC     1,S   ; fccstk d=0 b=1
                STA     5,S   ; fccstk d=0 b=5
                BRL     _commacond_L0
_commacond_L1
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #7
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_eq16
                CMP     #0
                BNE     *+5
                BRL     _commacond_L2
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #10
                STA     5,S   ; fccstk d=0 b=5
_commacond_L2
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
                STA     _fcc_img0
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_img1
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_img2
_commacond_L3
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #100
                STA     _fcc_img2
                LDA     _fcc_img0
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_lts16
                CMP     #0
                BNE     *+5
                BRL     _commacond_L5
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #1
                STA     _fcc_img1
_commacond_L4
                LDA     _fcc_img0
                CLC
                ADC     #1
                STA     _fcc_img0
                BRL     _commacond_L3
_commacond_L5
                LDA     _fcc_img0
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_img1
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_img2
                STA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #104
                BEQ     *+5
                BRL     _commacond_L6
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #16
                STA     5,S   ; fccstk d=0 b=5
_commacond_L6
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
