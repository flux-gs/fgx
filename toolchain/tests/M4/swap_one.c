int swap(int *a, int *b)
{
    int t = *a;
    *a = *b;
    *b = t;
    return 0;
}

int main()
{
    int x = 7;
    int y = 42;
    swap(&x, &y);
    return x;
}
