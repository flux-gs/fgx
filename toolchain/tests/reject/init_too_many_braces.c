/* expect: too many braces in struct initializer */
/* A scalar's initializer is "a single expression, perhaps in braces" (K&R
 * A.8.7) -- one pair, not two.  Nested braces descend into a member's
 * subaggregates, and an int member has none to descend into. */
struct s { int a; int b; };
struct s v = { { { 1 } }, 2 };

int main()
{
    return v.a;
}
