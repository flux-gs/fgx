int memcpy(char *d, char *s, int n);

int main()
{
    char dst[8];
    memcpy(dst, "abcd", 5);
    return dst[2];
}
