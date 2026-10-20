int main()
{
    int x;
    void *vp;
    int *ip;
    x = 42;
    vp = &x;
    ip = (int*)vp;
    return *ip;
}
