/* SPDX-License-Identifier: Apache-2.0
 * FGX-Provenance: 65816-llvm-mos (vendor/65816-llvm-mos/runtime/src/softDouble.c)
 *   The W65816 llvm-mos fork's IEEE-754 double arithmetic, commit 4a13f9df,
 *   the source of fcc's 64-bit double runtime (apple/fgx#447).  FGX deltas:
 *   __floatsidf widens its argument before negating it, which overflowed an
 *   s32 at INT32_MIN (apple/fgx#493); __truncdfsf2 rounds to nearest, ties
 *   to even, where upstream truncates, and keeps a NaN whose payload is all in
 *   the dropped bits a NaN; comments are ASCII.  The upstream text
 *   follows.  See docs/PROVENANCE.md.
 */
// Real double-precision IEEE 754 soft-float for the W65816.  Treats
// a `double` as `unsigned long long` (64-bit) and operates on its
// bit pattern.  Returns by-value at the i64 ABI A:X:Y:DP[$F0].
//
// Earlier attempts crashed the Register Coalescer; the greedy
// regalloc landing fixed the underlying register pressure problem.
// Each routine is broken into small helpers to keep frames shallow.

// Local typedefs (no stdint.h -- clang's host stdint pulls glibc).
typedef unsigned long long u64;
typedef long long          s64;
typedef unsigned long      u32;
typedef long               s32;
typedef unsigned int       u16;
typedef int                s16;
typedef unsigned char      u8;

#define DSIGN_BIT  0x8000000000000000ULL
#define DEXP_MASK  0x7FF0000000000000ULL
#define DMANT_MASK 0x000FFFFFFFFFFFFFULL
#define DMANT_LEAD 0x0010000000000000ULL
#define DEXP_SHIFT 52
#define DEXP_BIAS  1023

// Pack sign / unbiased-exp / mantissa-with-leading-bit into IEEE-754
// double.  Returns sign for zero or underflow; sign|inf for overflow.
static u64 dpack(u64 sign, s16 exp, u64 mant) {
    if (mant == 0) return sign;
    s16 eS = exp + DEXP_BIAS;
    if (eS <= 0) return sign;
    if (eS >= 2047) return sign | DEXP_MASK;
    return sign | (mant & DMANT_MASK) | ((u64)(u16)eS << DEXP_SHIFT);
}

// Decompose `x` into sign / unbiased-exp / mantissa-with-leading-bit.
// Returns the class: 0=zero, 1=normal, 2=infinity, 3=NaN.
//
// Kept inline: passing pointer args from a noinline boundary lowers to
// `sta (d,s),y` (DBR-relative) -- broken under DBR != 0.  Inlining keeps
// the stores within the caller's frame.  See feedback_dbr_ptr_deref_spill.md.
static u16 dclass(u64 x, u64 *out_sign, s16 *out_exp, u64 *out_mant) {
    *out_sign = x & DSIGN_BIT;
    s16 e = (s16)((x >> DEXP_SHIFT) & 0x7FF);
    u64 m = x & DMANT_MASK;
    if (e == 0) {
        *out_exp = 0;
        *out_mant = 0;
        return 0;
    }
    if (e == 0x7FF) {
        *out_exp = 0x7FF;
        *out_mant = m;
        return (m == 0) ? 2 : 3;
    }
    *out_exp = e - DEXP_BIAS;
    *out_mant = m | DMANT_LEAD;
    return 1;
}

