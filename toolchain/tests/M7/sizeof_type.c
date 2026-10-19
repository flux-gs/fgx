int main()
{
    return sizeof(int) * sizeof(char[42]) / sizeof(int);
}
