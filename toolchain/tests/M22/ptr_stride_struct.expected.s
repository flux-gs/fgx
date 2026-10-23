                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptr_stride_struct.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT bump
bump            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #bump_FRAMESIZE
                DO      bump_STKGUARD
                BCC     bump_stkovf
                CMP     _fcc_stkfloor
                BCS     bump_stkok
bump_stkovf       JMP     _fcc_stkoflow
                FIN
bump_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     gr
                LDA     _fcc_fpr0+2
                STA     gr+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                SEC
                SBC     #10
                TAY
                TSC
                CLC
                ADC     #bump_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bump_FRAMESIZE   EQU     4
bump_STKGUARD    EQU     0
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
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #10
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #11
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #12
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #20
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #21
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #2
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #22
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #root
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #other
                STA     _fcc_fpr0
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gr
                LDA     _fcc_fpr0+2
                STA     gr+2
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gr
                CLC
                ADC     #4
                STA     gr
                TAY
                LDA     _fcc_ptr+2
                STA     gr+2
                TYA
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gr
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L0
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
_ptr_stride_struct_L0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gr
                LDA     _fcc_fpr0+2
                STA     gr+2
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gr
                CLC
                ADC     #4
                STA     gr
                TAY
                LDA     _fcc_ptr+2
                STA     gr+2
                TYA
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gr
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L1
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
_ptr_stride_struct_L1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gr
                LDA     _fcc_fpr0+2
                STA     gr+2
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gr
                SEC
                SBC     #4
                STA     gr
                TAY
                LDA     _fcc_ptr+2
                STA     gr+2
                TYA
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gr
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #10
                BNE     *+5
                BRL     _ptr_stride_struct_L2
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
_ptr_stride_struct_L2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gr
                LDA     _fcc_fpr0+2
                STA     gr+2
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gr
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gr
                LDA     _fcc_fpr0+2
                STA     gr+2
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gr
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L3
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
_ptr_stride_struct_L3
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gr
                LDA     _fcc_fpr0+2
                STA     gr+2
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gr
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                STA     _fcc_tmp_b
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_tmp_b
                STA     gr
                LDA     _fcc_fpr0+2
                STA     gr+2
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gr
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #10
                BNE     *+5
                BRL     _ptr_stride_struct_L4
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
_ptr_stride_struct_L4
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gr
                LDA     _fcc_fpr0+2
                STA     gr+2
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gr
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gr
                LDA     _fcc_fpr0+2
                STA     gr+2
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gr
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #12
                BNE     *+5
                BRL     _ptr_stride_struct_L5
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
_ptr_stride_struct_L5
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gt
                LDA     _fcc_fpr0+2
                STA     gt+2
                SEP     #$20
                MX      %10
                LDA     gt+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gt
                CLC
                ADC     #6
                STA     gt
                TAY
                LDA     _fcc_ptr+2
                STA     gt+2
                TYA
                SEP     #$20
                MX      %10
                LDA     gt+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gt
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #21
                BNE     *+5
                BRL     _ptr_stride_struct_L6
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
_ptr_stride_struct_L6
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gt
                LDA     _fcc_fpr0+2
                STA     gt+2
                SEP     #$20
                MX      %10
                LDA     gt+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gt
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gt
                LDA     _fcc_fpr0+2
                STA     gt+2
                SEP     #$20
                MX      %10
                LDA     gt+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gt
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #21
                BNE     *+5
                BRL     _ptr_stride_struct_L7
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
_ptr_stride_struct_L7
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gt
                LDA     _fcc_fpr0+2
                STA     gt+2
                SEP     #$20
                MX      %10
                LDA     gt+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gt
                STA     _fcc_fpr0
                LDA     #2
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gt
                LDA     _fcc_fpr0+2
                STA     gt+2
                SEP     #$20
                MX      %10
                LDA     gt+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gt
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #22
                BNE     *+5
                BRL     _ptr_stride_struct_L8
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
_ptr_stride_struct_L8
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #2
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gt
                LDA     _fcc_fpr0+2
                STA     gt+2
                SEP     #$20
                MX      %10
                LDA     gt+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gt
                STA     _fcc_fpr0
                LDA     #2
                ASL
                INC
                INC
                ASL
                STA     _fcc_tmp_b
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_tmp_b
                STA     gt
                LDA     _fcc_fpr0+2
                STA     gt+2
                SEP     #$20
                MX      %10
                LDA     gt+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gt
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #20
                BNE     *+5
                BRL     _ptr_stride_struct_L9
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
_ptr_stride_struct_L9
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gt
                LDA     _fcc_fpr0+2
                STA     gt+2
                SEP     #$20
                MX      %10
                LDA     gt+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gt
                CLC
                ADC     #6
                STA     gt
                TAY
                LDA     _fcc_ptr+2
                STA     gt+2
                TYA
                SEP     #$20
                MX      %10
                LDA     gt+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gt
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #21
                BNE     *+5
                BRL     _ptr_stride_struct_L10
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
_ptr_stride_struct_L10
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+0
                TAY
                LDA     _fcc_ptr+2
                STA     root+2
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CLC
                ADC     #4
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L11
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
_ptr_stride_struct_L11
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+0
                TAY
                LDA     _fcc_ptr+2
                STA     root+2
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #1
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L12
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
_ptr_stride_struct_L12
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+0
                TAY
                LDA     _fcc_ptr+2
                STA     root+2
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                SEC
                SBC     #4
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                TAX
                TXA
                CMP     #10
                BNE     *+5
                BRL     _ptr_stride_struct_L13
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
_ptr_stride_struct_L13
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+0
                TAY
                LDA     _fcc_ptr+2
                STA     root+2
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #1
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L14
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
_ptr_stride_struct_L14
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+8
                TAY
                LDA     _fcc_ptr+2
                STA     root+10
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     #2
                ASL
                INC
                INC
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                LDY     #8
                STA     [_fcc_fpr0],Y
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #22
                BNE     *+5
                BRL     _ptr_stride_struct_L15
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
_ptr_stride_struct_L15
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+8
                TAY
                LDA     _fcc_ptr+2
                STA     root+10
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                CLC
                ADC     #6
                LDY     #8
                STA     [_fcc_fpr0],Y
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #21
                BNE     *+5
                BRL     _ptr_stride_struct_L16
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
_ptr_stride_struct_L16
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+0
                TAY
                LDA     _fcc_ptr+2
                STA     root+2
                TYA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #root
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CLC
                ADC     #4
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #root
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
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L17
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
_ptr_stride_struct_L17
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+0
                TAY
                LDA     _fcc_ptr+2
                STA     root+2
                TYA
                LDA     root+0
                PHA
                LDA     #1
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     root+0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #root
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
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L18
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
_ptr_stride_struct_L18
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+8
                TAY
                LDA     _fcc_ptr+2
                STA     root+10
                TYA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #root
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CLC
                ADC     #6
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #root
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #21
                BNE     *+5
                BRL     _ptr_stride_struct_L19
                LDA     #20
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L19
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     other+0
                TAY
                LDA     _fcc_ptr+2
                STA     other+2
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
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CLC
                ADC     #4
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
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
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L20
                LDA     #21
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L20
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     other+0
                TAY
                LDA     _fcc_ptr+2
                STA     other+2
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
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CLC
                ADC     #4
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
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
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L21
                LDA     #22
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L21
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     other+8
                TAY
                LDA     _fcc_ptr+2
                STA     other+10
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     #1
                ASL
                INC
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                LDY     #8
                STA     [_fcc_fpr0],Y
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #21
                BNE     *+5
                BRL     _ptr_stride_struct_L22
                LDA     #23
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L22
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gr
                LDA     _fcc_fpr0+2
                STA     gr+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gr
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #1
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gr
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L23
                LDA     #24
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L23
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gr
                LDA     _fcc_fpr0+2
                STA     gr+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gr
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CLC
                ADC     #4
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gr
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L24
                LDA     #25
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L24
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gt
                LDA     _fcc_fpr0+2
                STA     gt+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
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
                LDA     gt+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gt
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #21
                BNE     *+5
                BRL     _ptr_stride_struct_L25
                LDA     #26
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L25
                LDA     #2
                STA     13,S   ; fccstk d=0 b=13
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gr
                LDA     _fcc_fpr0+2
                STA     gr+2
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gr
                STA     _fcc_fpr0
                LDA     13,S   ; fccstk d=0 b=13
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gr
                LDA     _fcc_fpr0+2
                STA     gr+2
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gr
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #12
                BNE     *+5
                BRL     _ptr_stride_struct_L26
                LDA     #27
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L26
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gt
                LDA     _fcc_fpr0+2
                STA     gt+2
                SEP     #$20
                MX      %10
                LDA     gt+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gt
                STA     _fcc_fpr0
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gt
                LDA     _fcc_fpr0+2
                STA     gt+2
                SEP     #$20
                MX      %10
                LDA     gt+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gt
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #22
                BNE     *+5
                BRL     _ptr_stride_struct_L27
                LDA     #28
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L27
                LDA     #2
                STA     15,S   ; fccstk d=0 b=15
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+0
                TAY
                LDA     _fcc_ptr+2
                STA     root+2
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     17,S   ; fccstk d=2 b=15
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                TAX
                TXA
                CMP     #12
                BNE     *+5
                BRL     _ptr_stride_struct_L28
                LDA     #29
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L28
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+0
                TAY
                LDA     _fcc_ptr+2
                STA     root+2
                TYA
                LDA     root+0
                PHA
                LDA     17,S   ; fccstk d=2 b=15
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     root+0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #root
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
                TAX
                TXA
                CMP     #12
                BNE     *+5
                BRL     _ptr_stride_struct_L29
                LDA     #30
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L29
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     other+0
                TAY
                LDA     _fcc_ptr+2
                STA     other+2
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     17,S   ; fccstk d=2 b=15
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
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
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #12
                BNE     *+5
                BRL     _ptr_stride_struct_L30
                LDA     #31
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L30
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gr
                LDA     _fcc_fpr0+2
                STA     gr+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gr
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_fpr0
                STA     17,S   ; fccstk d=0 b=17
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     17,S   ; fccstk d=2 b=15
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gr
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #12
                BNE     *+5
                BRL     _ptr_stride_struct_L31
                LDA     #32
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L31
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+8
                TAY
                LDA     _fcc_ptr+2
                STA     root+10
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     17,S   ; fccstk d=2 b=15
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                LDY     #8
                STA     [_fcc_fpr0],Y
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #22
                BNE     *+5
                BRL     _ptr_stride_struct_L32
                LDA     #33
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L32
                LDA     #2
                STA     21,S   ; fccstk d=0 b=21
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+0
                TAY
                LDA     _fcc_ptr+2
                STA     root+2
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     23,S   ; fccstk d=2 b=21
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                TAX
                TXA
                CMP     #10
                BNE     *+5
                BRL     _ptr_stride_struct_L33
                LDA     #34
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L33
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+0
                TAY
                LDA     _fcc_ptr+2
                STA     root+2
                TYA
                LDA     root+0
                PHA
                LDA     23,S   ; fccstk d=2 b=21
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                STA     root+0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #root
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
                TAX
                TXA
                CMP     #10
                BNE     *+5
                BRL     _ptr_stride_struct_L34
                LDA     #35
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L34
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     other+0
                TAY
                LDA     _fcc_ptr+2
                STA     other+2
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     23,S   ; fccstk d=2 b=21
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
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
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #10
                BNE     *+5
                BRL     _ptr_stride_struct_L35
                LDA     #36
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L35
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     gr
                LDA     _fcc_fpr0+2
                STA     gr+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gr
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     25,S   ; fccstk d=0 b=25
                LDA     _fcc_fpr0
                STA     23,S   ; fccstk d=0 b=23
                LDA     25,S   ; fccstk d=0 b=25
                STA     _fcc_fpr0+2
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     23,S   ; fccstk d=2 b=21
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     gr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gr
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #10
                BNE     *+5
                BRL     _ptr_stride_struct_L36
                LDA     #37
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L36
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #2
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+8
                TAY
                LDA     _fcc_ptr+2
                STA     root+10
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     #1
                ASL
                INC
                ASL
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                LDY     #8
                STA     [_fcc_fpr0],Y
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #21
                BNE     *+5
                BRL     _ptr_stride_struct_L37
                LDA     #38
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L37
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     53,S   ; fccstk d=0 b=53
                LDA     _fcc_ptr+2
                STA     55,S   ; fccstk d=0 b=55
                LDA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #52
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CLC
                ADC     #4
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #52
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
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L38
                LDA     #39
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L38
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     53,S   ; fccstk d=0 b=53
                LDA     _fcc_ptr+2
                STA     55,S   ; fccstk d=0 b=55
                LDA     53,S   ; fccstk d=0 b=53
                PHA
                LDA     #2
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     53,S   ; fccstk d=0 b=53
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #52
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
                TAX
                TXA
                CMP     #12
                BNE     *+5
                BRL     _ptr_stride_struct_L39
                LDA     #40
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L39
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     53,S   ; fccstk d=0 b=53
                LDA     _fcc_ptr+2
                STA     55,S   ; fccstk d=0 b=55
                LDA     53,S   ; fccstk d=0 b=53
                PHA
                LDA     #2
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                STA     53,S   ; fccstk d=0 b=53
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #52
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
                TAX
                TXA
                CMP     #10
                BNE     *+5
                BRL     _ptr_stride_struct_L40
                LDA     #41
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L40
                LDA     #iv
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #70
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #iv
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #71
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #iv
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #72
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_tmp_b
                LDA     #174
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #60
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b1
                STA     _fcc_fpr0
                LDA     #1
                STA     _fcc_tmp_b
                LDA     #174
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #61
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b1
                STA     _fcc_fpr0
                LDA     #2
                STA     _fcc_tmp_b
                LDA     #174
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #62
                STA     [_fcc_fpr0]
                LDA     #2
                STA     27,S   ; fccstk d=0 b=27
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_tmp_b
                LDA     #174
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     gb
                LDA     _fcc_fpr0+2
                STA     gb+2
                SEP     #$20
                MX      %10
                LDA     gb+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gb
                CLC
                ADC     #174
                STA     gb
                TAY
                LDA     _fcc_ptr+2
                STA     gb+2
                TYA
                SEP     #$20
                MX      %10
                LDA     gb+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gb
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #61
                BNE     *+5
                BRL     _ptr_stride_struct_L41
                LDA     #43
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L41
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_tmp_b
                LDA     #174
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     gb
                LDA     _fcc_fpr0+2
                STA     gb+2
                SEP     #$20
                MX      %10
                LDA     gb+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gb
                STA     _fcc_fpr0
                LDA     #1
                STA     _fcc_tmp_b
                LDA     #174
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     gb
                LDA     _fcc_fpr0+2
                STA     gb+2
                SEP     #$20
                MX      %10
                LDA     gb+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gb
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #61
                BNE     *+5
                BRL     _ptr_stride_struct_L42
                LDA     #44
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L42
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_tmp_b
                LDA     #174
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     gb
                LDA     _fcc_fpr0+2
                STA     gb+2
                SEP     #$20
                MX      %10
                LDA     gb+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gb
                STA     _fcc_fpr0
                LDA     27,S   ; fccstk d=0 b=27
                STA     _fcc_tmp_b
                LDA     #174
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     gb
                LDA     _fcc_fpr0+2
                STA     gb+2
                SEP     #$20
                MX      %10
                LDA     gb+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gb
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #62
                BNE     *+5
                BRL     _ptr_stride_struct_L43
                LDA     #45
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L43
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b1
                STA     _fcc_fpr0
                LDA     #2
                STA     _fcc_tmp_b
                LDA     #174
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     gb
                LDA     _fcc_fpr0+2
                STA     gb+2
                SEP     #$20
                MX      %10
                LDA     gb+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gb
                STA     _fcc_fpr0
                LDA     27,S   ; fccstk d=0 b=27
                STA     _fcc_tmp_b
                LDA     #174
                JSR     _fcc_mul16
                STA     _fcc_tmp_b
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_tmp_b
                STA     gb
                LDA     _fcc_fpr0+2
                STA     gb+2
                SEP     #$20
                MX      %10
                LDA     gb+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gb
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #60
                BNE     *+5
                BRL     _ptr_stride_struct_L44
                LDA     #46
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L44
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_tmp_b
                LDA     #174
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+12
                TAY
                LDA     _fcc_ptr+2
                STA     root+14
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     29,S   ; fccstk d=2 b=27
                STA     _fcc_tmp_b
                LDA     #174
                JSR     _fcc_mul16
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                LDY     #12
                STA     [_fcc_fpr0],Y
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #62
                BNE     *+5
                BRL     _ptr_stride_struct_L45
                LDA     #47
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L45
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+0
                TAY
                LDA     _fcc_ptr+2
                STA     root+2
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bump
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L46
                LDA     #48
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L46
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+0
                TAY
                LDA     _fcc_ptr+2
                STA     root+2
                TYA
                LDA     root+0
                PHA
                FGX2_FARCALL bump
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     root+0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #root
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
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L47
                LDA     #49
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L47
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     other+0
                TAY
                LDA     _fcc_ptr+2
                STA     other+2
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bump
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
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
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L48
                LDA     #50
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L48
                LDA     #2
                STA     29,S   ; fccstk d=0 b=29
                LDA     #parr
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
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
                LDA     #parr
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     [_fcc_ptr]
                PHA
                LDA     #1
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #0
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    parr+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    parr,X
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L49
                LDA     #51
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L49
                LDA     #parr
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
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
                LDA     #parr
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
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     [_fcc_ptr]
                PHA
                LDA     33,S   ; fccstk d=4 b=29
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #1
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    parr+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    parr,X
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #12
                BNE     *+5
                BRL     _ptr_stride_struct_L50
                LDA     #52
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L50
                LDA     #parr
                PHA
                LDA     #2
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
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
                LDA     #parr
                PHA
                LDA     #2
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     [_fcc_ptr]
                PHA
                LDA     33,S   ; fccstk d=4 b=29
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #2
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    parr+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    parr,X
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #10
                BNE     *+5
                BRL     _ptr_stride_struct_L51
                LDA     #53
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L51
                LDA     #tarr
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
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
                LDA     #tarr
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     [_fcc_ptr]
                PHA
                LDA     #1
                ASL
                INC
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #0
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    tarr+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    tarr,X
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #21
                BNE     *+5
                BRL     _ptr_stride_struct_L52
                LDA     #54
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L52
                LDA     #tarr
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
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
                LDA     #tarr
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
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     [_fcc_ptr]
                PHA
                LDA     33,S   ; fccstk d=4 b=29
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #1
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    tarr+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    tarr,X
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #22
                BNE     *+5
                BRL     _ptr_stride_struct_L53
                LDA     #55
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L53
                LDA     #iarr
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #iv
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
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
                LDA     #iarr
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     [_fcc_ptr]
                PHA
                LDA     #1
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #0
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    iarr+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    iarr,X
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #71
                BNE     *+5
                BRL     _ptr_stride_struct_L54
                LDA     #56
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L54
                LDA     #iarr
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #iv
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
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
                LDA     #iarr
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
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     [_fcc_ptr]
                PHA
                LDA     33,S   ; fccstk d=4 b=29
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #1
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    iarr+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    iarr,X
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #72
                BNE     *+5
                BRL     _ptr_stride_struct_L55
                LDA     #57
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L55
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #parr
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     ppg
                LDA     _fcc_fpr0+2
                STA     ppg+2
                LDA     #parr
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
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
                SEP     #$20
                MX      %10
                LDA     ppg+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     ppg
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #1
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     #0
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    parr+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    parr,X
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L56
                LDA     #58
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L56
                LDA     #1
                STA     31,S   ; fccstk d=0 b=31
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+8
                TAY
                LDA     _fcc_ptr+2
                STA     root+10
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     35,S   ; fccstk d=0 b=35
                LDA     _fcc_fpr0
                STA     33,S   ; fccstk d=0 b=33
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_fpr0+2
                LDA     33,S   ; fccstk d=0 b=33
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr1
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _ptr_stride_struct_L58
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _ptr_stride_struct_L58
                LDA     #0
                BRL     _ptr_stride_struct_L59
