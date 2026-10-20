/* M18: local fn-ptr — assign, call, return 42. */
int double_it(int x) { return x * 2; }

int main(void)
{
    int (*fp)(int);
    fp = double_it;
    return fp(21);
}
