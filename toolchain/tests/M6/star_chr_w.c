int poke(char *p)
{
    *p = 'A';
    return 0;
}

int main()
{
    char c;
    c = 0;
    poke(&c);
    return c;
}
