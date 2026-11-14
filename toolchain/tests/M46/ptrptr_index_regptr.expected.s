                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptrptr_index_regptr.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT base
base            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #base_FRAMESIZE
                DO      base_STKGUARD
                BCC     base_stkovf
                CMP     _fcc_stkfloor
                BCS     base_stkok
base_stkovf       JMP     _fcc_stkoflow
                FIN
base_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                LDA     ofile+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     ofile
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptrptr_index_regptr_L1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptrptr_index_regptr_L1
                LDA     #1
                BRA     _ptrptr_index_regptr_L2
_ptrptr_index_regptr_L1
                LDA     #0
_ptrptr_index_regptr_L2
                CMP     #0
                BEQ     _ptrptr_index_regptr_L0
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #base_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrptr_index_regptr_L0
                SEP     #$20
                MX      %10
                LDA     ofile+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     ofile
                STA     _fcc_fpr0
                DO      6+base_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+base_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+base_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #base_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
base_FRAMESIZE   EQU     0
base_STKGUARD    EQU     0
                FGX2_EXPORT f
f            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img20
                TSC
                SEC
                SBC     #f_FRAMESIZE-10
                DO      f_STKGUARD
                BCC     f_stkovf
                CMP     _fcc_stkfloor
                BCS     f_stkok
f_stkovf       JMP     _fcc_stkoflow
                FIN
f_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+f_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img16
                DO      10+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+f_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img17
                STA     _fcc_ptr+2
                LDA     _fcc_img16
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _ptrptr_index_regptr_L5
                EOR     #$8000
_ptrptr_index_regptr_L5
                BPL     _ptrptr_index_regptr_L3
                LDA     _fcc_img17
                STA     _fcc_ptr+2
                LDA     _fcc_img16
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                LDX     #4
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _ptrptr_index_regptr_L6
                EOR     #$8000
_ptrptr_index_regptr_L6
                BMI     _ptrptr_index_regptr_L3
                SEP     #$20
                MX      %10
                LDA     pool_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     pool_p
                STA     _fcc_fpr0
                LDA     _fcc_img17
                STA     _fcc_ptr+2
                LDA     _fcc_img16
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                DEC
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                BRA     _ptrptr_index_regptr_L4
_ptrptr_index_regptr_L3
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
_ptrptr_index_regptr_L4
                LDA     _fcc_fpr0+2
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     _fcc_img17
                STA     _fcc_ptr+2
                LDA     _fcc_img16
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                BEQ     _ptrptr_index_regptr_L8
                BRL     _ptrptr_index_regptr_L7
_ptrptr_index_regptr_L8
                DO      6+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+f_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                FGX2_FARCALL base
                PLY
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptrptr_index_regptr_L11
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptrptr_index_regptr_L11
                LDA     #1
                BRA     _ptrptr_index_regptr_L12
_ptrptr_index_regptr_L11
                LDA     #0
_ptrptr_index_regptr_L12
                CMP     #0
                BEQ     *+5
                BRL     _ptrptr_index_regptr_L10
                LDA     _fcc_img17
                STA     _fcc_ptr+2
                LDA     _fcc_img16
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                BMI     _ptrptr_index_regptr_L10
                LDA     _fcc_img17
                STA     _fcc_ptr+2
                LDA     _fcc_img16
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                SEC
                SBC     #4
                BVC     _ptrptr_index_regptr_L13
                EOR     #$8000
_ptrptr_index_regptr_L13
                BPL     _ptrptr_index_regptr_L10
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     _fcc_img17
                STA     _fcc_ptr+2
                LDA     _fcc_img16
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                TAY
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                TYA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptrptr_index_regptr_L14
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptrptr_index_regptr_L14
                LDA     #1
                BRA     _ptrptr_index_regptr_L15
_ptrptr_index_regptr_L14
                LDA     #0
_ptrptr_index_regptr_L15
                CMP     #0
                BEQ     _ptrptr_index_regptr_L9
_ptrptr_index_regptr_L10
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #f_FRAMESIZE-10
                TCS
                BRL     f_bandx
_ptrptr_index_regptr_L9
                LDA     #0
                STA     _fcc_img20
_ptrptr_index_regptr_L16
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img20
                TAX
                SEC
                SBC     #4
                BVC     _ptrptr_index_regptr_L19
                EOR     #$8000
_ptrptr_index_regptr_L19
                BMI     *+5
                BRL     _ptrptr_index_regptr_L18
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     _fcc_img17
                STA     _fcc_ptr+2
                LDA     _fcc_img16
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                TAY
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                TYA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     pool_p+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     pool_p
                STA     _fcc_fpr1
                LDA     _fcc_img20
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptrptr_index_regptr_L21
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptrptr_index_regptr_L21
                LDA     #1
                BRA     _ptrptr_index_regptr_L22
_ptrptr_index_regptr_L21
                LDA     #0
_ptrptr_index_regptr_L22
                CMP     #0
                BEQ     _ptrptr_index_regptr_L20
                LDA     _fcc_img20
                TAX
                INC
                TAY
                TSC
                CLC
                ADC     #f_FRAMESIZE-10
                TCS
                BRA     f_bandx
_ptrptr_index_regptr_L20
_ptrptr_index_regptr_L17
                INC     _fcc_img20
                BRL     _ptrptr_index_regptr_L16
_ptrptr_index_regptr_L18
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #f_FRAMESIZE-10
                TCS
                BRA     f_bandx
_ptrptr_index_regptr_L7
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptrptr_index_regptr_L23
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptrptr_index_regptr_L23
                LDA     #0
                BRA     _ptrptr_index_regptr_L24
_ptrptr_index_regptr_L23
                LDA     #1
_ptrptr_index_regptr_L24
                TAY
                TSC
                CLC
                ADC     #f_FRAMESIZE-10
                TCS
f_bandx
                PLA
                STA     _fcc_img20
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
f_FRAMESIZE   EQU     26
f_STKGUARD    EQU     0
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
                LDA     #pool
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     pool_p
                LDA     _fcc_fpr0+2
                STA     pool_p+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #tab
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     ofile
                LDA     _fcc_fpr0+2
                STA     ofile+2
                LDA     #tab
                PHA
                LDA     #2
                INC
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
                LDA     #pool+48
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
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #0
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                STA     [_fcc_ptr]
                PLA
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #1
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                STA     [_fcc_ptr]
                PLA
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL f
                PLY
                PLY
                PLY
                TAX
                CMP     #3
                BNE     _ptrptr_index_regptr_L25
                LDA     #42
                BRA     _ptrptr_index_regptr_L26
_ptrptr_index_regptr_L25
                LDA     #1
_ptrptr_index_regptr_L26
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
                FGX2_RELOC_COUNT 6
