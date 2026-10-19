/* pp_null_directive: a bare '#' with no directive name is a null directive
 * (ISO C 6.10.7) -- a no-op.  The 2.11BSD Bourne shell uses bare '#' lines as
 * separators throughout its source (Bournegol style), which fcc's preprocessor
 * rejected as "unknown preprocessor directive '#'".  Bare '#' alone, and '#'
 * followed only by a comment, are both null directives.  -> 42. */
#
int
main()
{
#
    int r;
#	
    r = 40;
#  /* a comment after the '#' is only whitespace: still a null directive */
    r += 2;
#
    return r;                /* 42 */
}
