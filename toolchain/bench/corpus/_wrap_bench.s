;==============================================================================
; _wrap_bench.s — headerless bare-metal wrapper for fbench CYCLE benchmarks.
; NO FGX1 header: file offset 0 == first instruction, so the harness loads the
; raw image at $001000 and sets PC=$1000 with no header to skip. ORG $001000 so
; every 2-byte JSR / DBR-relative data ref resolves at the load address. The
; benchmark's main() brackets its hot loop with FBENCH_START()/FBENCH_DONE()
; (marker.h -> fbench_markers.s, PUT below), so the same .c source also runs
; under the real FGX kernel (Option B); this wrapper just enters main and spins.
;==============================================================================
                MX      %11             ; emulation start: A+index 8-bit
                ORG     $001000

crt0_bench      EQU     *
                CLC
                XCE                     ; native mode
                REP     #$30            ; 16-bit A + index (runtime)
                MX      %00             ; tell Merlin32 both regs are 16-bit now —
                                        ; else LDX/LDA #imm assemble 1-byte and the
                                        ; 16-bit-mode CPU mis-reads the stream
                LDX     #$0FFF          ; ample bank-0 stack (recursive benches)
                TXS
                FGX2_FARCALL main       ; main brackets its hot loop w/ FBENCH_START/DONE
                                        ; FARCALL, not JSR: fcc functions end in RTL
done_spin       BRA     done_spin

;------------------------------------------------------------------------------
; SYSCALL STUBS -- bare metal has no kernel.
;
; fcc_runtime.s's three trap routines (_fcc_sfoflow, _fcc_stkoflow,
; _fcc_safepoint) reach SYS_EXIT and SYS_YIELD through SYS_TRAMP, and nothing
; defines those here, so the whole file failed to assemble.  (The kernel-C seam
; hit the identical wall and answered it by extracting the runtime from
; _fcc_mul16 onward; a bench can take the simpler route of stubbing the entry.)
;
; A bench must never reach one: a safepoint means the loop-yield was compiled
; in, and either overflow trap means the bench blew its stack.  Any of those
; makes the timing meaningless, so the stub SPINS rather than returning a
; plausible number -- the harness times out, which is a visible failure, where
; an RTL would silently carry on and report a figure.
;------------------------------------------------------------------------------
; SYS_YIELD is defined by fcc_runtime.s itself; only these two are missing.
SYS_TRAMP       EQU     _bench_syscall_stub
SYS_EXIT        EQU     0
_bench_syscall_stub
@bss_spin       BRA     @bss_spin


                PUT     bench_macros.s  ; MUST precede fcc_output.s: it uses these
                PUT     fcc_output.s
                PUT     fbench_markers.s
                PUT     ../../lib/fcc_runtime.s
                PUT     ../../lib/fcc_runtime_data.s
