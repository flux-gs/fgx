                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fconv_call.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT ri
ri            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ri_FRAMESIZE
                DO      ri_STKGUARD
                BCC     ri_stkovf
                CMP     _fcc_stkfloor
                BCS     ri_stkok
ri_stkovf       JMP     _fcc_stkoflow
                FIN
ri_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     FN+2
                STA     _fcc_long_hi
                LDA     FN
                JSR     _fcc_ftoi
                TAY
                TSC
                CLC
                ADC     #ri_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ri_FRAMESIZE   EQU     0
ri_STKGUARD    EQU     0
                FGX2_EXPORT rf
rf            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #rf_FRAMESIZE
                DO      rf_STKGUARD
                BCC     rf_stkovf
                CMP     _fcc_stkfloor
                BCS     rf_stkok
rf_stkovf       JMP     _fcc_stkoflow
                FIN
rf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     L+2
                STA     _fcc_long_hi
                LDA     L
                JSR     _fcc_ltof
                TAY
                TSC
                CLC
                ADC     #rf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
rf_FRAMESIZE   EQU     0
rf_STKGUARD    EQU     0
                FGX2_EXPORT ti
ti            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ti_FRAMESIZE
                DO      ti_STKGUARD
                BCC     ti_stkovf
                CMP     _fcc_stkfloor
                BCS     ti_stkok
ti_stkovf       JMP     _fcc_stkoflow
                FIN
ti_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+ti_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ti_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ti_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #ti_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ti_FRAMESIZE   EQU     0
ti_STKGUARD    EQU     0
                FGX2_EXPORT tl
tl            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #tl_FRAMESIZE
                DO      tl_STKGUARD
                BCC     tl_stkovf
                CMP     _fcc_stkfloor
                BCS     tl_stkok
tl_stkovf       JMP     _fcc_stkoflow
                FIN
tl_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+tl_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+tl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+tl_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+tl_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+tl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+tl_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #tl_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
tl_FRAMESIZE   EQU     0
tl_STKGUARD    EQU     0
                FGX2_EXPORT tf
tf            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #tf_FRAMESIZE
                DO      tf_STKGUARD
                BCC     tf_stkovf
                CMP     _fcc_stkfloor
                BCS     tf_stkok
tf_stkovf       JMP     _fcc_stkoflow
                FIN
tf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+tf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+tf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+tf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+tf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+tf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+tf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #tf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
tf_FRAMESIZE   EQU     0
tf_STKGUARD    EQU     0
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
                STA     1,S   ; fccstk d=0 b=1
                LDA     #16415
                STA     _fcc_q3
                LDA     #39321
                STA     _fcc_q2
                LDA     #39321
                STA     _fcc_long_hi
                LDA     #39322
                FGX2_FARCALL _fcc_dtof
                STA     F
                TAY
                LDA     _fcc_long_hi
                STA     F+2
                TYA
                LDA     #16390
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                TAY
                LDA     _fcc_q3
                EOR     #$8000
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_dtof
                STA     FN
                TAY
                LDA     _fcc_long_hi
                STA     FN+2
                TYA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     L
                TAY
                LDA     _fcc_long_hi
                STA     L+2
                TYA
                FGX2_FARCALL ri
                CMP     #$FFFE
                BNE     _fconv_call_L0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
_fconv_call_L0
                FGX2_FARCALL rf
                JSR     _fcc_ftol
                LDX     #4464
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _fconv_call_L1
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #2
                STA     1,S   ; fccstk d=0 b=1
_fconv_call_L1
                LDA     F+2
                STA     _fcc_long_hi
                LDA     F
                JSR     _fcc_ftoi
                PHA
                FGX2_FARCALL ti
                TAY
                PLA
                TYA
                TAX
                CMP     #7
                BNE     _fconv_call_L2
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #4
                STA     1,S   ; fccstk d=0 b=1
_fconv_call_L2
                LDA     F+2
                STA     _fcc_long_hi
                LDA     F
                JSR     _fcc_ftol
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL tl
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDX     #7
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _fconv_call_L3
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #8
                STA     1,S   ; fccstk d=0 b=1
_fconv_call_L3
                LDA     L+2
                STA     _fcc_long_hi
                LDA     L
                JSR     _fcc_ltof
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL tf
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                JSR     _fcc_ftol
                LDX     #4464
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _fconv_call_L4
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #16
                STA     1,S   ; fccstk d=0 b=1
_fconv_call_L4
                LDA     gi
                CMP     #2
                BNE     _fconv_call_L5
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #32
                STA     1,S   ; fccstk d=0 b=1
_fconv_call_L5
                LDA     gl+2
                STA     _fcc_long_hi
                LDA     gl
                LDX     #61072
                STX     _fcc_long_b_lo
                LDX     #65534
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _fconv_call_L6
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #64
                STA     1,S   ; fccstk d=0 b=1
_fconv_call_L6
                LDA     gc
                AND     #$00FF
                TAX
                CMP     #65
                BNE     _fconv_call_L7
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #128
                STA     1,S   ; fccstk d=0 b=1
_fconv_call_L7
                LDA     1,S   ; fccstk d=0 b=1
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
                FGX2_RELOC_COUNT 14
