struct point { int x; int y; };

int main()
{
    struct point p;
    struct point *pp;
    p.x = 7;
    p.y = 7;
    p.x += 21;
    p.y |= 14;
    pp = &p;
    pp->x -= 1;
    return pp->x + p.y;
}
