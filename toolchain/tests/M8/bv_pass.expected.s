                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from bv_pass.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT sum
sum            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sum_FRAMESIZE
                DO      sum_STKGUARD
                BCC     sum_stkovf
                CMP     _fcc_stkfloor
                BCS     sum_stkok
sum_stkovf       JMP     _fcc_stkoflow
                FIN
sum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      10+sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sum_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #sum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sum_FRAMESIZE   EQU     0
sum_STKGUARD    EQU     0
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
                LDA     #30
                STA     1,S   ; fccstk d=0 b=1
                LDA     #12
                STA     3,S   ; fccstk d=0 b=3
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                TSC
                SEC
                SBC     #4
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #2
_bv_pass_L0
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _bv_pass_L0
                FGX2_FARCALL sum
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
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
