"""يحوّل تقرير `flutter test --reporter json` إلى إحصاءات صغيرة.

يُستخدم في خط البناء وفي التشغيل المحلي:

    flutter test --reporter json > test_report.json
    python3 tool/test_stats.py test_report.json

يطبع: count/passed/failed ويفشل (exit 1) إذا وُجد أي اختبار فاشل.
"""
from __future__ import annotations

import json
import sys


def collect(path: str) -> dict[str, int]:
    passed = 0
    failed = 0
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line.startswith("{"):
                continue
            try:
                event = json.loads(line)
            except Exception:
                continue
            if event.get("type") != "testDone" or event.get("hidden"):
                continue
            if event.get("result") == "success":
                passed += 1
            else:
                failed += 1
    return {"count": passed + failed, "passed": passed, "failed": failed}


def main(argv: list[str]) -> int:
    path = argv[1] if len(argv) > 1 else "test_report.json"
    stats = collect(path)
    print(f"tests: {stats['count']} total, {stats['passed']} passed, {stats['failed']} failed")
    for key in ("count", "passed", "failed"):
        print(f"{key}={stats[key]}")
    return 0 if stats["failed"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
