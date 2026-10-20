/* A TRANSLATION UNIT MAY DEFINE A FUNCTION WHOSE NAME libc ALSO DEFINES.
 *
 * The --sigs sidecar is fcc's out-of-band knowledge of libc, added so an
 * UNDECLARED call gets the right argument widths (apple/fgx#327).  It is not a
 * declaration in this file, and K&R 2nd ed A.11.1 settles that: "The lexical
 * scope of an object or function identifier in an external declaration begins
 * at the end of its declarator and persists to the end of the translation unit
 * in which it appears."  The sidecar appears in no translation unit, so a
 * definition here is this program's own function that happens to share a name.
 *
 * THE CASE THAT FOUND IT IS 2.11BSD's chmod(1), whose `abs()' reads an OCTAL
 * NUMBER out of the mode string rather than an absolute value.  Until this,
 * the empty-paren declarator kept the sidecar's one-parameter signature and
 * the following `{' was reported as a redefinition, so the port could not
 * compile.  The two ways to get it compiling without touching fcc -- renaming
 * upstream's function, or dropping the sidecar for that TU -- are both edits
 * to the port to suit the compiler.
 *
 * THE NAME IS INVENTED AND THAT IS DELIBERATE.  sigsdef.sigs is this
 * fixture's OWN sidecar, so it can name a function libc does not have -- and
 * naming a real one instead (`abs', `qsort') buys nothing for the compiler
 * claim while adding a LINK hazard that is not about the compiler at all: the
 * libc dead-strip selects whole FILES, this harness's root set already pulls
 * stdlib.c, and libc's copy would arrive as a passenger and collide.  That is
 * the one-definition rule doing its job (K&R p.187: "For objects with
 * external linkage, it applies to the entire program"), and chmod(1) links
 * because nothing in it pulls stdlib.c.
 *
 * sigsdef.sigs NAMES TWO FUNCTIONS ON PURPOSE.  `strlen' is left undefined
 * here and called UNDECLARED, so the sidecar is still doing its #327 job in
 * the same fixture: a fix that made fcc ignore the sidecar would pass the
 * qsort half and silently lose the other.
 */
char msbuf[4];

mode2octal()
{
    return (7);
}

main()
{
    msbuf[0] = 'a';
    msbuf[1] = 'b';
    msbuf[2] = 0;
    return (mode2octal() + strlen(msbuf));
}
