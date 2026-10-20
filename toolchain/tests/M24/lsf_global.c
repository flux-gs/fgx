/* B-4: long field in a global struct — store, load, long arith, narrow.
 * 1000000/100000 = 10, + 5 = 15. */
struct s { long a; int b; };
struct s gg;
int main(){ gg.a = 1000000L; gg.b = 5; return (int)(gg.a / 100000L) + gg.b; }
