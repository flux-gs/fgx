                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from static_charptr_str.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT slen
slen            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #slen_FRAMESIZE
                DO      slen_STKGUARD
                BCC     slen_stkovf
                CMP     _fcc_stkfloor
                BCS     slen_stkok
slen_stkovf       JMP     _fcc_stkoflow
                FIN
slen_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+slen_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+slen_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+slen_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+slen_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+slen_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+slen_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
                LDA     #0
                STA     _fcc_img0
_static_charptr_str_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                CMP     #0
                BNE     *+5
                BRL     _static_charptr_str_L1
                INC     _fcc_img0
                BRL     _static_charptr_str_L0
_static_charptr_str_L1
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #slen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
slen_FRAMESIZE   EQU     2
slen_STKGUARD    EQU     0
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
                LDA     main_sl_fmts+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     main_sl_fmts
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL slen
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     main_sl_fmtd+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     main_sl_fmtd
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL slen
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                SEP     #$20
                MX      %10
                LDA     main_sl_emsg+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     main_sl_emsg
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL slen
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAX
                TXA
                CLC
                ADC     #26
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
