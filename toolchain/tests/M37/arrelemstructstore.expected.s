                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from arrelemstructstore.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _arrelemstructstore_seed
_arrelemstructstore_seed            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_arrelemstructstore_seed_FRAMESIZE
                DO      _arrelemstructstore_seed_STKGUARD
                BCC     _arrelemstructstore_seed_stkovf
                CMP     _fcc_stkfloor
                BCS     _arrelemstructstore_seed_stkok
_arrelemstructstore_seed_stkovf       JMP     _fcc_stkoflow
                FIN
_arrelemstructstore_seed_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #4369
                STA     g_src+0
                LDA     #$2222
                STA     _fcc_long_hi
                LDA     #$3333
                STA     g_src+2
                TAY
                LDA     _fcc_long_hi
                STA     g_src+4
                TYA
                LDA     #17476
                STA     g_src+6
                LDA     #0
                STA     g_zero+0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     g_zero+2
                TAY
                LDA     _fcc_long_hi
                STA     g_zero+4
                TYA
                LDA     #0
                STA     g_zero+6
                LDA     #0
                STA     _fcc_img0
_arrelemstructstore_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #3
                BVC     _arrelemstructstore_L3
                EOR     #$8000
_arrelemstructstore_L3
                BMI     *+5
                BRL     _arrelemstructstore_L2
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #49374
                STA     [_fcc_fpr0]
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     #48879
                STA     [_fcc_fpr0]
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #36864
                CLC
                ADC     _fcc_img0
                STA     [_fcc_fpr0]
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #$000A
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img0
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
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     #45056
                CLC
                ADC     _fcc_img0
                STA     [_fcc_fpr0]
_arrelemstructstore_L1
                INC     _fcc_img0
                BRL     _arrelemstructstore_L0
_arrelemstructstore_L2
                LDA     #61453
                STA     gt+36
                LDA     #65261
                STA     gt+46
                LDA     #30583
                STA     gt+38
                LDA     #$8888
                STA     _fcc_long_hi
                LDA     #$9999
                STA     gt+40
                TAY
                LDA     _fcc_long_hi
                STA     gt+42
                TYA
                LDA     #26214
                STA     gt+44
                LDA     #0
                STA     g_dst+0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     g_dst+2
                TAY
                LDA     _fcc_long_hi
                STA     g_dst+4
                TYA
                LDA     #0
                STA     g_dst+6
                TAY
                TSC
                CLC
                ADC     #_arrelemstructstore_seed_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrelemstructstore_seed_FRAMESIZE   EQU     2
_arrelemstructstore_seed_STKGUARD    EQU     0
                FGX2_EXPORT _arrelemstructstore_landed
_arrelemstructstore_landed            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_arrelemstructstore_landed_FRAMESIZE
                DO      _arrelemstructstore_landed_STKGUARD
                BCC     _arrelemstructstore_landed_stkovf
                CMP     _fcc_stkfloor
                BCS     _arrelemstructstore_landed_stkok
_arrelemstructstore_landed_stkovf       JMP     _fcc_stkoflow
                FIN
_arrelemstructstore_landed_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_arrelemstructstore_landed_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_arrelemstructstore_landed_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_arrelemstructstore_landed_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_arrelemstructstore_landed_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_arrelemstructstore_landed_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_arrelemstructstore_landed_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #4369
                BEQ     _arrelemstructstore_L4
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #_arrelemstructstore_landed_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrelemstructstore_L4
                DO      8+_arrelemstructstore_landed_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_arrelemstructstore_landed_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_arrelemstructstore_landed_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_arrelemstructstore_landed_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_arrelemstructstore_landed_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_arrelemstructstore_landed_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$2222
                STA     _fcc_long_hi
                LDA     #$3333
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
                BEQ     _arrelemstructstore_L5
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #_arrelemstructstore_landed_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrelemstructstore_L5
                DO      8+_arrelemstructstore_landed_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_arrelemstructstore_landed_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_arrelemstructstore_landed_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_arrelemstructstore_landed_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_arrelemstructstore_landed_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_arrelemstructstore_landed_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #17476
                BEQ     _arrelemstructstore_L6
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #_arrelemstructstore_landed_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrelemstructstore_L6
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_arrelemstructstore_landed_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrelemstructstore_landed_FRAMESIZE   EQU     0
_arrelemstructstore_landed_STKGUARD    EQU     0
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
                LDA     #gt
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     gp
                LDA     _fcc_fpr0+2
                STA     gp+2
                FGX2_FARCALL _arrelemstructstore_seed
                LDA     #1
                STA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #g_src
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #6
_arrelemstructstore_L7
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _arrelemstructstore_L7
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt+14
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _arrelemstructstore_landed
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BEQ     _arrelemstructstore_L8
                LDA     #1
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt+14
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _arrelemstructstore_landed
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
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
_arrelemstructstore_L8
                LDA     gt+12
                TAX
                CMP     #49374
                BEQ     _arrelemstructstore_L9
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
_arrelemstructstore_L9
                LDA     gt+22
                TAX
                CMP     #48879
                BEQ     _arrelemstructstore_L10
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
_arrelemstructstore_L10
                LDA     gt+2
                TAX
                CMP     #36864
                BEQ     _arrelemstructstore_L11
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
_arrelemstructstore_L11
                LDA     gt+26
                TAX
                CMP     #36866
                BEQ     _arrelemstructstore_L12
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
_arrelemstructstore_L12
                FGX2_FARCALL _arrelemstructstore_seed
                LDA     #2
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #g_src
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #6
_arrelemstructstore_L13
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _arrelemstructstore_L13
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt+26
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _arrelemstructstore_landed
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BEQ     _arrelemstructstore_L14
                LDA     #10
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt+26
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _arrelemstructstore_landed
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
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
_arrelemstructstore_L14
                LDA     gt+24
                TAX
                CMP     #49374
                BEQ     _arrelemstructstore_L15
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
_arrelemstructstore_L15
                LDA     gt+34
                TAX
                CMP     #48879
                BEQ     _arrelemstructstore_L16
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
_arrelemstructstore_L16
                LDA     gt+14
                TAX
                CMP     #36865
                BEQ     _arrelemstructstore_L17
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
_arrelemstructstore_L17
                FGX2_FARCALL _arrelemstructstore_seed
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #g_dst
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                CLC
                ADC     #2
                STA     _fcc_fpr1
                LDY     #6
