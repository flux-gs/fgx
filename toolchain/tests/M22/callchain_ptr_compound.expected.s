                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from callchain_ptr_compound.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT hf
hf            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #hf_FRAMESIZE
                DO      hf_STKGUARD
                BCC     hf_stkovf
                CMP     _fcc_stkfloor
                BCS     hf_stkok
hf_stkovf       JMP     _fcc_stkoflow
                FIN
hf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     calls
                INC
                STA     calls
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #hroot
                STA     _fcc_fpr0
                PLA
                TAY
                TSC
                CLC
                ADC     #hf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
hf_FRAMESIZE   EQU     0
hf_STKGUARD    EQU     0
                FGX2_EXPORT pvec
pvec            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #pvec_FRAMESIZE
                DO      pvec_STKGUARD
                BCC     pvec_stkovf
                CMP     _fcc_stkfloor
                BCS     pvec_stkok
pvec_stkovf       JMP     _fcc_stkoflow
                FIN
pvec_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     calls
                INC
                STA     calls
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #pvv
                STA     _fcc_fpr0
                PLA
                TAY
                TSC
                CLC
                ADC     #pvec_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
pvec_FRAMESIZE   EQU     0
pvec_STKGUARD    EQU     0
                FGX2_EXPORT ivec
ivec            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ivec_FRAMESIZE
                DO      ivec_STKGUARD
                BCC     ivec_stkovf
                CMP     _fcc_stkfloor
                BCS     ivec_stkok
ivec_stkovf       JMP     _fcc_stkoflow
                FIN
ivec_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     calls
                INC
                STA     calls
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ivv
                STA     _fcc_fpr0
                PLA
                TAY
                TSC
                CLC
                ADC     #ivec_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ivec_FRAMESIZE   EQU     0
