/* C-1: continue inside do-while jumps to the condition test.  Sums 1..5
 * but skips i==3: 1+2+4+5 = 12. */
int main(){ int i; int s; i=0; s=0; do { i=i+1; if (i==3) continue; s=s+i; } while (i<5); return s; }
