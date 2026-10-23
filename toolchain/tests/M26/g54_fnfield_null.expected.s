                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from g54_fnfield_null.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT one
one            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #one_FRAMESIZE
                DO      one_STKGUARD
                BCC     one_stkovf
                CMP     _fcc_stkfloor
                BCS     one_stkok
one_stkovf       JMP     _fcc_stkoflow
                FIN
one_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #one_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
one_FRAMESIZE   EQU     0
one_STKGUARD    EQU     0
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
                LDA     _g54_fnfield_null_FA0+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _g54_fnfield_null_FA0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     sa+2
                TAY
                LDA     _fcc_ptr+2
                STA     sa+4
                TYA
                LDA     #0
                STA     sa+2
                TAY
                LDA     #0
                STA     sa+4
                TYA
                STZ     _fcc_fpr0+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #sa
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _g54_fnfield_null_L5
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _g54_fnfield_null_L5
                LDA     #1
                BRL     _g54_fnfield_null_L6
_g54_fnfield_null_L5
                LDA     #0
_g54_fnfield_null_L6
                CMP     #0
                BNE     *+5
                BRL     _g54_fnfield_null_L3
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                PHA
                LDA     #2
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _g54_fnfield_null_L3
                LDA     #1
                BRL     _g54_fnfield_null_L4
_g54_fnfield_null_L3
                LDA     #0
_g54_fnfield_null_L4
                CMP     #0
                BNE     *+5
                BRL     _g54_fnfield_null_L1
                LDA     #42
                BRL     _g54_fnfield_null_L2
_g54_fnfield_null_L1
                LDA     #7
_g54_fnfield_null_L2
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
                FGX2_RELOC_COUNT 3
