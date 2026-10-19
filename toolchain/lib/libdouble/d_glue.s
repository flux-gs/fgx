;==============================================================================
; d_glue -- the soft double's entry points (apple/fgx#447), assembled into the
; fpsim module (src/modules/fpsim) with softdouble.s, which fcc compiles from
; softdouble.c (the llvm-mos soft double; see docs/PROVENANCE.md).  Programs
; reach them through d_stub.s and the module's dispatcher, with the carrier
; and B already in the module's own cells.
;
; fcc carries a 64-bit value in four words: w0 in A, w1 in _fcc_long_hi, w2 in
; _fcc_q2, w3 in _fcc_q3 (the carrier), and a second operand in
; _fcc_long_b_lo, _fcc_long_b_hi, _fcc_qb2 and _fcc_qb3 -- the llong runtime's
; convention, so fcc reaches a double operation the way it reaches a long long
; one.  softdouble.c's routines are C: arguments pushed right to left, a
; 64-bit argument as four words with w0 lowest, the caller popping them, and a
; 64-bit result back in the carrier.  Each entry here pushes its operands that
; way, calls the routine, and drops them.  Nothing is kept in memory between
; calls, so an entry is reentrant.
;
;   _fcc_dadd _fcc_dsub _fcc_dmul _fcc_ddiv   carrier op B -> carrier
;   _fcc_dcmp     A = $FFFF (carrier < B), 0 (equal), 1 (greater), 2 (either
;                 is a NaN: unordered), N and Z set from A
;   _fcc_dfroml   the long in A:_fcc_long_hi -> carrier
;   _fcc_dfromul  the unsigned long in A:_fcc_long_hi -> carrier
;   _fcc_dfromf   the float in A:_fcc_long_hi -> carrier
;   _fcc_dtol     carrier -> A:_fcc_long_hi, the fraction discarded
;   _fcc_dtof     carrier -> the float in A:_fcc_long_hi
;
; _fcc_dtol serves every integral target.  K&R A.6.3: "the fractional part is
; discarded; if the resulting value cannot be represented in the integral
; type, the behavior is undefined."  A negative value goes through __fixdfsi
; and any other through __fixunsdfsi, so each value a long or an unsigned
; long can hold converts exactly, and a narrower target keeps the low word.
;==============================================================================
                MX      %00

                FGX2_EXPORT _fcc_dadd
_fcc_dadd       ENT
                JSR     d_push2
                PILE_CALL       __adddf3
                JMP     d_drop16

                FGX2_EXPORT _fcc_dsub
_fcc_dsub       ENT
                JSR     d_push2
                PILE_CALL       __subdf3
                JMP     d_drop16

                FGX2_EXPORT _fcc_dmul
_fcc_dmul       ENT
                JSR     d_push2
                PILE_CALL       __muldf3
                JMP     d_drop16

                FGX2_EXPORT _fcc_ddiv
_fcc_ddiv       ENT
                JSR     d_push2
                PILE_CALL       __divdf3
                JMP     d_drop16

; __cmpdf2 orders bit patterns and does not know a NaN, so __unorddf2 goes
; first.  Neither routine assigns to its parameters, so the operands pushed
; once serve both calls.
                FGX2_EXPORT _fcc_dcmp
_fcc_dcmp       ENT
                JSR     d_push2
                PILE_CALL       __unorddf2
                CMP     #0
                BNE     @dcmp_un
                PILE_CALL       __cmpdf2
                JMP     d_drop16
@dcmp_un        TSC
                CLC
                ADC     #16
                TCS
                LDA     #2
                RTL

                FGX2_EXPORT _fcc_dfroml
_fcc_dfroml     ENT
                JSR     d_push1l
                PILE_CALL       __floatsidf
                JMP     d_drop4

                FGX2_EXPORT _fcc_dfromul
_fcc_dfromul    ENT
                JSR     d_push1l
                PILE_CALL       __floatunsidf
                JMP     d_drop4

                FGX2_EXPORT _fcc_dfromf
_fcc_dfromf     ENT
                JSR     d_push1l
                PILE_CALL       __extendsfdf2
                JMP     d_drop4

                FGX2_EXPORT _fcc_dtol
_fcc_dtol       ENT
                TAY
                LDA     _fcc_q3
                BMI     @dtol_neg
                TYA
                JSR     d_push1q
                PILE_CALL       __fixunsdfsi
                JMP     d_drop8
@dtol_neg       TYA
                JSR     d_push1q
                PILE_CALL       __fixdfsi
                JMP     d_drop8

                FGX2_EXPORT _fcc_dtof
_fcc_dtof       ENT
                JSR     d_push1q
                PILE_CALL       __truncdfsf2
                JMP     d_drop8

; The pushers run as near subroutines, so each slides its own return address
; up past what it pushes: pull it into X, push, push X back, RTS.

; Push B, then the carrier: f(carrier, B) with the carrier as the first
; argument.
d_push2         PLX
                TAY
                LDA     _fcc_qb3
                PHA
                LDA     _fcc_qb2
                PHA
                LDA     _fcc_long_b_hi
                PHA
                LDA     _fcc_long_b_lo
                PHA
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                PHY
                PHX
                RTS

; Push the carrier as one 64-bit argument.
d_push1q        PLX
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                PHY
                PHX
                RTS

; Push A:_fcc_long_hi as one 32-bit argument.
d_push1l        PLX
                TAY
                LDA     _fcc_long_hi
                PHA
                PHY
                PHX
                RTS

; Drop the arguments, keep A, and return to fcc's caller with N and Z set
; from A.
d_drop16        TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                RTL
d_drop8         TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                RTL
d_drop4         TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                RTL
