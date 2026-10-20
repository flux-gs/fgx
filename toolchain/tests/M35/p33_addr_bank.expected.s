                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from p33_addr_bank.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT setto
setto            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #setto_FRAMESIZE
                DO      setto_STKGUARD
                BCC     setto_stkovf
                CMP     _fcc_stkfloor
                BCS     setto_stkok
setto_stkovf       JMP     _fcc_stkoflow
                FIN
setto_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+setto_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+setto_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+setto_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+setto_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+setto_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+setto_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      10+setto_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+setto_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+setto_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     [_fcc_fpr0]
                TAY
                TSC
                CLC
                ADC     #setto_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
setto_FRAMESIZE   EQU     0
setto_STKGUARD    EQU     0
                FGX2_EXPORT getfrom
getfrom            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #getfrom_FRAMESIZE
                DO      getfrom_STKGUARD
                BCC     getfrom_stkovf
                CMP     _fcc_stkfloor
                BCS     getfrom_stkok
getfrom_stkovf       JMP     _fcc_stkoflow
                FIN
getfrom_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+getfrom_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+getfrom_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+getfrom_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+getfrom_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+getfrom_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+getfrom_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                TAY
                TSC
                CLC
                ADC     #getfrom_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
getfrom_FRAMESIZE   EQU     0
getfrom_STKGUARD    EQU     0
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
                LDA     #777
                PHA
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
                FGX2_FARCALL setto
                TSC
                CLC
                ADC     #6
                TCS
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #777
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _p33_addr_bank_L0
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
_p33_addr_bank_L0
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
                FGX2_FARCALL getfrom
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                LDA     #777
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _p33_addr_bank_L1
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
_p33_addr_bank_L1
                LDA     #555
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL setto
                TSC
                CLC
                ADC     #6
                TCS
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                LDA     #555
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _p33_addr_bank_L2
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
_p33_addr_bank_L2
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
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDA     #888
                STA     [_fcc_fpr0]
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #888
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _p33_addr_bank_L3
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
_p33_addr_bank_L3
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDA     #2
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #999
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                LDA     #999
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _p33_addr_bank_L4
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
_p33_addr_bank_L4
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
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 7
