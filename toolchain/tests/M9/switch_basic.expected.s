                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from switch_basic.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT classify
classify            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #classify_FRAMESIZE
                DO      classify_STKGUARD
                BCC     classify_stkovf
                CMP     _fcc_stkfloor
                BCS     classify_stkok
classify_stkovf       JMP     _fcc_stkoflow
                FIN
classify_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+classify_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+classify_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+classify_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CMP     #1
                BEQ     _switch_basic_L1
                CMP     #2
                BEQ     _switch_basic_L2
                CMP     #3
                BEQ     _switch_basic_L3
                BRA     _switch_basic_L4
_switch_basic_L1
                LDA     #100
                TAY
                TSC
                CLC
                ADC     #classify_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_switch_basic_L2
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #classify_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_switch_basic_L3
                LDA     #300
                TAY
                TSC
                CLC
                ADC     #classify_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_switch_basic_L4
                LDA     #999
                TAY
                TSC
                CLC
                ADC     #classify_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_switch_basic_L0
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #classify_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
classify_FRAMESIZE   EQU     0
classify_STKGUARD    EQU     0
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
                LDA     #2
                PHA
                FGX2_FARCALL classify
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
