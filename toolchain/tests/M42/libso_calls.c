/* M42: --libso calls.  Every call -- to a static function, to an extern, to
 * setjmp, and to the long long runtime -- is a JSL (FGX2_FARCALL): libc.so's
 * banks are relocated at load, so a call needs no pile trampoline. */
#include <setjmp.h>
static int helper(x) int x; { return x + 1; }
int ext();
static jmp_buf jb;
int main()
{
    long long a = 3, b = 5;
    if (setjmp(jb)) return 1;
    a = a * b;
    return helper((int)a) == 16 ? 42 : ext();
}
int ext() { return 0; }
