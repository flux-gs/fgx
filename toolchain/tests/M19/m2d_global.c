/* M19: global int m[2][3] with brace-init, indexed read. */
int m[2][3] = { {1, 2, 3}, {11, 12, 13} };

int main(void)
{
    return m[0][0] + m[0][1] + m[0][2] +
           m[1][0] + m[1][1] + m[1][2];   /* 42 */
}
