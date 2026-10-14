#!/usr/bin/env python3
"""Fix Flutter 3.44 const-related compile errors.

Flutter 3.44 removed `const` from `BorderRadius.circular` and `Border.all`, so
any `const` keyword that encloses one of those calls now fails to compile with
`const_with_non_const`. The `printing` package's `pw.TextStyle` also no longer
const-evaluates (its `PdfColors`/`FontWeight` members are not compile-time
constants), producing `const_eval_type_bool_num_string`.

Removing an enclosing `const` keyword is always safe: it never changes runtime
behavior, it only gives up a const-optimization that the framework no longer
allows at these sites.

Usage:  python3 fix_const_errors.py [path-to-dart-analyze-output]
"""

import re
import sys
from collections import defaultdict

ANALYZE_FILE = sys.argv[1] if len(sys.argv) > 1 else '/tmp/analyze.txt'

# error line format:  error - path:line:col - message - code
ERR_RE = re.compile(
    r'^\s*error - (.+?):(\d+):(\d+) - .* - '
    r'(const_with_non_const|const_eval_type_bool_num_string)$')


def parse_errors(path):
    files = defaultdict(list)  # relpath -> [(line, col, code), ...]
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            m = ERR_RE.match(line)
            if m:
                rel, line_no, col, code = m.group(1), int(m.group(2)), int(m.group(3)), m.group(4)
                files[rel].append((line_no, col, code))
    return files


def full_path(rel):
    return rel if rel.startswith('lib/') else 'lib/' + rel


def offset_of(text, line, col):
    """1-based (line, col) -> 0-based char offset."""
    pos = 0
    for _ in range(line - 1):
        pos = text.find('\n', pos) + 1
    return pos + (col - 1)


def code_mask(text):
    """Char-level mask: True = real code, False = inside string/comment.

    Handles Dart string literals incl. raw strings (r'...'), triple-quoted
    strings, escapes, and ${...} interpolation (interpolation bodies are
    treated as code so embedded quotes do not terminate the outer string).
    """
    n = len(text)
    code = [True] * n
    i = 0
    while i < n:
        c = text[i]
        # line comment
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            j = text.find('\n', i)
            j = n if j == -1 else j
            for k in range(i, j):
                code[k] = False
            i = j
            continue
        # block comment
        if c == '/' and i + 1 < n and text[i + 1] == '*':
            j = text.find('*/', i + 2)
            j = n if j == -1 else j + 2
            for k in range(i, j):
                code[k] = False
            i = j
            continue
        # string literal
        if c in ('"', "'"):
            raw = (i >= 1 and text[i - 1] == 'r' and
                   (i < 2 or not is_ident_char(text[i - 2])))
            start = i - 1 if raw else i
            triple = i + 2 < n and text[i + 1] == c and text[i + 2] == c
            qlen = 3 if triple else 1
            j = i + qlen
            while j < n:
                if triple and text.startswith(c * 3, j):
                    j += 3
                    break
                if text[j] == c and not triple:
                    j += 1
                    break
                if text[j] == '\\' and not raw:
                    j += 2
                    continue
                if not raw and text[j] == '$' and j + 1 < n and text[j + 1] == '{':
                    depth = 1
                    j += 2
                    while j < n and depth > 0:
                        if text[j] == '{':
                            depth += 1
                        elif text[j] == '}':
                            depth -= 1
                        j += 1
                    continue
                j += 1
            for k in range(start, min(j, n)):
                code[k] = False
            i = j
            continue
        i += 1
    return code


def is_ident_char(ch):
    return ch.isalnum() or ch in '_$'


def matching_open(text, mask, close_pos):
    depth = 1
    j = close_pos - 1
    while j >= 0 and depth > 0:
        if mask[j]:
            c = text[j]
            if c in '([{':
                depth -= 1
                if depth == 0:
                    return j
            elif c in ')]}':
                depth += 1
        j -= 1
    return -1


def matching_close(text, mask, open_pos):
    depth = 1
    j = open_pos + 1
    n = len(text)
    while j < n and depth > 0:
        if mask[j]:
            c = text[j]
            if c in ')]}':
                depth -= 1
                if depth == 0:
                    return j
            elif c in '([{':
                depth += 1
        j += 1
    return -1


