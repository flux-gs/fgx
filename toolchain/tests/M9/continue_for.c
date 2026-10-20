int main()
{
    int s;
    int i;
    s = 0;
    for (i = 0; i < 10; i = i + 1) {
        if (i > 5) continue;
        s = s + 7;
    }
    return s;
}
