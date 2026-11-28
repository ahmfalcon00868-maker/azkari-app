#!/usr/bin/env python3
"""تحليل صورة شاشة خام من `adb exec-out screencap`.

يطبع: الأبعاد + نسبة البكسلات شبه البيضاء + عدد الألوان التقريبية.
الغرض: التمييز موضوعيًا بين «شاشة بيضاء» وواجهة مرسومة فعلًا.

صيغة screencap الخام: 4 أعداد int32 (width, height, format, colorspace) ثم RGBA.
"""
from __future__ import annotations

import struct
import sys

WHITE_THRESHOLD = 235
MAX_SAMPLES = 40000
COLOR_SAMPLES = 4000


def analyse(path: str) -> str:
    with open(path, "rb") as handle:
        data = handle.read()
    if len(data) < 16:
        return "empty"
    width, height, _fmt, _space = struct.unpack("<iiii", data[:16])
    pixels = data[16:]
    total_pixels = width * height
    if total_pixels <= 0 or len(pixels) < total_pixels * 4:
        return f"bad-size({width}x{height},bytes={len(pixels)})"

    step = max(1, total_pixels // MAX_SAMPLES)
    white = 0
    counted = 0
    colors: set[tuple[int, int, int]] = set()
    for index in range(0, total_pixels, step):
        offset = index * 4
        red, green, blue = pixels[offset], pixels[offset + 1], pixels[offset + 2]
        if red > WHITE_THRESHOLD and green > WHITE_THRESHOLD and blue > WHITE_THRESHOLD:
            white += 1
        if counted < COLOR_SAMPLES:
            colors.add((red >> 4, green >> 4, blue >> 4))
        counted += 1
    percent = 100 * white // max(1, counted)
    return f"{width}x{height} white={percent}% colors={len(colors)}"


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__)
        return 2
    print(analyse(argv[1]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