_arrelemstructstore_L18
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _arrelemstructstore_L18
                LDA     g_dst+0
                TAX
                CMP     #36864
                BEQ     _arrelemstructstore_L19
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
_arrelemstructstore_L19
                LDA     g_dst+4
                STA     _fcc_long_hi
                LDA     g_dst+2
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$000A
                STA     _fcc_long_hi
                LDA     #$0000
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
                BEQ     _arrelemstructstore_L20
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
_arrelemstructstore_L20
                LDA     g_dst+6
                TAX
                CMP     #45056
                BEQ     _arrelemstructstore_L21
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
_arrelemstructstore_L21
                LDA     gt+2
                TAX
                CMP     #36864
                BEQ     _arrelemstructstore_L22
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
_arrelemstructstore_L22
                FGX2_FARCALL _arrelemstructstore_seed
                LDA     #2
                STA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #2
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt+2
                STA     _fcc_fpr1
                PLA
                LDY     #6
_arrelemstructstore_L23
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _arrelemstructstore_L23
                LDA     gt+26
                TAX
                CMP     #36864
                BEQ     _arrelemstructstore_L24
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
_arrelemstructstore_L24
                LDA     gt+30
                STA     _fcc_long_hi
                LDA     gt+28
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$000A
                STA     _fcc_long_hi
                LDA     #$0000
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
                BEQ     _arrelemstructstore_L25
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
_arrelemstructstore_L25
                LDA     gt+32
                TAX
                CMP     #45056
                BEQ     _arrelemstructstore_L26
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
_arrelemstructstore_L26
                LDA     gt+24
                TAX
                CMP     #49374
                BEQ     _arrelemstructstore_L27
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
_arrelemstructstore_L27
                LDA     gt+34
                TAX
                CMP     #48879
                BEQ     _arrelemstructstore_L28
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
_arrelemstructstore_L28
                LDA     gt+2
                TAX
                CMP     #36864
                BEQ     _arrelemstructstore_L29
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
_arrelemstructstore_L29
                LDA     gt+14
                TAX
                CMP     #36865
                BEQ     _arrelemstructstore_L30
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
_arrelemstructstore_L30
                FGX2_FARCALL _arrelemstructstore_seed
                LDA     #1
                STA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #g_zero
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #6
_arrelemstructstore_L31
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _arrelemstructstore_L31
                LDA     gt+14
                CMP     #0
                BEQ     _arrelemstructstore_L32
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
_arrelemstructstore_L32
                LDA     gt+18
                STA     _fcc_long_hi
                LDA     gt+16
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
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
                BEQ     _arrelemstructstore_L33
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
_arrelemstructstore_L33
                LDA     gt+20
                BEQ     _arrelemstructstore_L34
                LDA     #42
                TAX
                CLC
                ADC     #100
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrelemstructstore_L34
                LDA     gt+12
                TAX
                CMP     #49374
                BEQ     _arrelemstructstore_L35
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
_arrelemstructstore_L35
                LDA     gt+22
                TAX
                CMP     #48879
                BEQ     _arrelemstructstore_L36
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
_arrelemstructstore_L36
                LDA     gt+8
                TAX
                CMP     #45056
                BEQ     _arrelemstructstore_L37
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
_arrelemstructstore_L37
                LDA     gt+26
                TAX
                CMP     #36866
                BEQ     _arrelemstructstore_L38
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
_arrelemstructstore_L38
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
                FGX2_RELOC_COUNT 13
