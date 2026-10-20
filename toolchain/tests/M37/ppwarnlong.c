/* A #warning whose message runs past the 160-byte capture buffer.  The capture
 * loop stops on LENGTH rather than on the newline, so the directive has to
 * drain the rest of the line itself; without that drain the tail is lexed as C
 * and the next token comes from the middle of the message.  Here that tail is
 * `nine hundred and ninety nine.' -- an identifier run that parses as a
 * declaration and takes `acc' with it.  FGX-only oracle.  Value 42. */
#ifndef SOMETHING_UNDEFINED
#warning this message is deliberately longer than the capture buffer so that the tail has to be drained by the directive rather than handed to the lexer as nine hundred and ninety nine.
#endif

int acc;

int main(void)
{
    acc = 20;
    return acc + 22;         /* 42 */
}
