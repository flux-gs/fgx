                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ufssb.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _ufssb_sb_u32
_ufssb_sb_u32            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ufssb_sb_u32_FRAMESIZE
                DO      _ufssb_sb_u32_STKGUARD
                BCC     _ufssb_sb_u32_stkovf
                CMP     _fcc_stkfloor
                BCS     _ufssb_sb_u32_stkok
_ufssb_sb_u32_stkovf       JMP     _fcc_stkoflow
                FIN
_ufssb_sb_u32_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_ufssb_sb_u32_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ufssb_sb_u32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ufssb_sb_u32_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+_ufssb_sb_u32_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ufssb_sb_u32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ufssb_sb_u32_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      12+_ufssb_sb_u32_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ufssb_sb_u32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ufssb_sb_u32_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                AND     #$00FF
                PHA
                DO      10+_ufssb_sb_u32_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ufssb_sb_u32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ufssb_sb_u32_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      8+_ufssb_sb_u32_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ufssb_sb_u32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ufssb_sb_u32_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                PHA
                DO      14+_ufssb_sb_u32_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_ufssb_sb_u32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_ufssb_sb_u32_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                TAX
                TXA
                INC
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                ORA     _fcc_tmp_b
                LDX     #0
                STX     _fcc_long_hi
                STA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img1
                TYA
                DO      8+_ufssb_sb_u32_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ufssb_sb_u32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ufssb_sb_u32_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+_ufssb_sb_u32_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ufssb_sb_u32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ufssb_sb_u32_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      12+_ufssb_sb_u32_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ufssb_sb_u32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ufssb_sb_u32_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                TAX
                TXA
                INC
                INC
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                AND     #$00FF
                PHA
                DO      10+_ufssb_sb_u32_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ufssb_sb_u32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ufssb_sb_u32_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      8+_ufssb_sb_u32_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ufssb_sb_u32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ufssb_sb_u32_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                PHA
                DO      14+_ufssb_sb_u32_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_ufssb_sb_u32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_ufssb_sb_u32_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                TAX
                TXA
                CLC
                ADC     #3
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                ORA     _fcc_tmp_b
                LDX     #0
                STX     _fcc_long_hi
                STA     _fcc_img2
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img3
                TYA
                LDA     _fcc_img0
                STA     _fcc_long_hi
                LDA     #0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img3
                STA     _fcc_long_hi
                LDA     _fcc_img2
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                TAY
                TSC
                CLC
                ADC     #_ufssb_sb_u32_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_sb_u32_FRAMESIZE   EQU     8
_ufssb_sb_u32_STKGUARD    EQU     0
                FGX2_EXPORT _ufssb_sb_u16
_ufssb_sb_u16            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ufssb_sb_u16_FRAMESIZE
                DO      _ufssb_sb_u16_STKGUARD
                BCC     _ufssb_sb_u16_stkovf
                CMP     _fcc_stkfloor
                BCS     _ufssb_sb_u16_stkok
_ufssb_sb_u16_stkovf       JMP     _fcc_stkoflow
                FIN
_ufssb_sb_u16_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_ufssb_sb_u16_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ufssb_sb_u16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ufssb_sb_u16_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+_ufssb_sb_u16_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ufssb_sb_u16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ufssb_sb_u16_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      12+_ufssb_sb_u16_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ufssb_sb_u16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ufssb_sb_u16_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                AND     #$00FF
                PHA
                DO      10+_ufssb_sb_u16_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ufssb_sb_u16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ufssb_sb_u16_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      8+_ufssb_sb_u16_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ufssb_sb_u16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ufssb_sb_u16_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                PHA
                DO      14+_ufssb_sb_u16_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_ufssb_sb_u16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_ufssb_sb_u16_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                TAX
                TXA
                INC
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                ORA     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #_ufssb_sb_u16_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_sb_u16_FRAMESIZE   EQU     0
_ufssb_sb_u16_STKGUARD    EQU     0
                FGX2_EXPORT _ufssb_sb_p32
