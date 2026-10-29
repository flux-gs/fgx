                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptr_held.c
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
                DO      6+bump_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bump_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bump_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                INC
                TAY
                TSC
                CLC
                ADC     #bump_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bump_FRAMESIZE   EQU     0
bump_STKGUARD    EQU     0
                FGX2_EXPORT sum
sum            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                TSC
                SEC
                SBC     #sum_FRAMESIZE-6
                DO      sum_STKGUARD
                BCC     sum_stkovf
                CMP     _fcc_stkfloor
                BCS     sum_stkok
sum_stkovf       JMP     _fcc_stkoflow
                FIN
sum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img16
                DO      8+sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sum_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img17
                LDA     #0
                STA     _fcc_img18
_ptr_held_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _ptr_held_L1
                LDA     _fcc_img18
                PHA
                LDA     [_fcc_img16]
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                PHA
                LDA     [_fcc_img16]
                PHA
                FGX2_FARCALL bump
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img18
                LDY     #2
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                BRA     _ptr_held_L0
_ptr_held_L1
                LDA     _fcc_img18
                TAY
                TSC
                CLC
                ADC     #sum_FRAMESIZE-6
                TCS
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
sum_FRAMESIZE   EQU     8
sum_STKGUARD    EQU     0
                FGX2_EXPORT pick
pick            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #pick_FRAMESIZE
                DO      pick_STKGUARD
                BCC     pick_stkovf
                CMP     _fcc_stkfloor
                BCS     pick_stkok
pick_stkovf       JMP     _fcc_stkoflow
                FIN
pick_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+pick_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+pick_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                LDA     [_fcc_img0]
                PHA
                DO      12+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+pick_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _ptr_held_L2
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_held_L2
                LDY     #2
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _ptr_held_L3
                LDY     #2
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                DO      12+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+pick_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _ptr_held_L3
                LDY     #2
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_held_L3
                LDY     #2
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _ptr_held_L4
                LDY     #2
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                BRA     _ptr_held_L5
_ptr_held_L4
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
_ptr_held_L5
                TAY
                TSC
                CLC
                ADC     #pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
pick_FRAMESIZE   EQU     0
pick_STKGUARD    EQU     0
                FGX2_EXPORT deep
deep            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #deep_FRAMESIZE
                DO      deep_STKGUARD
                BCC     deep_stkovf
                CMP     _fcc_stkfloor
                BCS     deep_stkok
deep_stkovf       JMP     _fcc_stkoflow
                FIN
deep_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+deep_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+deep_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+deep_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+deep_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+deep_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+deep_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                STA     1,S   ; fccstk d=0 b=1
                DO      8+deep_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+deep_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+deep_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+deep_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+deep_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+deep_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      6+deep_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+deep_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+deep_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+deep_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+deep_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+deep_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr1],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                PLA
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                DO      8+deep_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+deep_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+deep_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      10+deep_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+deep_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+deep_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                PHA
                DO      10+deep_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+deep_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+deep_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      12+deep_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+deep_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+deep_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                PHA
                FGX2_FARCALL bump
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #deep_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
deep_FRAMESIZE   EQU     2
deep_STKGUARD    EQU     0
                FGX2_EXPORT walker
walker            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #walker_FRAMESIZE
                DO      walker_STKGUARD
                BCC     walker_stkovf
                CMP     _fcc_stkfloor
                BCS     walker_stkok
walker_stkovf       JMP     _fcc_stkoflow
                FIN
walker_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+walker_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+walker_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+walker_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img0
                DO      12+walker_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+walker_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+walker_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img1
                DO      8+walker_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+walker_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+walker_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+walker_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+walker_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+walker_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                INC
                STA     _fcc_fpr0
                LDA     #88
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     [_fcc_img0]
                CLC
                ADC     #100
                STA     [_fcc_img0]
                LDA     [_fcc_img0]
                INC
                STA     [_fcc_img0]
                DO      8+walker_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+walker_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+walker_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+walker_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+walker_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+walker_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #88
                BNE     _ptr_held_L6
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #104
                BNE     _ptr_held_L6
                LDA     #1
                BRA     _ptr_held_L7
