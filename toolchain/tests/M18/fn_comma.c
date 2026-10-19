/* M18: comma-separated fn-ptr locals — `int (*a)(), (*b)();`
 * (ex_voper.c operator×motion idiom; both editors need this). */
int add10() { return 10; }
int add32() { return 32; }

int main(void)
{
    int (*a)(), (*b)();
    a = add10;
    b = add32;
    return a() + b();   /* 10 + 32 = 42 */
}
