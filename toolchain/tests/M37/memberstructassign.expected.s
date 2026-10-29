                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from memberstructassign.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _memberstructassign_fill
_memberstructassign_fill            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_memberstructassign_fill_FRAMESIZE
                DO      _memberstructassign_fill_STKGUARD
                BCC     _memberstructassign_fill_stkovf
                CMP     _fcc_stkfloor
                BCS     _memberstructassign_fill_stkok
_memberstructassign_fill_stkovf       JMP     _fcc_stkoflow
                FIN
_memberstructassign_fill_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_memberstructassign_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_memberstructassign_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_memberstructassign_fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+_memberstructassign_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_memberstructassign_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_memberstructassign_fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                LDA     #4660
                STA     [_fcc_img0]
                LDA     #$1122
                STA     _fcc_long_hi
                LDA     #$3344
                LDY     #2
                STA     [_fcc_img0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #4
                STA     [_fcc_img0],Y
                TXA
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     #22136
                LDY     #6
                STA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #_memberstructassign_fill_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_memberstructassign_fill_FRAMESIZE   EQU     0
_memberstructassign_fill_STKGUARD    EQU     0
                FGX2_EXPORT _memberstructassign_clear
_memberstructassign_clear            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_memberstructassign_clear_FRAMESIZE
                DO      _memberstructassign_clear_STKGUARD
                BCC     _memberstructassign_clear_stkovf
                CMP     _fcc_stkfloor
                BCS     _memberstructassign_clear_stkok
_memberstructassign_clear_stkovf       JMP     _fcc_stkoflow
                FIN
_memberstructassign_clear_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_memberstructassign_clear_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_memberstructassign_clear_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_memberstructassign_clear_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+_memberstructassign_clear_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_memberstructassign_clear_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_memberstructassign_clear_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                LDA     #43690
                STA     [_fcc_img0]
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #0
                STA     [_fcc_fpr0]
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     #0
                STA     [_fcc_fpr0]
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     #48059
                LDY     #10
                STA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #_memberstructassign_clear_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_memberstructassign_clear_FRAMESIZE   EQU     0
_memberstructassign_clear_STKGUARD    EQU     0
                FGX2_EXPORT _memberstructassign_landed
_memberstructassign_landed            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_memberstructassign_landed_FRAMESIZE
                DO      _memberstructassign_landed_STKGUARD
                BCC     _memberstructassign_landed_stkovf
                CMP     _fcc_stkfloor
                BCS     _memberstructassign_landed_stkok
_memberstructassign_landed_stkovf       JMP     _fcc_stkoflow
                FIN
_memberstructassign_landed_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_memberstructassign_landed_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_memberstructassign_landed_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_memberstructassign_landed_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+_memberstructassign_landed_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_memberstructassign_landed_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_memberstructassign_landed_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #4660
                BEQ     _memberstructassign_L0
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #_memberstructassign_landed_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_memberstructassign_L0
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #13124
                STX     _fcc_long_b_lo
                LDX     #4386
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _memberstructassign_L1
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #_memberstructassign_landed_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_memberstructassign_L1
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #22136
                BEQ     _memberstructassign_L2
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #_memberstructassign_landed_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_memberstructassign_L2
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #43690
                BEQ     _memberstructassign_L3
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #_memberstructassign_landed_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_memberstructassign_L3
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #48059
                BEQ     _memberstructassign_L4
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #_memberstructassign_landed_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_memberstructassign_L4
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_memberstructassign_landed_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_memberstructassign_landed_FRAMESIZE   EQU     0
_memberstructassign_landed_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img20
                PEI     _fcc_img21
                PEI     _fcc_img22
                PEI     _fcc_img23
                PEI     _fcc_img24
                TSC
                SEC
                SBC     #main_FRAMESIZE-18
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
                LDA     #g_src
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memberstructassign_fill
                PLY
                PLY
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_dst
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_clear
                PLY
                PLY
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
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
_memberstructassign_L5
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L5
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                CMP     #0
                BEQ     _memberstructassign_L6
                LDA     #10
                PHA
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L6
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_src
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img21
                LDA     _fcc_fpr0
                STA     _fcc_img20
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_clear
                PLY
                PLY
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                CLC
                ADC     #2
                STA     _fcc_fpr0
                LDA     _fcc_img21
                STA     _fcc_fpr1+2
                LDA     _fcc_img20
                STA     _fcc_fpr1
                LDY     #6
_memberstructassign_L7
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L7
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                CMP     #0
                BEQ     _memberstructassign_L8
                LDA     #20
                PHA
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L8
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_dst2
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img18
                FGX2_FARCALL _memberstructassign_clear
                PLY
                PLY
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
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
_memberstructassign_L9
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L9
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_clear
                PLY
                PLY
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img19
                STA     _fcc_fpr1+2
                LDA     _fcc_img18
                CLC
                ADC     #2
                STA     _fcc_fpr1
                LDY     #6
_memberstructassign_L10
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L10
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                CMP     #0
                BEQ     _memberstructassign_L11
                LDA     #30
                PHA
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L11
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #13124
                STX     _fcc_long_b_lo
                LDX     #4386
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _memberstructassign_L12
                LDA     #39
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L12
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_dst2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memberstructassign_clear
                PLY
                PLY
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_dst2+2
                STA     _fcc_fpr0
                PLA
                LDY     #6
_memberstructassign_L13
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L13
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_clear
                PLY
                PLY
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
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
                LDA     #g_dst2+2
                STA     _fcc_fpr1
                PLA
                LDY     #6
_memberstructassign_L14
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L14
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                CMP     #0
                BEQ     _memberstructassign_L15
                LDA     #40
                PHA
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L15
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_arr+12
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memberstructassign_clear
                PLY
                PLY
                LDA     #1
                ASL
                INC
                ASL
                ASL
                CLC
                ADC     #g_arr+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
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
_memberstructassign_L16
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L16
                LDA     #1
                STA     _fcc_img24
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_clear
                PLY
                PLY
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img24
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #g_arr+2
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                LDY     #6
_memberstructassign_L17
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L17
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                CMP     #0
                BEQ     _memberstructassign_L18
                LDA     #50
                PHA
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L18
                LDA     #0
                STA     13,S   ; fccstk d=0 b=13
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_long_hi
                STA     17,S   ; fccstk d=0 b=17
                LDA     #0
                STA     19,S   ; fccstk d=0 b=19
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
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
_memberstructassign_L19
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L19
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                LDX     #13124
                STX     _fcc_long_b_lo
                LDX     #4386
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _memberstructassign_L20
                LDA     #60
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L20
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CMP     #22136
                BEQ     _memberstructassign_L21
                LDA     #61
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L21
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #g_zero
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
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
_memberstructassign_L22
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L22
                LDA     g_zero+4
                STA     _fcc_long_hi
                LDA     g_zero+2
                LDX     #13124
                STX     _fcc_long_b_lo
                LDX     #4386
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _memberstructassign_L23
                LDA     #62
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L23
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img21
                LDA     _fcc_fpr0
                STA     _fcc_img20
                LDA     #0
                STA     [_fcc_img20]
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                LDY     #2
                STA     [_fcc_img20],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #4
                STA     [_fcc_img20],Y
                TXA
                LDA     #0
                LDY     #6
                STA     [_fcc_img20],Y
                LDA     _fcc_img21
                STA     _fcc_fpr0+2
                LDA     _fcc_img20
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
_memberstructassign_L24
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L24
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                LDX     #13124
                STX     _fcc_long_b_lo
                LDX     #4386
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _memberstructassign_L25
                LDA     #63
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L25
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CMP     #22136
                BEQ     _memberstructassign_L26
                LDA     #64
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L26
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_clear
                PLY
                PLY
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
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
_memberstructassign_L27
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L27
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                CMP     #0
                BEQ     _memberstructassign_L28
                LDA     #70
                PHA
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L28
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_dst2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memberstructassign_clear
                PLY
                PLY
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_dst2+2
                STA     _fcc_fpr0
                PLA
                LDY     #6
_memberstructassign_L29
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L29
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_dst2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                CMP     #0
                BEQ     _memberstructassign_L30
                LDA     #80
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_dst2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L30
                LDA     #0
                STA     _fcc_img24
_memberstructassign_L31
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img24
                TAX
                SEC
                SBC     #3
                BVC     _memberstructassign_L34
                EOR     #$8000
_memberstructassign_L34
                BPL     _memberstructassign_L33
                LDA     _fcc_img24
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #g_arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memberstructassign_clear
                PLY
                PLY
_memberstructassign_L32
                INC     _fcc_img24
                BRA     _memberstructassign_L31
_memberstructassign_L33
                LDA     #1
                STA     _fcc_img24
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #g_arr+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
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
_memberstructassign_L35
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L35
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_arr+12
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                CMP     #0
                BEQ     _memberstructassign_L36
                LDA     #90
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_arr+12
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L36
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_arr
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _memberstructassign_L37
                LDA     #98
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L37
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_arr+24
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _memberstructassign_L38
                LDA     #99
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L38
                LDA     #52428
                STA     g_nest+0
                LDA     #56797
                STA     g_nest+14
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_nest+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memberstructassign_clear
                PLY
                PLY
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_nest
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img23
                LDA     _fcc_fpr0
                STA     _fcc_img22
                LDA     _fcc_img23
                STA     _fcc_fpr0+2
                LDA     _fcc_img22
                CLC
                ADC     #4
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
_memberstructassign_L39
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L39
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_nest+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                CMP     #0
                BEQ     _memberstructassign_L40
                LDA     #100
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_nest+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L40
                LDA     g_nest+0
                TAX
                CMP     #52428
                BEQ     _memberstructassign_L41
                LDA     #108
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L41
                LDA     g_nest+14
                TAX
                CMP     #56797
                BEQ     _memberstructassign_L42
                LDA     #109
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L42
                LDA     #52428
                STA     g_nest+0
                LDA     #56797
                STA     g_nest+14
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_nest+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memberstructassign_clear
                PLY
                PLY
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_nest+4
                STA     _fcc_fpr0
                PLA
                LDY     #6
_memberstructassign_L43
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L43
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_nest+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                CMP     #0
                BEQ     _memberstructassign_L44
                LDA     #110
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_nest+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memberstructassign_landed
                PLY
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L44
                LDA     g_nest+0
                TAX
                CMP     #52428
                BEQ     _memberstructassign_L45
                LDA     #118
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L45
                LDA     g_nest+14
                TAX
                CMP     #56797
                BEQ     _memberstructassign_L46
                LDA     #119
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L46
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL _memberstructassign_clear
                PLY
                PLY
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
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
_memberstructassign_L47
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memberstructassign_L47
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                BEQ     _memberstructassign_L48
                LDA     #120
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRL     main_bandx
_memberstructassign_L48
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _memberstructassign_L49
                LDA     #121
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRA     main_bandx
_memberstructassign_L49
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                BEQ     _memberstructassign_L50
                LDA     #122
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRA     main_bandx
_memberstructassign_L50
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #43690
                BEQ     _memberstructassign_L51
                LDA     #123
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRA     main_bandx
_memberstructassign_L51
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #48059
                BEQ     _memberstructassign_L52
                LDA     #124
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                BRA     main_bandx
_memberstructassign_L52
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
main_bandx
                PLA
                STA     _fcc_img24
                PLA
                STA     _fcc_img23
                PLA
                STA     _fcc_img22
                PLA
                STA     _fcc_img21
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
main_FRAMESIZE   EQU     44
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 40