_ptr_stride_struct_L58
                LDA     #1
_ptr_stride_struct_L59
                CMP     #0
                BNE     *+5
                BRL     _ptr_stride_struct_L57
                LDA     #59
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L57
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     35,S   ; fccstk d=0 b=35
                LDA     _fcc_fpr0
                STA     33,S   ; fccstk d=0 b=33
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_fpr0+2
                LDA     33,S   ; fccstk d=0 b=33
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #21
                BNE     *+5
                BRL     _ptr_stride_struct_L60
                LDA     #60
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L60
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     31,S   ; fccstk d=0 b=31
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     35,S   ; fccstk d=0 b=35
                LDA     _fcc_fpr0
                STA     33,S   ; fccstk d=0 b=33
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_fpr0+2
                LDA     33,S   ; fccstk d=0 b=33
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr1
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _ptr_stride_struct_L62
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _ptr_stride_struct_L62
                LDA     #0
                BRL     _ptr_stride_struct_L63
_ptr_stride_struct_L62
                LDA     #1
_ptr_stride_struct_L63
                CMP     #0
                BNE     *+5
                BRL     _ptr_stride_struct_L61
                LDA     #61
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L61
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #2
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     35,S   ; fccstk d=0 b=35
                LDA     _fcc_fpr0
                STA     33,S   ; fccstk d=0 b=33
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_fpr0+2
                LDA     33,S   ; fccstk d=0 b=33
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #22
                BNE     *+5
                BRL     _ptr_stride_struct_L64
                LDA     #62
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L64
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+0
                TAY
                LDA     _fcc_ptr+2
                STA     root+2
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     39,S   ; fccstk d=0 b=39
                LDA     _fcc_fpr0
                STA     37,S   ; fccstk d=0 b=37
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_fpr0+2
                LDA     37,S   ; fccstk d=0 b=37
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #f4
                STA     _fcc_fpr1
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _ptr_stride_struct_L66
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _ptr_stride_struct_L66
                LDA     #0
                BRL     _ptr_stride_struct_L67
