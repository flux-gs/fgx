                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from cmp_branch.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT lt
lt            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #lt_FRAMESIZE
                DO      lt_STKGUARD
                BCC     lt_stkovf
                CMP     _fcc_stkfloor
                BCS     lt_stkok
lt_stkovf       JMP     _fcc_stkoflow
                FIN
lt_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     a
                TAX
                LDA     b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _cmp_branch_L2
                EOR     #$8000
_cmp_branch_L2
                BPL     _cmp_branch_L0
                LDA     #1
                BRA     _cmp_branch_L1
_cmp_branch_L0
                LDA     #0
_cmp_branch_L1
                TAY
                TSC
                CLC
                ADC     #lt_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
lt_FRAMESIZE   EQU     0
lt_STKGUARD    EQU     0
                FGX2_EXPORT gt
gt            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #gt_FRAMESIZE
                DO      gt_STKGUARD
                BCC     gt_stkovf
                CMP     _fcc_stkfloor
                BCS     gt_stkok
gt_stkovf       JMP     _fcc_stkoflow
                FIN
gt_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     a
                TAX
                LDA     b
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _cmp_branch_L5
                EOR     #$8000
_cmp_branch_L5
                BPL     _cmp_branch_L3
                LDA     #1
                BRA     _cmp_branch_L4
_cmp_branch_L3
                LDA     #0
_cmp_branch_L4
                TAY
                TSC
                CLC
                ADC     #gt_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
gt_FRAMESIZE   EQU     0
gt_STKGUARD    EQU     0
                FGX2_EXPORT le
le            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #le_FRAMESIZE
                DO      le_STKGUARD
                BCC     le_stkovf
                CMP     _fcc_stkfloor
                BCS     le_stkok
le_stkovf       JMP     _fcc_stkoflow
                FIN
le_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     a
                TAX
                LDA     b
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _cmp_branch_L8
                EOR     #$8000
_cmp_branch_L8
                BMI     _cmp_branch_L6
                LDA     #1
                BRA     _cmp_branch_L7
_cmp_branch_L6
                LDA     #0
_cmp_branch_L7
                TAY
                TSC
                CLC
                ADC     #le_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
le_FRAMESIZE   EQU     0
le_STKGUARD    EQU     0
                FGX2_EXPORT ge
ge            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ge_FRAMESIZE
                DO      ge_STKGUARD
                BCC     ge_stkovf
                CMP     _fcc_stkfloor
                BCS     ge_stkok
ge_stkovf       JMP     _fcc_stkoflow
                FIN
ge_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     a
                TAX
                LDA     b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _cmp_branch_L11
                EOR     #$8000
_cmp_branch_L11
                BMI     _cmp_branch_L9
                LDA     #1
                BRA     _cmp_branch_L10
_cmp_branch_L9
                LDA     #0
_cmp_branch_L10
                TAY
                TSC
                CLC
                ADC     #ge_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ge_FRAMESIZE   EQU     0
ge_STKGUARD    EQU     0
                FGX2_EXPORT eq
eq            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #eq_FRAMESIZE
                DO      eq_STKGUARD
                BCC     eq_stkovf
                CMP     _fcc_stkfloor
                BCS     eq_stkok
eq_stkovf       JMP     _fcc_stkoflow
                FIN
eq_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     a
                TAX
                LDA     b
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     _cmp_branch_L12
                LDA     #1
                BRA     _cmp_branch_L13
_cmp_branch_L12
                LDA     #0
_cmp_branch_L13
                TAY
                TSC
                CLC
                ADC     #eq_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
eq_FRAMESIZE   EQU     0
eq_STKGUARD    EQU     0
                FGX2_EXPORT ne
ne            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ne_FRAMESIZE
                DO      ne_STKGUARD
                BCC     ne_stkovf
                CMP     _fcc_stkfloor
                BCS     ne_stkok
ne_stkovf       JMP     _fcc_stkoflow
                FIN
ne_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     a
                TAX
                LDA     b
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _cmp_branch_L14
                LDA     #1
                BRA     _cmp_branch_L15
_cmp_branch_L14
                LDA     #0
_cmp_branch_L15
                TAY
                TSC
                CLC
                ADC     #ne_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ne_FRAMESIZE   EQU     0
ne_STKGUARD    EQU     0
                FGX2_EXPORT ult
ult            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ult_FRAMESIZE
                DO      ult_STKGUARD
                BCC     ult_stkovf
                CMP     _fcc_stkfloor
                BCS     ult_stkok
ult_stkovf       JMP     _fcc_stkoflow
                FIN
