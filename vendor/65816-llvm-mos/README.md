# vendor/65816-llvm-mos -- the llvm-mos 65816 soft double (pristine subset)

The W65816 fork of llvm-mos at
<https://forge.duensing.digital/AI_Slop/65816-llvm-mos>, commit
`4a13f9df266b1d093db6ceb82caa26b6fd67f2b2` (2026-07-26).  Licence: Apache 2.0,
"matching the LLVM project's license", as its README states; the fork carries
no licence file of its own and points at llvm-mos's `LICENSE.TXT`.  That text
is vendored here as `LICENSE.TXT`, verbatim: "The LLVM Project is under the
Apache License v2.0 with LLVM Exceptions", from llvm-mos
(<https://github.com/llvm-mos/llvm-mos>, `llvm/LICENSE.TXT` at commit
`0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63`, fetched 2026-10-11).

Vendored subset: `runtime/src/softDouble.c` only, unmodified
(sha256 `2ad0562f9c7d41c6174d990dc3b7422a2119a34c630348420f4a922d71fd43e7`).
It is IEEE-754 double arithmetic in C over `unsigned long long`: add, sub,
mul, div, compares, and the float and 32-bit integer conversions.

FGX's derived copy is `toolchain/lib/libdouble/softdouble.c`, the source of
fcc's 64-bit double runtime (apple/fgx#447); its deltas are listed in its
header and in docs/PROVENANCE.md.  Per the ports convention this tree stays
pristine for diffing.
