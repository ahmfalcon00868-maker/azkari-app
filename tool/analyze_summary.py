"""يلخّص مخرجات `flutter analyze` ويفصل الأخطاء عن التحذيرات والملاحظات.

    flutter analyze > analyze.log 2>&1 || true
    python3 tool/analyze_summary.py analyze.log

يطبع العدد لكل فئة، ويعيد 1 فقط عند وجود أخطاء (warnings/infos لا تُسقط البناء).
"""
from __future__ import annotations

import re
import sys

LINE = re.compile(r"^\s*(error|warning|info)\s+•")


def summarize(path: str) -> dict[str, int]:
    counts = {"error": 0, "warning": 0, "info": 0}
    errors: list[str] = []
    first: dict[str, list[str]] = {"error": [], "warning": [], "info": []}
    with open(path, encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            match = LINE.match(raw)
            if not match:
                continue
            kind = match.group(1)
            counts[kind] += 1
            if len(first[kind]) < 10:
                first[kind].append(raw.strip())
            if kind == "error":
                errors.append(raw.strip())
    for kind in ("error", "warning", "info"):
        for line in first[kind]:
            prefix = "::error::" if kind == "error" else "::notice::"
            print(f"{prefix}analyze {kind}: {line[:220]}")
    if errors:
        with open("analyze_errors.txt", "w", encoding="utf-8") as out:
            out.write("\n".join(errors))
    with open("analyze_counts.txt", "w", encoding="utf-8") as out:
        out.write(
            f"errors={counts['error']}-warnings={counts['warning']}-infos={counts['info']}"
        )
    return counts


def main(argv: list[str]) -> int:
    path = argv[1] if len(argv) > 1 else "analyze.log"
    counts = summarize(path)
    total = sum(counts.values())
    print(
        "analyze summary: "
        f"{counts['error']} error(s), {counts['warning']} warning(s), "
        f"{counts['info']} info(s) — total {total}"
    )
    print(f"errors={counts['error']}")
    print(f"warnings={counts['warning']}")
    print(f"infos={counts['info']}")
    return 1 if counts["error"] > 0 else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
