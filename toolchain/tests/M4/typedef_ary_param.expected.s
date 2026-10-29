                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from typedef_ary_param.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT walk
walk            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #walk_FRAMESIZE
                DO      walk_STKGUARD
                BCC     walk_stkovf
                CMP     _fcc_stkfloor
                BCS     walk_stkok
walk_stkovf       JMP     _fcc_stkoflow
                FIN
walk_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
_typedef_ary_param_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                DO      8+walk_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+walk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+walk_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+walk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+walk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+walk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _typedef_ary_param_L1
                INC     _fcc_img0
                BRA     _typedef_ary_param_L0
_typedef_ary_param_L1
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #walk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
walk_FRAMESIZE   EQU     2
walk_STKGUARD    EQU     0
                FGX2_EXPORT count
count            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #count_FRAMESIZE
                DO      count_STKGUARD
                BCC     count_stkovf
                CMP     _fcc_stkfloor
                BCS     count_stkok
count_stkovf       JMP     _fcc_stkoflow
                FIN
count_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
                DO      8+count_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+count_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+count_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+count_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+count_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+count_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_typedef_ary_param_L2
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _typedef_ary_param_L4
                INC     _fcc_img0
_typedef_ary_param_L3
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
                BRA     _typedef_ary_param_L2
_typedef_ary_param_L4
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #count_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
count_FRAMESIZE   EQU     6
count_STKGUARD    EQU     0
                FGX2_EXPORT first
first            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #first_FRAMESIZE
                DO      first_STKGUARD
                BCC     first_stkovf
                CMP     _fcc_stkfloor
                BCS     first_stkok
first_stkovf       JMP     _fcc_stkoflow
                FIN
first_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+first_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+first_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+first_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+first_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+first_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+first_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAY
                TSC
                CLC
                ADC     #first_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
first_FRAMESIZE   EQU     0
first_STKGUARD    EQU     0
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
                LDA     #table
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL walk
                PLY
                PLY
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #table
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL count
                PLY
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #tag
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL first
                PLY
                PLY
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