_ufssb_sb_p32            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ufssb_sb_p32_FRAMESIZE
                DO      _ufssb_sb_p32_STKGUARD
                BCC     _ufssb_sb_p32_stkovf
                CMP     _fcc_stkfloor
                BCS     _ufssb_sb_p32_stkok
_ufssb_sb_p32_stkovf       JMP     _fcc_stkoflow
                FIN
_ufssb_sb_p32_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      14+_ufssb_sb_p32_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_ufssb_sb_p32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_ufssb_sb_p32_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_long_hi
                DO      12+_ufssb_sb_p32_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ufssb_sb_p32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ufssb_sb_p32_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                LDA     _fcc_long_hi
                LDX     #0
                CMP     #$8000
                BCC     _ufssb_L0
                LDX     #$FFFF
_ufssb_L0
                STX     _fcc_long_hi
                STA     _fcc_img0
                DO      14+_ufssb_sb_p32_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_ufssb_sb_p32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_ufssb_sb_p32_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_long_hi
                DO      12+_ufssb_sb_p32_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ufssb_sb_p32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ufssb_sb_p32_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img1
                DO      8+_ufssb_sb_p32_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ufssb_sb_p32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ufssb_sb_p32_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+_ufssb_sb_p32_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ufssb_sb_p32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ufssb_sb_p32_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      12+_ufssb_sb_p32_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ufssb_sb_p32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ufssb_sb_p32_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     _fcc_img0
                TAX
                TXA
                AND     #255
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                DO      8+_ufssb_sb_p32_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ufssb_sb_p32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ufssb_sb_p32_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+_ufssb_sb_p32_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ufssb_sb_p32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ufssb_sb_p32_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      12+_ufssb_sb_p32_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ufssb_sb_p32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ufssb_sb_p32_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                TAX
                TXA
                INC
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     _fcc_img0
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shrs16
                TAX
                TXA
                AND     #255
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                DO      8+_ufssb_sb_p32_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ufssb_sb_p32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ufssb_sb_p32_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+_ufssb_sb_p32_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ufssb_sb_p32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ufssb_sb_p32_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      12+_ufssb_sb_p32_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ufssb_sb_p32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ufssb_sb_p32_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                TAX
                TXA
                INC
                INC
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     _fcc_img1
                TAX
                TXA
                AND     #255
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                DO      8+_ufssb_sb_p32_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ufssb_sb_p32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ufssb_sb_p32_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+_ufssb_sb_p32_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ufssb_sb_p32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ufssb_sb_p32_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      12+_ufssb_sb_p32_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ufssb_sb_p32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ufssb_sb_p32_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                TAX
                TXA
                CLC
                ADC     #3
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     _fcc_img1
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shrs16
                TAX
                TXA
                AND     #255
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                TAY
                TSC
                CLC
                ADC     #_ufssb_sb_p32_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_sb_p32_FRAMESIZE   EQU     4
_ufssb_sb_p32_STKGUARD    EQU     0
                FGX2_EXPORT _ufssb_sb_p16
_ufssb_sb_p16            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ufssb_sb_p16_FRAMESIZE
                DO      _ufssb_sb_p16_STKGUARD
                BCC     _ufssb_sb_p16_stkovf
                CMP     _fcc_stkfloor
                BCS     _ufssb_sb_p16_stkok
_ufssb_sb_p16_stkovf       JMP     _fcc_stkoflow
                FIN
_ufssb_sb_p16_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_ufssb_sb_p16_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ufssb_sb_p16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ufssb_sb_p16_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+_ufssb_sb_p16_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ufssb_sb_p16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ufssb_sb_p16_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      12+_ufssb_sb_p16_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ufssb_sb_p16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ufssb_sb_p16_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                DO      16+_ufssb_sb_p16_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_ufssb_sb_p16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_ufssb_sb_p16_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                TAX
                TXA
                AND     #255
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                DO      8+_ufssb_sb_p16_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ufssb_sb_p16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ufssb_sb_p16_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+_ufssb_sb_p16_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ufssb_sb_p16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ufssb_sb_p16_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      12+_ufssb_sb_p16_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ufssb_sb_p16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ufssb_sb_p16_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                TAX
                TXA
                INC
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                DO      16+_ufssb_sb_p16_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_ufssb_sb_p16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_ufssb_sb_p16_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shrs16
                TAX
                TXA
                AND     #255
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                TAY
                TSC
                CLC
                ADC     #_ufssb_sb_p16_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_sb_p16_FRAMESIZE   EQU     0
