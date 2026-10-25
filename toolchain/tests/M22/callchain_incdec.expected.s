                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from callchain_incdec.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT lookup
lookup            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #lookup_FRAMESIZE
                DO      lookup_STKGUARD
                BCC     lookup_stkovf
                CMP     _fcc_stkfloor
                BCS     lookup_stkok
lookup_stkovf       JMP     _fcc_stkoflow
                FIN
lookup_stkok        TCS
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
                LDA     #root
                STA     _fcc_fpr0
                PLA
                TAY
                TSC
                CLC
                ADC     #lookup_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
lookup_FRAMESIZE   EQU     0
lookup_STKGUARD    EQU     0
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
                LDA     #vec
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
                LDA     #10
                STA     root+8
                LDA     #0
                STA     calls
                LDA     #1
                PHA
                FGX2_FARCALL lookup
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_fpr0]
                LDA     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #10
                BEQ     _callchain_incdec_L0
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
_callchain_incdec_L0
                LDA     root+8
                TAX
                CMP     #11
                BEQ     _callchain_incdec_L1
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
_callchain_incdec_L1
                LDA     #1
                PHA
                FGX2_FARCALL lookup
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                STA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #12
                BEQ     _callchain_incdec_L2
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
_callchain_incdec_L2
                LDA     root+8
                TAX
                CMP     #12
                BEQ     _callchain_incdec_L3
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
_callchain_incdec_L3
                LDA     #1
                PHA
                FGX2_FARCALL lookup
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                DEC
                STA     [_fcc_fpr0]
                LDA     root+8
                TAX
                CMP     #11
                BEQ     _callchain_incdec_L4
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
_callchain_incdec_L4
                LDA     #1
                PHA
                FGX2_FARCALL lookup
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                LDA     root+8
                TAX
                CMP     #12
                BEQ     _callchain_incdec_L5
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
_callchain_incdec_L5
                LDA     calls
                TAX
                CMP     #4
                BEQ     _callchain_incdec_L6
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
_callchain_incdec_L6
                LDA     #vec
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #5
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
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_fpr0]
                LDA     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #5
                BEQ     _callchain_incdec_L7
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
_callchain_incdec_L7
                LDA     #2
                ASL
                TAX
                LDA:    vec,X
                TAX
                CMP     #6
                BEQ     _callchain_incdec_L8
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
_callchain_incdec_L8
                FGX2_FARCALL ivec
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                STA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #7
                BEQ     _callchain_incdec_L9
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
_callchain_incdec_L9
                LDA     #2
                ASL
                TAX
                LDA:    vec,X
                TAX
                CMP     #7
                BEQ     _callchain_incdec_L10
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
_callchain_incdec_L10
                FGX2_FARCALL ivec
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                DEC
                STA     [_fcc_fpr0]
                LDA     #2
                ASL
                TAX
                LDA:    vec,X
                TAX
                CMP     #6
                BEQ     _callchain_incdec_L11
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
_callchain_incdec_L11
                LDA     calls
                TAX
                CMP     #3
                BEQ     _callchain_incdec_L12
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
_callchain_incdec_L12
                LDA     #vec
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #20
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     vec+2
                INC
                STA     vec+2
                STA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #21
                BEQ     _callchain_incdec_L13
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
_callchain_incdec_L13
                LDA     #1
                ASL
                TAX
                LDA:    vec,X
                TAX
                CMP     #21
                BEQ     _callchain_incdec_L14
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
_callchain_incdec_L14
                LDA     vec+2
                INC
                STA     vec+2
                LDA     #1
                ASL
                TAX
                LDA:    vec,X
                TAX
                CMP     #22
                BEQ     _callchain_incdec_L15
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
_callchain_incdec_L15
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #sub
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #100
                STA     [_fcc_fpr0]
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #sub
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #200
                STA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #sub
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+4
                TAY
                LDA     _fcc_ptr+2
                STA     root+6
                TYA
                LDA     #1
                PHA
                FGX2_FARCALL lookup
                TAY
                PLA
                TYA
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                CLC
                ADC     #4
                STA     [_fcc_fpr0],Y
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                LDA     _fcc_tmp_b
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #100
                BEQ     _callchain_incdec_L16
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
_callchain_incdec_L16
                SEP     #$20
                MX      %10
                LDA     root+6
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     root+4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #200
                BEQ     _callchain_incdec_L17
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
_callchain_incdec_L17
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
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 12
