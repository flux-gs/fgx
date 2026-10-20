/* M21: a macro expanding to () in a function-DECLARATOR position — the NetBSD
 * `P_((...))` prototype-bridge idiom used on every elvis function decl.  The
 * top-level func-vs-var classifier peeks past the name; that peek must be
 * preprocessor-frame-safe or the macro's `()` is lost and the parser sees the
 * following `;` ("expected '('").  Covers func-like (P_) and object-like (Q). */
#define P_(s) ()
#define Q     ()
int  add7 P_((int));      /* K&R proto via func-like macro -> `int add7 ();` */
void noop Q;              /* object-like macro -> `void noop ();`            */
int add7(x) int x; { return 7 + x; }
void noop() { }
int main(void)
{
    noop();
    return add7(35);      /* 7 + 35 = 42 */
}