_ufssb_sb_p16_STKGUARD    EQU     0
                FGX2_EXPORT ufs_sbdecode
ufs_sbdecode            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ufs_sbdecode_FRAMESIZE
                DO      ufs_sbdecode_STKGUARD
                BCC     ufs_sbdecode_stkovf
                CMP     _fcc_stkfloor
                BCS     ufs_sbdecode_stkok
ufs_sbdecode_stkovf       JMP     _fcc_stkoflow
                FIN
ufs_sbdecode_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                PHA
                DO      14+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _ufssb_sb_u16
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                STA     [_fcc_fpr0]
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #2
                PHA
                DO      14+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _ufssb_sb_u32
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #2
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #4
                STA     [_fcc_fpr0],Y
                TXA
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #6
                PHA
                DO      14+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _ufssb_sb_u16
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #6
                STA     [_fcc_fpr0],Y
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #208
                PHA
                DO      14+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _ufssb_sb_u16
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #208
                STA     [_fcc_fpr0],Y
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #414
                PHA
                DO      14+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _ufssb_sb_u32
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #410
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #412
                STA     [_fcc_fpr0],Y
                TXA
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #418
                PHA
                DO      14+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _ufssb_sb_u32
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #414
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #416
                STA     [_fcc_fpr0],Y
                TXA
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #422
                PHA
                DO      14+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _ufssb_sb_u16
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #418
                STA     [_fcc_fpr0],Y
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #424
                PHA
                DO      14+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _ufssb_sb_u16
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #420
                STA     [_fcc_fpr0],Y
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #426
                PHA
                DO      14+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _ufssb_sb_u16
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #422
                STA     [_fcc_fpr0],Y
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #440
                PHA
                DO      14+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _ufssb_sb_u16
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #424
                STA     [_fcc_fpr0],Y
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #442
                PHA
                DO      14+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _ufssb_sb_u16
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #426
                STA     [_fcc_fpr0],Y
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #444
                PHA
                DO      14+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _ufssb_sb_u16
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #428
                STA     [_fcc_fpr0],Y
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                DO      8+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #413
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                SEP     #$20
                MX      %10
                LDY     #430
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                DO      8+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #411
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                SEP     #$20
                MX      %10
                LDY     #431
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                DO      8+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #410
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                SEP     #$20
                MX      %10
                LDY     #432
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                DO      8+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #412
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                SEP     #$20
                MX      %10
                LDY     #433
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
_ufssb_L1
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                SEC
                SBC     #50
                BVC     _ufssb_L4
                EOR     #$8000
_ufssb_L4
                BMI     *+5
                BRL     _ufssb_L3
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #8
                PHA
                LDA     7,S   ; fccstk d=6 b=1
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      14+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _ufssb_sb_u32
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
_ufssb_L2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRL     _ufssb_L1
_ufssb_L3
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
_ufssb_L5
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                SEC
                SBC     #100
                BVC     _ufssb_L8
                EOR     #$8000
_ufssb_L8
                BMI     *+5
                BRL     _ufssb_L7
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                CLC
                ADC     #210
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #210
                PHA
                LDA     7,S   ; fccstk d=6 b=1
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      14+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+ufs_sbdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbdecode_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _ufssb_sb_u16
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                STA     [_fcc_fpr0]
_ufssb_L6
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRL     _ufssb_L5
_ufssb_L7
                TAY
                TSC
                CLC
                ADC     #ufs_sbdecode_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ufs_sbdecode_FRAMESIZE   EQU     2
ufs_sbdecode_STKGUARD    EQU     0
                FGX2_EXPORT ufs_sbencode