_ptr_stride_struct_L66
                LDA     #1
_ptr_stride_struct_L67
                CMP     #0
                BNE     *+5
                BRL     _ptr_stride_struct_L65
                LDA     #63
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L65
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                LDA     31,S   ; fccstk d=0 b=31
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     39,S   ; fccstk d=0 b=39
                LDA     _fcc_fpr0
                STA     37,S   ; fccstk d=0 b=37
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_fpr0+2
                LDA     37,S   ; fccstk d=0 b=37
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _ptr_stride_struct_L68
                LDA     #64
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L68
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     other+8
                TAY
                LDA     _fcc_ptr+2
                STA     other+10
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #2
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     35,S   ; fccstk d=0 b=35
                LDA     _fcc_fpr0
                STA     33,S   ; fccstk d=0 b=33
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_fpr0+2
                LDA     33,S   ; fccstk d=0 b=33
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr1
                LDA     #2
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _ptr_stride_struct_L70
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _ptr_stride_struct_L70
                LDA     #0
                BRL     _ptr_stride_struct_L71
_ptr_stride_struct_L70
                LDA     #1
_ptr_stride_struct_L71
                CMP     #0
                BNE     *+5
                BRL     _ptr_stride_struct_L69
                LDA     #65
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L69
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #2
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     35,S   ; fccstk d=0 b=35
                LDA     _fcc_fpr0
                STA     33,S   ; fccstk d=0 b=33
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_fpr0+2
                LDA     33,S   ; fccstk d=0 b=33
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #22
                BNE     *+5
                BRL     _ptr_stride_struct_L72
                LDA     #66
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L72
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     gh+8
                TAY
                LDA     _fcc_ptr+2
                STA     gh+10
                TYA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     35,S   ; fccstk d=0 b=35
                LDA     _fcc_fpr0
                STA     33,S   ; fccstk d=0 b=33
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_fpr0+2
                LDA     33,S   ; fccstk d=0 b=33
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr1
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _ptr_stride_struct_L74
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _ptr_stride_struct_L74
                LDA     #0
                BRL     _ptr_stride_struct_L75
