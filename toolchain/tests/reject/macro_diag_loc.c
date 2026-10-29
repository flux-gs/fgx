/* expect: macro_diag_loc.c:16:5: error: expected expression */
/* A diagnostic on a token from a macro body names the line and column where
 * the macro is used, as cpp does.  The bad token here is `]', two expansions
 * deep: SET's body uses CLOSE, whose body is the `]'.  Body tokens are scanned
 * from the #define text, so without the invocation's location they report
 * that text's own position, 1:1.  The expected location is SET's use. */
#define CLOSE   ]
#define SET(v)  v = CLOSE

int main()
{
    int r;

    r = 1;
    r = 2;
    SET(r);
    return r;
}
