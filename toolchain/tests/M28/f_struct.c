/* B-6 deferred: float struct/union fields (read + write, incl. type-pun).
 * Covers a union float<->long pun (local + global), struct float fields with
 * arithmetic (local + global), and a mixed int field.  Returns 42. */
union flt  { float f; long l; };
struct pt  { float x; float y; int tag; };

union flt  gu;
struct pt  gp;

int main(void)
{
    union flt  u;
    struct pt  p;

    u.f = 2.0;
    if (u.l != 0x40000000L)       return 1;   /* type-pun: 2.0 bits   */
    gu.f = 0.5;
    if (gu.l != 0x3F000000L)      return 2;   /* global union pun     */

    p.x = 1.5;
    p.y = 2.5;
    p.tag = 7;
    if ((int)(p.x + p.y) != 4)    return 3;   /* struct float fields  */
    if (p.tag != 7)               return 4;   /* mixed int field      */

    gp.x = 40.0;
    gp.y = 2.0;
    if ((int)(gp.x + gp.y) != 42) return 5;   /* global struct fields */

    return 42;
}
