/* Type specifiers in any order (K&R A.8.2: "At most one of the words long or
 * short may be specified together with int; the meaning is the same if int
 * is not mentioned ... At most one of signed or unsigned may be specified
 * together with int or any of its short or long varieties").  4.3BSD-Reno
 * doprnt.c casts through `long unsigned' and `short unsigned'.  Each line
 * fails if the trailing words were lost or read as a name.  Returns 42. */
int main()
{
    int long v;
    long w = 70000L;
    char *p;
    int r = 0;

    v = 70000L;
    if (v == 70000L) r += 10;
    if (sizeof(int long) == sizeof(long) && sizeof v == sizeof w) r += 10;
    if ((long unsigned)-1 > 0) r += 10;                 /* unsigned */
    if ((long)(short unsigned)-1 == 65535L) r += 5;
    p = (char *)&w;
    if (*(long unsigned *)p == 70000L) r += 7;
    return r;
}
