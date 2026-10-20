struct point { int x; int y; };
struct point g_p;

int main()
{
    g_p.x = 30;
    g_p.y = 12;
    return g_p.x + g_p.y;
}
