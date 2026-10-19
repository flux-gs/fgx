/* fcc regression: PROTOTYPE RE-DECLARATION AFTER a function's DEFINITION
 * must be a no-op (legal C).  Shape: a header re-included later in the
 * same TU — exactly the libcurses merged-pile TU, where curses.ext's
 * `int _putchar(int);` reappears after putchar.c's definition.  Before
 * the fix funcs_declare died "redeclaration of function"; the defined
 * entry must also NOT be scribbled (return type / params / variadic /
 * is_extern all keep the definition's state).  A second BODY still dies
 * ("redefinition of function") — not exercised here (fail-closed path).
 * 20 + 20 + 2 = 42. */
int f(int x) { return x + 20; }
int f(int x);            /* redecl after definition — no-op */

int g();                 /* K&R proto (RTL-ABI variadic-flip carrier) */
int g() { return 2; }
int g();                 /* redecl after a K&R definition — no-op */

int main(void)
{
    return f(20) + g();
}
