#!/usr/bin/env python3
"""Reverse the off-by-one corruption introduced by an earlier run of
fix_const_errors.py.

The buggy script removed the 5 chars ' cons' that precede the final 't' of a
'const' keyword, leaving a stray 't' glued to the preceding character, e.g.:

    decoration: const BoxDecoration(   ->   decoration:t BoxDecoration(

This script finds each stray 't' (or 'finalt') whose following expression
group contains one of the original const_with_non_const error lines (from the
pre-fix analyzer output), and restores 'const'. This is deterministic and
cannot touch legitimate code, because:
  * the stray 't' is a lone token followed by an expression start
    (Identifier + '(', '[', or '{'), which is invalid Dart in real code;
  * the following expression must contain an original error line, which only
    the corrupted sites do.

Usage:  python3 reverse_fix_const_errors.py [--apply] [analyze-output-file]
"""

import re
import sys

ANALYZE_FILE = '/tmp/analyze.txt'
APPLY = '--apply' in sys.argv
if len(sys.argv) > 1 and not sys.argv[1].startswith('--'):
    ANALYZE_FILE = sys.argv[1]

ERR_RE = re.compile(
    r'^\s*error - (.+?):(\d+):\d+ - .* - const_with_non_const$')


def parse_errors(path):
    files = {}  # relpath -> set of error line numbers
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            m = ERR_RE.match(line)
            if m:
                files.setdefault(m.group(1), set()).add(int(m.group(2)))
    return files


def full_path(rel):
    return rel if rel.startswith('lib/') else 'lib/' + rel


def code_mask(text):
    n = len(text)
    code = [True] * n
    i = 0
    while i < n:
        c = text[i]
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            j = text.find('\n', i)
            j = n if j == -1 else j
            for k in range(i, j):
                code[k] = False
            i = j
            continue
        if c == '/' and i + 1 < n and text[i + 1] == '*':
            j = text.find('*/', i + 2)
            j = n if j == -1 else j + 2
            for k in range(i, j):
                code[k] = False
            i = j
            continue
        if c in ('"', "'"):
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
                if text[j] == '\\':
                    j += 2
                    continue
                j += 1
            for k in range(i, min(j, n)):
                code[k] = False
            i = j
            continue
        i += 1
    return code


def is_ident_char(ch):
    return ch.isalnum() or ch in '_$'


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


def line_of(text, pos):
    return text.count('\n', 0, pos) + 1


def scan_file(rel, error_lines):
    fpath = full_path(rel)
    with open(fpath, encoding='utf-8', errors='replace') as f:
        text = f.read()
    mask = code_mask(text)
    n = len(text)
    fixes = []  # (position_of_stray_t, 'const')

    i = 0
    while i < n:
        if mask[i] and is_ident_char(text[i]):
            # scan the identifier run forward
            j = i
            while j < n and mask[j] and is_ident_char(text[j]):
                j += 1
            run = text[i:j]
            # candidate runs: lone 't' or 'finalt' (no other glued variants
            # were produced: no return/throw/await/yield const sites existed)
            if run == 't' or run == 'finalt':
                prev_ok = (i == 0 or not mask[i - 1] or
                           (not is_ident_char(text[i - 1]) and text[i - 1] != '.'))
                if prev_ok:
                    # token after the run (skip horizontal whitespace only:
                    # corruption sites are on a single line)
                    k = j
                    while k < n and mask[k] and text[k] in ' \t':
                        k += 1
                    open_pos = -1
                    if k < n and mask[k]:
                        if text[k] in '[{':
                            open_pos = k
                        elif text[k] == '(':
                            open_pos = k
                        elif is_ident_char(text[k]):
                            e = k
                            while e < n and mask[e] and (is_ident_char(text[e]) or text[e] == '.'):
                                e += 1
                            if e < n and mask[e] and text[e] == '(':
                                open_pos = e
                    if open_pos != -1:
                        close = matching_close(text, mask, open_pos)
                        if close != -1:
                            lo = line_of(text, open_pos)
                            hi = line_of(text, close)
                            if any(lo <= el <= hi for el in error_lines):
                                fixes.append((i, 'const'))
            i = j
            continue
        i += 1
    return text, fixes


def main():
    files = parse_errors(ANALYZE_FILE)
    total = 0
    for rel, error_lines in sorted(files.items()):
        text, fixes = scan_file(rel, error_lines)
        if not fixes:
            continue
        total += len(fixes)
        if APPLY:
            for pos, _rep in sorted(fixes, reverse=True):
                text = text[:pos] + 'const' + text[pos + 1:]
            with open(full_path(rel), 'w', encoding='utf-8') as f:
                f.write(text)
        # report (show first few lines per file)
        shown = 0
        for pos, rep in fixes:
            lo = line_of(text, pos)
            line = text.split('\n')[lo - 1].strip()
            print(f'  {rel}:{lo}: {line}')
            shown += 1
            if shown >= 4:
                break
        if len(fixes) > 4:
            print(f'  {rel}: ... and {len(fixes) - 4} more')
    print(f'\n{"Applied" if APPLY else "Dry-run: found"} {total} corruption site(s) '
          f'across {sum(1 for r in files if True)} analyzed file(s).')


if __name__ == '__main__':
    main()
