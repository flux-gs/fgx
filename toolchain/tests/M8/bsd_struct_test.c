typedef struct point {
    int  x;
    int  y;
    char tag;
} Point;

void set_point(Point *p, int x, int y, char t)
{
    p->x = x;
    p->y = y;
    p->tag = t;
}

int sum_xys(Point *arr, int n)
{
    int total;
    int i;
    total = 0;
    i = 0;
    while (i < n) {
        total = total + arr[i].x + arr[i].y;
        i = i + 1;
    }
    return total;
}

int main()
{
    Point pts[3];
    set_point(&pts[0], 5, 7, 'A');
    set_point(&pts[1], 8, 9, 'B');
    set_point(&pts[2], 6, 7, 'C');
    return sum_xys(pts, 3);
}