_ptr_stride_struct_L74
                LDA     #1
_ptr_stride_struct_L75
                CMP     #0
                BNE     *+5
                BRL     _ptr_stride_struct_L73
                LDA     #67
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L73
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     31,S   ; fccstk d=0 b=31
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     35,S   ; fccstk d=0 b=35
                LDA     _fcc_fpr0
                STA     33,S   ; fccstk d=0 b=33
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_fpr0+2
                LDA     33,S   ; fccstk d=0 b=33
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #21
                BNE     *+5
                BRL     _ptr_stride_struct_L76
                LDA     #68
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L76
                LDA     #2
                STA     41,S   ; fccstk d=0 b=41
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_tmp_b
                LDA     #174
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+12
                TAY
                LDA     _fcc_ptr+2
                STA     root+14
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #1
                STA     _fcc_tmp_b
                LDA     #174
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     45,S   ; fccstk d=0 b=45
                LDA     _fcc_fpr0
                STA     43,S   ; fccstk d=0 b=43
                LDA     45,S   ; fccstk d=0 b=45
                STA     _fcc_fpr0+2
                LDA     43,S   ; fccstk d=0 b=43
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #b1
                STA     _fcc_fpr1
                LDA     #1
                STA     _fcc_tmp_b
                LDA     #174
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _ptr_stride_struct_L78
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _ptr_stride_struct_L78
                LDA     #0
                BRL     _ptr_stride_struct_L79
