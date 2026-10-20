/* Pointer typedefs: `typedef char *cp;` resolves to PTR<CHAR>; a further
 * declarator star yields char** (cp *p).  Previously rejected with
 * "M8: typedef of pointer type not supported".  Exercises the yacc value-stack
 * shape (cp v[]; cp *p; p = &v[-1]; ++p; *p = ...) and the multi-declarator
 * `cp ga, gb;` (both must be char*, not gb=char).  Result: 42. */
typedef char *cp;
cp ga, gb;
cp garr[3];

int main()
{
    cp v[4];
    cp *p;

    ga = "AB";
    gb = ga;
    garr[0] = gb;
    if (garr[0][0] != 'A') return 1;
    v[0] = "Z";
    p = &v[-1];
    ++p;
    *p = v[0];
    if ((*p)[0] != 'Z') return 2;
    return 42;
}
