/* D-1: partial init zero-fills the rest.  a[0]=7, a[1..3]=0 -> sum 7
 * (garbage if zero-fill were missing). */
int main(){ int a[4] = {7}; return a[0]+a[1]+a[2]+a[3]; }
