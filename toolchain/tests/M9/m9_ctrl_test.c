int classify(int c)
{
    switch (c) {
        case 'a': case 'A': return 1;
        case 'b': case 'B': return 2;
        case 'c': case 'C': return 3;
        default:            return 0;
    }
}

int main()
{
    int s;
    int i;
    s = 0;
    for (i = 0; i < 10; i = i + 1) {
        if (i == 1) continue;
        if (i == 5) break;
        s = s + classify('a' + (i < 3 ? i : 0));
    }
    return s * 7;
}
