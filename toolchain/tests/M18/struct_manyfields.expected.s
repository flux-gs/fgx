                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_manyfields.c
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #M
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_struct_manyfields_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                SEC
                SBC     #104
                BVC     _struct_manyfields_L3
                EOR     #$8000
_struct_manyfields_L3
                BPL     _struct_manyfields_L2
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     #0
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
_struct_manyfields_L1
                INC     _fcc_img0
                BRA     _struct_manyfields_L0
_struct_manyfields_L2
                LDA     #3
                SEP     #$20
                MX      %10
                STA     M+0
                REP     #$20
                MX      %00
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                STA     M+44
                TAY
                LDA     _fcc_long_hi
                STA     M+46
                TYA
                LDA     #5
                STA     M+82
                LDA     #9
                SEP     #$20
                MX      %10
                STA     M+88
                REP     #$20
                MX      %00
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$000B
                STA     M+92
                TAY
                LDA     _fcc_long_hi
                STA     M+94
                TYA
                LDA     #13
                STA     M+102
                LDA     M+0
                AND     #$00FF
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     M+46
                STA     _fcc_long_hi
                LDA     M+44
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     M+82
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     _fcc_img3
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img4
                TYA
                LDA     _fcc_img4
                STA     _fcc_long_hi
                LDA     _fcc_img3
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     M+88
                AND     #$00FF
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     M+94
                STA     _fcc_long_hi
                LDA     M+92
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     M+102
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     _fcc_img3
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img4
                TYA
                LDA     M+8
                AND     #$00FF
                BNE     _struct_manyfields_L5
                LDA     M+2
                BNE     _struct_manyfields_L5
                LDA     M+6
                STA     _fcc_long_hi
                LDA     M+4
                ORA     _fcc_long_hi
                BNE     _struct_manyfields_L5
                LDA     M+80
                AND     #$00FF
                BNE     _struct_manyfields_L5
                LDA     M+90
                BNE     _struct_manyfields_L5
                LDA     M+96
                BNE     _struct_manyfields_L5
                LDA     M+100
                BEQ     _struct_manyfields_L4
_struct_manyfields_L5
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_struct_manyfields_L4
                LDA     _fcc_img4
                STA     _fcc_long_hi
                LDA     _fcc_img3
                TAX
                SEC
                SBC     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