ufs_sbencode            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ufs_sbencode_FRAMESIZE
                DO      ufs_sbencode_STKGUARD
                BCC     ufs_sbencode_stkovf
                CMP     _fcc_stkfloor
                BCS     ufs_sbencode_stkok
ufs_sbencode_stkovf       JMP     _fcc_stkoflow
                FIN
ufs_sbencode_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #0
                PHA
                DO      16+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p16
                TSC
                CLC
                ADC     #8
                TCS
                DO      8+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
                PHA
                DO      18+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+ufs_sbencode_FRAMESIZE,S   ; fccstk d=6 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      16+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_sbencode_FRAMESIZE,S   ; fccstk d=6 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p32
                TSC
                CLC
                ADC     #10
                TCS
                DO      8+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     #6
                PHA
                DO      16+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p16
                TSC
                CLC
                ADC     #8
                TCS
                DO      8+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #208
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     #208
                PHA
                DO      16+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p16
                TSC
                CLC
                ADC     #8
                TCS
                DO      8+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #412
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #410
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #414
                PHA
                DO      18+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+ufs_sbencode_FRAMESIZE,S   ; fccstk d=6 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      16+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_sbencode_FRAMESIZE,S   ; fccstk d=6 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p32
                TSC
                CLC
                ADC     #10
                TCS
                DO      8+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #416
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #414
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #418
                PHA
                DO      18+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+ufs_sbencode_FRAMESIZE,S   ; fccstk d=6 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      16+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_sbencode_FRAMESIZE,S   ; fccstk d=6 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p32
                TSC
                CLC
                ADC     #10
                TCS
                DO      8+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #418
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     #422
                PHA
                DO      16+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p16
                TSC
                CLC
                ADC     #8
                TCS
                DO      8+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #420
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     #424
                PHA
                DO      16+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p16
                TSC
                CLC
                ADC     #8
                TCS
                DO      8+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #422
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     #426
                PHA
                DO      16+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p16
                TSC
                CLC
                ADC     #8
                TCS
                DO      8+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #424
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     #440
                PHA
                DO      16+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p16
                TSC
                CLC
                ADC     #8
                TCS
                DO      8+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #426
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     #442
                PHA
                DO      16+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p16
                TSC
                CLC
                ADC     #8
                TCS
                DO      8+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #428
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     #444
                PHA
                DO      16+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p16
                TSC
                CLC
                ADC     #8
                TCS
                DO      12+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_ptr+2
                DO      10+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                PHA
                LDA     #413
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                DO      12+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #430
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                DO      12+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_ptr+2
                DO      10+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                PHA
                LDA     #411
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                DO      12+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #431
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                DO      12+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_ptr+2
                DO      10+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                PHA
                LDA     #410
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                DO      12+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #432
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                DO      12+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_ptr+2
                DO      10+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                PHA
                LDA     #412
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                DO      12+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #433
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
_ufssb_L9
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                SEC
                SBC     #50
                BVC     _ufssb_L12
                EOR     #$8000
_ufssb_L12
                BMI     *+5
                BRL     _ufssb_L11
                DO      8+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #8
                PHA
                LDA     7,S   ; fccstk d=6 b=1
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      18+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+ufs_sbencode_FRAMESIZE,S   ; fccstk d=6 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      16+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_sbencode_FRAMESIZE,S   ; fccstk d=6 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p32
                TSC
                CLC
                ADC     #10
                TCS
_ufssb_L10
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRL     _ufssb_L9
_ufssb_L11
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
_ufssb_L13
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                SEC
                SBC     #100
                BVC     _ufssb_L16
                EOR     #$8000
_ufssb_L16
                BMI     *+5
                BRL     _ufssb_L15
                DO      8+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbencode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #210
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     #210
                PHA
                LDA     5,S   ; fccstk d=4 b=1
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      16+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+ufs_sbencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbencode_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p16
                TSC
                CLC
                ADC     #8
                TCS
_ufssb_L14
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRL     _ufssb_L13
_ufssb_L15
                TAY
                TSC
                CLC
                ADC     #ufs_sbencode_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ufs_sbencode_FRAMESIZE   EQU     2
