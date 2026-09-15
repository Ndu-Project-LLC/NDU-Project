#!/usr/bin/env python3
"""Remove `borderRadius:` from BoxDecoration blocks that also pass a
non-uniform `Border(...)` (single/partial-side borders).

Flutter's Border.paint asserts that a borderRadius can only be used with a
uniform border. In debug/DDC builds the assert throws and ABORTS painting of
the subtree (missing content). In release builds the assert is skipped and the
corners are simply square. Removing the borderRadius therefore reproduces the
release rendering exactly while eliminating the whole exception class.

Usage: python3 scripts/fix_border_radius_nonuniform.py [--dry]
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCAN_DIRS = [os.path.join(ROOT, 'lib'), os.path.join(ROOT, 'test')]

# Border( == positional, non-uniform by construction unless fromBorderSide.
NONUNIFORM = re.compile(r'border:\s*(?:const\s+)?Border\s*\(')
UNIFORM_OK = re.compile(r'Border\s*\.\s*(?:all|fromBorderSide)\s*\(')


def find_block_end(src, open_paren_idx):
    """Given index of '(' return index of its matching ')'."""
    depth = 0
    for i in range(open_paren_idx, len(src)):
        c = src[i]
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return i
    return -1


def remove_border_radius(src, block_start, block_open, block_close):
    """Remove the `borderRadius:` argument from one BoxDecoration block.

    Returns (new_src, removed_desc) or (src, None).
    """
    block = src[block_start:block_close + 1]
    m = re.search(r'borderRadius\s*:', block)
    if not m:
        return src, None
    # Start of the argument (include preceding whitespace/indent).
    arg_start = block.rfind('\n', 0, m.start())
    if arg_start == -1:
        arg_start = m.start()
    else:
        arg_start += 1  # keep the newline itself
    # Walk forward from after the colon to find the value end: the comma at
    # paren/brace/brace depth 0 relative to the value expression.
    i = block.index(':', m.start()) + 1
    depth = 0
    val_end = -1
    while i < len(block):
        c = block[i]
        if c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
        elif c == ',' and depth == 0:
            val_end = i
            break
        elif c == '/' and i + 1 < len(block) and block[i + 1] == '/':
            # comment line — skip to end of line
            j = block.find('\n', i)
            i = j if j != -1 else len(block)
            continue
        elif c == '/' and i + 1 < len(block) and block[i + 1] == '*':
            j = block.find('*/', i)
            i = j + 2 if j != -1 else len(block)
            continue
        i += 1
    if val_end == -1:
        return src, None
    arg_end = val_end + 1  # consume trailing comma
    removed = ' '.join(block[arg_start:arg_end].split())
    new_block = block[:arg_start] + block[arg_end:]
    # Collapse a leading blank line left behind (keep indentation of next arg).
    new_block = re.sub(r'\n[ \t]*\n([ \t]*(?:color|border|gradient|boxShadow|\}))',
                       r'\n\1', new_block, count=1)
    return src[:block_start] + new_block + src[block_close + 1:], removed


def iter_blocks(src, needle='BoxDecoration('):
    """Yield (start, open_idx, close_idx) for every BoxDecoration( call."""
    idx = 0
    while True:
        start = src.find(needle, idx)
        if start == -1:
            return
        open_idx = start + len(needle) - 1
        close_idx = find_block_end(src, open_idx)
        if close_idx == -1:
            idx = start + 1
            continue
        yield start, open_idx, close_idx
        idx = close_idx + 1


def process(path, dry=False):
    src = open(path).read()
    if 'BoxDecoration(' not in src:
        return []
    changes = []
    # Iterate repeatedly: block indices shift after each removal.
    while True:
        applied = False
        for start, open_idx, close_idx in iter_blocks(src):
            block = src[start:close_idx + 1]
            has_radius = 'borderRadius' in block
            if not has_radius:
                continue
            if not NONUNIFORM.search(block):
                continue
            if UNIFORM_OK.search(block):
                # border is Border.all / fromBorderSide (uniform) — safe, but
                # if block ALSO contains a positional Border( keep the rule:
                # only skip when there is NO positional Border(.
                pos = [m for m in NONUNIFORM.finditer(block)]
                # UNIFORM_OK match position vs positional match — if all
                # `Border(` occurrences belong to Border.all they would not
                # match NONUNIFORM at all, so reaching here means a real mix.
                if not pos:
                    continue
            new_src, removed = remove_border_radius(src, start, open_idx, close_idx)
            if removed is None:
                continue
            line = src[:start].count('\n') + 1
            changes.append((line, removed))
            src = new_src
            applied = True
            break
        if not applied:
            break
    if changes and not dry:
        open(path, 'w').write(src)
    return changes


def main():
    dry = '--dry' in sys.argv
    total = 0
    for scan_dir in SCAN_DIRS:
        if not os.path.isdir(scan_dir):
            continue
        for dirpath, _, filenames in os.walk(scan_dir):
            for fn in sorted(filenames):
                if not fn.endswith('.dart'):
                    continue
                p = os.path.join(dirpath, fn)
                ch = process(p, dry)
                for line, removed in ch:
                    print(f"{p}:{line}  removed {removed}")
                total += len(ch)
    print(f"\n{'[DRY] ' if dry else ''}total removals: {total}")


if __name__ == '__main__':
    main()
