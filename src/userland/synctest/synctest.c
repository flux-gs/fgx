/*
 * synctest - slow sapling writer for the periodic-metadata-sync test.
 *
 * Writes a 768-byte (>1 block -> sapling) file ONE BYTE AT A TIME, with a
 * ~0.42s nanosleep every 64 bytes, so the whole write spans ~5s and straddles
 * several of the kernel's ~1s Fs_Write metadata syncs. Block 0 is filled with
 * 'A', block 1 with 'B' (distinctive so a concurrent `cat` is assertable).
 *
 * Run backgrounded with a separate reader (`synctest & ; sleep 3 ; cat …`):
 *   - the `cat` proves the file is VISIBLE and growing on disk mid-write (the
 *     periodic sync committed the dir entry; before it, the file stayed 0-byte
 *     until close);
 *   - this tool then reopens its own file and verifies every byte, proving the
 *     periodic syncs + the concurrent cross-process read did not corrupt it.
 *
 * Prints "synctest: bad=<M> of <T>" + SYNCOK (bad==0) or SYNCBAD.
 */
#include <stdio.h>

int nanosleep(int t);          /* synctest_stubs.s: SYS_NANOSLEEP */
long atol(char *s);
int atoi(char *s);

#define NB 768

/*
 * Two invocation modes:
 *   synctest                        legacy 768B sapling A/B writer (synctest.json)
 *   synctest <fill> <path> <nbytes> parametrized single-char writer, 512B chunks
 *
 * The parametrized mode is the TRAIN-3 F0 red bar: run TWO of them backgrounded
 * to different paths (`synctest A /root/SF1 N & synctest B /root/SF2 N &`).  Each
 * nanosleeps after every 512B chunk, so while one sleeps the other's SYS_WRITEs
 * drive _Fs_SwitchToFCB to the peer FCB; on wake the switch-BACK restores this
 * file's write-state incompletely (the singleton bug), corrupting the content ->
 * SYNCBAD.  Size N picks the storage class exercised: a few KB = sapling
 * (block-transition / _fwDataBlkIdx), >128KB = tree (master+index restore).
 */
static char chunkbuf[512];

int main(int argc, char **argv)
{
    FILE *w, *r;
    long nb, i, bad;
    int blk, c, exp, fill, k, n, slp;
    char *path;

    slp = 2;                            /* default per-chunk sleep (~33ms) */
    if (argc >= 4) {
        fill = argv[1][0];
        path = argv[2];
        nb   = atol(argv[3]);
        if (argc >= 5) slp = atoi(argv[4]);   /* per-chunk sleep ticks */
    } else {
        fill = 0;                       /* 0 => legacy A/B per-block fill */
        path = "/root/SYNCF";
        nb   = NB;
    }

    w = fopen(path, "w");
    if (!w) { printf("synctest: create fail\n"); return 1; }

    if (fill == 0) {
        for (i = 0; i < nb; i = i + 1) {
            blk = (int)(i >> 9);        /* 0 or 1 */
            fputc('A' + blk, w);        /* one Fs_Write each (unbuffered) */
            if (((int)i & 63) == 63)
                nanosleep(25);         /* ~0.42s @ 60Hz -> ~5s total write */
        }
    } else {
        for (k = 0; k < 512; k = k + 1) chunkbuf[k] = fill;
        for (i = 0; i < nb; i = i + n) {
            n = 512;
            if (nb - i < 512) n = (int)(nb - i);
            fwrite(chunkbuf, 1, n, w);  /* one SYS_WRITE per chunk */
            /* Sleep (yield to the peer) ONLY once this file is in TREE storage
               (>128KB): blast through the sapling ramp so two writers co-occupy
               tree state simultaneously, where the master/index switch-back bug
               lives -- rather than staggering out of tree during a slow ramp. */
            if (i >= 131072L)
                nanosleep(slp);
        }
    }
    fclose(w);

    /* verify content survived the interleave (+ any concurrent reader) */
    r = fopen(path, "r");
    if (!r) { printf("synctest: reopen fail\n"); return 1; }
    bad = 0;
    for (i = 0; i < nb; i = i + 1) {
        c = fgetc(r);
        if (fill == 0) exp = 'A' + (int)(i >> 9);
        else exp = fill;
        if (c != exp) bad = bad + 1;
    }
    fclose(r);

    printf("synctest: bad=%ld of %ld\n", bad, nb);
    if (bad == 0) printf("SYNCOK\n");
    else printf("SYNCBAD\n");
    return 0;
}
