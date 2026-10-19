int main()
{
    char buf[6];
    char *p;
    char *q;
    p = buf;
    q = buf + 5;
    return (q - p) + 37;
}