ult_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     ua
                TAX
                LDA     ub
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCS     _cmp_branch_L16
                LDA     #1
                BRA     _cmp_branch_L17
_cmp_branch_L16
                LDA     #0
_cmp_branch_L17
                TAY
                TSC
                CLC
                ADC     #ult_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ult_FRAMESIZE   EQU     0
ult_STKGUARD    EQU     0
                FGX2_EXPORT ugt
ugt            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ugt_FRAMESIZE
                DO      ugt_STKGUARD
                BCC     ugt_stkovf
                CMP     _fcc_stkfloor
                BCS     ugt_stkok
ugt_stkovf       JMP     _fcc_stkoflow
                FIN
ugt_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     ua
                TAX
                LDA     ub
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCS     _cmp_branch_L18
                LDA     #1
                BRA     _cmp_branch_L19
_cmp_branch_L18
                LDA     #0
_cmp_branch_L19
                TAY
                TSC
                CLC
                ADC     #ugt_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ugt_FRAMESIZE   EQU     0
ugt_STKGUARD    EQU     0
                FGX2_EXPORT ule
ule            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ule_FRAMESIZE
                DO      ule_STKGUARD
                BCC     ule_stkovf
                CMP     _fcc_stkfloor
                BCS     ule_stkok
ule_stkovf       JMP     _fcc_stkoflow
                FIN
ule_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     ua
                TAX
                LDA     ub
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCC     _cmp_branch_L20
                LDA     #1
                BRA     _cmp_branch_L21
_cmp_branch_L20
                LDA     #0
_cmp_branch_L21
                TAY
                TSC
                CLC
                ADC     #ule_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ule_FRAMESIZE   EQU     0
ule_STKGUARD    EQU     0
                FGX2_EXPORT uge
uge            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #uge_FRAMESIZE
                DO      uge_STKGUARD
                BCC     uge_stkovf
                CMP     _fcc_stkfloor
                BCS     uge_stkok
uge_stkovf       JMP     _fcc_stkoflow
                FIN
uge_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     ua
                TAX
                LDA     ub
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCC     _cmp_branch_L22
                LDA     #1
                BRA     _cmp_branch_L23
_cmp_branch_L22
                LDA     #0
_cmp_branch_L23
                TAY
                TSC
                CLC
                ADC     #uge_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
uge_FRAMESIZE   EQU     0
uge_STKGUARD    EQU     0
                FGX2_EXPORT allrel
allrel            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #allrel_FRAMESIZE
                DO      allrel_STKGUARD
                BCC     allrel_stkovf
                CMP     _fcc_stkfloor
                BCS     allrel_stkok
allrel_stkovf       JMP     _fcc_stkoflow
                FIN
allrel_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
                LDA     a
                TAX
                LDA     b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _cmp_branch_L25
                EOR     #$8000
_cmp_branch_L25
                BPL     _cmp_branch_L24
                LDA     _fcc_img0
                CLC
                ADC     #1
                STA     _fcc_img0
_cmp_branch_L24
                LDA     a
                TAX
                LDA     b
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _cmp_branch_L27
                EOR     #$8000
_cmp_branch_L27
                BPL     _cmp_branch_L26
                LDA     _fcc_img0
                CLC
                ADC     #2
                STA     _fcc_img0
_cmp_branch_L26
                LDA     a
                TAX
                LDA     b
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _cmp_branch_L29
                EOR     #$8000
_cmp_branch_L29
                BMI     _cmp_branch_L28
                LDA     _fcc_img0
                CLC
                ADC     #4
                STA     _fcc_img0
_cmp_branch_L28
                LDA     a
                TAX
                LDA     b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _cmp_branch_L31
                EOR     #$8000
_cmp_branch_L31
                BMI     _cmp_branch_L30
                LDA     _fcc_img0
                CLC
                ADC     #8
                STA     _fcc_img0
_cmp_branch_L30
                LDA     a
                TAX
                LDA     b
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     _cmp_branch_L32
                LDA     _fcc_img0
                CLC
                ADC     #16
                STA     _fcc_img0
_cmp_branch_L32
                LDA     a
                TAX
                LDA     b
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _cmp_branch_L33
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #32
                STA     _fcc_img0
_cmp_branch_L33
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #allrel_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
allrel_FRAMESIZE   EQU     2
allrel_STKGUARD    EQU     0
                FGX2_EXPORT uallrel
uallrel            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #uallrel_FRAMESIZE
                DO      uallrel_STKGUARD
                BCC     uallrel_stkovf
                CMP     _fcc_stkfloor
                BCS     uallrel_stkok