_ptr_stride_struct_L78
                LDA     #1
_ptr_stride_struct_L79
                CMP     #0
                BNE     *+5
                BRL     _ptr_stride_struct_L77
                LDA     #69
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L77
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     41,S   ; fccstk d=0 b=41
                STA     _fcc_tmp_b
                LDA     #174
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     45,S   ; fccstk d=0 b=45
                LDA     _fcc_fpr0
                STA     43,S   ; fccstk d=0 b=43
                LDA     45,S   ; fccstk d=0 b=45
                STA     _fcc_fpr0+2
                LDA     43,S   ; fccstk d=0 b=43
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #62
                BNE     *+5
                BRL     _ptr_stride_struct_L80
                LDA     #70
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L80
                LDA     #1
                STA     47,S   ; fccstk d=0 b=47
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #root
                STA     gp
                LDA     _fcc_fpr0+2
                STA     gp+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     root+8
                TAY
                LDA     _fcc_ptr+2
                STA     root+10
                TYA
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     51,S   ; fccstk d=0 b=51
                LDA     _fcc_fpr0
                STA     49,S   ; fccstk d=0 b=49
                LDA     51,S   ; fccstk d=0 b=51
                STA     _fcc_fpr0+2
                LDA     49,S   ; fccstk d=0 b=49
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr1
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _ptr_stride_struct_L82
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _ptr_stride_struct_L82
                LDA     #0
                BRL     _ptr_stride_struct_L83
