/* B-7: initialised fn-ptr GLOBAL — `cb_t gh = f;` and `int (*gh2)(int) = f;`
 * at file scope.  Each global's 4-byte storage is emitted as
 * DA func / DFB ^func / DFB pad; the runtime bank is recovered via PHK at
 * load (own-bank fn-ptr semantics).  Returns 42. */
typedef int (*cb_t)(int);

int double_it(int x) { return x * 2; }
int triple_it(int x) { return x * 3; }

cb_t gh = double_it;             /* typedef'd global init  */
int (*gh2)(int) = triple_it;     /* declarator global init */

int main(void)
{
    return gh(6) + gh2(10);      /* 12 + 30 = 42 */
}