_ptr_held_L6
                LDA     #0
_ptr_held_L7
                TAY
                TSC
                CLC
                ADC     #walker_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
walker_FRAMESIZE   EQU     0
walker_STKGUARD    EQU     0
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
                STA     9,S   ; fccstk d=0 b=9
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c1
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sum
                PLY
                PLY
                TAX
                CMP     #69
                BEQ     _ptr_held_L8
                LDA     9,S   ; fccstk d=0 b=9
                CLC
                ADC     #1
                STA     9,S   ; fccstk d=0 b=9
_ptr_held_L8
                LDA     #2
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c1
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL pick
                PLY
                PLY
                PLY
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #c2
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptr_held_L11
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptr_held_L11
                LDA     #0
                BRA     _ptr_held_L12
_ptr_held_L11
                LDA     #1
_ptr_held_L12
                CMP     #0
                BEQ     *+5
                BRL     _ptr_held_L10
                LDA     #3
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c1
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL pick
                PLY
                PLY
                PLY
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #c3
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptr_held_L13
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptr_held_L13
                LDA     #0
                BRA     _ptr_held_L14
_ptr_held_L13
                LDA     #1
_ptr_held_L14
                CMP     #0
                BNE     _ptr_held_L10
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
                LDA     #c1
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL pick
                PLY
                PLY
                PLY
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #c1
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptr_held_L15
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptr_held_L15
                LDA     #0
                BRA     _ptr_held_L16
_ptr_held_L15
                LDA     #1
_ptr_held_L16
                CMP     #0
                BEQ     _ptr_held_L9
_ptr_held_L10
                LDA     9,S   ; fccstk d=0 b=9
                CLC
                ADC     #1
                STA     9,S   ; fccstk d=0 b=9
_ptr_held_L9
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c1
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
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
                FGX2_FARCALL deep
                PLY
                PLY
                TAX
                CMP     #6
                BNE     _ptr_held_L18
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #c2
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptr_held_L19
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptr_held_L19
                LDA     #0
                BRA     _ptr_held_L20
_ptr_held_L19
                LDA     #1
_ptr_held_L20
                CMP     #0
                BEQ     _ptr_held_L17
_ptr_held_L18
                LDA     9,S   ; fccstk d=0 b=9
                CLC
                ADC     #1
                STA     9,S   ; fccstk d=0 b=9
_ptr_held_L17
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #97
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
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                LDA     _fcc_fb
                CLC
                ADC     #4
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #98
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
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                LDA     _fcc_fb
                CLC
                ADC     #4
                PHA
                LDA     #2
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
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c3
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL walker
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BEQ     _ptr_held_L22
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #88
                BNE     _ptr_held_L22
                LDA     c3+0
                TAX
                CMP     #104
                BEQ     _ptr_held_L21
_ptr_held_L22
                LDA     9,S   ; fccstk d=0 b=9
                CLC
                ADC     #1
                STA     9,S   ; fccstk d=0 b=9
_ptr_held_L21
                LDA     #3
                STA     c3+0
                LDA     #9
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c1
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL pick
                PLY
                PLY
                PLY
                LDY     #6
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #116
                BNE     _ptr_held_L24
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sum
                PLY
                PLY
                PHA
                LDA     #20
                CLC
                ADC     #3
                CLC
                ADC     #30
                TAX
                CLC
                ADC     #4
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _ptr_held_L23
_ptr_held_L24
                LDA     9,S   ; fccstk d=0 b=9
                CLC
                ADC     #1
                STA     9,S   ; fccstk d=0 b=9
_ptr_held_L23
                LDA     9,S   ; fccstk d=0 b=9
                BEQ     _ptr_held_L25
                LDA     9,S   ; fccstk d=0 b=9
                BRA     _ptr_held_L26
_ptr_held_L25
                LDA     #42
_ptr_held_L26
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
                FGX2_RELOC_COUNT 17
