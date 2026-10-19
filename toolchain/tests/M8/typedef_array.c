/* typedef_array: an array typedef `typedef char MSG[]` names "array of char"
 * (K&R A.8.9 -- the declarator is parsed in the usual way, A.8.6.2).  A use
 * `MSG g = "..."` is then equivalent to `char g[] = "..."`: a sizeless array
 * completed by its initializer (A.8.7).  The 2.11BSD Bourne /bin/sh declares
 * every message string this way (MSG in mode.h).  '*' is ASCII 42.  -> 42. */
typedef char MSG[];
MSG greeting = "*hello";
int
main()
{
    return greeting[0];      /* '*' == 42 */
}
