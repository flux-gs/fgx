int main()
{
    int s;
    int i;
    s = 0;
    for (i = 0; i < 100; i = i + 1) {
        if (i == 6) break;
        s = s + 7;
    }
    return s;
}
