                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from krvarencl.c
;---------------------------------------

                MX      %00
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
                LDA     #3
                PHA
                LDA     #2
                PHA
                FGX2_FARCALL relay
                TAY
                PLA
                PLA
                TYA
                TAX
                LDA     #235
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _krvarencl_L0
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
_krvarencl_L0
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_EXPORT relay
relay            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #relay_FRAMESIZE
                DO      relay_STKGUARD
                BCC     relay_stkovf
                CMP     _fcc_stkfloor
                BCS     relay_stkok
relay_stkovf       JMP     _fcc_stkoflow
                FIN
relay_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #5
                PHA
                DO      10+relay_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+relay_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+relay_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                PHA
                DO      10+relay_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+relay_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+relay_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                PHA
                FGX2_FARCALL mix3
                TAY
                PLA
                PLA
                PLA
                TYA
                TAY
                TSC
                CLC
                ADC     #relay_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
relay_FRAMESIZE   EQU     0
relay_STKGUARD    EQU     0
                FGX2_EXPORT mix3
mix3            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #mix3_FRAMESIZE
                DO      mix3_STKGUARD
                BCC     mix3_stkovf
                CMP     _fcc_stkfloor
                BCS     mix3_stkok
mix3_stkovf       JMP     _fcc_stkoflow
                FIN
mix3_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+mix3_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+mix3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+mix3_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                TAX
                DO      8+mix3_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+mix3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+mix3_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAX
                DO      10+mix3_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+mix3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+mix3_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #mix3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
mix3_FRAMESIZE   EQU     0
mix3_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
