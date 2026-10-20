typedef struct point {
    int x;
    int y;
    int z;
} Point;

int main()
{
    Point p;
    return sizeof p * 7;
}
