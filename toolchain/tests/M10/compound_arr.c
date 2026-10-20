int main()
{
    int arr[3];
    int i;
    arr[0] = 0;
    arr[1] = 0;
    arr[2] = 0;
    for (i = 0; i < 3; i = i + 1) {
        arr[i] += 14;
    }
    return arr[0] + arr[1] + arr[2];
}
