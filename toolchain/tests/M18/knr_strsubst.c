/* K&R substitute-inside-STRING-literal: #define S(x) "x-tag" -> S(hi) = "hi-tag". */
#define S(x) "x-tag"
int main() { char *s; s = S(hi); return s[0] + s[3]; }   /* 'h'(104) + 't'(116) = 220 */
