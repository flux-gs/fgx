/* bzero(3): BSD zero-fill (memset wrapper).  Added for tar(1).
 *
 * THE LENGTH IS UNSIGNED, which is what upstream's is in fact if not in its
 * prototype: 2.11BSD declares `bzero(b, length)' with an int length, but the
 * body is PDP-11 assembly that treats the count as a word, so a 40 KB bzero
 * works there.  Declaring it int here would not merely lose the top half of
 * the range, it would lose it SILENTLY -- memset's own note has the case. */
void bzero(char *b, unsigned n)
{
    memset(b, 0, n);
}
