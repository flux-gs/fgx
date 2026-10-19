"""Comment-only editing helpers.  cut() REFUSES to remove a span that contains
anything but comment or blank lines -- deleting code by accident is the one
mistake this whole sweep can make."""
import io

def _is_comment(l, ext):
    t = l.strip()
    if ext == 's':
        return t == '' or t.startswith(';')
    return t == '' or t.startswith('*') or t.startswith('/*') or t.startswith('//') or t.startswith('*/')

class F:
    def __init__(self, path):
        self.path = path
        self.ext = path.rsplit('.', 1)[-1]
        self.s = io.open(path, encoding='utf-8').read()

    def cut(self, a, b, repl=""):
        """Delete from the start of `a` up to the start of `b`, comment-only."""
        i = self.s.index(a)
        j = self.s.index(b, i)
        span = self.s[i:j]
        bad = [l for l in span.split('\n')[:-1] if not _is_comment(l, self.ext)]
        if bad:
            raise SystemExit("REFUSED: span carries code, first offender:\n  %r" % bad[0])
        self.s = self.s[:i] + repl + self.s[j:]

    def sub(self, a, b):
        assert a in self.s, a[:70]
        self.s = self.s.replace(a, b, 1)

    def save(self):
        io.open(self.path, 'w', encoding='utf-8').write(self.s)
