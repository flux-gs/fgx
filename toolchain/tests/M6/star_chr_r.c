int peek(char *p)
{
    return *p;
}

int main()
{
    char c;
    c = 'A';
    return peek(&c);
}
