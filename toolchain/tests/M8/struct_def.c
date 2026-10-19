struct point {
    int x;
    int y;
    char tag;
};

int main()
{
    return sizeof(struct point) * 7;
}
