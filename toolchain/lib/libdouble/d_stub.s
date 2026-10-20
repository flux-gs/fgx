;==============================================================================
; d_stub -- fcc's entry points into the soft double, for a program: each one
; calls the fpsim module through the bank-0 vector FPSIM_TRAMP (apple/fgx#447,
; docs/history/plans/2026-09-24-fpsim-module-plan.md).  The double archive's
; one member; the archive walk selects it into the tool's libc pile, and the
; tool's own code reaches it by FGX2_FARCALL.
;
; The entries and their contract are d_glue.s's, which the module runs:
;
;   _fcc_dadd _fcc_dsub _fcc_dmul _fcc_ddiv   carrier op B -> carrier
;   _fcc_dcmp     A = $FFFF / 0 / 1, or 2 when either is a NaN; N, Z from A
;   _fcc_dfroml _fcc_dfromul _fcc_dfromf      A:_fcc_long_hi -> carrier
;   _fcc_dtol _fcc_dtof                       carrier -> A:_fcc_long_hi
;
; A 64-bit value is w0 in A, w1 in _fcc_long_hi, w2 and w3 in _fcc_q2 and
; _fcc_q3; B is _fcc_long_b_lo, _fcc_long_b_hi, _fcc_qb2 and _fcc_qb3.  The
; module runs on this program's direct page and stack, so A and the direct
; page words cross as they are.  _fcc_q2 ... _fcc_qb3 are DATA cells, in this
; program's data bank, which the module cannot read, so they are pushed, and
; the module hands the result's w2 and w3 back in X and Y.
;
; `JSL FPSIM_TRAMP' has a bank-0 operand, so it needs no relocation and the
; reloc-free pile can make it -- as it makes `JSL SYS_TRAMP'.
;==============================================================================
                MX      %00

; The bank-0 vector, include/kernel.s.  A fixed address, like SYS_TRAMP's.
FPSIM_TRAMP     EQU     $000324

; The module's operation numbers, the index fpsim_entry dispatches on
; (src/modules/fpsim/fpsim.s).
FPOP_ADD        EQU     0
FPOP_SUB        EQU     2
FPOP_MUL        EQU     4
FPOP_DIV        EQU     6
FPOP_CMP        EQU     8
FPOP_FROML      EQU     10
FPOP_FROMUL     EQU     12
FPOP_FROMF      EQU     14
FPOP_TOL        EQU     16
FPOP_TOF        EQU     18

                FGX2_EXPORT _fcc_dadd
_fcc_dadd       ENT
                LDX     #FPOP_ADD
                BRA     ds_call

                FGX2_EXPORT _fcc_dsub
_fcc_dsub       ENT
                LDX     #FPOP_SUB
                BRA     ds_call

                FGX2_EXPORT _fcc_dmul
_fcc_dmul       ENT
                LDX     #FPOP_MUL
                BRA     ds_call

                FGX2_EXPORT _fcc_ddiv
_fcc_ddiv       ENT
                LDX     #FPOP_DIV
                BRA     ds_call

                FGX2_EXPORT _fcc_dcmp
_fcc_dcmp       ENT
                LDX     #FPOP_CMP
                BRA     ds_call

                FGX2_EXPORT _fcc_dfroml
_fcc_dfroml     ENT
                LDX     #FPOP_FROML
                BRA     ds_call

                FGX2_EXPORT _fcc_dfromul
_fcc_dfromul    ENT
                LDX     #FPOP_FROMUL
                BRA     ds_call

                FGX2_EXPORT _fcc_dfromf
_fcc_dfromf     ENT
                LDX     #FPOP_FROMF
                BRA     ds_call

                FGX2_EXPORT _fcc_dtol
_fcc_dtol       ENT
                LDX     #FPOP_TOL
                BRA     ds_call

                FGX2_EXPORT _fcc_dtof
_fcc_dtof       ENT
                LDX     #FPOP_TOF

; Push the data-bank words, call the module, store w2 and w3 back, drop the 8
; bytes, and return to the entry's caller with A and N, Z from A.
ds_call         TAY                             ; w0, across the pushes
                LDA     _fcc_qb3
                PHA
                LDA     _fcc_qb2
                PHA
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                TYA
                JSL     FPSIM_TRAMP
                STX     _fcc_q2
                STY     _fcc_q3
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                RTL

; This file's FGX2_EXPORT rows, counted as fcc counts its own.
                FGX2_RELOC_COUNT 10
