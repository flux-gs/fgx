int fopen(char *path, char *mode);

int main()
{
    int fp;
    fp = fopen("/nope", "r");
    return fp;
}
