/* B-6 Phase 1: float store / load / copy codegen.  Exercises the 4-byte
 * float store (emit_store_local / emit_store_global_int) and load
 * (emit_load_local / emit_load_global) by moving float values between a
 * local, a second local, and a global.  The emitted 4-byte sequences are
 * golden-verified; runtime VALUE verification (reading a float back into an
 * int) needs int<->float conversion or a float compare, both of which
 * arrive in Phase 2 (e.g. `if (f == 2.0)`).  Returns a sizeof-based 42 so
 * the binary runs cleanly on MAME. */
float g_f;

int main(void)
{
    float a, b;

    a   = 2.0;     /* literal -> local        (emit_load_lit_float + store)   */
    b   = a;       /* local  -> local copy    (4-byte load + 4-byte store)    */
    g_f = b;       /* local  -> global        (load + emit_store_global_int)  */
    a   = g_f;     /* global -> local         (emit_load_global + store)      */

    return sizeof(a) + sizeof(b) + sizeof(g_f) + 30;   /* 4 + 4 + 4 + 30 = 42 */
}
