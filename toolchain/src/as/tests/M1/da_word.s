; M1: DA emits little-endian 16-bit word.  Also tests EQU + addition.
g_val           EQU     $1234
                DA      g_val
                DA      g_val+1
