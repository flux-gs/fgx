/* `&f(args)[i]' and `&f(args)[i].m': '&' of a subscript whose base is a call.
 * K&R A.7.4.2 wants an lvalue; E1[E2] is *((E1)+(E2)) and `*' of a pointer to
 * an object is one, whatever computed E1.  fcc took `&f()->m' but refused
 * the subscript.  Returns 42. */
static char buf[8];
struct s { int a; int b; };
static struct s arr[3];
char *pb() { return buf; }
struct s *ps() { return arr; }
int main()
{
    char *p = &pb()[3];
    struct s *q = &ps()[2];
    int *r = &ps()[1].b;
    *p = 30; q->a = 7; *r = 5;
    return buf[3] + arr[2].a + arr[1].b;   /* 42 */
}
