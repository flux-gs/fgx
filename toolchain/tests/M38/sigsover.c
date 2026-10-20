/* A CALL WITH MORE ARGUMENTS THAN THE SIDECAR'S SIGNATURE HAS PARAMETERS.
 * 2.11BSD telnetd calls `dooption(TELOPT_TTYPE, 0)' above its own old-style
 * `dooption(option) int option;'.
 *
 * No declaration of the name is in scope at the call -- the sidecar is not
 * one -- so K&R A.7.3.2's old-style rule governs it: "The effect of the call
 * is undefined if the number of arguments disagrees with the number of
 * parameters in the definition of the function".  Undefined, not a
 * constraint: "The number of arguments must be the same" is said only of a
 * new-style declaration in scope.  So it compiles, with a warning, and every
 * argument is evaluated and pushed; the callee reads its one parameter from
 * the shallowest slot and the extra lies deeper, unread.  Exit 42.
 */
main()
{
    return (opt(5, 0));
}

opt(o)
    int o;
{
    return (o + 37);
}
