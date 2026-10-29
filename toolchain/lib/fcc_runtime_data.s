;==============================================================================
; fcc_runtime_data.s - DA-declared scratch storage for fcc runtime helpers.
;
; Split out from fcc_runtime.s so multi-bank FGX2 builds can PUT this file
; into seg1 (the DBR-resident data segment).  Helper code in fcc_runtime.s
; references these globals via DBR-relative absolute addressing (`STA name`),
; which at runtime resolves to (DBR : name_offset).  In a single-bank build
; DBR == seg0 bank, so storage in seg0 worked.  In multi-bank, DBR == seg1
; bank, so the storage MUST live in seg1 to match.
;
; PUT order:
;   single-bank (tests/M*/_wrap.s, tools/fcc/fcc_multi.sh):
;     after fcc_runtime.s in the same segment
;   multi-bank (tools/fas/seg1.link.s, future userland C binaries):
;     anywhere in seg1
;
; See feedback_fas_load_corrupts_src_at_certain_addrs.md for the multi-bank
; bug this fixes.  At MAX_SYMBOLS=244, the DA cells used to land at seg0
; offsets that collided with fas_src_buf in seg1.
;==============================================================================

                MX      %00

; --- M1 binop scratch (8-bit and 16-bit helpers) ---
_fcc_tmp_b      DA      0

; --- apple/fgx#12: the task DATA BANK, cached as a 16-bit value (bank in the
;     low byte, high byte 0 so no masking is needed at the use site).
;
; K&R code launders pointers through `int` constantly (2.11BSD's
; `#define Rcheat(a) ((int)(a))` / `BLK(x)`), and a RUNTIME int reconstituted as
; a pointer has to address the data bank.  Reading DBR live costs an 8-bit
; island -- SEP/PHB/PLA/REP/AND, 9 bytes -- at every such site, and tcsh has
; 1511 of them.  DBR is INVARIANT in FGX2 user code: the loader pre-sets it to
; bank-of-n_data_segment and crt0 deliberately does NOT PHK/PLB (that is the
; seg0-code-reads-seg1-data invariant), so a value cached once at entry is
; exactly what PHB would have pushed.  Seeded by crt0.
;
; Lives in the DATA segment on purpose: one copy per binary.  The same cell in
; fcc_runtime.s would be duplicated into every code bank (nine times in tcsh).
_fcc_dbr        DA      0

; --- _fcc_mul16 scratch ---
_fcc_mul_lhs    DA      0
_fcc_mul_acc    DA      0

; --- _fcc_divs16 scratch ---
_fcc_div_dvd    DA      0
_fcc_div_negq   DA      0

; --- _fcc_lts16 / _fcc_ges16 scratch ---
_fcc_cmp_scratch DA      0
_fcc_cmp_swap    DA      0

; --- M20 long-mul scratch ---
_fcc_long_mul_lhs_lo DA 0
_fcc_long_mul_lhs_hi DA 0
_fcc_long_mul_acc_lo DA 0
_fcc_long_mul_acc_hi DA 0

; --- M20 long-div scratch ---
_fcc_long_div_dvd_lo  DA 0
_fcc_long_div_dvd_hi  DA 0
_fcc_long_div_rem_lo  DA 0
_fcc_long_div_rem_hi  DA 0
_fcc_long_div_quo_lo  DA 0
_fcc_long_div_quo_hi  DA 0
_fcc_long_div_negq    DA 0

; --- M20 long-mods scratch ---
_fcc_long_mods_dvd_lo DA 0
_fcc_long_mods_dvd_hi DA 0

; --- M20 long-cmp scratch ---
_fcc_long_gts_tmp_lo DA 0
_fcc_long_gts_tmp_hi DA 0
_fcc_long_gts_swap_lo DA 0
_fcc_long_gts_swap_hi DA 0

; --- B-6 softfloat scratch (IEEE-754 single) ---
_fcc_f_lo       DA      0        ; working mantissa / result low word
_fcc_f_hi       DA      0        ; working mantissa / result high word
_fcc_f_exp      DA      0        ; exponent field / unbiased exponent
_fcc_f_sign     DA      0        ; sign bit (0 or $8000)
_fcc_f_tmp      DA      0        ; scratch
; unpacked operands a (LHS) and b (RHS): 24-bit mantissa in lo:hi
_fcc_fa_lo      DA      0
_fcc_fa_hi      DA      0
_fcc_fa_exp     DA      0
_fcc_fa_sign    DA      0
_fcc_fb_lo      DA      0
_fcc_fb_hi      DA      0
_fcc_fb_exp     DA      0
_fcc_fb_sign    DA      0
; 48-bit multiply accumulator + multiplicand
_fcc_fm0        DA      0
_fcc_fm1        DA      0
_fcc_fm2        DA      0
_fcc_fmc0       DA      0
_fcc_fmc1       DA      0
_fcc_fmc2       DA      0
; round-to-nearest-even scratch (B-6 follow-up)
_fcc_f_guard    DA      0        ; guard bit (nonzero = the dropped MSB is 1)
_fcc_f_sticky   DA      0        ; sticky bit (nonzero = any lower dropped bit 1)
_fcc_f_g        DA      0        ; result guard word (bits below mantissa LSB)
_fcc_fb_g       DA      0        ; operand-b guard word during fadd alignment
_fcc_f_round    DA      0        ; dropped low byte during ltof (>>8)

; --- T5-C C1 __syscall builtin latch cells ---
; Every N_SYSCALL emission stores the raw carry (0/1) and the Y register
; here after the trampoline returns (DB variant: after the PLB restore, so
; the stores are caller-data-bank relative).  C wrappers read them back via
; __syscall_c()/__syscall_y().  Durable across expression codegen — these
; are NOT scratch the next binop may clobber.
__sys_c         DA      0        ; carry from the last __syscall (raw sense)
__sys_y         DA      0        ; Y from the last __syscall (return-hi word)

; --- T5-C C4b __asm staging cells ---
; C-addressable handoff into __asm blocks (extern in lib/libc_c/libc_c.c).
; fcc NEVER touches __asm_* — a C store here survives to the block; the
; _fcc_* scratch would not (codegen may clobber it between the store and
; the asm).  p0/p1 are 4-byte far pointers, w0/w1 words.
__asm_p0        DS      4
__asm_p1        DS      4
__asm_w0        DA      0
__asm_w1        DA      0
__asm_w2        DA      0        ; third word lane (c_time's 3-word RTC frame)

; --- long long: the accumulator's and the second operand's two high words ---
; A long long is a long with two more words: w0 in A and w1 in _fcc_long_hi
; (DP) as for a long, w2/w3 here, because direct page is full from $98 up.  The
; second operand extends _fcc_long_b_lo/_hi the same way.  Nothing holds them
; across a call or a loop back-edge, which is where a signal handler can run
; (docs/history/plans/2026-09-23-fcc-long-long-plan.md).
_fcc_q2         DA      0
_fcc_q3         DA      0
_fcc_qb2        DA      0
_fcc_qb3        DA      0
