/* M20: long array with brace init, indexed read. */
long ages[3] = { 100000L, 200000L, 142L };
int main(void)
{
    long sum;
    sum = ages[0] + ages[1] + ages[2];   /* 300142 */
    sum = sum - 300100L;                  /* 42 */
    return (int)sum;
}
