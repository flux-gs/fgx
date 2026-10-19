/* Increment 4: return types that tripped the old fcc "bad return type"
 * whitelist -- a typedef'd pointer return (ret_t.base resolves to LT_CHAR_PTR,
 * not a bare base) and a union-pointer return.  Both now flow through the ONE
 * parse_declarator, deriving the return type via the same type_for_decl every
 * context uses.  This is the tcsh sh.h construct class.  Returns 42. */

typedef char *string;

union u { int i; char c; };

static char msg[4];
static union u box;

string getmsg()          /* typedef'd pointer return */
{
    return msg;
}

union u *getbox()        /* union pointer return */
{
    return &box;
}

int main()
{
    msg[0] = 40;
    box.i = 2;
    return getmsg()[0] + getbox()->i;   /* 40 + 2 = 42 */
}
