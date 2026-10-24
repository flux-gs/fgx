                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptr_cmp.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT pcount
pcount            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #pcount_FRAMESIZE
                DO      pcount_STKGUARD
                BCC     pcount_stkovf
                CMP     _fcc_stkfloor
                BCS     pcount_stkok
pcount_stkovf       JMP     _fcc_stkoflow
                FIN
pcount_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
                SEP     #$20
                MX      %10
                LDA     lo+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     lo
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
_ptr_cmp_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     hi+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     hi
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                PHA
                LDA     _fcc_fpr1
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_leu16
                CMP     #0
                BNE     *+5
                BRL     _ptr_cmp_L2
                INC     _fcc_img0
_ptr_cmp_L1
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                CLC
                ADC     #2
                STA     _fcc_img1
                BRL     _ptr_cmp_L0
_ptr_cmp_L2
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #pcount_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
pcount_FRAMESIZE   EQU     6
pcount_STKGUARD    EQU     0
                FGX2_EXPORT icmp
icmp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #icmp_FRAMESIZE
                DO      icmp_STKGUARD
                BCC     icmp_stkovf
                CMP     _fcc_stkfloor
                BCS     icmp_stkok
icmp_stkovf       JMP     _fcc_stkoflow
                FIN
icmp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+icmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+icmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+icmp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                DO      8+icmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+icmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+icmp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_les16
                TAY
                TSC
                CLC
                ADC     #icmp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
icmp_FRAMESIZE   EQU     0
icmp_STKGUARD    EQU     0
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
                LDA     #arr
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     lo
                LDA     _fcc_fpr0+2
                STA     lo+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #arr+6
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     hi
                LDA     _fcc_fpr0+2
                STA     hi+2
                FGX2_FARCALL pcount
                STA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _ptr_cmp_L3
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
_ptr_cmp_L3
                SEP     #$20
                MX      %10
                LDA     lo+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     lo
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     hi+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     hi
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                PHA
                LDA     _fcc_fpr1
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_ltu16
                CMP     #0
                BEQ     _ptr_cmp_L5
                LDA     #0
                BRA     _ptr_cmp_L6
_ptr_cmp_L5
                LDA     #1
_ptr_cmp_L6
                CMP     #0
                BNE     *+5
                BRL     _ptr_cmp_L4
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
_ptr_cmp_L4
                SEP     #$20
                MX      %10
                LDA     hi+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hi
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     lo+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     lo
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                PHA
                LDA     _fcc_fpr1
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_gtu16
                CMP     #0
                BEQ     _ptr_cmp_L8
                LDA     #0
                BRA     _ptr_cmp_L9
_ptr_cmp_L8
                LDA     #1
_ptr_cmp_L9
                CMP     #0
                BNE     *+5
                BRL     _ptr_cmp_L7
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
_ptr_cmp_L7
                SEP     #$20
                MX      %10
                LDA     hi+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hi
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     lo+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     lo
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                PHA
                LDA     _fcc_fpr1
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_geu16
                CMP     #0
                BEQ     _ptr_cmp_L11
                LDA     #0
                BRA     _ptr_cmp_L12
_ptr_cmp_L11
                LDA     #1
_ptr_cmp_L12
                CMP     #0
                BNE     *+5
                BRL     _ptr_cmp_L10
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
_ptr_cmp_L10
                LDA     #5
                PHA
                LDA     #3
                PHA
                FGX2_FARCALL icmp
                TAY
                PLA
                PLA
                TYA
                TAX
                TXA
                CMP     #1
                BNE     *+5
                BRL     _ptr_cmp_L13
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
_ptr_cmp_L13
                LDA     #0
                PHA
                LDA     #$FFFF
                PHA
                FGX2_FARCALL icmp
                TAY
                PLA
                PLA
                TYA
                TAX
                TXA
                CMP     #1
                BNE     *+5
                BRL     _ptr_cmp_L14
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
_ptr_cmp_L14
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
                FGX2_RELOC_COUNT 7
