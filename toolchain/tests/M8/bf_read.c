struct flags {
    unsigned a:3;
    unsigned b:5;
    unsigned c:8;
};

int main()
{
    struct flags f;
    f.a = 7;
    f.b = 21;
    f.c = 6;
    return f.b * 2;
}
