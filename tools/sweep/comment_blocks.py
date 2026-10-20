import re, sys
PAT = re.compile(r'\bused to\b|\bstood here\b|\bfirst (cut|draft|attempt|version)\b|\bno longer\b'
                 r'|[Mm]easured 20\d\d-\d\d-\d\d|\bIS GONE\b|\bIS RETIRED\b|\bit said\b'
                 r'|\bused to say\b|\bwas true (until|while)\b|\bis FIXED\b|\bwhat it said\b', re.I)

def is_comment(l, ext):
    t = l.strip()
    if ext == 's':  return t.startswith(';') or t == ''
    return t.startswith('*') or t.startswith('/*') or t.startswith('//') or t == ''

def blocks(path):
    ext = path.rsplit('.',1)[-1]
    lines = open(path, encoding='utf-8').read().split('\n')
    out, i = [], 0
    while i < len(lines):
        if is_comment(lines[i], ext) and lines[i].strip():
            j = i
            while j < len(lines) and is_comment(lines[j], ext):
                j += 1
            blk = lines[i:j]
            if any(PAT.search(x) for x in blk):
                out.append((i+1, j, blk))
            i = j
        else:
            i += 1
    return out

if __name__ == '__main__':
    path = sys.argv[1]
    lo = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    hi = int(sys.argv[3]) if len(sys.argv) > 3 else 10**9
    b = blocks(path)
    print("## %s: %d comment blocks carry history" % (path, len(b)))
    for n,(a,z,blk) in enumerate(b):
        if not (lo <= n < hi): continue
        print("\n===== block %d  lines %d-%d" % (n, a, z))
        print('\n'.join(blk))
