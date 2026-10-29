                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fnptr_vnodeops.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _fnptr_vnodeops_s0
_fnptr_vnodeops_s0            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s0_FRAMESIZE
                DO      _fnptr_vnodeops_s0_STKGUARD
                BCC     _fnptr_vnodeops_s0_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s0_stkok
_fnptr_vnodeops_s0_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s0_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s0_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s0_FRAMESIZE   EQU     0
_fnptr_vnodeops_s0_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s1
_fnptr_vnodeops_s1            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s1_FRAMESIZE
                DO      _fnptr_vnodeops_s1_STKGUARD
                BCC     _fnptr_vnodeops_s1_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s1_stkok
_fnptr_vnodeops_s1_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s1_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s1_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s1_FRAMESIZE   EQU     0
_fnptr_vnodeops_s1_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s2
_fnptr_vnodeops_s2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s2_FRAMESIZE
                DO      _fnptr_vnodeops_s2_STKGUARD
                BCC     _fnptr_vnodeops_s2_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s2_stkok
_fnptr_vnodeops_s2_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s2_FRAMESIZE   EQU     0
_fnptr_vnodeops_s2_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s3
_fnptr_vnodeops_s3            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s3_FRAMESIZE
                DO      _fnptr_vnodeops_s3_STKGUARD
                BCC     _fnptr_vnodeops_s3_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s3_stkok
_fnptr_vnodeops_s3_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s3_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s3_FRAMESIZE   EQU     0
_fnptr_vnodeops_s3_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s4
_fnptr_vnodeops_s4            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s4_FRAMESIZE
                DO      _fnptr_vnodeops_s4_STKGUARD
                BCC     _fnptr_vnodeops_s4_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s4_stkok
_fnptr_vnodeops_s4_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s4_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s4_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s4_FRAMESIZE   EQU     0
_fnptr_vnodeops_s4_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s5
_fnptr_vnodeops_s5            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s5_FRAMESIZE
                DO      _fnptr_vnodeops_s5_STKGUARD
                BCC     _fnptr_vnodeops_s5_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s5_stkok
_fnptr_vnodeops_s5_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s5_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s5_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s5_FRAMESIZE   EQU     0
_fnptr_vnodeops_s5_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s6
_fnptr_vnodeops_s6            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s6_FRAMESIZE
                DO      _fnptr_vnodeops_s6_STKGUARD
                BCC     _fnptr_vnodeops_s6_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s6_stkok
_fnptr_vnodeops_s6_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s6_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s6_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s6_FRAMESIZE   EQU     0
_fnptr_vnodeops_s6_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s7
_fnptr_vnodeops_s7            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s7_FRAMESIZE
                DO      _fnptr_vnodeops_s7_STKGUARD
                BCC     _fnptr_vnodeops_s7_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s7_stkok
_fnptr_vnodeops_s7_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s7_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s7_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s7_FRAMESIZE   EQU     0
_fnptr_vnodeops_s7_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s8
_fnptr_vnodeops_s8            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s8_FRAMESIZE
                DO      _fnptr_vnodeops_s8_STKGUARD
                BCC     _fnptr_vnodeops_s8_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s8_stkok
_fnptr_vnodeops_s8_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s8_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s8_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s8_FRAMESIZE   EQU     0
_fnptr_vnodeops_s8_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s9
_fnptr_vnodeops_s9            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s9_FRAMESIZE
                DO      _fnptr_vnodeops_s9_STKGUARD
                BCC     _fnptr_vnodeops_s9_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s9_stkok
_fnptr_vnodeops_s9_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s9_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s9_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s9_FRAMESIZE   EQU     0
_fnptr_vnodeops_s9_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s10
_fnptr_vnodeops_s10            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s10_FRAMESIZE
                DO      _fnptr_vnodeops_s10_STKGUARD
                BCC     _fnptr_vnodeops_s10_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s10_stkok
_fnptr_vnodeops_s10_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s10_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s10_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s10_FRAMESIZE   EQU     0
_fnptr_vnodeops_s10_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s11
_fnptr_vnodeops_s11            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s11_FRAMESIZE
                DO      _fnptr_vnodeops_s11_STKGUARD
                BCC     _fnptr_vnodeops_s11_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s11_stkok
_fnptr_vnodeops_s11_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s11_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s11_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s11_FRAMESIZE   EQU     0
_fnptr_vnodeops_s11_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s12
_fnptr_vnodeops_s12            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s12_FRAMESIZE
                DO      _fnptr_vnodeops_s12_STKGUARD
                BCC     _fnptr_vnodeops_s12_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s12_stkok
