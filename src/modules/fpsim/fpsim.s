;==============================================================================
; fpsim.s - the floating point simulator module: fcc's soft double, as a system
; service (apple/fgx#447, docs/history/plans/2026-09-24-fpsim-module-plan.md).
;
; FGX's counterpart of 2.11BSD's usr/sys/pdp/mch_fpsim.s, "Kernel floating
; point simulator".  On a PDP-11 without an FPU, a floating point instruction
; traps and trap.c sends T_INSTRAP to fptrap(), so no program carries floating
; point code of its own.  Here a program's double operation is a call through
; the bank-0 vector FPSIM_TRAMP, and this module is what it reaches: one copy
; of the llvm-mos soft double (toolchain/lib/libdouble/softdouble.c, compiled
; by fcc as pile code) for every process.  Until this module loads, the far
; bank points the vector at _Fpsim_Absent, which raises SIGILL, as trap.c does
; with no FPU and no FPSIM.
;
; THE CALL.  A 64-bit operand is four words: w0 in A, w1 in _fcc_long_hi, w2
; and w3 in _fcc_q2 and _fcc_q3, and a second operand in _fcc_long_b_lo,
; _fcc_long_b_hi, _fcc_qb2 and _fcc_qb3.  w0 and w1 are in A and the direct
; page, and this module runs on the CALLER'S direct page and stack, so they
; cross as they are.  w2 and w3 are DATA cells in the caller's data bank, at
; offsets that differ in every binary, so the caller's stub
; (toolchain/lib/libdouble/d_stub.s) pushes them:
;
;       PEA-order: _fcc_qb3, _fcc_qb2, _fcc_q3, _fcc_q2;  X = FPOP_*;
;       JSL FPSIM_TRAMP
;
; fpsim_entry puts DBR on this bank, copies the four words into this module's
; own cells, runs the d_glue.s entry X names, and returns w0 in A, w1 in
; _fcc_long_hi, w2 in X and w3 in Y.  The stub stores X and Y back and drops
; the 8 bytes.
;
; ONE COPY SERVES EVERY PROCESS because a call runs to completion.  A task
; switches only at a syscall or an fcc loop safepoint (docs/scheduler.md), a
; signal is delivered only on a syscall's return, and none of this code makes a
; syscall or has a safepoint (-fno-safepoints) -- except the stack-overflow
; exit below, which does not return.  No interrupt handler calls it.
;
; MODBANK-C-OK: every global, literal and runtime scratch the soft double
; touches is read DBR-relatively, which fpsim_entry makes this module's bank
; for the whole call.
;==============================================================================

                MX      %11
                PUT     modplace.s
                ORG     MODP_ORG

                PUT     ../../../include/config.s
                PUT     ../../../include/macros.s       ; FGX2_*, PILE_CALL
                PUT     ../../../include/kernel.s       ; FPSIM_TRAMP, SYS_TRAMP
                PUT     ../../../include/loader.s       ; SYS_EXIT
                PUT     ../../../include/modules.s      ; VT_END

;------------------------------------------------------------------------------
; FGXM header v2 (40 bytes).
;------------------------------------------------------------------------------
fpsim_bss       EQU     0

fpsim_hdr       ASC     'FGXM'                          ; +0  magic
                DFB     <MODP_ORG                       ; +4  load lo
                DFB     >MODP_ORG                       ; +5  load mid
                DFB     ^MODP_ORG                       ; +6  load hi
                DFB     $02                             ; +7  header format v2
                DA      mod_init-$050000                ; +8  entry, bank-rel
                DA      fpsim_end-fpsim_text            ; +10 text bytes
                DA      fpsim_bss                       ; +12 bss bytes
                DA      fpsim_vtdir-fpsim_text          ; +14 vtdir offset
fpsim_name      ASC     'fpsim'                         ; +16 module name
                DS      16-*+fpsim_name                 ;     NUL-pad to 16
                DA      $0000                           ; +32 module version
                ; +34 build identity.  $0000 = not build-locked: this module
                ; bakes no kernel address; it names only the bank-0 vectors.
                DA      $0000
                DS      4                               ; +36 reserved

fpsim_text      EQU     *

fpsim_vtdir     ASC     'VTDR'
                DA      VT_END

;==============================================================================
; mod_init - point FPSIM_TRAMP at fpsim_entry.  A JML with this module's live
; bank (PHK), the way _Sys_InstallVectors plants SYS_TRAMP.  Runs in the
; modload syscall, so no program is between the bytes while they change.
;==============================================================================
mod_init        MX      %00
                PHP
                SEP     #$20
                MX      %10
                LDA     #$5C                    ; JML
                STAL    FPSIM_TRAMP+0
                LDA     #<fpsim_entry
                STAL    FPSIM_TRAMP+1
                LDA     #>fpsim_entry
                STAL    FPSIM_TRAMP+2
                PHK
                PLA
                STAL    FPSIM_TRAMP+3
                PLP
                SEC                             ; init OK
                RTL

;==============================================================================
; fpsim_entry - the dispatcher FPSIM_TRAMP reaches.  In: the carrier and B as
; above, X = FPOP_*.  Stack on entry: return (3), then _fcc_q2, _fcc_q3,
; _fcc_qb2, _fcc_qb3 as pushed by the stub.  MX %00.
;==============================================================================
FPOP_ADD        EQU     0                       ; must match d_stub.s
FPOP_SUB        EQU     2
FPOP_MUL        EQU     4
FPOP_DIV        EQU     6
FPOP_CMP        EQU     8
FPOP_FROML      EQU     10
FPOP_FROMUL     EQU     12
FPOP_FROMF      EQU     14
FPOP_TOL        EQU     16
FPOP_TOF        EQU     18

fpsim_entry     MX      %00
                PHB
                PHK
                PLB                             ; DBR = this module's bank
                TAY                             ; w0, across the copy
                LDA     5,S                     ; +1 DBR, +2..4 return
                STA     _fcc_q2
                LDA     7,S
                STA     _fcc_q3
                LDA     9,S
                STA     _fcc_qb2
                LDA     11,S
                STA     _fcc_qb3
                TYA
                JSR     (fpsim_ops,X)
                LDX     _fcc_q2
                LDY     _fcc_q3
                PLB                             ; the caller's DBR
                RTL

fpsim_ops       DA      fps_add,fps_sub,fps_mul,fps_div,fps_cmp
                DA      fps_froml,fps_fromul,fps_fromf,fps_tol,fps_tof

fps_add         PILE_CALL _fcc_dadd
                RTS
fps_sub         PILE_CALL _fcc_dsub
                RTS
fps_mul         PILE_CALL _fcc_dmul
                RTS
fps_div         PILE_CALL _fcc_ddiv
                RTS
fps_cmp         PILE_CALL _fcc_dcmp
                RTS
fps_froml       PILE_CALL _fcc_dfroml
                RTS
fps_fromul      PILE_CALL _fcc_dfromul
                RTS
fps_fromf       PILE_CALL _fcc_dfromf
                RTS
fps_tol         PILE_CALL _fcc_dtol
                RTS
fps_tof         PILE_CALL _fcc_dtof
                RTS

;------------------------------------------------------------------------------
; _fcc_stkoflow - the soft double's prologue stack guard, for a caller's stack.
; The code runs on the calling program's stack against that program's floor
; (_fcc_stkfloor, its direct page), so an overflow is the program's, and it
; ends the program the way toolchain/lib/fcc_runtime.s's _fcc_stkoflow does:
; exit status 134.  Not the kernel's fcc_ktrap.s, which halts the machine.
;------------------------------------------------------------------------------
_fcc_stkoflow   MX      %00
                LDA     #134
                JSL     SYS_TRAMP
                DFB     SYS_EXIT
@so_spin        BRA     @so_spin                ; SYS_EXIT does not return

;------------------------------------------------------------------------------
; The soft double, the long long routines it computes with, and the runtime.
;------------------------------------------------------------------------------
                PUT     ../../kernel/far/fcc_dp.s               ; EQU only
                PUT     ../../../toolchain/lib/libdouble/d_glue.s
                PUT     ../../../toolchain/lib/libdouble/softdouble.s
                PUT     ../../../toolchain/lib/libllong/ll_addsub.s
                PUT     ../../../toolchain/lib/libllong/ll_bit.s
                PUT     ../../../toolchain/lib/libllong/ll_neg.s
                PUT     ../../../toolchain/lib/libllong/ll_shift.s
                PUT     ../../../toolchain/lib/libllong/ll_cmp.s
                PUT     ../../../toolchain/lib/libllong/ll_mul.s
                PUT     ../../../toolchain/lib/libllong/ll_div.s
                PUT     ../../kernel/far/fcc_rt.s
                PUT     ../../../toolchain/lib/libdouble/softdouble.data.s
                PUT     ../../../toolchain/lib/libllong/ll_shift.data.s
                PUT     ../../../toolchain/lib/libllong/ll_mul.data.s
                PUT     ../../../toolchain/lib/libllong/ll_div.data.s
                PUT     ../../../toolchain/lib/fcc_runtime_data.s

fpsim_end       EQU     *

; Placement guards (tools/gen_modplace.py writes MODP_* into modplace.s).
                ERR     fpsim_hdr-MODP_ORG
                ERR     fpsim_end-MODP_ORG+fpsim_bss/MODP_LIMIT
