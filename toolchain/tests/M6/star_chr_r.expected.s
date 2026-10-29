                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from star_chr_r.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT peek
peek            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #peek_FRAMESIZE
                DO      peek_STKGUARD
                BCC     peek_stkovf
                CMP     _fcc_stkfloor
                BCS     peek_stkok
peek_stkovf       JMP     _fcc_stkoflow
                FIN
peek_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+peek_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+peek_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+peek_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+peek_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+peek_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+peek_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAY
                TSC
                CLC
                ADC     #peek_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
peek_FRAMESIZE   EQU     0
peek_STKGUARD    EQU     0
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
                LDA     #65
                STA     1,S   ; fccstk d=0 b=1
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
                FGX2_FARCALL peek
                PLY
                PLY
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