_ptr_stride_struct_L82
                LDA     #1
_ptr_stride_struct_L83
                CMP     #0
                BNE     *+5
                BRL     _ptr_stride_struct_L81
                LDA     #71
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L81
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     47,S   ; fccstk d=0 b=47
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     51,S   ; fccstk d=0 b=51
                LDA     _fcc_fpr0
                STA     49,S   ; fccstk d=0 b=49
                LDA     51,S   ; fccstk d=0 b=51
                STA     _fcc_fpr0+2
                LDA     49,S   ; fccstk d=0 b=49
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #21
                BNE     *+5
                BRL     _ptr_stride_struct_L84
                LDA     #72
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L84
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     77,S   ; fccstk d=0 b=77
                LDA     _fcc_ptr+2
                STA     79,S   ; fccstk d=0 b=79
                LDA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #68
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     51,S   ; fccstk d=0 b=51
                LDA     _fcc_fpr0
                STA     49,S   ; fccstk d=0 b=49
                LDA     51,S   ; fccstk d=0 b=51
                STA     _fcc_fpr0+2
                LDA     49,S   ; fccstk d=0 b=49
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #t3
                STA     _fcc_fpr1
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _ptr_stride_struct_L86
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _ptr_stride_struct_L86
                LDA     #0
                BRL     _ptr_stride_struct_L87
_ptr_stride_struct_L86
                LDA     #1
_ptr_stride_struct_L87
                CMP     #0
                BNE     *+5
                BRL     _ptr_stride_struct_L85
                LDA     #73
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L85
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #68
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     47,S   ; fccstk d=0 b=47
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     51,S   ; fccstk d=0 b=51
                LDA     _fcc_fpr0
                STA     49,S   ; fccstk d=0 b=49
                LDA     51,S   ; fccstk d=0 b=51
                STA     _fcc_fpr0+2
                LDA     49,S   ; fccstk d=0 b=49
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #21
                BNE     *+5
                BRL     _ptr_stride_struct_L88
                LDA     #74
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_stride_struct_L88
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
main_FRAMESIZE   EQU     84
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