ufs_sbencode_STKGUARD    EQU     0
                FGX2_EXPORT ufs_dget32
ufs_dget32            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ufs_dget32_FRAMESIZE
                DO      ufs_dget32_STKGUARD
                BCC     ufs_dget32_stkovf
                CMP     _fcc_stkfloor
                BCS     ufs_dget32_stkok
ufs_dget32_stkovf       JMP     _fcc_stkoflow
                FIN
ufs_dget32_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+ufs_dget32_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_dget32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_dget32_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                PHA
                DO      10+ufs_dget32_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_dget32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_dget32_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+ufs_dget32_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_dget32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_dget32_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_u32
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #ufs_dget32_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ufs_dget32_FRAMESIZE   EQU     0
ufs_dget32_STKGUARD    EQU     0
                FGX2_EXPORT ufs_dput32
ufs_dput32            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ufs_dput32_FRAMESIZE
                DO      ufs_dput32_STKGUARD
                BCC     ufs_dput32_stkovf
                CMP     _fcc_stkfloor
                BCS     ufs_dput32_stkok
ufs_dput32_stkovf       JMP     _fcc_stkoflow
                FIN
ufs_dput32_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      14+ufs_dput32_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_dput32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_dput32_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_long_hi
                DO      12+ufs_dput32_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_dput32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_dput32_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      14+ufs_dput32_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_dput32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_dput32_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                PHA
                DO      14+ufs_dput32_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_dput32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_dput32_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      12+ufs_dput32_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_dput32_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_dput32_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p32
                TSC
                CLC
                ADC     #10
                TCS
                TAY
                TSC
                CLC
                ADC     #ufs_dput32_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ufs_dput32_FRAMESIZE   EQU     0
ufs_dput32_STKGUARD    EQU     0
                FGX2_EXPORT ufs_dput16
ufs_dput16            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ufs_dput16_FRAMESIZE
                DO      ufs_dput16_STKGUARD
                BCC     ufs_dput16_stkovf
                CMP     _fcc_stkfloor
                BCS     ufs_dput16_stkok
ufs_dput16_stkovf       JMP     _fcc_stkoflow
                FIN
ufs_dput16_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+ufs_dput16_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_dput16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_dput16_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                PHA
                DO      12+ufs_dput16_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_dput16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_dput16_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                PHA
                DO      12+ufs_dput16_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_dput16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_dput16_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_dput16_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_dput16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_dput16_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p16
                TSC
                CLC
                ADC     #8
                TCS
                TAY
                TSC
                CLC
                ADC     #ufs_dput16_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ufs_dput16_FRAMESIZE   EQU     0
ufs_dput16_STKGUARD    EQU     0
                FGX2_EXPORT ufs_dget16
ufs_dget16            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ufs_dget16_FRAMESIZE
                DO      ufs_dget16_STKGUARD
                BCC     ufs_dget16_stkovf
                CMP     _fcc_stkfloor
                BCS     ufs_dget16_stkok
ufs_dget16_stkovf       JMP     _fcc_stkoflow
                FIN
ufs_dget16_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+ufs_dget16_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_dget16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_dget16_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                PHA
                DO      10+ufs_dget16_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_dget16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_dget16_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+ufs_dget16_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_dget16_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_dget16_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_u16
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #ufs_dget16_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ufs_dget16_FRAMESIZE   EQU     0
ufs_dget16_STKGUARD    EQU     0
                FGX2_EXPORT ufs_fblkdecode
ufs_fblkdecode            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ufs_fblkdecode_FRAMESIZE
                DO      ufs_fblkdecode_STKGUARD
                BCC     ufs_fblkdecode_stkovf
                CMP     _fcc_stkfloor
                BCS     ufs_fblkdecode_stkok
ufs_fblkdecode_stkovf       JMP     _fcc_stkoflow
                FIN
ufs_fblkdecode_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+ufs_fblkdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_fblkdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_fblkdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_fblkdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_fblkdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_fblkdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                PHA
                DO      14+ufs_fblkdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_fblkdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_fblkdecode_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+ufs_fblkdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_fblkdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_fblkdecode_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _ufssb_sb_u16
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #6
                STA     [_fcc_fpr0],Y
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
_ufssb_L17
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                SEC
                SBC     #50
                BVC     _ufssb_L20
                EOR     #$8000
