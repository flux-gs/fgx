                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fn_multi_call.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT add
add            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add_FRAMESIZE
                DO      add_STKGUARD
                BCC     add_stkovf
                CMP     _fcc_stkfloor
                BCS     add_stkok
add_stkovf       JMP     _fcc_stkoflow
                FIN
add_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+add_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+add_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+add_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                DO      8+add_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+add_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+add_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #add_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add_FRAMESIZE   EQU     0
add_STKGUARD    EQU     0
                FGX2_EXPORT sub
sub            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sub_FRAMESIZE
                DO      sub_STKGUARD
                BCC     sub_stkovf
                CMP     _fcc_stkfloor
                BCS     sub_stkok
sub_stkovf       JMP     _fcc_stkoflow
                FIN
sub_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+sub_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sub_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sub_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                DO      8+sub_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sub_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sub_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #sub_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sub_FRAMESIZE   EQU     0
sub_STKGUARD    EQU     0
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
                LDA     #8
                PHA
                LDA     #20
                PHA
                FGX2_FARCALL sub
                TAY
                PLA
                PLA
                TYA
                PHA
                LDA     #30
                PHA
                FGX2_FARCALL add
                TAY
                PLA
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
                FGX2_RELOC_COUNT 6
