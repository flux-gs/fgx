                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_cast_bank.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT copyout
copyout            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #copyout_FRAMESIZE
                DO      copyout_STKGUARD
                BCC     copyout_stkovf
                CMP     _fcc_stkfloor
                BCS     copyout_stkok
copyout_stkovf       JMP     _fcc_stkoflow
                FIN
copyout_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      14+copyout_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+copyout_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+copyout_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_img0
                DO      6+copyout_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+copyout_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+copyout_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+copyout_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+copyout_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+copyout_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
                DO      10+copyout_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+copyout_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+copyout_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img3
                DO      12+copyout_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+copyout_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+copyout_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img4
_struct_cast_bank_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                DEC
                STA     _fcc_img0
                LDA     _fcc_tmp_b
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _struct_cast_bank_L2
                EOR     #$8000
_struct_cast_bank_L2
                BPL     _struct_cast_bank_L1
                LDA     [_fcc_img3]
                INC     _fcc_img3
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_img1]
                REP     #$20
                MX      %00
                INC     _fcc_img1
                BRA     _struct_cast_bank_L0
_struct_cast_bank_L1
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #copyout_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
copyout_FRAMESIZE   EQU     0
copyout_STKGUARD    EQU     0
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
                LDA     #12
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #gjb
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #2
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL copyout
                TSC
                CLC
                ADC     #10
                TCS
                LDA     #12
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #sink
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #14
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL copyout
                TSC
                CLC
                ADC     #10
                TCS
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
                LDA     #sink
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
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
                FGX2_FARCALL copyout
                TSC
                CLC
                ADC     #10
                TCS
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     26
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
