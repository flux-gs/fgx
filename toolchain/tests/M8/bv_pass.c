struct pair { int a; int b; };

int sum(struct pair s)
{
    return s.a + s.b;
}

int main()
{
    struct pair p;
    p.a = 30;
    p.b = 12;
    return sum(p);
}
