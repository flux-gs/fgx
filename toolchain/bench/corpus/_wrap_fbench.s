;==============================================================================
; _wrap_fbench.s - FGX1 wrapper for fbench CYCLE benchmarks run under the REAL
; kernel (Option B).  Same shape as the test _wrap_libc.s (FGX1 header + crt0 +
; libc + cc shims), plus PUT of fbench_markers.s so the benchmark's
; fbench_start()/fbench_done() calls resolve.  The kernel loader loads this at
; its load bank, crt0 calls main(), main brackets its hot loop with the markers
; (STAL bank 2, DBR-independent), then returns -> crt0 -> SYS_EXIT.  The fbench
; harness taps the $025000/$025002 writes for the cycle delta.
;==============================================================================

                MX      %11
                ORG     $0B0000

SYS_EXIT        EQU     1
SYS_WRITE       EQU     4
SYS_TRAMP       EQU     $000328

fcc_hdr         ASC     'FGX1'
                DFB     <$0B0000
                DFB     >$0B0000
                DFB     ^$0B0000
                DFB     $00
                DA      _crt0_start-$0B0000
                DA      fcc_end-fcc_text
                DA      0
                DFB     fcc_stack_pages
                DFB     $00

fcc_text        EQU     *
; libc.s gates its far-call paths on LIBC_FAR.  A bench is single-segment, so
; the answer is 0 -- but the symbol must EXIST or Merlin cannot evaluate the DO.
LIBC_FAR        EQU     0
                PUT     bench_macros.s  ; MUST precede fcc_output.s: it uses these
                PUT     ../../lib/crt0.s
                PUT     fcc_output.s
                PUT     fbench_markers.s
                PUT     ../../lib/fcc_runtime.s
                PUT     ../../lib/fcc_runtime_data.s
                PUT     ../../lib/libc.s
                PUT     ../../lib/libc_data.s
                PUT     ../../lib/fcc_libc_shims.s
                PUT     ../../lib/args.s
                PUT     ../../lib/args_data.s
fcc_end         EQU     *
