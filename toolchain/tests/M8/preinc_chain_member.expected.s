                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from preinc_chain_member.c
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
                LDA     #0
                STA     _fcc_img0
                LDA     #5
                STA     I+0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                STA     I+2
                TAY
                LDA     _fcc_long_hi
                STA     I+4
                TYA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #I
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     O+0
                TAY
                LDA     _fcc_ptr+2
                STA     O+2
                TYA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #O
                STA     pp
                LDA     _fcc_fpr0+2
                STA     pp+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #pp
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                DEC
                STA     [_fcc_ptr]
                TAX
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _preinc_chain_member_L0
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #10
                STA     _fcc_img0
_preinc_chain_member_L0
                LDA     I+0
                TAX
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _preinc_chain_member_L1
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #10
                STA     _fcc_img0
_preinc_chain_member_L1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #pp
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                INC
                STA     [_fcc_ptr]
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _preinc_chain_member_L2
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #11
                STA     _fcc_img0
_preinc_chain_member_L2
                LDA     I+0
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _preinc_chain_member_L3
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #11
                STA     _fcc_img0
_preinc_chain_member_L3
                LDA     _fcc_img0
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
                FGX2_RELOC_COUNT 2
