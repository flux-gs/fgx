int classify(int c)
{
    switch (c) {
        case 1: return 100;
        case 2: return 42;
        case 3: return 300;
        default: return 999;
    }
}

int main()
{
    return classify(2);
}
