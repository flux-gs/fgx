int main()
{
    char buf[5];
    int i;
    int sum;
    buf[0] = 5;
    buf[1] = 9;
    buf[2] = 10;
    buf[3] = 9;
    buf[4] = 9;
    sum = 0;
    i = 0;
    while (i < 5) {
        sum = sum + buf[i];
        i = i + 1;
    }
    return sum;
}
