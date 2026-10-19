/*
 * slotscan - show what peripheral card is in each Apple II slot.  Calls
 * slotscan(buf, max) (SYS_SLOTSCAN=90), which copies the kernel's boot-time
 * slot-scan table into the buffer: buf[0] = the detected Uthernet II (W5100)
 * slot (0 if none), then 7 records of {flags, sig[6]} for slots 1..7.  The
 * W5100 is found by an I/O probe (it has no ROM signature); other cards are
 * named from their $Cn00 ROM signature bytes.
 */
#include <stdio.h>

#define SLF_OCCUPIED 0x01
#define SLF_W5100    0x02
#define SLF_HASROM   0x04
#define SLOTSCAN_WIRE 50   /* bytes the kernel writes: 1 (W5100 slot) + 7*7 (slotTab) */

int slotscan(unsigned char *buf, int max);  /* libc shim c_slotscan: SYS_SLOTSCAN */

/* Data-bank buffer (NOT a stack local): the syscall writes via the caller DBR. */
unsigned char sbuf[64];

static char hx(int n)
{
    n &= 15;
    if (n < 10) return '0' + n;
    return 'A' + (n - 10);
}

/* Name a card from its captured signature bytes (offsets $01,$03,$05,$07,$0B,$0C).
 * Returns 0 if unrecognized.  Values from public Apple II firmware-protocol docs;
 * extend freely. */
static char *cardname(unsigned char *s)
{
    if (s[0] == 0x20 && s[1] == 0x00 && s[2] == 0x03 && s[3] == 0x00)
        return "SmartPort/disk";
    if (s[2] == 0x38 && s[3] == 0x18 && s[4] == 0x01) {
        if (s[5] == 0x31) return "Serial/modem";
        if (s[5] == 0x88) return "80-column";
        if (s[5] == 0x20) return "Mouse";
    }
    if (s[2] == 0x2C && s[3] == 0x18 && s[4] == 0x01 && s[5] == 0x8B)
        return "VidHD";
    return 0;
}

int main(void)
{
    int n, i, sl, j;
    unsigned char *r, *sig, flags, w5;
    char *nm;

    n = slotscan(sbuf, 64);
    if (n < SLOTSCAN_WIRE) {
        printf("slotscan: scan unavailable\n");
        return 1;
    }
    w5 = sbuf[0];
    printf("Slot  Card\n");
    for (i = 0; i < 7; i++) {
        sl = i + 1;
        r = sbuf + 1 + i * 7;
        flags = r[0];
        sig = r + 1;
        if (flags & SLF_W5100) {
            printf("  %d   Uthernet II (W5100)", sl);
            if (sl == w5) printf("  [net]");
            printf("\n");
        } else if (flags & SLF_HASROM) {
            nm = cardname(sig);
            if (nm) {
                printf("  %d   %s\n", sl, nm);
            } else {
                printf("  %d   unknown sig ", sl);
                for (j = 0; j < 6; j++)
                    printf("%c%c ", hx(sig[j] >> 4), hx(sig[j]));
                printf("\n");
            }
        }
        /* else: empty slot - omit */
    }
    return 0;
}
