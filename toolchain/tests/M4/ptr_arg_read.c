int deref(int *p)
{
    return *p;
}

int main()
{
    int x = 42;
    return deref(&x);
}
