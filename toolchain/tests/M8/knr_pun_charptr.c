/* knr_pun_charptr: K&R global-member pun through a NON-struct pointer (A.7.3,
 * 1st ed).  2.11BSD /bin/sh allocates a struct's memory but holds it in a
 * STRING (char*) / STRING* (char**) and accesses struct fields via `->`:
 * `args->argnxt` (args a char*), `np->doluse`/`np=np->dolarg` (np a char**).
 * The base value is a byte address; the member resolves globally.  Host `cc`
 * (ANSI) rejects this; the value is checked by the ANSI-equivalent layout.
 * -> 42. */
struct argnod { struct argnod *argnxt; char argval[2]; };
struct argnod  storage;
char          *args;             /* char* punned as argnod* (STORE + READ) */

int
main()
{
    char *back;

    args = (char *)&storage;
    args->argval[0] = 42;        /* store through a char* pun (argval @ ~2) */
    args->argnxt = 0;            /* pointer-field store through the pun     */
    back = (char *)args->argnxt; /* pointer-field READ through the pun (0)  */

    return (back == 0) ? args->argval[0] : 0;   /* 42 */
}
