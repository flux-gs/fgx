                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from u_param.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT big
big            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #big_FRAMESIZE
                DO      big_STKGUARD
                BCC     big_stkovf
                CMP     _fcc_stkfloor
                BCS     big_stkok
big_stkovf       JMP     _fcc_stkoflow
                FIN
big_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+big_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+big_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+big_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDA     #20000
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_gtu16
                TAY
                TSC
                CLC
                ADC     #big_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
big_FRAMESIZE   EQU     0
big_STKGUARD    EQU     0
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
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
                PHA
                FGX2_FARCALL big
                TAY
                PLA
                TYA
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
                FGX2_RELOC_COUNT 4
