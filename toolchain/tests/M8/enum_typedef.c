/* enum_typedef: enum used as a TYPE -- `typedef enum {..} NAME;` (tcsh tw.h
 * `typedef enum { LIST, ... } COMMAND;`), plus the typedef name as a parameter
 * type.  fcc previously handled enum only as a top-level `enum {..};`
 * definition and rejected enum in parse_type_spec ("expected type"), blocking
 * every TU that includes tw.h.  -> 42. */
typedef enum { LIST, RECOGNIZE, PRINT_HELP, SPELL, GLOB } COMMAND;
COMMAND gcmd;

static int
val(COMMAND c)          /* enum-typedef parameter */
{
    return (int)c;
}

int
main()
{
    gcmd = SPELL;                 /* 3 */
    return 39 + val(gcmd);        /* 39 + 3 == 42 */
}
