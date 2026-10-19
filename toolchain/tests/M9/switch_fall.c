int main()
{
    int s;
    int x;
    s = 0;
    x = 1;
    switch (x) {
        case 1:
            s = s + 14;
        case 2:
            s = s + 14;
        case 3:
            s = s + 14;
            break;
        case 4:
            s = 999;
    }
    return s;
}
