                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from g53_scalarfar.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT scalarfar
scalarfar            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #scalarfar_FRAMESIZE
                DO      scalarfar_STKGUARD
                BCC     scalarfar_stkovf
                CMP     _fcc_stkfloor
                BCS     scalarfar_stkok
scalarfar_stkovf       JMP     _fcc_stkoflow
                FIN
scalarfar_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+scalarfar_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+scalarfar_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+scalarfar_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     3,S   ; fccstk d=0 b=3
                TAY
                LDA     _fcc_long_hi
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_q3
                STA     9,S   ; fccstk d=0 b=9
                TYA
                LDA     #1
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     11,S   ; fccstk d=0 b=11
                TAY
                LDA     _fcc_long_hi
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_q2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_q3
                STA     17,S   ; fccstk d=0 b=17
                TYA
                LDA     #2
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     19,S   ; fccstk d=0 b=19
                TAY
                LDA     _fcc_long_hi
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q2
                STA     23,S   ; fccstk d=0 b=23
                LDA     _fcc_q3
                STA     25,S   ; fccstk d=0 b=25
                TYA
                LDA     #3
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     27,S   ; fccstk d=0 b=27
                TAY
                LDA     _fcc_long_hi
                STA     29,S   ; fccstk d=0 b=29
                LDA     _fcc_q2
                STA     31,S   ; fccstk d=0 b=31
                LDA     _fcc_q3
                STA     33,S   ; fccstk d=0 b=33
                TYA
                LDA     #4
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     35,S   ; fccstk d=0 b=35
                TAY
                LDA     _fcc_long_hi
                STA     37,S   ; fccstk d=0 b=37
                LDA     _fcc_q2
                STA     39,S   ; fccstk d=0 b=39
                LDA     _fcc_q3
                STA     41,S   ; fccstk d=0 b=41
                TYA
                LDA     #5
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     43,S   ; fccstk d=0 b=43
                TAY
                LDA     _fcc_long_hi
                STA     45,S   ; fccstk d=0 b=45
                LDA     _fcc_q2
                STA     47,S   ; fccstk d=0 b=47
                LDA     _fcc_q3
                STA     49,S   ; fccstk d=0 b=49
                TYA
                LDA     #6
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     51,S   ; fccstk d=0 b=51
                TAY
                LDA     _fcc_long_hi
                STA     53,S   ; fccstk d=0 b=53
                LDA     _fcc_q2
                STA     55,S   ; fccstk d=0 b=55
                LDA     _fcc_q3
                STA     57,S   ; fccstk d=0 b=57
                TYA
                LDA     #7
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     59,S   ; fccstk d=0 b=59
                TAY
                LDA     _fcc_long_hi
                STA     61,S   ; fccstk d=0 b=61
                LDA     _fcc_q2
                STA     63,S   ; fccstk d=0 b=63
                LDA     _fcc_q3
                STA     65,S   ; fccstk d=0 b=65
                TYA
                LDA     #8
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     67,S   ; fccstk d=0 b=67
                TAY
                LDA     _fcc_long_hi
                STA     69,S   ; fccstk d=0 b=69
                LDA     _fcc_q2
                STA     71,S   ; fccstk d=0 b=71
                LDA     _fcc_q3
                STA     73,S   ; fccstk d=0 b=73
                TYA
                LDA     #9
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     75,S   ; fccstk d=0 b=75
                TAY
                LDA     _fcc_long_hi
                STA     77,S   ; fccstk d=0 b=77
                LDA     _fcc_q2
                STA     79,S   ; fccstk d=0 b=79
                LDA     _fcc_q3
                STA     81,S   ; fccstk d=0 b=81
                TYA
                LDA     #10
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     83,S   ; fccstk d=0 b=83
                TAY
                LDA     _fcc_long_hi
                STA     85,S   ; fccstk d=0 b=85
                LDA     _fcc_q2
                STA     87,S   ; fccstk d=0 b=87
                LDA     _fcc_q3
                STA     89,S   ; fccstk d=0 b=89
                TYA
                LDA     #11
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     91,S   ; fccstk d=0 b=91
                TAY
                LDA     _fcc_long_hi
                STA     93,S   ; fccstk d=0 b=93
                LDA     _fcc_q2
                STA     95,S   ; fccstk d=0 b=95
                LDA     _fcc_q3
                STA     97,S   ; fccstk d=0 b=97
                TYA
                LDA     #12
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     99,S   ; fccstk d=0 b=99
                TAY
                LDA     _fcc_long_hi
                STA     101,S   ; fccstk d=0 b=101
                LDA     _fcc_q2
                STA     103,S   ; fccstk d=0 b=103
                LDA     _fcc_q3
                STA     105,S   ; fccstk d=0 b=105
                TYA
                LDA     #13
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     107,S   ; fccstk d=0 b=107
                TAY
                LDA     _fcc_long_hi
                STA     109,S   ; fccstk d=0 b=109
                LDA     _fcc_q2
                STA     111,S   ; fccstk d=0 b=111
                LDA     _fcc_q3
                STA     113,S   ; fccstk d=0 b=113
                TYA
                LDA     #14
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     115,S   ; fccstk d=0 b=115
                TAY
                LDA     _fcc_long_hi
                STA     117,S   ; fccstk d=0 b=117
                LDA     _fcc_q2
                STA     119,S   ; fccstk d=0 b=119
                LDA     _fcc_q3
                STA     121,S   ; fccstk d=0 b=121
                TYA
                LDA     #15
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     123,S   ; fccstk d=0 b=123
                TAY
                LDA     _fcc_long_hi
                STA     125,S   ; fccstk d=0 b=125
                LDA     _fcc_q2
                STA     127,S   ; fccstk d=0 b=127
                LDA     _fcc_q3
                STA     129,S   ; fccstk d=0 b=129
                TYA
                LDA     #16
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     131,S   ; fccstk d=0 b=131
                TAY
                LDA     _fcc_long_hi
                STA     133,S   ; fccstk d=0 b=133
                LDA     _fcc_q2
                STA     135,S   ; fccstk d=0 b=135
                LDA     _fcc_q3
                STA     137,S   ; fccstk d=0 b=137
                TYA
                LDA     #17
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     139,S   ; fccstk d=0 b=139
                TAY
                LDA     _fcc_long_hi
                STA     141,S   ; fccstk d=0 b=141
                LDA     _fcc_q2
                STA     143,S   ; fccstk d=0 b=143
                LDA     _fcc_q3
                STA     145,S   ; fccstk d=0 b=145
                TYA
                LDA     #18
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     147,S   ; fccstk d=0 b=147
                TAY
                LDA     _fcc_long_hi
                STA     149,S   ; fccstk d=0 b=149
                LDA     _fcc_q2
                STA     151,S   ; fccstk d=0 b=151
                LDA     _fcc_q3
                STA     153,S   ; fccstk d=0 b=153
                TYA
                LDA     #19
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     155,S   ; fccstk d=0 b=155
                TAY
                LDA     _fcc_long_hi
                STA     157,S   ; fccstk d=0 b=157
                LDA     _fcc_q2
                STA     159,S   ; fccstk d=0 b=159
                LDA     _fcc_q3
                STA     161,S   ; fccstk d=0 b=161
                TYA
                LDA     #20
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     163,S   ; fccstk d=0 b=163
                TAY
                LDA     _fcc_long_hi
                STA     165,S   ; fccstk d=0 b=165
                LDA     _fcc_q2
                STA     167,S   ; fccstk d=0 b=167
                LDA     _fcc_q3
                STA     169,S   ; fccstk d=0 b=169
                TYA
                LDA     #21
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     171,S   ; fccstk d=0 b=171
                TAY
                LDA     _fcc_long_hi
                STA     173,S   ; fccstk d=0 b=173
                LDA     _fcc_q2
                STA     175,S   ; fccstk d=0 b=175
                LDA     _fcc_q3
                STA     177,S   ; fccstk d=0 b=177
                TYA
                LDA     #22
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     179,S   ; fccstk d=0 b=179
                TAY
                LDA     _fcc_long_hi
                STA     181,S   ; fccstk d=0 b=181
                LDA     _fcc_q2
                STA     183,S   ; fccstk d=0 b=183
                LDA     _fcc_q3
                STA     185,S   ; fccstk d=0 b=185
                TYA
                LDA     #23
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     187,S   ; fccstk d=0 b=187
                TAY
                LDA     _fcc_long_hi
                STA     189,S   ; fccstk d=0 b=189
                LDA     _fcc_q2
                STA     191,S   ; fccstk d=0 b=191
                LDA     _fcc_q3
                STA     193,S   ; fccstk d=0 b=193
                TYA
                LDA     #24
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     195,S   ; fccstk d=0 b=195
                TAY
                LDA     _fcc_long_hi
                STA     197,S   ; fccstk d=0 b=197
                LDA     _fcc_q2
                STA     199,S   ; fccstk d=0 b=199
                LDA     _fcc_q3
                STA     201,S   ; fccstk d=0 b=201
                TYA
                LDA     #25
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     203,S   ; fccstk d=0 b=203
                TAY
                LDA     _fcc_long_hi
                STA     205,S   ; fccstk d=0 b=205
                LDA     _fcc_q2
                STA     207,S   ; fccstk d=0 b=207
                LDA     _fcc_q3
                STA     209,S   ; fccstk d=0 b=209
                TYA
                LDA     #26
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     211,S   ; fccstk d=0 b=211
                TAY
                LDA     _fcc_long_hi
                STA     213,S   ; fccstk d=0 b=213
                LDA     _fcc_q2
                STA     215,S   ; fccstk d=0 b=215
                LDA     _fcc_q3
                STA     217,S   ; fccstk d=0 b=217
                TYA
                LDA     #27
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     219,S   ; fccstk d=0 b=219
                TAY
                LDA     _fcc_long_hi
                STA     221,S   ; fccstk d=0 b=221
                LDA     _fcc_q2
                STA     223,S   ; fccstk d=0 b=223
                LDA     _fcc_q3
                STA     225,S   ; fccstk d=0 b=225
                TYA
                LDA     #28
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     227,S   ; fccstk d=0 b=227
                TAY
                LDA     _fcc_long_hi
                STA     229,S   ; fccstk d=0 b=229
                LDA     _fcc_q2
                STA     231,S   ; fccstk d=0 b=231
                LDA     _fcc_q3
                STA     233,S   ; fccstk d=0 b=233
                TYA
                LDA     #29
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     235,S   ; fccstk d=0 b=235
                TAY
                LDA     _fcc_long_hi
                STA     237,S   ; fccstk d=0 b=237
                LDA     _fcc_q2
                STA     239,S   ; fccstk d=0 b=239
                LDA     _fcc_q3
                STA     241,S   ; fccstk d=0 b=241
                TYA
                LDA     #30
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     243,S   ; fccstk d=0 b=243
                TAY
                LDA     _fcc_long_hi
                STA     245,S   ; fccstk d=0 b=245
                LDA     _fcc_q2
                STA     247,S   ; fccstk d=0 b=247
                LDA     _fcc_q3
                STA     249,S   ; fccstk d=0 b=249
                TYA
                LDA     #31
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     251,S   ; fccstk d=0 b=251
                TAY
                LDA     _fcc_long_hi
                STA     253,S   ; fccstk d=0 b=253
                LDA     _fcc_q2
                STA     255,S   ; fccstk d=0 b=255
                LDA     _fcc_q3
                PHA
                TSC
                CLC
                ADC     #259
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                TYA
                LDA     #32
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                PHA
                TSC
                CLC
                ADC     #261
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                TAY
                LDA     _fcc_long_hi
                PHA
                TSC
                CLC
                ADC     #263
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                LDA     _fcc_q2
                PHA
                TSC
                CLC
                ADC     #265
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                LDA     _fcc_q3
                PHA
                TSC
                CLC
                ADC     #267
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                TYA
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                TSC
                CLC
                ADC     #269
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                TSC
                CLC
                ADC     #267
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                TAX
                TXA
                CLC
                ADC     #6
                PHA
                TSC
                CLC
                ADC     #271
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_q3
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=0 b=3
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     25,S   ; fccstk d=8 b=17
                STA     _fcc_q3
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q2
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     33,S   ; fccstk d=8 b=25
                STA     _fcc_q3
                LDA     31,S   ; fccstk d=8 b=23
                STA     _fcc_q2
                LDA     29,S   ; fccstk d=8 b=21
                STA     _fcc_long_hi
                LDA     27,S   ; fccstk d=8 b=19
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     41,S   ; fccstk d=8 b=33
                STA     _fcc_q3
                LDA     39,S   ; fccstk d=8 b=31
                STA     _fcc_q2
                LDA     37,S   ; fccstk d=8 b=29
                STA     _fcc_long_hi
                LDA     35,S   ; fccstk d=8 b=27
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     49,S   ; fccstk d=8 b=41
                STA     _fcc_q3
                LDA     47,S   ; fccstk d=8 b=39
                STA     _fcc_q2
                LDA     45,S   ; fccstk d=8 b=37
                STA     _fcc_long_hi
                LDA     43,S   ; fccstk d=8 b=35
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     57,S   ; fccstk d=8 b=49
                STA     _fcc_q3
                LDA     55,S   ; fccstk d=8 b=47
                STA     _fcc_q2
                LDA     53,S   ; fccstk d=8 b=45
                STA     _fcc_long_hi
                LDA     51,S   ; fccstk d=8 b=43
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     65,S   ; fccstk d=8 b=57
                STA     _fcc_q3
                LDA     63,S   ; fccstk d=8 b=55
                STA     _fcc_q2
                LDA     61,S   ; fccstk d=8 b=53
                STA     _fcc_long_hi
                LDA     59,S   ; fccstk d=8 b=51
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     73,S   ; fccstk d=8 b=65
                STA     _fcc_q3
                LDA     71,S   ; fccstk d=8 b=63
                STA     _fcc_q2
                LDA     69,S   ; fccstk d=8 b=61
                STA     _fcc_long_hi
                LDA     67,S   ; fccstk d=8 b=59
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     81,S   ; fccstk d=8 b=73
                STA     _fcc_q3
                LDA     79,S   ; fccstk d=8 b=71
                STA     _fcc_q2
                LDA     77,S   ; fccstk d=8 b=69
                STA     _fcc_long_hi
                LDA     75,S   ; fccstk d=8 b=67
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     89,S   ; fccstk d=8 b=81
                STA     _fcc_q3
                LDA     87,S   ; fccstk d=8 b=79
                STA     _fcc_q2
                LDA     85,S   ; fccstk d=8 b=77
                STA     _fcc_long_hi
                LDA     83,S   ; fccstk d=8 b=75
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     97,S   ; fccstk d=8 b=89
                STA     _fcc_q3
                LDA     95,S   ; fccstk d=8 b=87
                STA     _fcc_q2
                LDA     93,S   ; fccstk d=8 b=85
                STA     _fcc_long_hi
                LDA     91,S   ; fccstk d=8 b=83
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     105,S   ; fccstk d=8 b=97
                STA     _fcc_q3
                LDA     103,S   ; fccstk d=8 b=95
                STA     _fcc_q2
                LDA     101,S   ; fccstk d=8 b=93
                STA     _fcc_long_hi
                LDA     99,S   ; fccstk d=8 b=91
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     113,S   ; fccstk d=8 b=105
                STA     _fcc_q3
                LDA     111,S   ; fccstk d=8 b=103
                STA     _fcc_q2
                LDA     109,S   ; fccstk d=8 b=101
                STA     _fcc_long_hi
                LDA     107,S   ; fccstk d=8 b=99
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     121,S   ; fccstk d=8 b=113
                STA     _fcc_q3
                LDA     119,S   ; fccstk d=8 b=111
                STA     _fcc_q2
                LDA     117,S   ; fccstk d=8 b=109
                STA     _fcc_long_hi
                LDA     115,S   ; fccstk d=8 b=107
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     129,S   ; fccstk d=8 b=121
                STA     _fcc_q3
                LDA     127,S   ; fccstk d=8 b=119
                STA     _fcc_q2
                LDA     125,S   ; fccstk d=8 b=117
                STA     _fcc_long_hi
                LDA     123,S   ; fccstk d=8 b=115
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     137,S   ; fccstk d=8 b=129
                STA     _fcc_q3
                LDA     135,S   ; fccstk d=8 b=127
                STA     _fcc_q2
                LDA     133,S   ; fccstk d=8 b=125
                STA     _fcc_long_hi
                LDA     131,S   ; fccstk d=8 b=123
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     145,S   ; fccstk d=8 b=137
                STA     _fcc_q3
                LDA     143,S   ; fccstk d=8 b=135
                STA     _fcc_q2
                LDA     141,S   ; fccstk d=8 b=133
                STA     _fcc_long_hi
                LDA     139,S   ; fccstk d=8 b=131
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     153,S   ; fccstk d=8 b=145
                STA     _fcc_q3
                LDA     151,S   ; fccstk d=8 b=143
                STA     _fcc_q2
                LDA     149,S   ; fccstk d=8 b=141
                STA     _fcc_long_hi
                LDA     147,S   ; fccstk d=8 b=139
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     161,S   ; fccstk d=8 b=153
                STA     _fcc_q3
                LDA     159,S   ; fccstk d=8 b=151
                STA     _fcc_q2
                LDA     157,S   ; fccstk d=8 b=149
                STA     _fcc_long_hi
                LDA     155,S   ; fccstk d=8 b=147
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     169,S   ; fccstk d=8 b=161
                STA     _fcc_q3
                LDA     167,S   ; fccstk d=8 b=159
                STA     _fcc_q2
                LDA     165,S   ; fccstk d=8 b=157
                STA     _fcc_long_hi
                LDA     163,S   ; fccstk d=8 b=155
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     177,S   ; fccstk d=8 b=169
                STA     _fcc_q3
                LDA     175,S   ; fccstk d=8 b=167
                STA     _fcc_q2
                LDA     173,S   ; fccstk d=8 b=165
                STA     _fcc_long_hi
                LDA     171,S   ; fccstk d=8 b=163
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     185,S   ; fccstk d=8 b=177
                STA     _fcc_q3
                LDA     183,S   ; fccstk d=8 b=175
                STA     _fcc_q2
                LDA     181,S   ; fccstk d=8 b=173
                STA     _fcc_long_hi
                LDA     179,S   ; fccstk d=8 b=171
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     193,S   ; fccstk d=8 b=185
                STA     _fcc_q3
                LDA     191,S   ; fccstk d=8 b=183
                STA     _fcc_q2
                LDA     189,S   ; fccstk d=8 b=181
                STA     _fcc_long_hi
                LDA     187,S   ; fccstk d=8 b=179
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     201,S   ; fccstk d=8 b=193
                STA     _fcc_q3
                LDA     199,S   ; fccstk d=8 b=191
                STA     _fcc_q2
                LDA     197,S   ; fccstk d=8 b=189
                STA     _fcc_long_hi
                LDA     195,S   ; fccstk d=8 b=187
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     209,S   ; fccstk d=8 b=201
                STA     _fcc_q3
                LDA     207,S   ; fccstk d=8 b=199
                STA     _fcc_q2
                LDA     205,S   ; fccstk d=8 b=197
                STA     _fcc_long_hi
                LDA     203,S   ; fccstk d=8 b=195
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     217,S   ; fccstk d=8 b=209
                STA     _fcc_q3
                LDA     215,S   ; fccstk d=8 b=207
                STA     _fcc_q2
                LDA     213,S   ; fccstk d=8 b=205
                STA     _fcc_long_hi
                LDA     211,S   ; fccstk d=8 b=203
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     225,S   ; fccstk d=8 b=217
                STA     _fcc_q3
                LDA     223,S   ; fccstk d=8 b=215
                STA     _fcc_q2
                LDA     221,S   ; fccstk d=8 b=213
                STA     _fcc_long_hi
                LDA     219,S   ; fccstk d=8 b=211
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     233,S   ; fccstk d=8 b=225
                STA     _fcc_q3
                LDA     231,S   ; fccstk d=8 b=223
                STA     _fcc_q2
                LDA     229,S   ; fccstk d=8 b=221
                STA     _fcc_long_hi
                LDA     227,S   ; fccstk d=8 b=219
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     241,S   ; fccstk d=8 b=233
                STA     _fcc_q3
                LDA     239,S   ; fccstk d=8 b=231
                STA     _fcc_q2
                LDA     237,S   ; fccstk d=8 b=229
                STA     _fcc_long_hi
                LDA     235,S   ; fccstk d=8 b=227
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     249,S   ; fccstk d=8 b=241
                STA     _fcc_q3
                LDA     247,S   ; fccstk d=8 b=239
                STA     _fcc_q2
                LDA     245,S   ; fccstk d=8 b=237
                STA     _fcc_long_hi
                LDA     243,S   ; fccstk d=8 b=235
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                TSC
                CLC
                ADC     #257
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_q3
                LDA     255,S   ; fccstk d=8 b=247
                STA     _fcc_q2
                LDA     253,S   ; fccstk d=8 b=245
                STA     _fcc_long_hi
                LDA     251,S   ; fccstk d=8 b=243
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                TSC
                CLC
                ADC     #265
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_q3
                TSC
                CLC
                ADC     #263
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_q2
                TSC
                CLC
                ADC     #261
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_long_hi
                TSC
                CLC
                ADC     #259
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                TSC
                CLC
                ADC     #273
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_q3
                TSC
                CLC
                ADC     #271
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_q2
                TSC
                CLC
                ADC     #269
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_long_hi
                TSC
                CLC
                ADC     #267
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_add
                TAX
                TXA
                SEC
                SBC     #528
                PHA
                TSC
                CLC
                ADC     #271
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                TSC
                CLC
                ADC     #269
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #scalarfar_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
scalarfar_FRAMESIZE   EQU     270
scalarfar_STKGUARD    EQU     1
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
                LDA     #18
                PHA
                FGX2_FARCALL scalarfar
                TAY
                PLA
                TYA
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
                FGX2_RELOC_COUNT 36
