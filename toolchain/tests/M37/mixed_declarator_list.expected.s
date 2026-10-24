                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from mixed_declarator_list.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT seven
seven            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #seven_FRAMESIZE
                DO      seven_STKGUARD
                BCC     seven_stkovf
                CMP     _fcc_stkfloor
                BCS     seven_stkok
seven_stkovf       JMP     _fcc_stkoflow
                FIN
seven_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #seven_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
seven_FRAMESIZE   EQU     0
seven_STKGUARD    EQU     0
                FGX2_EXPORT eleven
eleven            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #eleven_FRAMESIZE
                DO      eleven_STKGUARD
                BCC     eleven_stkovf
                CMP     _fcc_stkfloor
                BCS     eleven_stkok
eleven_stkovf       JMP     _fcc_stkoflow
                FIN
eleven_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #eleven_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
eleven_FRAMESIZE   EQU     0
eleven_STKGUARD    EQU     0
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
                SEP     #$20
                MX      %10
                LDA     _mixed_declarator_list_FA0+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _mixed_declarator_list_FA0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                LDA     #0
                STA     19,S   ; fccstk d=0 b=19
                LDA     #1
                STA     1,S   ; fccstk d=0 b=1
                LDA     #2
                STA     3,S   ; fccstk d=0 b=3
                LDA     #3
                STA     9,S   ; fccstk d=0 b=9
                SEP     #$20
                MX      %10
                LDA     _mixed_declarator_list_FA1+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _mixed_declarator_list_FA1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _mixed_declarator_list_L9-1
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
_mixed_declarator_list_L9
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #11
                BEQ     *+5
                BRL     _mixed_declarator_list_L7
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _mixed_declarator_list_L7
                LDA     #1
                BRL     _mixed_declarator_list_L8
_mixed_declarator_list_L7
                LDA     #0
_mixed_declarator_list_L8
                CMP     #0
                BNE     *+5
                BRL     _mixed_declarator_list_L5
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _mixed_declarator_list_L5
                LDA     #1
                BRL     _mixed_declarator_list_L6
_mixed_declarator_list_L5
                LDA     #0
_mixed_declarator_list_L6
                CMP     #0
                BNE     *+5
                BRL     _mixed_declarator_list_L3
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _mixed_declarator_list_L3
                LDA     #1
                BRL     _mixed_declarator_list_L4
_mixed_declarator_list_L3
                LDA     #0
_mixed_declarator_list_L4
                CMP     #0
                BNE     *+5
                BRL     _mixed_declarator_list_L2
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CLC
                ADC     #14
                STA     19,S   ; fccstk d=0 b=19
_mixed_declarator_list_L2
                LDA     #4
                STA     11,S   ; fccstk d=0 b=11
                LDA     #5
                STA     17,S   ; fccstk d=0 b=17
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _mixed_declarator_list_L15-1
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
_mixed_declarator_list_L15
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #7
                BEQ     *+5
                BRL     _mixed_declarator_list_L13
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _mixed_declarator_list_L13
                LDA     #1
                BRL     _mixed_declarator_list_L14
_mixed_declarator_list_L13
                LDA     #0
_mixed_declarator_list_L14
                CMP     #0
                BNE     *+5
                BRL     _mixed_declarator_list_L11
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _mixed_declarator_list_L11
                LDA     #1
                BRL     _mixed_declarator_list_L12
_mixed_declarator_list_L11
                LDA     #0
_mixed_declarator_list_L12
                CMP     #0
                BNE     *+5
                BRL     _mixed_declarator_list_L10
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CLC
                ADC     #14
                STA     19,S   ; fccstk d=0 b=19
_mixed_declarator_list_L10
                LDA     #6
                STA     gplain
                LDA     #8
                STA     gplain2
                SEP     #$20
                MX      %10
                LDA     _mixed_declarator_list_FA16+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _mixed_declarator_list_FA16
                STA     gfp
                LDA     _fcc_fpr0+2
                STA     gfp+2
                SEP     #$20
                MX      %10
                LDA     _mixed_declarator_list_FA17+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _mixed_declarator_list_FA17
                STA     gfp2
                LDA     _fcc_fpr0+2
                STA     gfp2+2
                SEP     #$20
                MX      %10
                LDA     _mixed_declarator_list_FA18+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _mixed_declarator_list_FA18
                STA     gfa
                LDA     _fcc_fpr0+2
                STA     gfa+2
                SEP     #$20
                MX      %10
                LDA     _mixed_declarator_list_FA19+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _mixed_declarator_list_FA19
                STA     gfb
                LDA     _fcc_fpr0+2
                STA     gfb+2
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
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _mixed_declarator_list_L31-1
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
_mixed_declarator_list_L31
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #7
                BEQ     *+5
                BRL     _mixed_declarator_list_L29
                SEP     #$20
                MX      %10
                LDA     gfp2+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gfp2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _mixed_declarator_list_L32-1
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
_mixed_declarator_list_L32
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #11
                BEQ     *+5
                BRL     _mixed_declarator_list_L29
                LDA     #1
                BRL     _mixed_declarator_list_L30
_mixed_declarator_list_L29
                LDA     #0
_mixed_declarator_list_L30
                CMP     #0
                BNE     *+5
                BRL     _mixed_declarator_list_L27
                SEP     #$20
                MX      %10
                LDA     gfa+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gfa
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _mixed_declarator_list_L33-1
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
_mixed_declarator_list_L33
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #7
                BEQ     *+5
                BRL     _mixed_declarator_list_L27
                LDA     #1
                BRL     _mixed_declarator_list_L28
_mixed_declarator_list_L27
                LDA     #0
_mixed_declarator_list_L28
                CMP     #0
                BNE     *+5
                BRL     _mixed_declarator_list_L25
                SEP     #$20
                MX      %10
                LDA     gfb+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gfb
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _mixed_declarator_list_L34-1
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
_mixed_declarator_list_L34
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #11
                BEQ     *+5
                BRL     _mixed_declarator_list_L25
                LDA     #1
                BRL     _mixed_declarator_list_L26
_mixed_declarator_list_L25
                LDA     #0
_mixed_declarator_list_L26
                CMP     #0
                BNE     *+5
                BRL     _mixed_declarator_list_L23
                LDA     gplain
                TAX
                TXA
                CMP     #6
                BEQ     *+5
                BRL     _mixed_declarator_list_L23
                LDA     #1
                BRL     _mixed_declarator_list_L24
_mixed_declarator_list_L23
                LDA     #0
_mixed_declarator_list_L24
                CMP     #0
                BNE     *+5
                BRL     _mixed_declarator_list_L21
                LDA     gplain2
                TAX
                TXA
                CMP     #8
                BEQ     *+5
                BRL     _mixed_declarator_list_L21
                LDA     #1
                BRL     _mixed_declarator_list_L22
_mixed_declarator_list_L21
                LDA     #0
_mixed_declarator_list_L22
                CMP     #0
                BNE     *+5
                BRL     _mixed_declarator_list_L20
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CLC
                ADC     #14
                STA     19,S   ; fccstk d=0 b=19
_mixed_declarator_list_L20
                LDA     19,S   ; fccstk d=0 b=19
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     20
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 4
