/* expect: apply only to integral operands */
/* K&R A.7.11: "The usual arithmetic conversions are performed; the result is
 * the bitwise AND function of the operands.  The operator applies only to
 * integral operands."  A.7.12 and A.7.13 close with the same sentence for
 * '^' and '|'.  A struct or union value is not an integral operand.
 *
 * THIS IS THE SHAPE THAT SHIPPED A BUG.  2.11BSD's mount(8) declares
 * `union wait status' and tests it with WIFEXITED, whose 2.11BSD definition
 * takes the union (usr/sys/h/wait.h:66) -- but FGX's sys/wait.h defines that
 * macro over an int, so the port expanded to `(status) & 0x7F'.  fcc accepted
 * it and compiled the union as its ADDRESS: a stack address ANDed with 127 is
 * almost never 0, so the exit arm was never taken and mount printed
 * "Signal 0" after a mount that had just succeeded.
 *
 * The union here is 2.11BSD's own, bitfields included, because the bug needed
 * a union whose first member is an int -- which is exactly what makes the
 * wrong answer look plausible. */
union wait {
    int w_status;
    struct {
        unsigned short w_Termsig:7;
        unsigned short w_Coredump:1;
        unsigned short w_Retcode:8;
    } w_T;
};

int
exited(status)
union wait status;
{
    return ((status) & 0x7F) == 0;
}
