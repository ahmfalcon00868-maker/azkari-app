"""يطبع إحصاء اختبارات وحدة Android من تقارير JUnit XML، ويفشل إن لم يوجد تقرير.

    python3 tool/android_test_stats.py android/app/build/test-results/testDebugUnitTest
"""
from __future__ import annotations

import glob
import os
import sys
import xml.etree.ElementTree as ET


def main(argv: list[str]) -> int:
    results_dir = argv[1] if len(argv) > 1 else "android/app/build/test-results/testDebugUnitTest"
    files = sorted(glob.glob(os.path.join(results_dir, "*.xml")))
    if not files:
        print(f"::error:: لم تُنتج اختبارات Kotlin أي تقرير في {results_dir}")
        return 1

    total = failures = skipped = 0
    for path in files:
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError as exc:
            print(f"::error:: تقرير تالف {path}: {exc}")
            return 1
        total += int(root.get("tests", 0) or 0)
        failures += int(root.get("failures", 0) or 0) + int(root.get("errors", 0) or 0)
        skipped += int(root.get("skipped", 0) or 0)

    print(f"android unit tests: {total} run, {failures} failed, {skipped} skipped")
    if total == 0:
        print("::error:: لم تُشغَّل أي اختبارات Kotlin (مجلد فارغ)")
        return 1
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
