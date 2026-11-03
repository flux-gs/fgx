/* A global array of struct pointers, subscripted twice: file[k][i].value.
 * K&R A.7.3.1: "E1[E2] is identical (by definition) to *((E1)+(E2))", so the
 * second subscript scales by the struct's size as any struct pointer does.
 * fcc's global element lost its struct and died for want of a stride;
 * 2.11BSD diff's `struct line *file[2]' is the case.  The struct is three
 * ints so a stride of 2 would read the wrong member.  Returns 42. */
struct line { int serial; int value; int pad; };
struct line a0[3], a1[3];
struct line *file[2];

int main()
{
    int i, r;

    file[0] = a0;
    file[1] = a1;
    for (i = 0; i < 3; i++) {
        a0[i].value = i * 10;
        a1[i].serial = i + 1;
    }
    r = file[0][2].value + file[1][2].serial;   /* 20 + 3 */
    file[1][1].value = 19;
    return r + a1[1].value;                     /* 23 + 19 */
}
