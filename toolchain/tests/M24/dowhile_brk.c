/* C-1: break inside do-while exits the loop.  i reaches 3, breaks. Returns 3. */
int main(){ int i; i=0; do { i=i+1; if (i==3) break; } while (i<10); return i; }
