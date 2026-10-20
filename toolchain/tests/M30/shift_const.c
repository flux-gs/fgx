/* T1.2 inline constant shift: x<<2 -> ASL ASL ; (unsigned) x>>1 -> LSR ;
 * a<<3 -> ASL ASL ASL.  Exit code 30. */
unsigned f(unsigned x){ return (x << 2) + (x >> 1); }   /* (20)+(2)=22 */
int g(int a){ return a << 3; }                          /* 8 */
int main(void){ return (int)f(5) + g(1); }              /* 22 + 8 = 30 */