_ufssb_L20
                BMI     *+5
                BRL     _ufssb_L19
                DO      12+ufs_fblkdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_fblkdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_fblkdecode_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_fblkdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_fblkdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_fblkdecode_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #2
                PHA
                LDA     7,S   ; fccstk d=6 b=1
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      14+ufs_fblkdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_fblkdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_fblkdecode_FRAMESIZE,S   ; fccstk d=6 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      12+ufs_fblkdecode_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_fblkdecode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_fblkdecode_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL _ufssb_sb_u32
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
_ufssb_L18
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRL     _ufssb_L17
_ufssb_L19
                TAY
                TSC
                CLC
                ADC     #ufs_fblkdecode_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ufs_fblkdecode_FRAMESIZE   EQU     2
ufs_fblkdecode_STKGUARD    EQU     0
                FGX2_EXPORT ufs_fblkencode
ufs_fblkencode            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ufs_fblkencode_FRAMESIZE
                DO      ufs_fblkencode_STKGUARD
                BCC     ufs_fblkencode_stkovf
                CMP     _fcc_stkfloor
                BCS     ufs_fblkencode_stkok
ufs_fblkencode_stkovf       JMP     _fcc_stkoflow
                FIN
ufs_fblkencode_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+ufs_fblkencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_fblkencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_fblkencode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_fblkencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_fblkencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_fblkencode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     #0
                PHA
                DO      16+ufs_fblkencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_fblkencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_fblkencode_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+ufs_fblkencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_fblkencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_fblkencode_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p16
                TSC
                CLC
                ADC     #8
                TCS
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
_ufssb_L21
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                SEC
                SBC     #50
                BVC     _ufssb_L24
                EOR     #$8000
_ufssb_L24
                BMI     *+5
                BRL     _ufssb_L23
                DO      8+ufs_fblkencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_fblkencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_fblkencode_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_fblkencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_fblkencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_fblkencode_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
                PHA
                LDA     7,S   ; fccstk d=6 b=1
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      18+ufs_fblkencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+ufs_fblkencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+ufs_fblkencode_FRAMESIZE,S   ; fccstk d=6 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      16+ufs_fblkencode_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_fblkencode_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_fblkencode_FRAMESIZE,S   ; fccstk d=6 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ufssb_sb_p32
                TSC
                CLC
                ADC     #10
                TCS
_ufssb_L22
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRL     _ufssb_L21
_ufssb_L23
                TAY
                TSC
                CLC
                ADC     #ufs_fblkencode_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ufs_fblkencode_FRAMESIZE   EQU     2
ufs_fblkencode_STKGUARD    EQU     0
                FGX2_EXPORT ufs_sbvalid
ufs_sbvalid            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ufs_sbvalid_FRAMESIZE
                DO      ufs_sbvalid_STKGUARD
                BCC     ufs_sbvalid_stkovf
                CMP     _fcc_stkfloor
                BCS     ufs_sbvalid_stkok
ufs_sbvalid_stkovf       JMP     _fcc_stkoflow
                FIN
ufs_sbvalid_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #4
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                CMP     #0
                BNE     *+5
                BRL     _ufssb_L25
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #ufs_sbvalid_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_L25
                DO      8+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_les
                CMP     #0
                BNE     *+5
                BRL     _ufssb_L26
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #ufs_sbvalid_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_L26
                DO      8+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      12+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ges
                CMP     #0
                BNE     *+5
                BRL     _ufssb_L27
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #ufs_sbvalid_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_L27
                DO      8+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                SEC
                SBC     #0
                BVC     _ufssb_L31
                EOR     #$8000
_ufssb_L31
                BPL     *+5
                BRL     _ufssb_L29
                DO      8+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                LDX     #50
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _ufssb_L32
                EOR     #$8000
_ufssb_L32
                BPL     *+5
                BRL     _ufssb_L29
                LDA     #0
                BRL     _ufssb_L30