_fnptr_vnodeops_s12_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s12_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s12_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s12_FRAMESIZE   EQU     0
_fnptr_vnodeops_s12_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s13
_fnptr_vnodeops_s13            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s13_FRAMESIZE
                DO      _fnptr_vnodeops_s13_STKGUARD
                BCC     _fnptr_vnodeops_s13_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s13_stkok
_fnptr_vnodeops_s13_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s13_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s13_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s13_FRAMESIZE   EQU     0
_fnptr_vnodeops_s13_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s14
_fnptr_vnodeops_s14            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s14_FRAMESIZE
                DO      _fnptr_vnodeops_s14_STKGUARD
                BCC     _fnptr_vnodeops_s14_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s14_stkok
_fnptr_vnodeops_s14_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s14_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #14
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s14_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s14_FRAMESIZE   EQU     0
_fnptr_vnodeops_s14_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s15
_fnptr_vnodeops_s15            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s15_FRAMESIZE
                DO      _fnptr_vnodeops_s15_STKGUARD
                BCC     _fnptr_vnodeops_s15_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s15_stkok
_fnptr_vnodeops_s15_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s15_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #15
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s15_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s15_FRAMESIZE   EQU     0
_fnptr_vnodeops_s15_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s16
_fnptr_vnodeops_s16            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s16_FRAMESIZE
                DO      _fnptr_vnodeops_s16_STKGUARD
                BCC     _fnptr_vnodeops_s16_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s16_stkok
_fnptr_vnodeops_s16_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s16_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s16_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s16_FRAMESIZE   EQU     0
_fnptr_vnodeops_s16_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s17
_fnptr_vnodeops_s17            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s17_FRAMESIZE
                DO      _fnptr_vnodeops_s17_STKGUARD
                BCC     _fnptr_vnodeops_s17_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s17_stkok
_fnptr_vnodeops_s17_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s17_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #17
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s17_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s17_FRAMESIZE   EQU     0
_fnptr_vnodeops_s17_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s18
_fnptr_vnodeops_s18            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s18_FRAMESIZE
                DO      _fnptr_vnodeops_s18_STKGUARD
                BCC     _fnptr_vnodeops_s18_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s18_stkok
_fnptr_vnodeops_s18_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s18_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #18
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s18_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s18_FRAMESIZE   EQU     0
_fnptr_vnodeops_s18_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s19
_fnptr_vnodeops_s19            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s19_FRAMESIZE
                DO      _fnptr_vnodeops_s19_STKGUARD
                BCC     _fnptr_vnodeops_s19_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s19_stkok
_fnptr_vnodeops_s19_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s19_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #19
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s19_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s19_FRAMESIZE   EQU     0
_fnptr_vnodeops_s19_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s20
_fnptr_vnodeops_s20            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s20_FRAMESIZE
                DO      _fnptr_vnodeops_s20_STKGUARD
                BCC     _fnptr_vnodeops_s20_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s20_stkok
_fnptr_vnodeops_s20_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s20_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #20
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s20_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s20_FRAMESIZE   EQU     0
_fnptr_vnodeops_s20_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s21
_fnptr_vnodeops_s21            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s21_FRAMESIZE
                DO      _fnptr_vnodeops_s21_STKGUARD
                BCC     _fnptr_vnodeops_s21_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s21_stkok
_fnptr_vnodeops_s21_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s21_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #21
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s21_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s21_FRAMESIZE   EQU     0
_fnptr_vnodeops_s21_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s22
_fnptr_vnodeops_s22            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s22_FRAMESIZE
                DO      _fnptr_vnodeops_s22_STKGUARD
                BCC     _fnptr_vnodeops_s22_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s22_stkok
_fnptr_vnodeops_s22_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s22_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #22
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s22_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s22_FRAMESIZE   EQU     0
_fnptr_vnodeops_s22_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s23
_fnptr_vnodeops_s23            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s23_FRAMESIZE
                DO      _fnptr_vnodeops_s23_STKGUARD
                BCC     _fnptr_vnodeops_s23_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s23_stkok
_fnptr_vnodeops_s23_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s23_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #23
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s23_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s23_FRAMESIZE   EQU     0
_fnptr_vnodeops_s23_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s24
_fnptr_vnodeops_s24            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s24_FRAMESIZE
                DO      _fnptr_vnodeops_s24_STKGUARD
                BCC     _fnptr_vnodeops_s24_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s24_stkok
