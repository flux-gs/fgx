/* A call through a function-pointer member reached by `.' then `->':
 * `pack.who->func(args)' and its parenthesized spelling.  K&R A.7.3.2: "The
 * postfix expression ... must be of type ``pointer to function returning
 * T,'' for some type T, and the value of the function call has type T."
 * Returns 42 when both calls dispatch with their arguments. */
struct ops { int (*func)(); };
struct pk { int tag; struct ops *who; };

int add(a, b) int a, b; { return a + b; }

struct ops theops = { add };
struct pk pack;

int main()
{
    pack.who = &theops;
    return pack.who->func(30, 10) + (pack.who->func)(1, 1);   /* 40 + 2 */
}
