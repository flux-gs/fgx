                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from labelarm.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT probe
probe            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #probe_FRAMESIZE
                DO      probe_STKGUARD
                BCC     probe_stkovf
                CMP     _fcc_stkfloor
                BCS     probe_stkok
probe_stkovf       JMP     _fcc_stkoflow
                FIN
probe_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     r2
                STA     r1
                DO      6+probe_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+probe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+probe_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CMP     #0
                BEQ     _labelarm_L0
                DO      8+probe_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+probe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+probe_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                CMP     #0
                BEQ     _labelarm_L1
                LDA     #99
                STA     r1
                BRA     _labelarm_L2
_labelarm_L1
                DO      10+probe_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+probe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+probe_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                CMP     #0
                BEQ     _labelarm_L3
                LDA     #1
                STA     r1
                BRA     _labelarm_L4
_labelarm_L3
                BRA     probe_uL_nondes
_labelarm_L4
_labelarm_L2
                BRA     _labelarm_L5
_labelarm_L0
probe_uL_nondes
                DO      12+probe_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+probe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+probe_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                CMP     #0
                BEQ     _labelarm_L6
                LDA     #1
                STA     r2
                BRA     _labelarm_L7
_labelarm_L6
                LDA     #2
                STA     r2
_labelarm_L7
_labelarm_L5
                LDA     r1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     r2
                TAY
                TSC
                CLC
                ADC     #probe_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
probe_FRAMESIZE   EQU     0
probe_STKGUARD    EQU     0
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
                LDA     #1
                PHA
                LDA     #1
                PHA
                LDA     #0
                PHA
                LDA     #1
                PHA
                FGX2_FARCALL probe
                TAY
                PLA
                PLA
                PLA
                PLA
                TYA
                TAX
                TXA
                CMP     #10
                BEQ     _labelarm_L8
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
_labelarm_L8
                LDA     #1
                PHA
                LDA     #0
                PHA
                LDA     #0
                PHA
                LDA     #1
                PHA
                FGX2_FARCALL probe
                TAY
                PLA
                PLA
                PLA
                PLA
                TYA
                TAX
                TXA
                CMP     #1
                BEQ     _labelarm_L9
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
_labelarm_L9
                LDA     #1
                PHA
                LDA     #0
                PHA
                LDA     #0
                PHA
                LDA     #0
                PHA
                FGX2_FARCALL probe
                TAY
                PLA
                PLA
                PLA
                PLA
                TYA
                TAX
                TXA
                CMP     #1
                BEQ     _labelarm_L10
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
_labelarm_L10
                LDA     #1
                PHA
                LDA     #0
                PHA
                LDA     #1
                PHA
                LDA     #1
                PHA
                FGX2_FARCALL probe
                TAY
                PLA
                PLA
                PLA
                PLA
                TYA
                TAX
                TXA
                CMP     #990
                BEQ     _labelarm_L11
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
_labelarm_L11
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 7
