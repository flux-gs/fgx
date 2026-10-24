                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ldiv_sweep.c
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
                STA     _fcc_img2
                LDA     #0
                STA     _fcc_img0
_ldiv_sweep_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #14
                BVC     _ldiv_sweep_L3
                EOR     #$8000
_ldiv_sweep_L3
                BMI     *+5
                BRL     _ldiv_sweep_L2
                LDA     #0
                STA     _fcc_img1
_ldiv_sweep_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img1
                TAX
                SEC
                SBC     #14
                BVC     _ldiv_sweep_L7
                EOR     #$8000
_ldiv_sweep_L7
                BMI     *+5
                BRL     _ldiv_sweep_L6
                LDA     _fcc_img0
                ASL
                ASL
                TAX
                LDA:    un+2,X
                STA     _fcc_long_hi
                LDA:    un,X
                STA     _fcc_img11
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img12
                TYA
                LDA     _fcc_img1
                ASL
                ASL
                TAX
                LDA:    ud+2,X
                STA     _fcc_long_hi
                LDA:    ud,X
                STA     _fcc_img3
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img4
                TYA
                LDA     _fcc_img12
                STA     _fcc_long_hi
                LDA     _fcc_img11
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img4
                STA     _fcc_long_hi
                LDA     _fcc_img3
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_divu
                STA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                STA     17,S   ; fccstk d=0 b=17
                TYA
                LDA     _fcc_img12
                STA     _fcc_long_hi
                LDA     _fcc_img11
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img4
                STA     _fcc_long_hi
                LDA     _fcc_img3
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_modu
                STA     _fcc_img13
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img14
                TYA
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img4
                STA     _fcc_long_hi
                LDA     _fcc_img3
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img14
                STA     _fcc_long_hi
                LDA     _fcc_img13
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
                LDA     _fcc_img12
                STA     _fcc_long_hi
                LDA     _fcc_img11
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _ldiv_sweep_L8
                INC     _fcc_img2
_ldiv_sweep_L8
                LDA     _fcc_img14
                STA     _fcc_long_hi
                LDA     _fcc_img13
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img4
                STA     _fcc_long_hi
                LDA     _fcc_img3
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_geu
                CMP     #0
                BEQ     _ldiv_sweep_L9
                INC     _fcc_img2
_ldiv_sweep_L9
_ldiv_sweep_L5
                INC     _fcc_img1
                BRL     _ldiv_sweep_L4
_ldiv_sweep_L6
_ldiv_sweep_L1
                INC     _fcc_img0
                BRL     _ldiv_sweep_L0
_ldiv_sweep_L2
                LDA     #0
                STA     _fcc_img0
_ldiv_sweep_L10
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #11
                BVC     _ldiv_sweep_L13
                EOR     #$8000
_ldiv_sweep_L13
                BMI     *+5
                BRL     _ldiv_sweep_L12
                LDA     #0
                STA     _fcc_img1
_ldiv_sweep_L14
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img1
                TAX
                SEC
                SBC     #9
                BVC     _ldiv_sweep_L17
                EOR     #$8000
_ldiv_sweep_L17
                BMI     *+5
                BRL     _ldiv_sweep_L16
                LDA     _fcc_img0
                ASL
                ASL
                TAX
                LDA:    sn+2,X
                STA     _fcc_long_hi
                LDA:    sn,X
                STA     _fcc_img9
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img10
                TYA
                LDA     _fcc_img1
                ASL
                ASL
                TAX
                LDA:    sd+2,X
                STA     _fcc_long_hi
                LDA:    sd,X
                STA     _fcc_img5
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img6
                TYA
                LDA     _fcc_img10
                STA     _fcc_long_hi
                LDA     _fcc_img9
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img6
                STA     _fcc_long_hi
                LDA     _fcc_img5
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_divs
                STA     31,S   ; fccstk d=0 b=31
                TAY
                LDA     _fcc_long_hi
                STA     33,S   ; fccstk d=0 b=33
                TYA
                LDA     _fcc_img10
                STA     _fcc_long_hi
                LDA     _fcc_img9
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img6
                STA     _fcc_long_hi
                LDA     _fcc_img5
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     _fcc_img7
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img8
                TYA
                LDA     33,S   ; fccstk d=0 b=33
                STA     _fcc_long_hi
                LDA     31,S   ; fccstk d=0 b=31
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img6
                STA     _fcc_long_hi
                LDA     _fcc_img5
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img8
                STA     _fcc_long_hi
                LDA     _fcc_img7
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
                LDA     _fcc_img10
                STA     _fcc_long_hi
                LDA     _fcc_img9
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _ldiv_sweep_L18
                INC     _fcc_img2
