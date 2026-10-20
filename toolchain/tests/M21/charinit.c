/* char[N] = { ... } brace init.  Each init value stored as 1 byte
 * (DFB), zero-fill if N > init count.
 *
 * Sum of [1,2,3,4,5,6,7,8,9,42] across reads = ... actually just
 * check buf[9] = 42.
 */
char buf[10] = {
    0, 0, 0, 0, 0,
    0, 0, 0, 0, 42
};

int main()
{
    return buf[9];
}
