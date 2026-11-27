"""يطبع أهم أسطر فشل Gradle كتعليقات تشخيصية (annotations) قابلة للقراءة.

    python3 tool/gradle_failure_summary.py /tmp/gradle.log
"""
from __future__ import annotations

import sys

PATTERNS = (
    "* What went wrong",
    "FAILURE:",
    "Execution failed",
    "> Task",
    "e: ",
    "error:",
    "Caused by",
    "Cannot locate",
    "minSdkVersion",
    "tests completed",
    "tests failed",
)


def clean(line: str) -> str:
    return line.replace("::", ":").replace("\t", " ").strip()[:350]


def main(argv: list[str]) -> int:
    path = argv[1] if len(argv) > 1 else "/tmp/gradle.log"
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            lines = fh.readlines()
    except OSError as exc:
        print(f"::error::cannot read gradle log: {exc}")
        return 1

    picked: list[str] = []
    for line in lines:
        if any(p in line for p in PATTERNS):
            text = clean(line)
            if text and text not in picked:
                picked.append(text)
    if not picked:
        picked = [clean(l) for l in lines[-5:] if l.strip()]

    for text in picked[:6]:
        print(f"::error::{text}")
    print(f"gradle log lines: {len(lines)}; matched: {len(picked)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
