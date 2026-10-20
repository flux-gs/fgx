int sum(int *p, int n)
{
    return p[0] + p[1];
}

int main()
{
    int a[2];
    a[0] = 20;
    a[1] = 22;
    return sum(a, 2);
}
