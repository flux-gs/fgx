int sideef(int *p)
{
    *p = 42;
    return 0;
}

int main()
{
    int x = 0;
    sideef(&x);
    return x;
}