uallrel_stkovf       JMP     _fcc_stkoflow
                FIN
uallrel_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
                LDA     ua
                TAX
                LDA     ub
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCS     _cmp_branch_L34
                LDA     _fcc_img0
                CLC
                ADC     #1
                STA     _fcc_img0
_cmp_branch_L34
                LDA     ua
                TAX
                LDA     ub
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCS     _cmp_branch_L35
                LDA     _fcc_img0
                CLC
                ADC     #2
                STA     _fcc_img0
_cmp_branch_L35
                LDA     ua
                TAX
                LDA     ub
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCC     _cmp_branch_L36
                LDA     _fcc_img0
                CLC
                ADC     #4
                STA     _fcc_img0
_cmp_branch_L36
                LDA     ua
                TAX
                LDA     ub
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCC     _cmp_branch_L37
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #8
                STA     _fcc_img0
_cmp_branch_L37
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #uallrel_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
uallrel_FRAMESIZE   EQU     2
uallrel_STKGUARD    EQU     0
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
                LDA     #3
                STA     a
                LDA     #7
                STA     b
                FGX2_FARCALL allrel
                PHA
                LDA     #1
                CLC
                ADC     #4
                TAX
                CLC
                ADC     #32
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _cmp_branch_L38
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
_cmp_branch_L38
                LDA     #7
                STA     a
                LDA     #3
                STA     b
                FGX2_FARCALL allrel
                PHA
                LDA     #2
                CLC
                ADC     #8
                TAX
                CLC
                ADC     #32
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _cmp_branch_L39
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #2
                STA     1,S   ; fccstk d=0 b=1
_cmp_branch_L39
                LDA     #5
                STA     a
                LDA     #5
                STA     b
                FGX2_FARCALL allrel
                PHA
                LDA     #4
                CLC
                ADC     #8
                TAX
                CLC
                ADC     #16
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _cmp_branch_L40
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #4
                STA     1,S   ; fccstk d=0 b=1
_cmp_branch_L40
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
                JSR     _fcc_long_neg
                STA     a
                LDA     #1
                STA     b
                FGX2_FARCALL allrel
                PHA
                LDA     #1
                CLC
                ADC     #4
                TAX
                CLC
                ADC     #32
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _cmp_branch_L41
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #8
                STA     1,S   ; fccstk d=0 b=1
_cmp_branch_L41
                LDA     #32767
                STA     a
                LDA     #$FFFF
                STA     b
                FGX2_FARCALL allrel
                PHA
                LDA     #2
                CLC
                ADC     #8
                TAX
                CLC
                ADC     #32
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _cmp_branch_L42
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #16
                STA     1,S   ; fccstk d=0 b=1
_cmp_branch_L42
                LDA     #$FFFF
                STA     a
                LDA     #32767
                STA     b
                FGX2_FARCALL allrel
                PHA
                LDA     #1
                CLC
                ADC     #4
                TAX
                CLC
                ADC     #32
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _cmp_branch_L43
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #32
                STA     1,S   ; fccstk d=0 b=1
_cmp_branch_L43
                LDA     #1
                STA     a
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
                JSR     _fcc_long_neg
                STA     b
                FGX2_FARCALL allrel
                PHA
                LDA     #2
                CLC
                ADC     #8
                TAX
                CLC
                ADC     #32
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _cmp_branch_L44
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #64
                STA     1,S   ; fccstk d=0 b=1
_cmp_branch_L44
                LDA     #$FFF9
                STA     a
                LDA     #$FFFD
                STA     b
                FGX2_FARCALL allrel
                PHA
                LDA     #1
                CLC
                ADC     #4
                TAX
                CLC
                ADC     #32
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _cmp_branch_L45
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #128
                STA     1,S   ; fccstk d=0 b=1
_cmp_branch_L45
                LDA     #32768
                STA     ua
                LDA     #1
                STA     ub
                FGX2_FARCALL uallrel
                PHA
                LDA     #2
                TAX
                CLC
                ADC     #8
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _cmp_branch_L46
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #256
                STA     1,S   ; fccstk d=0 b=1
_cmp_branch_L46
                LDA     #1
                STA     ua
                LDA     #65535
                STA     ub
                FGX2_FARCALL uallrel
                PHA
                LDA     #1
                TAX
                CLC
                ADC     #4
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _cmp_branch_L47
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #512
                STA     1,S   ; fccstk d=0 b=1