u64 __adddf3(u64 a, u64 b) {
    u64 sa, sb, ma, mb;
    s16 ea, eb;
    u16 ca = dclass(a, &sa, &ea, &ma);
    u16 cb = dclass(b, &sb, &eb, &mb);
    if (ca == 0) return b;
    if (cb == 0) return a;
    // Shift mantissas left by 3 to reserve guard / round / sticky bits
    // below position 0.  Lead bit is now at position 55 instead of 52.
    // The sticky bit is preserved by ORing it into the LSB whenever a
    // significant bit would otherwise be shifted off the right side
    // (during alignment or post-add normalization).  At the end, RNE
    // rounds based on bits 2..0 (guard, round, sticky) and shifts back.
    ma <<= 3;
    mb <<= 3;
    // Align mantissas to common exponent.  The smaller-exp operand is
    // shifted right; bits shifted past position 0 become sticky.
    if (ea > eb) {
        s16 d = ea - eb;
        if (d > 56) return a;
        u64 sticky = 0;
        if (d > 3) {
            u64 mask = (d >= 64) ? ~0ULL : ((1ULL << d) - 1);
            sticky = (mb & mask) ? 1 : 0;
        }
        mb = (d >= 64) ? 0 : (mb >> d);
        mb |= sticky;
        eb = ea;
    } else if (eb > ea) {
        s16 d = eb - ea;
        if (d > 56) return b;
        u64 sticky = 0;
        if (d > 3) {
            u64 mask = (d >= 64) ? ~0ULL : ((1ULL << d) - 1);
            sticky = (ma & mask) ? 1 : 0;
        }
        ma = (d >= 64) ? 0 : (ma >> d);
        ma |= sticky;
        ea = eb;
    }
    u64 mr;
    u64 sr;
    if (sa == sb) {
        mr = ma + mb;
        sr = sa;
    } else {
        if (ma >= mb) {
            mr = ma - mb;
            sr = sa;
        } else {
            mr = mb - ma;
            sr = sb;
        }
    }
    if (mr == 0) return 0;
    // Renormalize.  Lead bit should land at position 55 (= 52 + 3 GRS).
    // Right-shift first to bring an over-wide sum back in range; then
    // left-shift if subtraction left the lead below 55.  Reverse order
    // would shift an over-wide value out of u64 range entirely.
    // Use if + do-while because pure `while (cond) body` triggers a
    // backend bug in the left-shift renormalize path: subtraction
    // cases (different signs) lose their result (7+(-8) -> -0 instead
    // of -1).  do-while is unaffected (test-after-body).
    if (mr & ~((1ULL << 56) - 1)) {
        do {
            u64 sticky_bit = mr & 1;
            mr = (mr >> 1) | sticky_bit;
            ea++;
        } while (mr & ~((1ULL << 56) - 1));
    }
    if ((mr & (1ULL << 55)) == 0 && mr != 0) {
        do {
            mr <<= 1;
            ea--;
        } while ((mr & (1ULL << 55)) == 0 && mr != 0);
    }
    // Round to nearest, ties to even.  Bits 0/1 are sticky+round, bit 2
    // is guard, bit 3 is mantissa LSB.
    int guard  = (int)((mr >> 2) & 1);
    int sticky = (int)(mr & 0x3);
    int lsb    = (int)((mr >> 3) & 1);
    mr >>= 3;  // drop GRS bits to get the 53-bit mantissa
    if (guard && (sticky || lsb)) {
        mr++;
        if (mr & (1ULL << 53)) {
            mr >>= 1;
            ea++;
        }
    }
    return dpack(sr, ea, mr);
}

u64 __subdf3(u64 a, u64 b) {
    return __adddf3(a, b ^ DSIGN_BIT);
}

u64 __negdf2(u64 a) {
    return a ^ DSIGN_BIT;
}

// Carry the high 64 bits of a 128-bit product in `hi` and the low 64
// in `lo`.  Carry bit indicates whether the leading bit was at 105
// (caller must increment exponent).
typedef struct {
    u64 mantissa;
    u16 carry;
} MantCarryT;

// 64x64 -> 128-bit product, returned as a packed u64 pair.  Returns
// the high 64 bits in the high u64 of the .mantissa lane is not
// possible -- instead, we shift in-line and return the aligned mantissa
// directly.  Splitting keeps register pressure low enough for greedy
// regalloc on the single-A W65816.
//
// Inlinable on purpose: passing a pointer to a stack local across a
// noinline boundary lowers to `sta (d,s),y` which uses DBR-relative
// addressing -- broken under DBR != 0 (e.g. after a bank switch).
// Keeping these inline keeps the stores within the caller's frame.
//
// out_round encodes the round bits as (guard << 1) | sticky.  Caller
// uses these for round-to-nearest-even.
static inline u64 mulhi64Aligned(u64 ma, u64 mb,
                                 u16 *out_carry, u16 *out_round) {
    u32 alo = (u32)ma;
    u32 ahi = (u32)(ma >> 32);
    u32 blo = (u32)mb;
    u32 bhi = (u32)(mb >> 32);
    u64 ll = (u64)alo * (u64)blo;
    u64 lh = (u64)alo * (u64)bhi;
    u64 hl = (u64)ahi * (u64)blo;
    u64 hh = (u64)ahi * (u64)bhi;
    u64 mid = lh + hl + (ll >> 32);
    u64 prod_hi = hh + (mid >> 32);
    u64 prod_lo = (ll & 0xFFFFFFFFULL) | ((mid & 0xFFFFFFFFULL) << 32);
    if (prod_hi & (1ULL << 41)) {
        // Lead-at-105 case: shift right 53 within full product.  The
        // bit at prod_lo position 52 is the guard; bits 0..51 are sticky.
        *out_carry = 1;
        u16 guard = (u16)((prod_lo >> 52) & 1);
        u16 sticky = (u16)((prod_lo & ((1ULL << 52) - 1)) != 0);
        *out_round = (guard << 1) | sticky;
        return (prod_hi << 11) | (prod_lo >> 53);
    }
    // Lead-at-104 case: shift right 52.  Guard at prod_lo bit 51,
    // sticky = OR of bits 0..50.
    *out_carry = 0;
    u16 guard = (u16)((prod_lo >> 51) & 1);
    u16 sticky = (u16)((prod_lo & ((1ULL << 51) - 1)) != 0);
    *out_round = (guard << 1) | sticky;
    return (prod_hi << 12) | (prod_lo >> 52);
}

