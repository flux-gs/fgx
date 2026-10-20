/* A-1 follow-up: unsigned function parameter compares unsigned.
 * big(40000): 40000 > 20000 is 1 unsigned; signed (40000 = -25536) gives 0. */
int big(unsigned n){ return n > 20000; }
int main(){ return big(40000); }
