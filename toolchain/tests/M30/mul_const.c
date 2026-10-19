/* T1.2 inline pow2 multiply: x*4 -> ASL ASL ; x*10 -> _fcc_mul16. Exit 48. */
unsigned f(unsigned x){ return x * 4; }     /* 7*4 = 28 */
unsigned h(unsigned x){ return x * 10; }    /* 2*10 = 20 (non-pow2 libcall) */
int main(void){ return (int)(f(7) + h(2)); }  /* 28 + 20 = 48 */
