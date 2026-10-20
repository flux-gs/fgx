/* M19 acceptance: nested init + partial decay + multi-dim param +
 * fully-indexed read.  Returns 42. */
int matrix[3][3] = {
    {1, 2, 3},
    {4, 5, 6},
    {7, 8, 9}
};

int sum_row(int *row, int n)
{
    int i, s;
    s = 0;
    for (i = 0; i < n; i = i + 1) s = s + row[i];
    return s;
}

int sum_grid(int m[][3], int rows)
{
    int i, s;
    s = 0;
    for (i = 0; i < rows; i = i + 1) s = s + sum_row(m[i], 3);
    return s;
}

int main(void)
{
    int total;
    total = sum_grid(matrix, 3);          /* 1+2+...+9 = 45 */
    return total - matrix[0][2];          /* 45 - 3 = 42 */
}
