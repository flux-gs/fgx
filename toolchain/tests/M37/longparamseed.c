/* A loop-hot `long' PARAMETER promoted to a direct-page register pair keeps
 * its HIGH word.
 *
 * fcc moves a long used in a loop into two _fcc_img slots, low word and high
 * word, and seeds a promoted parameter from its stack home at entry.  The seed
 * is four bytes, both slots, as it is for a pointer's offset and bank.
 *
 * K&R A.7.3.2 (p.163): "In preparing for the call to a function, a copy is
 * made of each argument; all argument-passing is strictly by value.  A
 * function may change the values of its parameter objects, which are copies
 * of the argument expressions".  The parameter object starts as the whole
 * argument, so every word of it is there before the first statement runs.
 *
 * store() is loadcda's relocation patcher: shift the value, then peel it into
 * bytes.  top() only reads the high word inside its loop.  Each is called
 * twice with different high words, so a slot left over from the first call
 * cannot supply the second call's answer.
 *
 * Exit 42.
 */

unsigned char img[4];

int
store(cnt, shift, v)
int           cnt;
int           shift;
unsigned long v;
{
    unsigned i;

    if (shift < 0)
        v >>= -shift;
    else
        v <<= shift;
    for (i = 0; i < (unsigned)cnt; i++) {
        img[i] = (unsigned char)v;
        v >>= 8;
    }
    return (0);
}

int
top(n, v)
int  n;
long v;
{
    int i, sum;

    sum = 0;
    for (i = 0; i < n; i++)
        sum += (int)(v >> 16) + (int)(v & 0xFFFFL);
    return (sum);
}

int
main()
{
    store(4, 0, 0x12345678L);
    if (img[0] != 0x78 || img[1] != 0x56) return (1);
    if (img[2] != 0x34 || img[3] != 0x12) return (2);

    store(3, -8, 0xCAFEBABEL);
    if (img[0] != 0xBA || img[1] != 0xFE || img[2] != 0xCA) return (3);

    store(3, 4, 0x00ABCDEFL);
    if (img[0] != 0xF0 || img[1] != 0xDE || img[2] != 0xBC) return (4);

    if (top(3, 0x00050001L) != 18) return (5);
    if (top(2, 0x00070000L) != 14) return (6);
    return (42);
}