ivec_STKGUARD    EQU     0
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
                CLC
                ADC     #0
                ASL
                CLC
                ADC     #blk
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #10
                STA     [_fcc_fpr0]
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     #blk
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #11
                STA     [_fcc_fpr0]
                LDA     #2
                ASL
                INC
                INC
                ASL
                CLC
                ADC     #blk
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #12
                STA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #other
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     hroot+6
                TAY
                LDA     _fcc_ptr+2
                STA     hroot+8
                TYA
                LDA     #2
                STA     5,S   ; fccstk d=0 b=5
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     hroot+2
                TAY
                LDA     _fcc_ptr+2
                STA     hroot+4
                TYA
                FGX2_FARCALL hf
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #1
                ASL
                INC
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     hroot+4
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hroot+2
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BEQ     _callchain_ptr_compound_L0
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
_callchain_ptr_compound_L0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     hroot+2
                TAY
                LDA     _fcc_ptr+2
                STA     hroot+4
                TYA
                FGX2_FARCALL hf
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     hroot+4
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hroot+2
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #12
                BEQ     _callchain_ptr_compound_L1
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
_callchain_ptr_compound_L1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk+12
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     hroot+2
                TAY
                LDA     _fcc_ptr+2
                STA     hroot+4
                TYA
                FGX2_FARCALL hf
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #1
                ASL
                INC
                ASL
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     hroot+4
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hroot+2
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BEQ     _callchain_ptr_compound_L2
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
_callchain_ptr_compound_L2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk+12
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     hroot+2
                TAY
                LDA     _fcc_ptr+2
                STA     hroot+4
                TYA
                FGX2_FARCALL hf
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     hroot+4
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hroot+2
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #10
                BEQ     _callchain_ptr_compound_L3
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
_callchain_ptr_compound_L3
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     other+2
                TAY
                LDA     _fcc_ptr+2
                STA     other+4
                TYA
                FGX2_FARCALL hf
                LDY     #6
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #1
                ASL
                INC
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     other+4
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     other+2
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BEQ     _callchain_ptr_compound_L4
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_callchain_ptr_compound_L4
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     other+2
                TAY
                LDA     _fcc_ptr+2
                STA     other+4
                TYA
                FGX2_FARCALL hf
                LDY     #6
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     other+4
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     other+2
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #12
                BEQ     _callchain_ptr_compound_L5
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_callchain_ptr_compound_L5
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     hroot+2
                TAY
                LDA     _fcc_ptr+2
                STA     hroot+4
                TYA
                FGX2_FARCALL hf
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                CLC
                ADC     #6
                STA     [_fcc_fpr0]
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     _fcc_fpr0
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     hroot+4
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hroot+2
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BEQ     _callchain_ptr_compound_L6
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_callchain_ptr_compound_L6
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk+6
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     hroot+2
                TAY
                LDA     _fcc_ptr+2
                STA     hroot+4
                TYA
                FGX2_FARCALL hf
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                SEC
                SBC     #6
                STA     [_fcc_fpr0]
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     _fcc_fpr0
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     hroot+4
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hroot+2
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #10
                BEQ     _callchain_ptr_compound_L7
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_callchain_ptr_compound_L7
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     hroot+2
                TAY
                LDA     _fcc_ptr+2
                STA     hroot+4
                TYA
                FGX2_FARCALL hf
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #1
                ASL
                INC
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_ptr+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                JSR     _fcc_bank_for_int
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BEQ     _callchain_ptr_compound_L8
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_callchain_ptr_compound_L8
                SEP     #$20
                MX      %10
                LDA     hroot+4
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hroot+2
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BEQ     _callchain_ptr_compound_L9
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_callchain_ptr_compound_L9
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk+12
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     hroot+2
                TAY
                LDA     _fcc_ptr+2
                STA     hroot+4
                TYA
                FGX2_FARCALL hf
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_ptr+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                JSR     _fcc_bank_for_int
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #10
                BEQ     _callchain_ptr_compound_L10
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_callchain_ptr_compound_L10
                LDA     #0
                STA     calls
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     hroot+2
                TAY
                LDA     _fcc_ptr+2
                STA     hroot+4
                TYA
                FGX2_FARCALL hf
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #1
                ASL
                INC
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     calls
                TAX
                TXA
                CMP     #1
                BEQ     _callchain_ptr_compound_L11
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_callchain_ptr_compound_L11
                LDA     #ivv
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #50
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #0
                STA     calls
                FGX2_FARCALL ivec
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                INC
                STA     [_fcc_fpr0]
                LDA     #1
                ASL
                TAX
                LDA:    ivv,X
                TAX
                TXA
                CMP     #51
                BEQ     _callchain_ptr_compound_L12
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_callchain_ptr_compound_L12
                LDA     calls
                TAX
                TXA
                CMP     #1
                BEQ     _callchain_ptr_compound_L13
                LDA     #14
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_callchain_ptr_compound_L13
                FGX2_FARCALL ivec
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                SEC
                SBC     #3
                STA     [_fcc_fpr0]
                LDA     #1
                ASL
                TAX
                LDA:    ivv,X
                TAX
                TXA
                CMP     #48
                BEQ     _callchain_ptr_compound_L14
                LDA     #15
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_callchain_ptr_compound_L14
                LDA     #pvv
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                LDA     #0
                STA     calls
                FGX2_FARCALL pvec
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #1
                ASL
                INC
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     #1
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    pvv+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    pvv,X
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BEQ     _callchain_ptr_compound_L15
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_callchain_ptr_compound_L15
                LDA     calls
                TAX
                TXA
                CMP     #1
                BEQ     _callchain_ptr_compound_L16
                LDA     #17
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_callchain_ptr_compound_L16
                LDA     #pvv
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk+12
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                FGX2_FARCALL pvec
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     #1
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    pvv+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    pvv,X
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #10
                BEQ     _callchain_ptr_compound_L17
                LDA     #18
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_callchain_ptr_compound_L17
                LDA     #pvv
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                FGX2_FARCALL pvec
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     #1
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    pvv+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    pvv,X
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #12
                BEQ     _callchain_ptr_compound_L18
                LDA     #19
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_callchain_ptr_compound_L18
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
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 21
