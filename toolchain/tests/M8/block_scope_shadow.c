/* block_scope_shadow: K&R A.11.1 (p.187) -- a name declared at the head of a
 * `{ }` block goes out of scope at the '}', and the outer same-name declaration
 * resumes.  fcc leaked the block-local, shadowing the outer for the rest of the
 * function.  This is the Bourne /bin/sh execute() bug: `case 14: { L_INT t[4]; }`
 * shadowed the function's `TREPTR t`, so a later `t->comset` treated t as an
 * array.  -> 42. */
struct s { int m; };
struct s  box;
struct s *t;

int
main()
{
    t = &box;
    t->m = 42;
    {
        int t[4];          /* block-scoped shadow: t is an int array HERE only */
        t[0] = 99;
        t[1] = t[0];
    }
    return t->m;           /* outer t (struct s*) resumes -> 42 */
}
