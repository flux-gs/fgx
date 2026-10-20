/* void_cast_call: `(void)voidfn();` -- the idiomatic discard of a void call's
 * (non-)value.  fcc rejected any void-returning call used in an expression,
 * including the no-op `(void)` cast around it; casting TO void now suppresses
 * that check.  tcsh tc.bind `(void) ClearXkey(map, in);`.  -> 42. */
int g;

void
bump()
{
    g = g + 1;
}

int
main()
{
    g = 40;
    (void) bump();          /* discard-cast of a void call: g = 41 */
    (void) bump();          /* g = 42 */
    return g;
}
