/* apple/fgx#42 -- casting an AUTOMATIC struct to char* must keep BANK 0.
 *
 * A struct VALUE is already an address, carried the legacy way (A = offset,
 * _fcc_ptr+2 = bank), and that bank is its storage's: 0 for a hardware frame,
 * DBR for a global.  Casting it to a pointer is a RETYPE.  fcc's N_CAST arm
 * had no LT_STRUCT case, so it fell to the int->pointer rule, which stamps DBR
 * unconditionally -- and `(char *)automatic_struct` came out addressing the
 * DATA bank at a bank-0 frame offset.
 *
 * Real-world detonation: tcsh's sh.parse.c alias() declares `jmp_buf osetexit`
 * as an automatic, and sh.h's getexit() expands to copy((char *)(osetexit),
 * ...).  The destination reached copy() as DBR:frame_offset, so 12 bytes went
 * into the malloc heap instead of onto the stack.  At tcsh's shipping data
 * segment size that landed somewhere harmless; grow the segment ~6 KB and the
 * heap moves under the write, it lands on a live free-list block header, and
 * the next free() walks a cycle forever -- a virtual-console login that never
 * prints its prompt.
 *
 * WHAT MAKES THIS DISCRIMINATE: both banks are exercised in one call, so the
 * golden pins the two apart.  `to` is an automatic (bank 0, staged LDA #0) and
 * `from` is a global (DBR, staged PHB); before the fix BOTH went through
 * `JSR _fcc_bank_for_int`, which made the global right by luck and the local
 * silently wrong.  A fixture using only a global would have passed unfixed.
 *
 * &local and local-ARRAY decay were always correct and are included so a future
 * change cannot fix this one by regressing those.
 */

struct jb { char b[12]; };

struct jb gjb;
char sink[12];

copyout(d, s, n)
    char *d, *s;
    int n;
{
    while (n-- > 0)
        *d++ = *s++;
}

main()
{
    struct jb local;
    char arr[12];
    int scalar;

    copyout((char *)(local), (char *)(gjb), 12);   /* the #42 shape */
    copyout((char *)(arr), sink, 12);              /* local array decay */
    copyout((char *)&scalar, sink, 2);             /* address-of local */
    return 0;
}