_cmp_branch_L47
                LDA     #65535
                STA     ua
                LDA     #65535
                STA     ub
                FGX2_FARCALL uallrel
                PHA
                LDA     #4
                TAX
                CLC
                ADC     #8
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _cmp_branch_L48
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #1024
                STA     1,S   ; fccstk d=0 b=1
_cmp_branch_L48
                LDA     #2
                STA     a
                LDA     #9
                STA     b
                FGX2_FARCALL lt
                CMP     #0
                BEQ     _cmp_branch_L49
                FGX2_FARCALL gt
                CMP     #0
                BNE     _cmp_branch_L49
                FGX2_FARCALL le
                CMP     #0
                BEQ     _cmp_branch_L49
                FGX2_FARCALL ge
                CMP     #0
                BNE     _cmp_branch_L49
                FGX2_FARCALL eq
                CMP     #0
                BNE     _cmp_branch_L49
                FGX2_FARCALL ne
                CMP     #0
                BEQ     _cmp_branch_L49
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #2048
                STA     1,S   ; fccstk d=0 b=1
_cmp_branch_L49
                LDA     #9
                STA     ua
                LDA     #2
                STA     ub
                FGX2_FARCALL ult
                CMP     #0
                BNE     _cmp_branch_L50
                FGX2_FARCALL ugt
                CMP     #0
                BEQ     _cmp_branch_L50
                FGX2_FARCALL ule
                CMP     #0
                BNE     _cmp_branch_L50
                FGX2_FARCALL uge
                CMP     #0
                BEQ     _cmp_branch_L50
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #4096
                STA     1,S   ; fccstk d=0 b=1
_cmp_branch_L50
                LDA     #1
                STA     a
                LDA     #2
                STA     b
                LDA     #0
                STA     hits
                LDA     a
                TAX
                LDA     b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _cmp_branch_L53
                EOR     #$8000
_cmp_branch_L53
                BMI     _cmp_branch_L52
                LDA     a
                TAX
                LDA     b
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _cmp_branch_L54
                EOR     #$8000
_cmp_branch_L54
                BPL     _cmp_branch_L51
_cmp_branch_L52
                LDA     hits
                CLC
                ADC     #1
                STA     hits
_cmp_branch_L51
                LDA     a
                TAX
                LDA     b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _cmp_branch_L56
                EOR     #$8000
_cmp_branch_L56
                BPL     _cmp_branch_L55
                LDA     b
                SEC
                SBC     #3
                BVC     _cmp_branch_L57
                EOR     #$8000
_cmp_branch_L57
                BPL     _cmp_branch_L55
                LDA     hits
                CLC
                ADC     #2
                STA     hits
_cmp_branch_L55
                LDA     a
                TAX
                LDA     b
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _cmp_branch_L59
                EOR     #$8000
_cmp_branch_L59
                BPL     _cmp_branch_L58
                LDA     b
                SEC
                SBC     #3
                BVC     _cmp_branch_L60
                EOR     #$8000
_cmp_branch_L60
                BPL     _cmp_branch_L58
                LDA     hits
                CLC
                ADC     #4
                STA     hits
_cmp_branch_L58
                LDA     hits
                TAX
                CMP     #3
                BNE     _cmp_branch_L61
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #8192
                STA     1,S   ; fccstk d=0 b=1
_cmp_branch_L61
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
                STA     _fcc_img0
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_img1
_cmp_branch_L62
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #10
                BVC     _cmp_branch_L65
                EOR     #$8000
_cmp_branch_L65
                BPL     _cmp_branch_L64
                INC     _fcc_img1
_cmp_branch_L63
                INC     _fcc_img0
                BRA     _cmp_branch_L62
_cmp_branch_L64
                LDA     _fcc_img0
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_img1
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     a
_cmp_branch_L66
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     a
                CLC
                ADC     #1
                STA     a
_cmp_branch_L67
                LDA     a
                TAX
                SEC
                SBC     #4
                BVC     _cmp_branch_L69
                EOR     #$8000
_cmp_branch_L69
                BPL     _cmp_branch_L68
                BRA     _cmp_branch_L66
_cmp_branch_L68
                LDA     5,S   ; fccstk d=0 b=5
                CMP     #10
                BNE     _cmp_branch_L70
                LDA     a
                CMP     #4
                BNE     _cmp_branch_L70
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #16384
                STA     1,S   ; fccstk d=0 b=1
_cmp_branch_L70
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #32767
                BNE     _cmp_branch_L71
                LDA     #42
                BRA     _cmp_branch_L72
_cmp_branch_L71
                LDA     1,S   ; fccstk d=0 b=1
_cmp_branch_L72
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 35
