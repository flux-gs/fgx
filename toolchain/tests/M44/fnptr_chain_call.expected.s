                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fnptr_chain_call.c
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #theops
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     pack+2
                TAY
                LDA     _fcc_ptr+2
                STA     pack+4
                TYA
                LDA     pack+4
                STA     _fcc_fpr0+2
                LDA     pack+2
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #10
                PHA
                LDA     #30
                PHA
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_chain_call_L0-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_fnptr_chain_call_L0
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                PHA
                LDA     pack+4
                STA     _fcc_fpr0+2
                LDA     pack+2
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                LDA     #1
                PHA
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_chain_call_L1-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_fnptr_chain_call_L1
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
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
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 3
