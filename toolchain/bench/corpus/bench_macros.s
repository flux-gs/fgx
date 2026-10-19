;==============================================================================
; bench_macros.s - the FGX2_* macros, for a bench that has no linker.
;
; WHY THIS EXISTS.  fcc used to emit a bare `JSR name` for a call to an extern
; it had not seen, and fbench_markers.s says so in its own header ("verified:
; no name mangling").  fcc is now single-ABI: every user call is
; `FGX2_FARCALL name`, every function ends in RTL, and each translation unit is
; stamped FGX2_MODE / FGX2_RELOC_COUNT.  Those are macro invocations, and the
; bench wrappers PUT no macro file, so the whole corpus stopped assembling --
; every bench reporting `merlin-fail` and being SKIPPED, which reads in the
; report exactly like a bench that was never configured.
;
; toolchain/lib/macros.s cannot be used here.  Its FGX2_FARCALL emits
; `JSL $000000` for fgx_ld to patch, and a bench is a single-bank image with no
; link step -- the call would jump to bank 0 offset 0.
;
; So FGX2_FARCALL is a SAME-BANK synthesized JSL: PHK pushes the live program
; bank and PER pushes the return address, which is exactly the 3-byte frame a
; JSL leaves and an RTL consumes.  It is relocation-independent -- PER is
; PC-relative and PHK reads the bank at runtime -- so it is correct whichever
; bank the loader puts the image in, which a baked `JSL label` would not be.
;==============================================================================

FGX2_MODE       MAC
;               (no linker here; the stamp is inert)
                <<<

FGX2_RELOC_COUNT MAC
;               (no linker here; nothing counts the rows)
                <<<

FGX2_EXPORT     MAC
;               (single segment: nothing to export to)
                <<<

;------------------------------------------------------------------------------
; FGX2_FARCALL <name> - a same-bank call to an RTL-terminated routine.
;
;   PHK      1 byte   pushes the LIVE program bank
;   PER *+5  3 bytes   pushes (this address + 5)
;   JMP name 3 bytes
;
; PER sits at A, so it pushes A+5.  JMP occupies A+3..A+5, the return point is
; A+6, and RTL pulls the pushed word and INCREMENTS it -- so A+5 is the value
; that must be on the stack.  Same shape as the kernel-C seam's boundary, and
; for the same reason: a baked JSL bank byte is wrong the moment the image is
; loaded somewhere other than where it was assembled.
;------------------------------------------------------------------------------
FGX2_FARCALL    MAC
                PHK
                PER     *+5
                JMP     ]1
                <<<
