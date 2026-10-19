/* Char-literal escapes that fcc previously rejected.
 *   \b  -> 8   (backspace)
 *   \f  -> 12  (form feed)
 *   \v  -> 11  (vertical tab)
 *   \a  -> 7   (bell)
 *   \"  -> 34  (double quote — useful in strings; here as char-lit too)
 *   \?  -> 63  (question mark)
 *
 * Sum: 8 + 12 + 11 + 7 + 4 = 42.
 */
int main()
{
    int s;
    s = '\b' + '\f' + '\v' + '\a' + 4;
    return s;
}