u64 __muldf3(u64 a, u64 b) {
    u64 sa, sb, ma, mb;
    s16 ea, eb;
    u16 ca = dclass(a, &sa, &ea, &ma);
    u16 cb = dclass(b, &sb, &eb, &mb);
    u64 sr = sa ^ sb;
    if (ca == 0 || cb == 0) return sr;
    u16 carry;
    u16 round_bits;
    u64 mr = mulhi64Aligned(ma, mb, &carry, &round_bits);
    s16 er = ea + eb + (s16)carry;
    // Round to nearest, ties to even.
    int guard = (round_bits >> 1) & 1;
    int sticky = round_bits & 1;
    if (guard && (sticky || (mr & 1))) {
        mr++;
        if (mr & (1ULL << 53)) {
            mr >>= 1;
            er++;
        }
    }
    return dpack(sr, er, mr);
}

u64 __divdf3(u64 a, u64 b) {
    u64 sa, sb, ma, mb;
    s16 ea, eb;
    u16 ca = dclass(a, &sa, &ea, &ma);
    u16 cb = dclass(b, &sb, &eb, &mb);
    u64 sr = sa ^ sb;
    if (ca == 0) return sr;
    if (cb == 0) return sr | DEXP_MASK;  // div-by-zero -> inf
    // Long division: handle the leading quotient bit explicitly (since
    // we need to "consume" the dividend's leading 1 by subtracting),
    // then generate 52 more fractional bits by shifting r left and
    // testing.  The previous shift-and-test-only loop over-counted
    // when r == mb after subtraction (e.g. 2.0/1.0 returned ~4.0).
    s16 er = ea - eb;
    // Normalize so the dividend is in [mb, 2*mb).  This ensures the
    // leading quotient bit will land at position 52 below.
    if (ma < mb) {
        ma <<= 1;
        er--;
    }
    // Handle the leading quotient bit explicitly.
    u64 q = DMANT_LEAD;
    u64 r = ma - mb;
    // Compute 52 more fractional bits via standard shift-test-subtract.
    for (int i = 51; i >= 0; i--) {
        r <<= 1;
        if (r >= mb) {
            r -= mb;
            q |= (1ULL << i);
        }
    }
    // Round to nearest, ties to even.  Generate one extra bit (the
    // "guard"), examine the remainder for any non-zero "sticky" tail,
    // and round q up when guard=1 and (sticky || (q & 1)).  Without
    // this we'd be truncate-toward-zero, off by 1 ULP from gcc's RNE
    // result on cases like 1.5/2.5.
    r <<= 1;
    int guard = (r >= mb) ? 1 : 0;
    if (guard) r -= mb;
    int sticky = (r != 0) ? 1 : 0;
    if (guard && (sticky || (q & 1))) {
        q++;
        if (q & (1ULL << 53)) {  // mantissa overflow into bit 53 -> renormalize
            q >>= 1;
            er++;
        }
    }
    return dpack(sr, er, q);
}

s16 __cmpdf2(u64 a, u64 b) {
    u64 sa = a & DSIGN_BIT;
    u64 sb = b & DSIGN_BIT;
    if (sa != sb) {
        // Negative < positive (unless both zero).
        if ((a | b) << 1 == 0) return 0;
        return sa ? -1 : 1;
    }
    if (a == b) return 0;
    if (sa) return a < b ? 1 : -1;
    return a < b ? -1 : 1;
}

s16 __unorddf2(u64 a, u64 b) {
    // Returns nonzero if either is NaN.
    u64 ea = (a >> DEXP_SHIFT) & 0x7FF;
    u64 eb = (b >> DEXP_SHIFT) & 0x7FF;
    if (ea == 0x7FF && (a & DMANT_MASK) != 0) return 1;
    if (eb == 0x7FF && (b & DMANT_MASK) != 0) return 1;
    return 0;
}