_ufssb_L29
                LDA     #1
_ufssb_L30
                CMP     #0
                BNE     *+5
                BRL     _ufssb_L28
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #ufs_sbvalid_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_L28
                DO      8+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #208
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                SEC
                SBC     #0
                BVC     _ufssb_L36
                EOR     #$8000
_ufssb_L36
                BPL     *+5
                BRL     _ufssb_L34
                DO      8+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #208
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                LDX     #100
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _ufssb_L37
                EOR     #$8000
_ufssb_L37
                BPL     *+5
                BRL     _ufssb_L34
                LDA     #0
                BRL     _ufssb_L35
_ufssb_L34
                LDA     #1
_ufssb_L35
                CMP     #0
                BNE     *+5
                BRL     _ufssb_L33
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #ufs_sbvalid_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_L33
                DO      8+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #416
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #414
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      12+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_gts
                CMP     #0
                BNE     *+5
                BRL     _ufssb_L38
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #ufs_sbvalid_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_L38
                DO      12+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      10+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _ufssb_L40
                DO      8+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      16+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+ufs_sbvalid_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+ufs_sbvalid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+ufs_sbvalid_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_gts
                CMP     #0
                BNE     *+5
                BRL     _ufssb_L40
                LDA     #1
                BRL     _ufssb_L41
_ufssb_L40
                LDA     #0
_ufssb_L41
                CMP     #0
                BNE     *+5
                BRL     _ufssb_L39
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #ufs_sbvalid_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_L39
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #ufs_sbvalid_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ufs_sbvalid_FRAMESIZE   EQU     0
ufs_sbvalid_STKGUARD    EQU     0
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ufssb_real_sb
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL ufs_sbdecode
                TSC
                CLC
                ADC     #8
                TCS
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #126
                BNE     *+5
                BRL     _ufssb_L42
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
_ufssb_L42
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                TXA
                CMP     #40
                BNE     *+5
                BRL     _ufssb_L43
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
_ufssb_L43
                LDA     209,S   ; fccstk d=0 b=209
                TAX
                TXA
                CMP     #92
                BNE     *+5
                BRL     _ufssb_L44
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
_ufssb_L44
                TSC
                CLC
                ADC     #419
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                TAX
                TXA
                CMP     #1368
                BNE     *+5
                BRL     _ufssb_L45
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
_ufssb_L45
                TSC
                CLC
                ADC     #421
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                TAX
                TXA
                CMP     #7
                BNE     *+5
                BRL     _ufssb_L46
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
_ufssb_L46
                TSC
                CLC
                ADC     #423
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                TAX
                TXA
                CMP     #400
                BNE     *+5
                BRL     _ufssb_L47
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
_ufssb_L47
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=0 b=3
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$1F06
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _ufssb_L48
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_L48
                TSC
                CLC
                ADC     #417
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_long_hi
                TSC
                CLC
                ADC     #415
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$1283
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _ufssb_L49
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_L49
                TSC
                CLC
                ADC     #413
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_long_hi
                TSC
                CLC
                ADC     #411
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$6A79
                STA     _fcc_long_hi
                LDA     #$37C3
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _ufssb_L50
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_L50
                LDA     #0
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
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
                FGX2_FARCALL ufs_sbvalid
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BEQ     _ufssb_L52
                LDA     #0
                BRA     _ufssb_L53
_ufssb_L52
                LDA     #1
_ufssb_L53
                CMP     #0
                BNE     *+5
                BRL     _ufssb_L51
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_L51
                LDA     #7942
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
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
                FGX2_FARCALL ufs_sbvalid
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BEQ     _ufssb_L55
                LDA     #0
                BRA     _ufssb_L56
_ufssb_L55
                LDA     #1
_ufssb_L56
                CMP     #0
                BNE     *+5
                BRL     _ufssb_L54
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_L54
                LDA     #100
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
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
                FGX2_FARCALL ufs_sbvalid
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _ufssb_L57
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ufssb_L57
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
main_FRAMESIZE   EQU     434
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 55
