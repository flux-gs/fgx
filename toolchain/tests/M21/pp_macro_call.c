/* Regression: a function-like macro whose body is a CALL, invoked as a
 * STATEMENT (e.g. `#define LOG() log_impl()` then `LOG();`).
 *
 * The statement-call fast path in parse_stmt captured the callee name as a
 * raw `g_cur.id_ptr` and used it only AFTER parsing the argument list (many
 * next_tok calls).  For a macro-expanded identifier that pointer aims into
 * the macro expansion buffer, which pp_pop frees once the expansion is
 * consumed -- so by the time emit_call ran the buffer was gone, and the JSR
 * target came out empty/garbage (and nondeterministically so, depending on
 * what reused the freed block).  The fix copies the spelling to a stable
 * buffer first, mirroring the parse_expr.c primary-expression guard.
 *
 * Covers both the 1-arg and 0-arg function-like-macro call forms.
 *
 * Expected exit code: 42.
 */
int g_acc;

void add(int n)
{
    g_acc = g_acc + n;
}

#define ADDN(n) add(n)      /* one-arg function-like macro -> call */
#define BUMP()  add(1)      /* zero-arg function-like macro -> call */

int main(void)
{
    g_acc = 0;
    ADDN(40);               /* statement-context macro call (1 arg) */
    BUMP();                 /* statement-context macro call (0 args) */
    BUMP();                 /* g_acc == 42 */
    return g_acc;
}
