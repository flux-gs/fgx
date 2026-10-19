struct flags {
    unsigned a:3;
    unsigned b:5;
    unsigned c:8;
};

int main()
{
    return sizeof(struct flags) * 21;
}
