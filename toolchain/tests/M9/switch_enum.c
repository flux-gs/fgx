enum E { LOW = 1, MID = 2, HIGH = 3 };

int main()
{
    int x;
    x = MID;
    switch (x) {
        case LOW:  return 10;
        case MID:  return 42;
        case HIGH: return 30;
    }
    return 0;
}
