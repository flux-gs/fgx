/* M19: m[i] partial decay → int *row, then row[j] indexing. */
int g[2][3] = { {1, 2, 3}, {11, 12, 13} };

int sum_row(int *row, int n)
{
    int i, s; s = 0;
    for (i = 0; i < n; i = i + 1) s = s + row[i];
    return s;
}

int main(void)
{
    int total;
    total = sum_row(g[0], 3) + sum_row(g[1], 3);   /* 6 + 36 = 42 */
    return total;
}
