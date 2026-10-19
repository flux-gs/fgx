/* M19: int m[][3] as function param. */
int g[2][3] = { {1, 2, 3}, {11, 12, 13} };

int sum_2x3(int m[][3])
{
    return m[0][0] + m[0][1] + m[0][2] +
           m[1][0] + m[1][1] + m[1][2];
}

int main(void) { return sum_2x3(g); }    /* 42 */
