                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from addr_dot_hops_ptr.c
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
                ASL
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     #_addr_dot_hops_ptr_arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #1
                LDY     #16
                STA     [_fcc_fpr0],Y
                LDA     #1
                ASL
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #_addr_dot_hops_ptr_arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #10
                LDY     #16
                STA     [_fcc_fpr0],Y
                LDA     #2
                ASL
                ASL
                ASL
                INC
                INC
                ASL
                CLC
                ADC     #_addr_dot_hops_ptr_arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #30
                LDY     #16
                STA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_addr_dot_hops_ptr_arr
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_ptr+2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_tmp_b
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_addr_dot_hops_ptr_arr
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _addr_dot_hops_ptr_G+2
                TAY
                LDA     _fcc_ptr+2
                STA     _addr_dot_hops_ptr_G+4
                TYA
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
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #36
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_fpr0
                STA     7,S   ; fccstk d=0 b=7
                SEP     #$20
                MX      %10
                LDA     _addr_dot_hops_ptr_G+4
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _addr_dot_hops_ptr_G+2
                CLC
                ADC     #18
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_fpr0
                STA     11,S   ; fccstk d=0 b=11
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0
                LDY     #16
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                INC
                LDY     #16
                STA     [_fcc_fpr0],Y
                LDY     #16
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     15,S   ; fccstk d=2 b=13
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=2 b=11
                STA     _fcc_fpr0
                LDY     #16
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     11,S   ; fccstk d=2 b=9
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=2 b=7
                STA     _fcc_fpr0
                LDA     15,S   ; fccstk d=2 b=13
                STA     _fcc_fpr1+2
                LDA     13,S   ; fccstk d=2 b=11
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                LDX     #18
                STX     _fcc_tmp_b
                JSR     _fcc_divs16
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
main_FRAMESIZE   EQU     14
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
