                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from p33_sdelta.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT g
g            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #g_FRAMESIZE
                DO      g_STKGUARD
                BCC     g_stkovf
                CMP     _fcc_stkfloor
                BCS     g_stkok
g_stkovf       JMP     _fcc_stkoflow
                FIN
g_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+g_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+g_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+g_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                INC
                TAY
                TSC
                CLC
                ADC     #g_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
g_FRAMESIZE   EQU     0
g_STKGUARD    EQU     0
                FGX2_EXPORT add3
add3            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add3_FRAMESIZE
                DO      add3_STKGUARD
                BCC     add3_stkovf
                CMP     _fcc_stkfloor
                BCS     add3_stkok
add3_stkovf       JMP     _fcc_stkoflow
                FIN
add3_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+add3_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+add3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+add3_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                DO      8+add3_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+add3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+add3_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAX
                DO      10+add3_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+add3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+add3_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #add3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add3_FRAMESIZE   EQU     0
add3_STKGUARD    EQU     0
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
                LDA     #10
                STA     1,S   ; fccstk d=0 b=1
                LDA     #3
                STA     3,S   ; fccstk d=0 b=3
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                FGX2_FARCALL g
                PLY
                PHA
                FGX2_FARCALL g
                PLY
                PHA
                LDA     3,S   ; fccstk d=2 b=1
                PHA
                LDA     5,S   ; fccstk d=4 b=1
                PHA
                FGX2_FARCALL g
                PLY
                PHA
                FGX2_FARCALL add3
                PLY
                PLY
                PLY
                STA     5,S   ; fccstk d=0 b=5
                TAX
                CMP     #33
                BEQ     _p33_sdelta_L0
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_sdelta_L0
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                FGX2_FARCALL g
                PLY
                PHA
                LDA     3,S   ; fccstk d=2 b=1
                PHA
                FGX2_FARCALL g
                PLY
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                TAX
                CMP     #44
                BEQ     _p33_sdelta_L1
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_sdelta_L1
                LDA     3,S   ; fccstk d=0 b=3
                PHA
                LDA     3,S   ; fccstk d=2 b=1
                PHA
                LDA     5,S   ; fccstk d=4 b=1
                PHA
                FGX2_FARCALL g
                PLY
                PHA
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                LDA     9,S   ; fccstk d=8 b=1
                PHA
                FGX2_FARCALL add3
                PLY
                PLY
                PLY
                PHA
                FGX2_FARCALL add3
                PLY
                PLY
                PLY
                STA     5,S   ; fccstk d=0 b=5
                TAX
                CMP     #37
                BEQ     _p33_sdelta_L2
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_sdelta_L2
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #10
                BNE     _p33_sdelta_L4
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CMP     #3
                BEQ     _p33_sdelta_L3
_p33_sdelta_L4
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_sdelta_L3
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
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 13
