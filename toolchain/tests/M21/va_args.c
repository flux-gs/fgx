/* Variadic function-like macros with __VA_ARGS__.
 *
 * APPLY(f, ...) calls f with the extra args.  Tests:
 *   - `...` accepted in the param list
 *   - __VA_ARGS__ in body substituted with comma-joined extras
 *   - The substituted text is passed verbatim to a function call
 *
 * Returns 42.
 */
#define APPLY(f, ...) f(__VA_ARGS__)

int sum3(int a, int b, int c)
{
    return a + b + c;
}

int main()
{
    return APPLY(sum3, 20, 21, 1);   /* sum3(20, 21, 1) = 42 */
}