_ldiv_sweep_L18
                LDA     _fcc_img8
                STA     _fcc_long_hi
                LDA     _fcc_img7
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _ldiv_sweep_L19
                LDA     _fcc_img8
                STA     _fcc_long_hi
                LDA     _fcc_img7
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                PHA
                LDA     _fcc_img10
                STA     _fcc_long_hi
                LDA     _fcc_img9
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _ldiv_sweep_L19
                INC     _fcc_img2
_ldiv_sweep_L19
                LDA     _fcc_img8
                STA     _fcc_long_hi
                LDA     _fcc_img7
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                CMP     #0
                BEQ     _ldiv_sweep_L21
                LDA     _fcc_img8
                STA     _fcc_long_hi
                LDA     _fcc_img7
                JSR     _fcc_long_neg
                BRA     _ldiv_sweep_L22
_ldiv_sweep_L21
                LDA     _fcc_img8
                STA     _fcc_long_hi
                LDA     _fcc_img7
_ldiv_sweep_L22
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img6
                STA     _fcc_long_hi
                LDA     _fcc_img5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                CMP     #0
                BEQ     _ldiv_sweep_L23
                LDA     _fcc_img6
                STA     _fcc_long_hi
                LDA     _fcc_img5
                JSR     _fcc_long_neg
                BRA     _ldiv_sweep_L24
_ldiv_sweep_L23
                LDA     _fcc_img6
                STA     _fcc_long_hi
                LDA     _fcc_img5
_ldiv_sweep_L24
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ges
                CMP     #0
                BEQ     _ldiv_sweep_L20
                INC     _fcc_img2
_ldiv_sweep_L20
_ldiv_sweep_L15
                INC     _fcc_img1
                BRL     _ldiv_sweep_L14
_ldiv_sweep_L16
_ldiv_sweep_L11
                INC     _fcc_img0
                BRL     _ldiv_sweep_L10
_ldiv_sweep_L12
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$000A
                STA     _fcc_img3
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img4
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img4
                STA     _fcc_long_hi
                LDA     _fcc_img3
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_divu
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$1999
                STA     _fcc_long_hi
                LDA     #$9999
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _ldiv_sweep_L25
                INC     _fcc_img2
_ldiv_sweep_L25
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img4
                STA     _fcc_long_hi
                LDA     _fcc_img3
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_modu
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _ldiv_sweep_L26
                INC     _fcc_img2
_ldiv_sweep_L26
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$5180
                STA     _fcc_img3
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img4
                TYA
                LDA     #$670E
                STA     _fcc_long_hi
                LDA     #$7240
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img4
                STA     _fcc_long_hi
                LDA     _fcc_img3
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_divu
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$4E2B
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _ldiv_sweep_L27
                INC     _fcc_img2
_ldiv_sweep_L27
                LDA     #$670E
                STA     _fcc_long_hi
                LDA     #$7240
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img4
                STA     _fcc_long_hi
                LDA     _fcc_img3
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_modu
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$C1C0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _ldiv_sweep_L28
                INC     _fcc_img2
_ldiv_sweep_L28
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$003C
                STA     _fcc_img5
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img6
                TYA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$517F
                JSR     _fcc_long_neg
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img6
                STA     _fcc_long_hi
                LDA     _fcc_img5
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_divs
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$059F
                JSR     _fcc_long_neg
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _ldiv_sweep_L29
                INC     _fcc_img2
_ldiv_sweep_L29
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$517F
                JSR     _fcc_long_neg
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img6
                STA     _fcc_long_hi
                LDA     _fcc_img5
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$003B
                JSR     _fcc_long_neg
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _ldiv_sweep_L30
                INC     _fcc_img2
_ldiv_sweep_L30
                LDA     _fcc_img2
                BNE     _ldiv_sweep_L31
                LDA     #42
                BRA     _ldiv_sweep_L32
_ldiv_sweep_L31
                LDA     _fcc_img2
_ldiv_sweep_L32
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     38
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
