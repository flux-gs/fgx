/* Static locals declared as function pointers, two in one list and one with
 * an initializer, as 2.11BSD patch's set_signals keeps its saved handlers:
 * `static int (*hupval)(),(*intval)();'.  K&R A.4.1: static objects "retain
 * their values across exit from and reentry to functions and blocks", so the
 * pointers set on the first call are the ones called on the second.
 * Returns 42. */
int seven() { return 7; }
int thirty() { return 30; }
int five() { return 5; }

int keep(int set)
{
    static int (*a)(), (*b)();
    static int (*c)() = five;

    if (set) {
        a = seven;
        b = thirty;
        return 0;
    }
    return (*a)() + (*b)() + (*c)();
}

int main()
{
    keep(1);
    return keep(0);
}
