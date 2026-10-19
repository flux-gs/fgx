struct flags {
    unsigned a:8;
    unsigned b:8;
};

int main()
{
    struct flags f;
    f.a = 100;
    f.b = 200;
    f.a = 42;
    return f.a;
}
