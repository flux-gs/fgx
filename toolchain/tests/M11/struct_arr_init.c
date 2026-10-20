/* M22: struct-array brace init + indexed field access.
 * Tests: global struct Item items[3] = {{...},...}; items[i].name strcmp,
 * items[i].v sum. 10+14+18 = 42. */
int strcmp(char *a, char *b);

struct Item { char *name; int v; };

struct Item items[3] = {
    {"alpha",  10},
    {"answer", 14},
    {"gamma",  18}
};

int main()
{
    int i;
    int sum;
    sum = 0;
    for (i = 0; i < 3; i = i + 1) {
        sum = sum + items[i].v;
    }
    /* Touch items[i].name via strcmp to verify the name field too. */
    if (strcmp(items[1].name, "answer") != 0) {
        return 0;
    }
    return sum;
}
