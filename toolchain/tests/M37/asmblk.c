/* T5-C C4b: __asm — the verbatim asm escape hatch (statement position).
 *
 * Exercises: plain op lines (indented by the emitter), an @-local label
 * emitted at column 1, a backward branch through it, and DBR-relative
 * access to a NON-STATIC C global by symbol (statics are mangled — the
 * compiler's business, not asm's).  The ;__ASM markers pin the peephole
 * opacity contract: nothing inside may be rewritten or used as a
 * dead-store proof.
 *
 * NOT clang-cross-checked (FGX-only construct); MAME is the oracle.
 * gv starts 39; the asm loop INCs it 3 times -> 42. */
int gv = 39;

int main(void)
{
    __asm(
        "LDX #3",
        "@lp",
        "INC gv",
        "DEX",
        "BNE @lp"
    );
    return gv;
}
