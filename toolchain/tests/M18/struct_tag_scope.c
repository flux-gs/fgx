/* K&R A.11.1: "The scope of a structure, union, or enumeration tag ...
 * persists to the end of a translation unit (for declarations at the external
 * level) or to the end of the block (for declarations within a function)."
 *
 * fcc kept ONE flat tag table, so the second function below reported
 * "redefinition of struct" and 2.11BSD's ls(1) could not be compiled: its
 * getname() and getgroup() each declare their own `struct ncache'.
 *
 * The three cases, in order:
 *   two functions each declaring the same tag, with DIFFERENT members;
 *   an inner block shadowing a file-scope tag of the same name;
 *   the file-scope tag still being the one in view after that block closes.
 */
struct ncache {                 /* file scope: two ints */
    int a;
    int b;
};

int outer_sum(void)
{
    struct ncache c;
    c.a = 3;
    c.b = 4;
    return c.a + c.b;
}

int first(void)
{
    struct ncache {             /* block scope: one char */
        char name[4];
    } t;
    t.name[0] = 'x';
    t.name[1] = 0;
    return t.name[0];
}

int second(void)
{
    struct ncache {             /* the same tag again, a different shape */
        int gid;
        char name[6];
    } u;
    u.gid = 9;
    u.name[0] = 'y';
    return u.gid + u.name[0];
}

int shadow_then_outer(void)
{
    int n;
    {
        struct ncache {         /* shadows the file-scope one */
            int only;
        } s;
        s.only = 100;
        n = s.only;
    }
    {
        struct ncache o;        /* ...which is back in view here */
        o.a = 1;
        o.b = 2;
        n = n + o.a + o.b;
    }
    return n;
}

int main(void)
{
    return outer_sum() + first() + second() + shadow_then_outer();
}
