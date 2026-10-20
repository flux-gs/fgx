int inc(int *p)
{
    *p = *p + 1;
    return 0;
}

int main()
{
    int x = 41;
    inc(&x);
    return x;
}
