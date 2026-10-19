/* fgxmem.c - FGX split-residency story memory for frotz
 *
 * FGX-Origin: original (no upstream counterpart; the FGX arm of frotz.h
 * and two #ifdef __FGX__ islands in fastmem.c are its only callers).
 *
 * The problem: a Z-machine story is 13 KB (CZECH) to 512 KB (v8), and a
 * process's data bank -- globals, malloc heap, everything a C pointer
 * indexes for free -- is one 64 KB bank.  frotz's own DOS ports solved
 * this with paging behind frotz.h's data-access macros; this layer is
 * the same idea over FGX's Memory Manager instead of EMS.
 *
 * The split: DYNAMIC memory (below h_dynamic_size -- the only region
 * the Z-machine may write, and the region quetzal saves and undo
 * diffs) stays a real malloc block behind the unchanged `zmp` pointer,
 * so every SET_* macro and all of quetzal/fastmem's dynamic code runs
 * exactly as upstream wrote it.  The WHOLE story additionally sits in
 * a locked, bank-spanning MM block (mm_alloc); reads above the dynamic
 * limit go there through fgx_zread().  fcc's (zbyte *)(long) cast
 * carries all 24 bits, so the far read is one long add and an
 * indirect-long load -- no per-bank windowing.
 *
 * Until the far block exists (fgx_zinit), fgx_zread reads the resident
 * block: init_memory parses the 64-byte header through LOW_* macros
 * before h_dynamic_size is even known.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "frotz.h"

/* libfgx (toolchain/include/fgx.h); declared here rather than included
 * -- frotz.h owns this TU's namespace and fgx.h is for native tools. */
extern long mm_alloc(unsigned long size, unsigned long *base);
extern int  mm_free(long handle);

zbyte *zmp = NULL;              /* -> the far story block (a far pointer) */
long   zpc = 0;                 /* program counter: story offset */

/* The whole story lives in ONE Memory-Manager block, BANK-ALIGNED, with
 * zmp pointing at its base.  There is no separate resident copy: an
 * earlier split kept dynamic memory resident in the 64 KB data bank, and
 * a large one (Acheton's ~45 KB) exhausted the bank so the screen grid's
 * malloc failed.  One block means reads always see writes.
 *
 * Why bank-aligned: fcc lowers a pointer index (zmp[addr]) and pointer
 * arithmetic (zmp+off) to a 16-bit offset add that does NOT carry into
 * the bank byte, so an index crossing a block bank line would wrap and
 * read the wrong bank.  Aligning the base to a 64 KB boundary keeps ALL
 * 16-bit-addressed memory -- dynamic + static, and everything quetzal,
 * undo, memcpy and fread touch -- inside the first bank, where a 16-bit
 * offset never overflows.  Only a full story OFFSET (a v8 routine or high
 * string, up to story_size) exceeds 64 KB; CODE_ and HIGH_WORD (frotz.h)
 * address those as fgx_zhi_base + offset, a full 32-bit add that carries. */
unsigned long fgx_zhi_base = 0;
static long   zhi_handle   = 0;

/* Allocate the far block and stream the story into it.  Returns 0 out of
 * memory / on a short read.  Called from init_memory's FGX island with the
 * header already parsed. */
int fgx_zinit(FILE *fp, unsigned long story_size)
{
    static zbyte chunk[512];    /* data-bank bounce buffer (own-bank ABI) */
    unsigned long raw_base, off;
    long i, n;

    /* Over-allocate one bank so the base can be rounded up to a 64 KB
     * boundary (dynamic memory then never crosses a bank line). */
    zhi_handle = mm_alloc (story_size + 0xFFFFL, &raw_base);
    if (zhi_handle == 0)
        return 0;
    fgx_zhi_base = (raw_base + 0xFFFFL) & ~0xFFFFL;
    zmp = (zbyte *) fgx_zhi_base;

    fseek (fp, 0L, SEEK_SET);
    for (off = 0; off < story_size; off += n) {
        n = 512;
        if (story_size - off < 512)
            n = (long) (story_size - off);
        if (fread (chunk, 1, n, fp) != (unsigned long) n)
            return 0;
        for (i = 0; i < n; i++)
            *(zbyte *)(fgx_zhi_base + off + i) = chunk[i];
    }
    return 1;
}

/* Dispose the far block: the MM handle is a KERNEL resource -- process
 * exit does not free it, so reset_memory must. */
void fgx_zfree(void)
{
    if (zhi_handle != 0)
        mm_free (zhi_handle);
    zhi_handle   = 0;
    fgx_zhi_base = 0;
    zmp          = NULL;
}
