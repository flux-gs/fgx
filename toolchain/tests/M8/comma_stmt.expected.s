                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from comma_stmt.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _comma_stmt_bump
_comma_stmt_bump            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_comma_stmt_bump_FRAMESIZE
                DO      _comma_stmt_bump_STKGUARD
                BCC     _comma_stmt_bump_stkovf
                CMP     _fcc_stkfloor
                BCS     _comma_stmt_bump_stkok
_comma_stmt_bump_stkovf       JMP     _fcc_stkoflow
                FIN
_comma_stmt_bump_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     g
                TAX
                TXA
                CLC
                ADC     #5
                STA     g
                TAY
                TSC
                CLC
                ADC     #_comma_stmt_bump_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_comma_stmt_bump_FRAMESIZE   EQU     0
_comma_stmt_bump_STKGUARD    EQU     0
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
                LDA     _fcc_fpr0+2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_fpr0
                STA     3,S   ; fccstk d=0 b=3
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     17,S   ; fccstk d=0 b=17
                LDA     _fcc_fpr0
                STA     15,S   ; fccstk d=0 b=15
                LDA     #10
                STA     7,S   ; fccstk d=0 b=7
                LDA     #20
                STA     9,S   ; fccstk d=0 b=9
                FGX2_FARCALL _comma_stmt_bump
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                TXA
                INC
                INC
                STA     7,S   ; fccstk d=0 b=7
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDA     #3
                STA     [_fcc_fpr0]
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                INC
                INC
                STA     1,S   ; fccstk d=0 b=1
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0+2
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0
                INC
                INC
                STA     15,S   ; fccstk d=0 b=15
                LDA     #8
                STA     [_fcc_fpr0]
                LDA     9,S   ; fccstk d=0 b=9
                DEC
                STA     9,S   ; fccstk d=0 b=9
                LDA     7,S   ; fccstk d=0 b=7
                PHA
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #10
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     11,S   ; fccstk d=2 b=9
                TAX
                TXA
                DEC
                DEC
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                CLC
                ADC     g
                TAX
                TXA
                SEC
                SBC     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     18
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
