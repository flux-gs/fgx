/* M19b: a MULTI-DIMENSIONAL ARRAY AS A STRUCT FIELD -- declared, stored into,
 * read back, and reached through both '.' and '->', including inside a union.
 *
 * apple/fgx#477.  The declarator was parsed and then rejected, so syslogd(8)'s
 * `char f_uname[MAXUNAMES][UNAMESZ+1]' could not be ported.  K&R A.8.6.2:
 * "An array may be constructed from ... another array (to generate a
 * multi-dimensional array)", and "arrays are stored by rows (last subscript
 * varies fastest) ... the first subscript in the declaration helps determine the
 * amount of storage consumed by an array, but plays no other part in subscript
 * calculations" -- so the stride is the INNER dimension and the total sizes the
 * field.  Both are asserted numerically below rather than read off the assembly.
 *
 * The `before'/`after' scalars bracket the field so a wrong field SIZE shows up
 * as a wrong neighbour rather than silently overlapping.
 */
struct filed {
    int  before;
    union {
        char f_uname[4][6];          /* 24 bytes; row stride 6 */
        char f_fname[24];
    } f_un;
    int  after;
};

struct filed F;
struct filed *pf = &F;

int main(void)
{
    int i, acc;

    F.before = 100;
    F.after  = 200;

    /* '.' path, both subscripts constant and variable */
    F.f_un.f_uname[0][0] = 1;
    F.f_un.f_uname[3][5] = 2;
    i = 2;
    F.f_un.f_uname[i][1] = 4;

    /* '->' path: store and read back */
    pf->f_un.f_uname[1][2] = 8;
    acc = pf->f_un.f_uname[1][2];              /* 8 */
    acc += F.f_un.f_uname[0][0];               /* 1 */
    acc += F.f_un.f_uname[3][5];               /* 2 */
    acc += pf->f_un.f_uname[i][1];             /* 4 */

    /* THE ROW ALIASES THE UNION'S FLAT MEMBER at i*6 + j, which is the storage
     * rule above stated as an assertion: row 3 column 5 is byte 23. */
    acc += (F.f_un.f_fname[23] == 2) ? 16 : 0;
    acc += (F.f_un.f_fname[13] == 4) ? 32 : 0; /* row 2 col 1 is byte 2*6+1 */

    /* sizeof sees the WHOLE field, not one row (A.7.4.8: "when applied to an
     * array, the result is the total number of bytes in the array"). */
    acc += (sizeof F.f_un.f_uname == 24) ? 64 : 0;

    /* the neighbours are untouched */
    acc += (F.before == 100 && F.after == 200) ? 128 : 0;
    return acc;                                /* 255 */
}
