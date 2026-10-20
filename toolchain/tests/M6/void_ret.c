void poke(int *p)
{
    *p = 42;
}

int main()
{
    int x;
    x = 0;
    poke(&x);
    return x;
}