_fnptr_vnodeops_s24_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s24_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #24
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s24_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s24_FRAMESIZE   EQU     0
_fnptr_vnodeops_s24_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s25
_fnptr_vnodeops_s25            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s25_FRAMESIZE
                DO      _fnptr_vnodeops_s25_STKGUARD
                BCC     _fnptr_vnodeops_s25_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s25_stkok
_fnptr_vnodeops_s25_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s25_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #25
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s25_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s25_FRAMESIZE   EQU     0
_fnptr_vnodeops_s25_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s26
_fnptr_vnodeops_s26            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s26_FRAMESIZE
                DO      _fnptr_vnodeops_s26_STKGUARD
                BCC     _fnptr_vnodeops_s26_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s26_stkok
_fnptr_vnodeops_s26_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s26_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #26
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s26_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s26_FRAMESIZE   EQU     0
_fnptr_vnodeops_s26_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s27
_fnptr_vnodeops_s27            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s27_FRAMESIZE
                DO      _fnptr_vnodeops_s27_STKGUARD
                BCC     _fnptr_vnodeops_s27_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s27_stkok
_fnptr_vnodeops_s27_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s27_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #27
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s27_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s27_FRAMESIZE   EQU     0
_fnptr_vnodeops_s27_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s28
_fnptr_vnodeops_s28            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s28_FRAMESIZE
                DO      _fnptr_vnodeops_s28_STKGUARD
                BCC     _fnptr_vnodeops_s28_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s28_stkok
_fnptr_vnodeops_s28_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s28_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #28
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s28_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s28_FRAMESIZE   EQU     0
_fnptr_vnodeops_s28_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s29
_fnptr_vnodeops_s29            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s29_FRAMESIZE
                DO      _fnptr_vnodeops_s29_STKGUARD
                BCC     _fnptr_vnodeops_s29_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s29_stkok
_fnptr_vnodeops_s29_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s29_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #29
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s29_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s29_FRAMESIZE   EQU     0
_fnptr_vnodeops_s29_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s30
_fnptr_vnodeops_s30            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s30_FRAMESIZE
                DO      _fnptr_vnodeops_s30_STKGUARD
                BCC     _fnptr_vnodeops_s30_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s30_stkok
_fnptr_vnodeops_s30_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s30_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #30
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s30_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s30_FRAMESIZE   EQU     0
_fnptr_vnodeops_s30_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_vnodeops_s31
_fnptr_vnodeops_s31            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_vnodeops_s31_FRAMESIZE
                DO      _fnptr_vnodeops_s31_STKGUARD
                BCC     _fnptr_vnodeops_s31_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_vnodeops_s31_stkok
_fnptr_vnodeops_s31_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_vnodeops_s31_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #31
                TAY
                TSC
                CLC
                ADC     #_fnptr_vnodeops_s31_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_vnodeops_s31_FRAMESIZE   EQU     0
_fnptr_vnodeops_s31_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #main_FRAMESIZE-8
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
                STA     a_vnode+0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ufs_vnodeops
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     a_vnode+2
                TAY
                LDA     _fcc_ptr+2
                STA     a_vnode+4
                TYA
                LDA     #0
                STA     a_vnode+6
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a_vnode
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDY     #2
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_vnodeops_L0-1
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
_fnptr_vnodeops_L0
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                PHA
                LDY     #2
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #32
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_vnodeops_L1-1
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
_fnptr_vnodeops_L1
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
                STA     9,S   ; fccstk d=0 b=9
                PHA
                LDY     #2
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #60
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_vnodeops_L2-1
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
_fnptr_vnodeops_L2
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
                STA     9,S   ; fccstk d=0 b=9
                PHA
                LDY     #2
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #68
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_vnodeops_L3-1
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
_fnptr_vnodeops_L3
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
                STA     9,S   ; fccstk d=0 b=9
                PHA
                LDY     #2
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #124
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_vnodeops_L4-1
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
_fnptr_vnodeops_L4
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
                STA     9,S   ; fccstk d=0 b=9
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     9,S   ; fccstk d=0 b=9
                PHA
                LDY     #112
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_vnodeops_L5-1
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
_fnptr_vnodeops_L5
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
                STA     9,S   ; fccstk d=0 b=9
                TAX
                SEC
                SBC     #57
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
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
main_FRAMESIZE   EQU     18
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 34
