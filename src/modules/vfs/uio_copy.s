;==============================================================================
; uio_copy.s - the block move behind `uiomove', in the bank that calls it.
;
; THIS IS Reno's `bcopy' AND IT IS ASSEMBLY UPSTREAM TOO.  `uiomove's SYSSPACE
; arm is `bcopy((caddr_t)cp, iov->iov_base, cnt)' (4.3BSD-Reno
; kern/kern_subr.c:48,50), and there is NO C definition of bcopy anywhere in
; the vendored trees -- it is machine-dependent on every BSD port, because
; every machine has a block move worth reaching (the VAX's `movc3', the
; PDP-11's loop).  The 65816's is MVN.  So this file is the port, not a
; local reimplementation working around a missing libc: kernel C links no
; libc here by design, and upstream's kernel does not either.
;
; WHAT IT REPLACES, and why the C version had to go.  `uio_copy' was a
; `for (i = 0; i < n; i++) dst[i] = src[i];' byte loop, and its own header
; comment predicted this day: "IT IS SLOW AND THAT IS A KNOWN CEILING ...
; the 65816 has MVN ... Nothing measures as slow yet because nothing calls
; this on a hot path -- the only caller is the probe."  The hot-path caller
; arrived with the vnode read path.  fcc spends about 45 instructions per byte
; on that loop: a `JSR _fcc_lts16' for the compare, BOTH far pointers rebuilt
; out of the frame every iteration, four PHA/PLA pairs, and a SEP/REP straddling
; the one store.  MVN is seven cycles a byte with no loop at all.
;
; THE BANK BYTES ARE PATCHED INTO THE INSTRUCTION, which is not a liberty --
; MVN's banks are OPERANDS, assembled as immediates, and both of ours are
; runtime values: a buffer-cache block in whatever bank the cache was allocated
; and a caller's buffer in whatever bank the process runs.  `_Far_ModLoad' does
; exactly this at `@fml_mvn' (src/kernel/far/vfs_seam_entry.s) and streams every
; module image through it.  The two `STA' targets follow that site's convention:
; operand+1 is the DESTINATION bank, operand+2 the SOURCE.
;
; A ZERO-LENGTH COPY MUST RETURN BEFORE THE DEC.  MVN moves A+1 bytes, so n = 0
; decremented is $FFFF and the move becomes SIXTY-FIVE KILOBYTES through two
; runtime banks.  `uiomove' does clamp `cnt' above zero before calling, but the
; guard is here because the failure is not a wrong answer, it is the kernel
; overwriting two banks; a caller's invariant is the wrong place to keep it.
;
; MVN LEAVES DBR ON THE DESTINATION BANK, so `_DBRK' puts it back before the
; RTL.  Kernel C runs with DBR = this module's bank (MOD_KC_ENTER put it
; there), and a DBR-relative read afterwards would otherwise come from the
; destination bank at the same offset -- plausible data, silently wrong.
;
; NO OVERLAP HANDLING, which is `bcopy's contract as Reno's callers use it and
; is what MVN gives: it INCREMENTS both pointers, so a destination above an
; overlapping source would eat its own tail.  A uio's two sides are a
; buffer-cache block and a caller's buffer -- different objects by
; construction.  MVP is the other direction if that ever stops being true.
;
; THE PATCHED OPERAND IS NOT RE-ENTRANT, and what makes that safe here is the
; invariant `tools/check_fs_sleep_invariant.py' already enforces: the FS layer
; does not sleep, so no task switch can land between the two `STA's and the
; MVN.  No interrupt handler reaches `uiomove' either -- the tty's read path
; goes to `ureadc', a byte at a time, and never here.  Recorded rather than
; guarded because the guard would be an SEI held across the whole move.
;==============================================================================

;------------------------------------------------------------------------------
; uio_copy(src, dst, n) - move n bytes from src to dst.  MX %00 in and out.
;
; THE FRAME IS fcc's PILE CALL and this routine pushes nothing, so the
; arguments sit at fixed offsets from the entry S.  A `char *' is FOUR bytes,
; offset word then bank word, and the three-byte return address is below them:
;
;    4,S  src offset      6,S  src bank      (low byte of the bank word)
;    8,S  dst offset     10,S  dst bank
;   12,S  n
;
; Both offsets load THROUGH A and transfer: `n,S' is an accumulator-only
; addressing mode on this processor, so `LDX 4,S' does not assemble.
;
; The caller pops; this returns with RTL and clobbers A, X and Y.
;------------------------------------------------------------------------------
                MX      %00
uio_copy        ENT
                MX      %00
                LDA     12,S                    ; n
                BEQ     @uc_done                ; zero is NOT 65536; see above
                SEP     #$20
                MX      %10
                LDA     6,S                     ; src bank -> operand+2
                STA     @uc_mvn+2
                LDA     10,S                    ; dst bank -> operand+1
                STA     @uc_mvn+1
                REP     #$20
                MX      %00
                LDA     4,S                     ; THROUGH A: the 65816 has no
                TAX                             ;   stack-relative LDX or LDY,
                LDA     8,S                     ;   only the accumulator gets
                TAY                             ;   `n,S'
                LDA     12,S
                DEC                             ; MVN moves A+1 bytes
@uc_mvn         MVN     $00,$00                 ; banks patched just above
                _DBRK                           ; MVN left DBR = destination
@uc_done        RTL
