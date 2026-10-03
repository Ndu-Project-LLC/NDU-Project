#!/usr/bin/env python3
"""
Create a dark mode variant of the NDU PROJECT logo.
Uses only Python stdlib (struct + zlib) to manipulate PNG pixels.

Dark mode logic:
- The original has a black/very-dark background with dark gray "NDU" + gold "PROJECT" + gray tagline.
- For dark mode, we invert the brightness of non-gold pixels so the dark
  "NDU" becomes light and the background becomes transparent/dark-friendly.
- Gold (#FFC000 range) pixels are preserved.
"""

import struct
import zlib
import sys


def read_png(path):
    """Read a PNG file and return (width, height, rows, color_type).
    Each row is a list of ints (filter_byte + pixel bytes).
    """
    with open(path, 'rb') as f:
        data = f.read()

    sig = data[:8]
    assert sig == b'\x89PNG\r\n\x1a\n', f'Not a PNG file: {sig}'

    pos = 8
    ihdr_data = None
    idat_parts = []

    while pos < len(data):
        if pos + 8 > len(data):
            break
        length = struct.unpack('>I', data[pos:pos+4])[0]
        chunk_type = data[pos+4:pos+8]
        chunk_data = data[pos+8:pos+8+length]
        pos += 12 + length  # 4(length) + 4(type) + length + 4(crc)

        if chunk_type == b'IHDR':
            ihdr_data = chunk_data
        elif chunk_type == b'IDAT':
            idat_parts.append(chunk_data)
        elif chunk_type == b'IEND':
            break

    if ihdr_data is None:
        raise ValueError('No IHDR chunk found')

    w, h = struct.unpack('>II', ihdr_data[:8])
    bit_depth = ihdr_data[8]
    color_type = ihdr_data[9]

    # Determine bytes per pixel
    if color_type == 6:  # RGBA
        bpp = 4
    elif color_type == 2:  # RGB
        bpp = 3
    elif color_type == 0:  # Grayscale
        bpp = 1
    elif color_type == 4:  # Grayscale + Alpha
        bpp = 2
    else:
        raise ValueError(f'Unsupported color type: {color_type}')

    # Decompress all IDAT data
    raw = zlib.decompress(b''.join(idat_parts))

    # Parse rows with filter reconstruction
    stride = w * bpp
    rows = []
    prev_row = [0] * stride
    idx = 0

    for y in range(h):
        filter_type = raw[idx]
        idx += 1
        scanline = list(raw[idx:idx + stride])
        idx += stride

        # Reconstruct
        if filter_type == 0:  # None
            pass
        elif filter_type == 1:  # Sub
            for i in range(bpp, stride):
                scanline[i] = (scanline[i] + scanline[i - bpp]) & 0xFF
        elif filter_type == 2:  # Up
            for i in range(stride):
                scanline[i] = (scanline[i] + prev_row[i]) & 0xFF
        elif filter_type == 3:  # Average
            for i in range(stride):
                a = scanline[i - bpp] if i >= bpp else 0
                b_val = prev_row[i]
                scanline[i] = (scanline[i] + (a + b_val) // 2) & 0xFF
        elif filter_type == 4:  # Paeth
            for i in range(stride):
                a = scanline[i - bpp] if i >= bpp else 0
                b_val = prev_row[i]
                c = prev_row[i - bpp] if i >= bpp else 0
                p = a + b_val - c
                pa, pb, pc = abs(p - a), abs(p - b_val), abs(p - c)
                if pa <= pb and pa <= pc:
                    pr = a
                elif pb <= pc:
                    pr = b_val
                else:
                    pr = c
                scanline[i] = (scanline[i] + pr) & 0xFF

        rows.append(scanline)
        prev_row = scanline

    return w, h, rows, color_type


def write_png(path, w, h, rows, color_type=6):
    """Write a PNG file from rows of pixel data (filter type 0)."""
    def make_chunk(ctype, data):
        chunk = ctype + data
        return struct.pack('>I', len(data)) + chunk + struct.pack('>I', zlib.crc32(chunk) & 0xFFFFFFFF)

    sig = b'\x89PNG\r\n\x1a\n'
    ihdr_data = struct.pack('>IIBBBBB', w, h, 8, color_type, 0, 0, 0)
    ihdr = make_chunk(b'IHDR', ihdr_data)

    raw_data = b''
    for row in rows:
        raw_data += b'\x00' + bytes(row)

    compressed = zlib.compress(raw_data, 9)
    idat = make_chunk(b'IDAT', compressed)
    iend = make_chunk(b'IEND', b'')

    with open(path, 'wb') as f:
        f.write(sig + ihdr + idat + iend)


def is_gold(r, g, b):
    """Check if a pixel is in the gold/yellow range."""
    return r > 180 and g > 130 and g < 230 and b < 100


def create_dark_variant(w, h, rows, color_type):
    """Create dark mode variant:
    - Very dark (near-black) background → transparent
    - Dark gray text (NDU) → light gray/white
    - Gold pixels → keep as-is
    - Other dark pixels → lighten
    """
    bpp = 4 if color_type == 6 else 3
    new_rows = []

    for y in range(h):
        new_row = bytearray()
        for x in range(w):
            idx = x * bpp
            r = rows[y][idx]
            g = rows[y][idx + 1]
            b = rows[y][idx + 2]
            a = rows[y][idx + 3] if bpp == 4 else 255

            brightness = (r * 0.299 + g * 0.587 + b * 0.114)

            if brightness < 25 and a > 200:
                # Very dark background → transparent
                new_row.extend([0, 0, 0, 0])
            elif is_gold(r, g, b):
                # Keep gold, maybe boost slightly
                new_row.extend([min(255, r + 8), min(255, g + 8), b, a])
            elif brightness < 120:
                # Dark gray text → lighten to near-white
                factor = 4.0
                nr = min(255, int(r * factor + 50))
                ng = min(255, int(g * factor + 50))
                nb = min(255, int(b * factor + 50))
                new_row.extend([nr, ng, nb, a])
            else:
                # Light pixels (tagline etc.) → keep but ensure visible
                new_row.extend([r, g, b, a])

        new_rows.append(list(new_row))

    return new_rows


if __name__ == '__main__':
    src = sys.argv[1] if len(sys.argv) > 1 else 'lib/screens/image.png'
    dst = sys.argv[2] if len(sys.argv) > 2 else 'assets/images/Ndu_logodarkmode.png'

    print(f"Reading {src}...")
    w, h, rows, ct = read_png(src)
    print(f"  Image: {w}x{h}, color_type={ct}")

    print("Creating dark mode variant (transparent background, light NDU text, gold PROJECT)...")
    new_rows = create_dark_variant(w, h, rows, ct)

    print(f"Writing {dst}...")
    write_png(dst, w, h, new_rows, color_type=6)
    print("Done!")