s16 __eqdf2(u64 a, u64 b) { return __cmpdf2(a, b) != 0; }
s16 __nedf2(u64 a, u64 b) { return __cmpdf2(a, b) != 0; }
s16 __ltdf2(u64 a, u64 b) { return __cmpdf2(a, b) <  0; }
s16 __ledf2(u64 a, u64 b) { return __cmpdf2(a, b) <= 0; }
s16 __gtdf2(u64 a, u64 b) { return __cmpdf2(a, b) >  0; }
s16 __gedf2(u64 a, u64 b) { return __cmpdf2(a, b) >= 0; }

// double <-> float conversions.
u64 __extendsfdf2(u32 x) {
    u64 sign = ((u64)x & 0x80000000UL) << 32;
    s16 e = (s16)((x >> 23) & 0xFF);
    u32 m = x & 0x7FFFFFUL;
    if (e == 0) return sign;
    if (e == 0xFF) {
        return sign | DEXP_MASK | ((u64)m << 29);
    }
    s16 unbiased = e - 127;
    return dpack(sign, unbiased, ((u64)m << 29) | DMANT_LEAD);
}

u32 __truncdfsf2(u64 x) {
    u64 sign = (x & DSIGN_BIT) >> 32;
    s16 e = (s16)((x >> DEXP_SHIFT) & 0x7FF);
    u64 m = x & DMANT_MASK;
    if (e == 0) return (u32)sign;
    if (e == 0x7FF) {
        u32 f = (u32)(m >> 29);
        if (m != 0 && f == 0) f = 0x400000UL;   // a NaN stays a NaN
        return (u32)sign | 0x7F800000UL | f;
    }
    s16 unbiased = e - DEXP_BIAS;
    s16 fexp = unbiased + 127;
    if (fexp <= 0) return (u32)sign;
    // Round to nearest, ties to even, on the 29 bits dropped.
    u32 f = (u32)(m >> 29);
    u32 rem = (u32)m & 0x1FFFFFFFUL;
    if (rem > 0x10000000UL || (rem == 0x10000000UL && (f & 1))) {
        f++;
        if (f == 0x800000UL) { f = 0; fexp++; }
    }
    if (fexp >= 255) return (u32)sign | 0x7F800000UL;
    return (u32)sign | ((u32)fexp << 23) | f;
}

// double <-> integer conversions.
u64 __floatsidf(s32 x) {
    if (x == 0) return 0;
    u64 sign = (x < 0) ? DSIGN_BIT : 0;
    // Widen before negating: -x overflows s32 at INT32_MIN.
    u64 m = (u64)(s64)x;
    if (x < 0) m = -m;
    s16 e = 0;
    while ((m & DMANT_LEAD) == 0) { m <<= 1; e--; }
    e += 31 + 21;  // shift to put bit-31 at bit-52
    return dpack(sign, e, m);
}


u64 __floatunsidf(u32 x) {
    if (x == 0) return 0;
    u64 m = (u64)x;
    s16 e = 0;
    while ((m & DMANT_LEAD) == 0) { m <<= 1; e--; }
    e += 31 + 21;
    return dpack(0, e, m);
}

s32 __fixdfsi(u64 x) {
    u64 sign = x & DSIGN_BIT;
    s16 e = (s16)((x >> DEXP_SHIFT) & 0x7FF);
    if (e == 0) return 0;
    if (e == 0x7FF) return sign ? (s32)0x80000000 : 0x7FFFFFFF;
    s16 unbiased = e - DEXP_BIAS;
    if (unbiased < 0) return 0;
    if (unbiased > 30) return sign ? (s32)0x80000000 : 0x7FFFFFFF;
    u64 m = (x & DMANT_MASK) | DMANT_LEAD;
    s16 shift = 52 - unbiased;
    if (shift >= 0) m >>= shift; else m <<= -shift;
    return sign ? -(s32)m : (s32)m;
}


// __fixunsdfsi: unsigned double -> uint32. Saturates to 0 for negative
// inputs, to 0xFFFFFFFF for inputs >= 2^32. Used by clang when casting
// double values to unsigned integer types.
u32 __fixunsdfsi(u64 x) {
    if (x & DSIGN_BIT) return 0;                 // negative -> 0
    u16 e = (u16)((x >> DEXP_SHIFT) & 0x7FF);
    if (e == 0) return 0;
    if (e == 0x7FF) return 0xFFFFFFFF;
    s16 unbiased = (s16)e - DEXP_BIAS;
    if (unbiased < 0) return 0;
    if (unbiased > 31) return 0xFFFFFFFF;
    u64 m = (x & DMANT_MASK) | DMANT_LEAD;
    if (unbiased >= 52) {
        m <<= (unbiased - 52);
    } else {
        m >>= (52 - unbiased);
    }
    return (u32)m;
}
