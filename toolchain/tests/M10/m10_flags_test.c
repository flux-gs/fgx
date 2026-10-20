enum { F_A = 1, F_B = 2, F_C = 4, F_D = 8 };

int score(int f)
{
    int n;
    n = 0;
    if (f & F_A) n += 7;
    if (f & F_B) n |= 14;
    if ((f & F_C) && !(f & F_D)) n <<= 1;
    return n;
}

int main()
{
    int total;
    int i;
    int mask;
    total = 0;
    mask = ~0;
    for (i = 0; i < 4; i = i + 1) {
        total += score((1 << i) & mask);
    }
    return total * 2;
}