def find_removals(text, mask, offsets):
    """For each error offset, find enclosing `const` keyword(s) to remove.

    Returns {const_pos: kind} where kind is 'remove' or 'final' (declarations
    like `static const X = ...` must become `final` rather than lose the word).
    """
    n = len(text)
    removals = {}

    for p in offsets:
        i = p - 1
        while i >= 0:
            if not mask[i]:
                i -= 1
                continue
            ch = text[i]
            if ch in ')]}':
                op = matching_open(text, mask, i)
                i = (op - 1) if op >= 0 else -1
                continue
            if is_ident_char(ch):
                # scan backward over the identifier run
                j = i
                while j >= 0 and mask[j] and is_ident_char(text[j]):
                    j -= 1
                run = text[j + 1:i + 1]
                if (run == 'const'
                        and (j < 0 or not is_ident_char(text[j]))
                        and (i + 1 >= n or not is_ident_char(text[i + 1]))):
                    # examine the token after the const keyword
                    k = i + 1
                    while k < n and (not mask[k] or text[k] in ' \t\r\n'):
                        k += 1
                    if k >= n:
                        i = j - 1
                        continue
                    c2 = text[k]
                    handled = False
                    if c2 in '([{':
                        close = matching_close(text, mask, k)
                        if close != -1 and p < close:
                            removals[j + 1] = 'remove'
                            break
                        handled = True
                    elif is_ident_char(c2):
                        # identifier chain (e.g. BorderRadius.circular)
                        e = k
                        while e < n and mask[e] and (is_ident_char(text[e]) or text[e] == '.'):
                            e += 1
                        while e < n and not mask[e]:
                            e += 1
                        if e < n and text[e] == '(':
                            close = matching_close(text, mask, e)
                            if close != -1 and p < close:
                                removals[j + 1] = 'remove'
                                break
                            handled = True
                        elif e < n and text[e] == '=':
                            # declaration like `static const Border _x = Border.all(...)`
                            depth = 0
                            s = e + 1
                            stmt_end = -1
                            while s < n:
                                if mask[s]:
                                    if text[s] == ';' and depth == 0:
                                        stmt_end = s
                                        break
                                    if text[s] in '([{':
                                        depth += 1
                                    elif text[s] in ')]}':
                                        if depth == 0:
                                            break
                                        depth -= 1
                                s += 1
                            if stmt_end != -1 and p < stmt_end:
                                removals[j + 1] = 'final'
                                break
                            handled = True
                    if handled:
                        pass  # const did not enclose p; keep walking
                i = j - 1
                continue
            i -= 1
    return removals


def apply_removals(text, removals):
    for pos in sorted(removals, reverse=True):
        kind = removals[pos]
        if kind == 'remove':
            end = pos + 5
            if end < len(text) and text[end] == ' ':
                end += 1
            text = text[:pos] + text[end:]
        else:  # final
            text = text[:pos] + 'final' + text[pos + 5:]
    return text


def main():
    files = parse_errors(ANALYZE_FILE)
    if not files:
        print('No error sites found in', ANALYZE_FILE)
        return

    total_const_errors = sum(
        1 for sites in files.values()
        for _l, _c, code in sites if code == 'const_with_non_const')
    total_eval_errors = sum(
        1 for sites in files.values()
        for _l, _c, code in sites if code == 'const_eval_type_bool_num_string')
    print(f'Parsed {len(files)} files with '
          f'{total_const_errors} const_with_non_const + '
          f'{total_eval_errors} const_eval errors.')

    # Explicitly-const'd calls to constructors that are no longer const in
    # Flutter 3.44 are always invalid, so a global de-const is safe everywhere.
    GLOBAL_PATTERNS = [
        (r'const BorderRadius\.circular\(', 'BorderRadius.circular('),
        (r'const Border\.all\(', 'Border.all('),
    ]

    pw_files = set()
    unhandled = []
    changed_files = []

    for rel, sites in sorted(files.items()):
        fpath = full_path(rel)
        with open(fpath, encoding='utf-8', errors='replace') as f:
            text = f.read()
        mask = code_mask(text)

        const_sites = [offset_of(text, l, c) for l, c, code in sites
                       if code == 'const_with_non_const']
        if const_sites:
            removals = find_removals(text, mask, const_sites)
            if removals:
                new_text = apply_removals(text, removals)
                with open(fpath, 'w', encoding='utf-8') as f:
                    f.write(new_text)
                changed_files.append(fpath)
                print(f'  [const] {rel}: removed {len(removals)} const keyword(s)')
            else:
                # everything we could not auto-handle
                for l, c, _code in sites:
                    if 'const_with_non_const' == _code:
                        unhandled.append(f'{rel}:{l}:{c}')

        eval_sites = [(l, c) for l, c, code in sites
                      if code == 'const_eval_type_bool_num_string']
        # global de-const of explicitly const-marked non-const constructors
        with open(fpath, encoding='utf-8', errors='replace') as f:
            text = f.read()
        for pat, rep in GLOBAL_PATTERNS:
            new_text, cnt = re.subn(pat, rep, text)
            if cnt:
                with open(fpath, 'w', encoding='utf-8') as f:
                    f.write(new_text)
                if fpath not in changed_files:
                    changed_files.append(fpath)
                print(f'  [global] {rel}: de-consted {cnt} explicit const call(s)')
                text = new_text

        if eval_sites:
            for l, c in eval_sites:
                lines = text.split('\n')
                if 'const pw.TextStyle(' not in lines[l - 1]:
                    unhandled.append(f'{rel}:{l}:{c}')
            pw_files.add(fpath)

    # const pw.TextStyle( -> pw.TextStyle( (position-independent global replace)
    for fpath in sorted(pw_files):
        with open(fpath, encoding='utf-8', errors='replace') as f:
            text = f.read()
        new_text, count = re.subn(r'const pw\.TextStyle\(', 'pw.TextStyle(', text)
        if count:
            with open(fpath, 'w', encoding='utf-8') as f:
                f.write(new_text)
            if fpath not in changed_files:
                changed_files.append(fpath)
            print(f'  [eval] {fpath}: de-consted {count} pw.TextStyle site(s)')

    print()
    print(f'Modified {len(changed_files)} file(s).')
    if unhandled:
        print('UNHANDLED sites (review manually):')
        for u in unhandled:
            print('   ', u)
    else:
        print('No unhandled sites.')


if __name__ == '__main__':
    main()
