int sum(int *arr, int n)
{
    int s = 0;
    int i = 0;
    while (i < n) {
        s = s + arr[i];
        i = i + 1;
    }
    return s;
}

int main()
{
    int a[5];
    a[0] = 8;
    a[1] = 9;
    a[2] = 10;
    a[3] = 7;
    a[4] = 8;
    return sum(a, 5);
}
