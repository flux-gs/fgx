struct point { int x; int y; };
struct outer { int z; struct point in; };

int main()
{
    struct outer s;
    s.z = 10;
    s.in.x = 20;
    s.in.y = 12;
    return s.z + s.in.x + s.in.y;
}
