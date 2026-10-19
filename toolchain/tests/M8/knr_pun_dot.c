/* knr_pun_dot: the K&R global-member pun reached through a '.', not a '->'.
 *
 * Its twins knr_global_member and knr_pun_charptr both pun through `->`, so
 * until this fixture the '.' form -- which 2.11BSD /bin/sh DOES use -- was held
 * up by nothing in the gate.  sh's mode.h declares
 *
 *     union { int _cheat; };
 *     #define Lcheat(a)   ((a)._cheat)
 *
 * and applies it to a POINTER (`Lcheat(gchain) |= ARGMK`, gchain an ARGPTR;
 * `Lcheat((--p)->word) &= ~BUSY`, word a BLKPTR) to steal a low tag bit of an
 * address as an int.  The operand is not a struct, so no strict lookup can ever
 * resolve `_cheat`; it is found in the global namespace and the operand's OWN
 * storage is reinterpreted, with no dereference.
 *
 * A.7.3.3 requires a member name to belong to the struct for BOTH operators,
 * and says "E1->MOS is the same as (*E1).MOS" -- so this pun is a violation the
 * 1st edition stated and did not police, not a dialect K&R blesses.  What FGX
 * keeps tolerating is narrower than "any '.'": apple/fgx#85 draws the line at
 * the OPERAND, so a '.' on a struct VALUE now says "no such field" while a '.'
 * on a POINTER -- the `(*E1).MOS` shape, which is what this fixture is -- still
 * resolves globally.  This is the boundary marker for that line: it must keep
 * compiling, and a tightening that cannot tell the two operands apart breaks
 * the shell.  tests/reject/ holds the cases that must NOT compile.
 *
 * THE TAG IS TOGGLED, NOT SET-THEN-CLEARED, and that is not a stylistic choice.
 * The first cut wrote sh's own `|= 1` / `&= ~1` pair and returned 0 on the
 * machine.  fcc does not even-align a struct GLOBAL -- measured: `&storage` is
 * ODD -- so `|= 1` was a no-op that no observation could tell apart from the pun
 * failing outright, and `&= ~1` then moved the pointer a byte LOW, which is why
 * np->val read 0.  `^=` flips whatever the bit was and the second `^=` restores
 * it exactly, so the round trip proves the pun reached np's storage on any
 * alignment.  sh's two spellings are still exercised below, with the pointer
 * restored by assignment afterwards rather than by arithmetic.
 *
 * The tag is observed with a cast rather than by reading `Lcheat(np)` back,
 * because `(E).member` as an RVALUE does not parse at all (apple/fgx#95) -- so
 * only the compound-assignment forms are available, which is exactly what sh
 * uses.
 *
 * Host `cc` (ANSI) rejects the pun; the value is the ANSI-equivalent of
 * toggling a pointer's low bit and toggling it back. -> 42. */
union cheat { int _cheat; };
#define Lcheat(a)       ((a)._cheat)     /* verbatim from 2.11BSD sh mode.h */
struct node { struct node *next; int val; };
struct node  storage;
struct node *np;                 /* the pointer whose low bit is stolen */

int
main()
{
    int base, flipped, restored;

    storage.val = 42;
    np = &storage;
    base = (int)np;

    Lcheat(np) ^= 1;             /* '.' pun as an lvalue: flip a tag bit IN np */
    flipped  = (((int)np) != base);
    Lcheat(np) ^= 1;             /* flip back -- exact, whatever the alignment */
    restored = (((int)np) == base);

    Lcheat(np) |= 1;             /* sh's set-tag spelling  */
    Lcheat(np) &= ~1;            /* sh's clear-tag spelling */
    np = &storage;               /* restore by assignment, not by arithmetic */

    return (flipped && restored) ? np->val : 0;   /* 42 */
}
