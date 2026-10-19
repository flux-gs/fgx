/* The fit rule's fixture (shared libc SP3 step 3): a data segment that
 * fits fgx_ld's bank but ends above LIM, the lowest library core less the
 * blocks the program reaches. */
static char big[64000];
int
main()
{
    return big[0];
}
