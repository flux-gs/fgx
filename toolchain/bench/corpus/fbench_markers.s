;==============================================================================
; fbench_markers.s — START/DONE cycle markers, callable from C.
;
; fcc emits `FGX2_FARCALL fbench_start` / `FGX2_FARCALL fbench_done` for the extern
; calls in marker.h, so these END IN RTL.  They used to end in RTS, back when fcc
; emitted a bare JSR for an unseen extern -- when fcc went single-ABI that stopped
; being true and the whole corpus began reporting merlin-fail, which the report
; renders as SKIP and reads exactly like a bench nobody configured.
; The stores are absolute-long (STAL), hence DBR-independent — they hit bank 2
; ($025000 / $025002) whether running bare-metal at bank 0 or under the FGX
; kernel with an arbitrary DBR. The fbench cycle harness taps those two writes
; (install_write_tap) and captures emu.time() at each, so the markers must be the
; FIRST and LAST things bracketing the hot loop.
;
; PHP/PLP preserve the caller's M/X width; REP #$30 makes the LDA #imm16 16-bit
; at runtime regardless of the caller's mode (matches the MX %00 directive the
; assembler sizes the immediate under).
;==============================================================================
                MX      %00

; FGX2_EXPORT: fgx_ld resolves FGX2_FARCALL by name across segments, and a
; hand-asm label it has not been told about is 'unresolved symbol in any
; segment'.  Harmless in the bare-metal link, where the macro is inert.
                FGX2_EXPORT fbench_start
fbench_start    PHP
                REP     #$30
                LDA     #$A1A1
                STAL    $025000
                PLP
                RTL

                FGX2_EXPORT fbench_done
fbench_done     PHP
                REP     #$30
                LDA     #$A2A2
                STAL    $025002
                PLP
                RTL
