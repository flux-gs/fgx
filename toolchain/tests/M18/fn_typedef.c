/* M18: typedef-declared fn-ptr. */
typedef int (*cb_t)(int);
int double_it(int x) { return x * 2; }

int main(void)
{
    cb_t fp;
    fp = double_it;
    return fp(21);
}
