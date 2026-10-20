typedef long code_int;
typedef long count_int;
long storage[5010];
count_int *htab;
unsigned short cstorage[5010];
unsigned short *codetab;

int main(void)
{
    register code_int i, ent;
    register int c;
    register code_int free_ent;
    long fcode;
    int k, hshift;

    htab = storage;
    codetab = cstorage;
    for (k = 0; k < 5010; k++) { htab[k] = -1L; codetab[k] = 0; }

    hshift = 4;
    ent = 116; c = 104; free_ent = 257;
    fcode = ((long) c << 9) + ent;      /* 53364 */
    i = ((c << hshift) ^ ent);          /* 1780 */
    if (i != 1780) return 10;
    if (htab[i] != -1L) return 11;
    if ((long) htab[i] >= 0) return 12;

    codetab[i] = free_ent++;
    htab[i] = fcode;

    if (codetab[i] != 257) return 1;
    if (free_ent != 258) return 2;
    if (htab[i] != 53364L) return 3;
    if (storage[1780] != 53364L) return 4;
    if (cstorage[1780] != 257) return 5;
    return 42;
}
