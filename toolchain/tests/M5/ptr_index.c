int peek(int *p)
{
    return p[0];
}

int main()
{
    int x = 42;
    return peek(&x);
}
