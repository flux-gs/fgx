#!/bin/bash
# Convert .po to .2mg format (adds 64-byte header)
# Usage: po2mg.sh input.po output.2mg

if [ $# -lt 2 ]; then
    echo "Usage: $0 input.po output.2mg"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"

# 2IMG header format for 800K 3.5" disk
# See: https://apple2.org.za/gswv/a2zine/Docs/DiskImage_2MG_Info.txt

# Get input size
SIZE=$(wc -c < "$INPUT" | tr -d ' ')

# Create header (64 bytes)
# Magic: 2IMG (32 49 4D 47)
# Creator: FGX! 
# Header size: 64 (40 00)
# Version: 1 (01 00)
# Format: ProDOS order (01 00 00 00)
# Flags: 0
# ProDOS blocks: 1600 for 800K (40 06 00 00)
# Data offset: 64 (40 00 00 00)
# Data length: disk size (00 00 0C 80 = 819200)

printf '2IMG' > "$OUTPUT"                        # Magic
printf 'FGX!' >> "$OUTPUT"                       # Creator
printf '\x40\x00' >> "$OUTPUT"                   # Header length (64)
printf '\x01\x00' >> "$OUTPUT"                   # Version (1)
printf '\x01\x00\x00\x00' >> "$OUTPUT"           # Format (1 = ProDOS order)
printf '\x00\x00\x00\x00' >> "$OUTPUT"           # Flags
printf '\x40\x06\x00\x00' >> "$OUTPUT"           # ProDOS blocks (1600 = 0x640)
printf '\x40\x00\x00\x00' >> "$OUTPUT"           # Data offset (64)
printf '\x00\x80\x0c\x00' >> "$OUTPUT"           # Data length (819200 = 0xC8000)
printf '\x00\x00\x00\x00' >> "$OUTPUT"           # Comment offset (none)
printf '\x00\x00\x00\x00' >> "$OUTPUT"           # Comment length (none)
printf '\x00\x00\x00\x00' >> "$OUTPUT"           # Creator data offset (none)
printf '\x00\x00\x00\x00' >> "$OUTPUT"           # Creator data length (none)
# Pad to 64 bytes
printf '\x00\x00\x00\x00\x00\x00\x00\x00' >> "$OUTPUT"
printf '\x00\x00\x00\x00\x00\x00\x00\x00' >> "$OUTPUT"

# Append disk data
cat "$INPUT" >> "$OUTPUT"

echo "Created: $OUTPUT ($(wc -c < "$OUTPUT" | tr -d ' ') bytes)"
