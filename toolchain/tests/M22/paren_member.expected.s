                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from paren_member.c
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
                LDA     #1
                STA     1,S   ; fccstk d=0 b=1
                LDA     #64
                STA     3,S   ; fccstk d=0 b=3
                LDA     #2
                STA     g+0
                LDA     #2
                STA     g+2
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #1
                BEQ     _paren_member_L0
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
_paren_member_L0
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                CMP     #64
                BEQ     _paren_member_L1
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
_paren_member_L1
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                AND     #240
                TAX
                LDA     #64
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_eq16
                CMP     #0
                BEQ     _paren_member_L3
                LDA     #0
                BRA     _paren_member_L4
_paren_member_L3
                LDA     #1
_paren_member_L4
                CMP     #0
                BEQ     _paren_member_L2
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
_paren_member_L2
                LDA     g+2
                TAX
                TXA
                CMP     #2
                BEQ     _paren_member_L5
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
_paren_member_L5
                LDA     #42
                STA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
