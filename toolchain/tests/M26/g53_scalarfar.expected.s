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
                LDA     #0
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #1
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_long_hi
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_q2
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_q3
                STA     15,S   ; fccstk d=0 b=15
                TYA
                LDA     #2
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     #3
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     25,S   ; fccstk d=0 b=25
                TAY
                LDA     _fcc_long_hi
                STA     27,S   ; fccstk d=0 b=27
                LDA     _fcc_q2
                STA     29,S   ; fccstk d=0 b=29
                LDA     _fcc_q3
                STA     31,S   ; fccstk d=0 b=31
                TYA
                LDA     #4
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     33,S   ; fccstk d=0 b=33
                TAY
                LDA     _fcc_long_hi
                STA     35,S   ; fccstk d=0 b=35
                LDA     _fcc_q2
                STA     37,S   ; fccstk d=0 b=37
                LDA     _fcc_q3
                STA     39,S   ; fccstk d=0 b=39
                TYA
                LDA     #5
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     41,S   ; fccstk d=0 b=41
                TAY
                LDA     _fcc_long_hi
                STA     43,S   ; fccstk d=0 b=43
                LDA     _fcc_q2
                STA     45,S   ; fccstk d=0 b=45
                LDA     _fcc_q3
                STA     47,S   ; fccstk d=0 b=47
                TYA
                LDA     #6
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     49,S   ; fccstk d=0 b=49
                TAY
                LDA     _fcc_long_hi
                STA     51,S   ; fccstk d=0 b=51
                LDA     _fcc_q2
                STA     53,S   ; fccstk d=0 b=53
                LDA     _fcc_q3
                STA     55,S   ; fccstk d=0 b=55
                TYA
                LDA     #7
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     57,S   ; fccstk d=0 b=57
                TAY
                LDA     _fcc_long_hi
                STA     59,S   ; fccstk d=0 b=59
                LDA     _fcc_q2
                STA     61,S   ; fccstk d=0 b=61
                LDA     _fcc_q3
                STA     63,S   ; fccstk d=0 b=63
                TYA
                LDA     #8
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     65,S   ; fccstk d=0 b=65
                TAY
                LDA     _fcc_long_hi
                STA     67,S   ; fccstk d=0 b=67
                LDA     _fcc_q2
                STA     69,S   ; fccstk d=0 b=69
                LDA     _fcc_q3
                STA     71,S   ; fccstk d=0 b=71
                TYA
                LDA     #9
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     73,S   ; fccstk d=0 b=73
                TAY
                LDA     _fcc_long_hi
                STA     75,S   ; fccstk d=0 b=75
                LDA     _fcc_q2
                STA     77,S   ; fccstk d=0 b=77
                LDA     _fcc_q3
                STA     79,S   ; fccstk d=0 b=79
                TYA
                LDA     #10
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     81,S   ; fccstk d=0 b=81
                TAY
                LDA     _fcc_long_hi
                STA     83,S   ; fccstk d=0 b=83
                LDA     _fcc_q2
                STA     85,S   ; fccstk d=0 b=85
                LDA     _fcc_q3
                STA     87,S   ; fccstk d=0 b=87
                TYA
                LDA     #11
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     89,S   ; fccstk d=0 b=89
                TAY
                LDA     _fcc_long_hi
                STA     91,S   ; fccstk d=0 b=91
                LDA     _fcc_q2
                STA     93,S   ; fccstk d=0 b=93
                LDA     _fcc_q3
                STA     95,S   ; fccstk d=0 b=95
                TYA
                LDA     #12
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     97,S   ; fccstk d=0 b=97
                TAY
                LDA     _fcc_long_hi
                STA     99,S   ; fccstk d=0 b=99
                LDA     _fcc_q2
                STA     101,S   ; fccstk d=0 b=101
                LDA     _fcc_q3
                STA     103,S   ; fccstk d=0 b=103
                TYA
                LDA     #13
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     105,S   ; fccstk d=0 b=105
                TAY
                LDA     _fcc_long_hi
                STA     107,S   ; fccstk d=0 b=107
                LDA     _fcc_q2
                STA     109,S   ; fccstk d=0 b=109
                LDA     _fcc_q3
                STA     111,S   ; fccstk d=0 b=111
                TYA
                LDA     #14
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     113,S   ; fccstk d=0 b=113
                TAY
                LDA     _fcc_long_hi
                STA     115,S   ; fccstk d=0 b=115
                LDA     _fcc_q2
                STA     117,S   ; fccstk d=0 b=117
                LDA     _fcc_q3
                STA     119,S   ; fccstk d=0 b=119
                TYA
                LDA     #15
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     121,S   ; fccstk d=0 b=121
                TAY
                LDA     _fcc_long_hi
                STA     123,S   ; fccstk d=0 b=123
                LDA     _fcc_q2
                STA     125,S   ; fccstk d=0 b=125
                LDA     _fcc_q3
                STA     127,S   ; fccstk d=0 b=127
                TYA
                LDA     #16
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     129,S   ; fccstk d=0 b=129
                TAY
                LDA     _fcc_long_hi
                STA     131,S   ; fccstk d=0 b=131
                LDA     _fcc_q2
                STA     133,S   ; fccstk d=0 b=133
                LDA     _fcc_q3
                STA     135,S   ; fccstk d=0 b=135
                TYA
                LDA     #17
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     137,S   ; fccstk d=0 b=137
                TAY
                LDA     _fcc_long_hi
                STA     139,S   ; fccstk d=0 b=139
                LDA     _fcc_q2
                STA     141,S   ; fccstk d=0 b=141
                LDA     _fcc_q3
                STA     143,S   ; fccstk d=0 b=143
                TYA
                LDA     #18
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     145,S   ; fccstk d=0 b=145
                TAY
                LDA     _fcc_long_hi
                STA     147,S   ; fccstk d=0 b=147
                LDA     _fcc_q2
                STA     149,S   ; fccstk d=0 b=149
                LDA     _fcc_q3
                STA     151,S   ; fccstk d=0 b=151
                TYA
                LDA     #19
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     153,S   ; fccstk d=0 b=153
                TAY
                LDA     _fcc_long_hi
                STA     155,S   ; fccstk d=0 b=155
                LDA     _fcc_q2
                STA     157,S   ; fccstk d=0 b=157
                LDA     _fcc_q3
                STA     159,S   ; fccstk d=0 b=159
                TYA
                LDA     #20
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     161,S   ; fccstk d=0 b=161
                TAY
                LDA     _fcc_long_hi
                STA     163,S   ; fccstk d=0 b=163
                LDA     _fcc_q2
                STA     165,S   ; fccstk d=0 b=165
                LDA     _fcc_q3
                STA     167,S   ; fccstk d=0 b=167
                TYA
                LDA     #21
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     169,S   ; fccstk d=0 b=169
                TAY
                LDA     _fcc_long_hi
                STA     171,S   ; fccstk d=0 b=171
                LDA     _fcc_q2
                STA     173,S   ; fccstk d=0 b=173
                LDA     _fcc_q3
                STA     175,S   ; fccstk d=0 b=175
                TYA
                LDA     #22
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     177,S   ; fccstk d=0 b=177
                TAY
                LDA     _fcc_long_hi
                STA     179,S   ; fccstk d=0 b=179
                LDA     _fcc_q2
                STA     181,S   ; fccstk d=0 b=181
                LDA     _fcc_q3
                STA     183,S   ; fccstk d=0 b=183
                TYA
                LDA     #23
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     185,S   ; fccstk d=0 b=185
                TAY
                LDA     _fcc_long_hi
                STA     187,S   ; fccstk d=0 b=187
                LDA     _fcc_q2
                STA     189,S   ; fccstk d=0 b=189
                LDA     _fcc_q3
                STA     191,S   ; fccstk d=0 b=191
                TYA
                LDA     #24
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     193,S   ; fccstk d=0 b=193
                TAY
                LDA     _fcc_long_hi
                STA     195,S   ; fccstk d=0 b=195
                LDA     _fcc_q2
                STA     197,S   ; fccstk d=0 b=197
                LDA     _fcc_q3
                STA     199,S   ; fccstk d=0 b=199
                TYA
                LDA     #25
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     201,S   ; fccstk d=0 b=201
                TAY
                LDA     _fcc_long_hi
                STA     203,S   ; fccstk d=0 b=203
                LDA     _fcc_q2
                STA     205,S   ; fccstk d=0 b=205
                LDA     _fcc_q3
                STA     207,S   ; fccstk d=0 b=207
                TYA
                LDA     #26
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     209,S   ; fccstk d=0 b=209
                TAY
                LDA     _fcc_long_hi
                STA     211,S   ; fccstk d=0 b=211
                LDA     _fcc_q2
                STA     213,S   ; fccstk d=0 b=213
                LDA     _fcc_q3
                STA     215,S   ; fccstk d=0 b=215
                TYA
                LDA     #27
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     217,S   ; fccstk d=0 b=217
                TAY
                LDA     _fcc_long_hi
                STA     219,S   ; fccstk d=0 b=219
                LDA     _fcc_q2
                STA     221,S   ; fccstk d=0 b=221
                LDA     _fcc_q3
                STA     223,S   ; fccstk d=0 b=223
                TYA
                LDA     #28
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     225,S   ; fccstk d=0 b=225
                TAY
                LDA     _fcc_long_hi
                STA     227,S   ; fccstk d=0 b=227
                LDA     _fcc_q2
                STA     229,S   ; fccstk d=0 b=229
                LDA     _fcc_q3
                STA     231,S   ; fccstk d=0 b=231
                TYA
                LDA     #29
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     233,S   ; fccstk d=0 b=233
                TAY
                LDA     _fcc_long_hi
                STA     235,S   ; fccstk d=0 b=235
                LDA     _fcc_q2
                STA     237,S   ; fccstk d=0 b=237
                LDA     _fcc_q3
                STA     239,S   ; fccstk d=0 b=239
                TYA
                LDA     #30
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     241,S   ; fccstk d=0 b=241
                TAY
                LDA     _fcc_long_hi
                STA     243,S   ; fccstk d=0 b=243
                LDA     _fcc_q2
                STA     245,S   ; fccstk d=0 b=245
                LDA     _fcc_q3
                STA     247,S   ; fccstk d=0 b=247
                TYA
                LDA     #31
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     249,S   ; fccstk d=0 b=249
                TAY
                LDA     _fcc_long_hi
                STA     251,S   ; fccstk d=0 b=251
                LDA     _fcc_q2
                STA     253,S   ; fccstk d=0 b=253
                LDA     _fcc_q3
                STA     255,S   ; fccstk d=0 b=255
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
                ADC     #259
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                TAY
                LDA     _fcc_long_hi
                PHA
                TSC
                CLC
                ADC     #261
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                LDA     _fcc_q2
                PHA
                TSC
                CLC
                ADC     #263
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                LDA     _fcc_q3
                PHA
                TSC
                CLC
                ADC     #265
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                TYA
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
                PHA
                TSC
                CLC
                ADC     #267
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                TSC
                CLC
                ADC     #265
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                TAX
                LDA     #6
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                PHA
                TSC
                CLC
                ADC     #269
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
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
                LDA     31,S   ; fccstk d=8 b=23
                STA     _fcc_q3
                LDA     29,S   ; fccstk d=8 b=21
                STA     _fcc_q2
                LDA     27,S   ; fccstk d=8 b=19
                STA     _fcc_long_hi
                LDA     25,S   ; fccstk d=8 b=17
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
                LDA     39,S   ; fccstk d=8 b=31
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=8 b=29
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=8 b=27
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=8 b=25
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
                LDA     47,S   ; fccstk d=8 b=39
                STA     _fcc_q3
                LDA     45,S   ; fccstk d=8 b=37
                STA     _fcc_q2
                LDA     43,S   ; fccstk d=8 b=35
                STA     _fcc_long_hi
                LDA     41,S   ; fccstk d=8 b=33
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
                LDA     55,S   ; fccstk d=8 b=47
                STA     _fcc_q3
                LDA     53,S   ; fccstk d=8 b=45
                STA     _fcc_q2
                LDA     51,S   ; fccstk d=8 b=43
                STA     _fcc_long_hi
                LDA     49,S   ; fccstk d=8 b=41
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
                LDA     63,S   ; fccstk d=8 b=55
                STA     _fcc_q3
                LDA     61,S   ; fccstk d=8 b=53
                STA     _fcc_q2
                LDA     59,S   ; fccstk d=8 b=51
                STA     _fcc_long_hi
                LDA     57,S   ; fccstk d=8 b=49
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
                LDA     71,S   ; fccstk d=8 b=63
                STA     _fcc_q3
                LDA     69,S   ; fccstk d=8 b=61
                STA     _fcc_q2
                LDA     67,S   ; fccstk d=8 b=59
                STA     _fcc_long_hi
                LDA     65,S   ; fccstk d=8 b=57
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
                LDA     79,S   ; fccstk d=8 b=71
                STA     _fcc_q3
                LDA     77,S   ; fccstk d=8 b=69
                STA     _fcc_q2
                LDA     75,S   ; fccstk d=8 b=67
                STA     _fcc_long_hi
                LDA     73,S   ; fccstk d=8 b=65
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
                LDA     87,S   ; fccstk d=8 b=79
                STA     _fcc_q3
                LDA     85,S   ; fccstk d=8 b=77
                STA     _fcc_q2
                LDA     83,S   ; fccstk d=8 b=75
                STA     _fcc_long_hi
                LDA     81,S   ; fccstk d=8 b=73
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
                LDA     95,S   ; fccstk d=8 b=87
                STA     _fcc_q3
                LDA     93,S   ; fccstk d=8 b=85
                STA     _fcc_q2
                LDA     91,S   ; fccstk d=8 b=83
                STA     _fcc_long_hi
                LDA     89,S   ; fccstk d=8 b=81
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
                LDA     103,S   ; fccstk d=8 b=95
                STA     _fcc_q3
                LDA     101,S   ; fccstk d=8 b=93
                STA     _fcc_q2
                LDA     99,S   ; fccstk d=8 b=91
                STA     _fcc_long_hi
                LDA     97,S   ; fccstk d=8 b=89
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
                LDA     111,S   ; fccstk d=8 b=103
                STA     _fcc_q3
                LDA     109,S   ; fccstk d=8 b=101
                STA     _fcc_q2
                LDA     107,S   ; fccstk d=8 b=99
                STA     _fcc_long_hi
                LDA     105,S   ; fccstk d=8 b=97
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
                LDA     119,S   ; fccstk d=8 b=111
                STA     _fcc_q3
                LDA     117,S   ; fccstk d=8 b=109
                STA     _fcc_q2
                LDA     115,S   ; fccstk d=8 b=107
                STA     _fcc_long_hi
                LDA     113,S   ; fccstk d=8 b=105
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
                LDA     127,S   ; fccstk d=8 b=119
                STA     _fcc_q3
                LDA     125,S   ; fccstk d=8 b=117
                STA     _fcc_q2
                LDA     123,S   ; fccstk d=8 b=115
                STA     _fcc_long_hi
                LDA     121,S   ; fccstk d=8 b=113
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
                LDA     135,S   ; fccstk d=8 b=127
                STA     _fcc_q3
                LDA     133,S   ; fccstk d=8 b=125
                STA     _fcc_q2
                LDA     131,S   ; fccstk d=8 b=123
                STA     _fcc_long_hi
                LDA     129,S   ; fccstk d=8 b=121
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
                LDA     143,S   ; fccstk d=8 b=135
                STA     _fcc_q3
                LDA     141,S   ; fccstk d=8 b=133
                STA     _fcc_q2
                LDA     139,S   ; fccstk d=8 b=131
                STA     _fcc_long_hi
                LDA     137,S   ; fccstk d=8 b=129
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
                LDA     151,S   ; fccstk d=8 b=143
                STA     _fcc_q3
                LDA     149,S   ; fccstk d=8 b=141
                STA     _fcc_q2
                LDA     147,S   ; fccstk d=8 b=139
                STA     _fcc_long_hi
                LDA     145,S   ; fccstk d=8 b=137
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
                LDA     159,S   ; fccstk d=8 b=151
                STA     _fcc_q3
                LDA     157,S   ; fccstk d=8 b=149
                STA     _fcc_q2
                LDA     155,S   ; fccstk d=8 b=147
                STA     _fcc_long_hi
                LDA     153,S   ; fccstk d=8 b=145
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
                LDA     167,S   ; fccstk d=8 b=159
                STA     _fcc_q3
                LDA     165,S   ; fccstk d=8 b=157
                STA     _fcc_q2
                LDA     163,S   ; fccstk d=8 b=155
                STA     _fcc_long_hi
                LDA     161,S   ; fccstk d=8 b=153
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
                LDA     175,S   ; fccstk d=8 b=167
                STA     _fcc_q3
                LDA     173,S   ; fccstk d=8 b=165
                STA     _fcc_q2
                LDA     171,S   ; fccstk d=8 b=163
                STA     _fcc_long_hi
                LDA     169,S   ; fccstk d=8 b=161
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
                LDA     183,S   ; fccstk d=8 b=175
                STA     _fcc_q3
                LDA     181,S   ; fccstk d=8 b=173
                STA     _fcc_q2
                LDA     179,S   ; fccstk d=8 b=171
                STA     _fcc_long_hi
                LDA     177,S   ; fccstk d=8 b=169
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
                LDA     191,S   ; fccstk d=8 b=183
                STA     _fcc_q3
                LDA     189,S   ; fccstk d=8 b=181
                STA     _fcc_q2
                LDA     187,S   ; fccstk d=8 b=179
                STA     _fcc_long_hi
                LDA     185,S   ; fccstk d=8 b=177
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
                LDA     199,S   ; fccstk d=8 b=191
                STA     _fcc_q3
                LDA     197,S   ; fccstk d=8 b=189
                STA     _fcc_q2
                LDA     195,S   ; fccstk d=8 b=187
                STA     _fcc_long_hi
                LDA     193,S   ; fccstk d=8 b=185
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
                LDA     207,S   ; fccstk d=8 b=199
                STA     _fcc_q3
                LDA     205,S   ; fccstk d=8 b=197
                STA     _fcc_q2
                LDA     203,S   ; fccstk d=8 b=195
                STA     _fcc_long_hi
                LDA     201,S   ; fccstk d=8 b=193
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
                LDA     215,S   ; fccstk d=8 b=207
                STA     _fcc_q3
                LDA     213,S   ; fccstk d=8 b=205
                STA     _fcc_q2
                LDA     211,S   ; fccstk d=8 b=203
                STA     _fcc_long_hi
                LDA     209,S   ; fccstk d=8 b=201
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
                LDA     223,S   ; fccstk d=8 b=215
                STA     _fcc_q3
                LDA     221,S   ; fccstk d=8 b=213
                STA     _fcc_q2
                LDA     219,S   ; fccstk d=8 b=211
                STA     _fcc_long_hi
                LDA     217,S   ; fccstk d=8 b=209
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
                LDA     231,S   ; fccstk d=8 b=223
                STA     _fcc_q3
                LDA     229,S   ; fccstk d=8 b=221
                STA     _fcc_q2
                LDA     227,S   ; fccstk d=8 b=219
                STA     _fcc_long_hi
                LDA     225,S   ; fccstk d=8 b=217
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
                LDA     239,S   ; fccstk d=8 b=231
                STA     _fcc_q3
                LDA     237,S   ; fccstk d=8 b=229
                STA     _fcc_q2
                LDA     235,S   ; fccstk d=8 b=227
                STA     _fcc_long_hi
                LDA     233,S   ; fccstk d=8 b=225
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
                LDA     247,S   ; fccstk d=8 b=239
                STA     _fcc_q3
                LDA     245,S   ; fccstk d=8 b=237
                STA     _fcc_q2
                LDA     243,S   ; fccstk d=8 b=235
                STA     _fcc_long_hi
                LDA     241,S   ; fccstk d=8 b=233
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
                LDA     255,S   ; fccstk d=8 b=247
                STA     _fcc_q3
                LDA     253,S   ; fccstk d=8 b=245
                STA     _fcc_q2
                LDA     251,S   ; fccstk d=8 b=243
                STA     _fcc_long_hi
                LDA     249,S   ; fccstk d=8 b=241
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
                ADC     #263
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_q3
                TSC
                CLC
                ADC     #261
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_q2
                TSC
                CLC
                ADC     #259
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_long_hi
                TSC
                CLC
                ADC     #257
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
                ADC     #271
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_q3
                TSC
                CLC
                ADC     #269
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_q2
                TSC
                CLC
                ADC     #267
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_long_hi
                TSC
                CLC
                ADC     #265
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
                LDA     #528
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
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
                PHA
                TSC
                CLC
                ADC     #267
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
scalarfar_FRAMESIZE   EQU     268
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
