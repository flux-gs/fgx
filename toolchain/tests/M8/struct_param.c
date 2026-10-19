struct point { int x; int y; };

void setp(struct point *p, int x, int y)
{
    p->x = x;
    p->y = y;
}

int main()
{
    struct point p;
    setp(&p, 30, 12);
    return p.x + p.y;
}
