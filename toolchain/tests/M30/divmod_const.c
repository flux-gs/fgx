/* T1.2 unsigned pow2 div/mod: x/4 -> LSR LSR ; x%8 -> AND #7 ; non-pow2 x/3,x%5
 * keep the libcall with DIVIDEND IN A (proves 37/3==12, not 3/37==0). Exit 28. */
unsigned p2(unsigned x){ return (x / 4) + (x % 8); }   /* 37: 9 + 5 = 14 */
unsigned np(unsigned x){ return (x / 3) + (x % 5); }   /* 37: 12 + 2 = 14 */
int main(void){ return (int)(p2(37) + np(37)); }       /* 14 + 14 = 28 */
