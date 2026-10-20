struct point { int x; int y; };

int main()
{
    struct point pts[3];
    pts[0].x = 10;
    pts[0].y = 5;
    pts[1].x = 14;
    pts[1].y = 7;
    pts[2].x = 4;
    pts[2].y = 2;
    return pts[1].x + pts[1].y + pts[2].x + pts[2].y + pts[0].x + pts[0].y;
}
