                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fnptr_drfcall.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT add3
add3            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add3_FRAMESIZE
                DO      add3_STKGUARD
                BCC     add3_stkovf
                CMP     _fcc_stkfloor
                BCS     add3_stkok
add3_stkovf       JMP     _fcc_stkoflow
                FIN
add3_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+add3_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+add3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+add3_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      10+add3_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+add3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+add3_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      20+add3_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+add3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+add3_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+add3_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+add3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+add3_FRAMESIZE,S   ; fccstk d=4 b=14 fs
                FIN
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
                DO      12+add3_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+add3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+add3_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      10+add3_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+add3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+add3_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
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
                TAY
                TSC
                CLC
                ADC     #add3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add3_FRAMESIZE   EQU     0
add3_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #main_FRAMESIZE-4
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
                LDA     _fnptr_drfcall_FA0+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fnptr_drfcall_FA0
                STA     gfp
                LDA     _fcc_fpr0+2
                STA     gfp+2
                SEP     #$20
                MX      %10
                LDA     _fnptr_drfcall_FA1+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fnptr_drfcall_FA1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     gdisp+0
                TAY
                LDA     _fcc_ptr+2
                STA     gdisp+2
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdisp
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     ggp
                LDA     _fcc_fpr0+2
                STA     ggp+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdisp
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                SEP     #$20
                MX      %10
                LDA     gfp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gfp
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0006
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                TAY
                LDA     _fcc_long_hi
                PHA
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
                LDA     #one
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     13,S
                STA     _fcc_fpr0
                LDA     15,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_drfcall_L2-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_fnptr_drfcall_L2
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     [_fcc_img16]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0008
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                TAY
                LDA     _fcc_long_hi
                PHA
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
                LDA     #one
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     13,S
                STA     _fcc_fpr0
                LDA     15,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_drfcall_L3-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_fnptr_drfcall_L3
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     ggp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     ggp
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$000A
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0003
                TAY
                LDA     _fcc_long_hi
                PHA
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
                LDA     #one
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     13,S
                STA     _fcc_fpr0
                LDA     15,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_drfcall_L4-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_fnptr_drfcall_L4
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 3
