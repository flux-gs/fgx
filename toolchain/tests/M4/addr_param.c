int f(int x)
{
    int *p = &x;
    return *p;
}

int main()
{
    return f(42);
}
