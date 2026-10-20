int dbl(int *p)
{
    return *p + *p;
}

int main()
{
    int x = 21;
    return dbl(&x);
}
