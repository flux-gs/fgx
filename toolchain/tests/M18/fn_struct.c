/* M18: struct-of-fn-ptrs (BSD vt shape). */
int seven(int x) { return 7 + x; }
struct ops {
    int (*compute)(int);
};

int main(void)
{
    struct ops o;
    o.compute = seven;
    return o.compute(35);   /* 7 + 35 = 42 */
}
