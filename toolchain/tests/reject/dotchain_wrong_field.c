/* expect: no such field */
/* apple/fgx#85.  `struct mid` has no member `pre` -- but `pre` IS a member of
 * `struct leaf`, which is the type of mid's OTHER member `ld`.  fcc used to
 * resolve the name through the K&R global member namespace and emit a store at
 * T+4, the offset of the POINTER T.md.lp, with no diagnostic at all.
 *
 * K&R A.7.3.3 requires the member to belong to the struct here -- "the first
 * operand expression must be a structure or a union, and the identifier must
 * name a member of the structure or union" -- and records that the 1st edition
 * had the same rule but did not police it.  The pun FGX keeps is that
 * non-enforcement where the operand is a POINTER (M8/knr_global_member,
 * M8/knr_pun_dot).  Here the operand is a struct VALUE of known type, so a name
 * that misses it is a typo -- the spelling a half-finished refactor produces. */
struct leaf { int pre; int i; };
struct mid  { struct leaf *lp; struct leaf ld; };
struct top  { struct mid *mp; struct mid md; };
struct top T;

int f() { T.md.pre = 5; return 0; }
