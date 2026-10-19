struct point { int x; int y; };

int main()
{
    struct point p;
    struct point *pp;
    pp = &p;
    pp->x = 42;
    return pp->x;
}
