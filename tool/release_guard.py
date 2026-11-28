"""حرس التجميد: يمنع أي مسار يصل منه تحديث للمستخدمين بدون موافقة صريحة.

يُشغَّل من `.github/workflows/release_guard.yml` على main/PR، ويمكن تشغيله محلياً:

    python3 tool/release_guard.py
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APPROVAL_FILE = ROOT / "docs" / "release_approval.md"
PUBLISH_TOKENS = (
    "gh release create",
    "action-gh-release",
    "softprops/action-gh-release",
)


def read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def is_approved() -> bool:
    return APPROVAL_FILE.exists() and "approved: true" in read(APPROVAL_FILE)


def check_updates_flag(approved: bool) -> list[str]:
    problems: list[str] = []
    src = read(ROOT / "lib" / "services" / "update_service.dart")
    flag_on = re.search(r"kUpdatesEnabled\s*=\s*true", src) is not None
    if flag_on and not approved:
        problems.append("kUpdatesEnabled=true بدون docs/release_approval.md")
    if "AZKARI_ALLOW_UPDATES" not in src:
        problems.append("حماية البناء (AZKARI_ALLOW_UPDATES) مفقودة من update_service.dart")
    return problems


def check_workflows(approved: bool) -> list[str]:
    problems: list[str] = []
    for wf in sorted((ROOT / ".github" / "workflows").glob("*.yml")):
        # ملف الحرس نفسه يذكر أسماء أوامر النشر للفحص فقط — لا يُفحص.
        if wf.name == "release_guard.yml":
            continue
        text = read(wf)
        for token in PUBLISH_TOKENS:
            if token in text and not approved:
                problems.append(f"{wf.name}: يحتوي \"{token}\" (نشر إصدار) بدون موافقة")
        if "AZKARI_ALLOW_UPDATES=true" in text and not approved:
            problems.append(f"{wf.name}: يبني مع تفعيل التحديثات بدون موافقة")
    return problems


def check_version_json(approved: bool) -> list[str]:
    problems: list[str] = []
    version = re.search(
        r"^version:\s*(\S+)", read(ROOT / "pubspec.yaml"), re.M
    ).group(1)
    local_build = int(version.split("+")[1]) if "+" in version else 0
    remote_build = int(
        json.loads(read(ROOT / "version.json")).get("build_number", 0)
    )
    if remote_build > local_build and not approved:
        problems.append(
            f"version.json يعلن build {remote_build} أعلى من التطبيق ({local_build}) بدون موافقة"
        )
    return problems


def main() -> int:
    approved = is_approved()
    problems = (
        check_updates_flag(approved)
        + check_workflows(approved)
        + check_version_json(approved)
    )
    if problems:
        for problem in problems:
            print(f"::error::{problem}")
        return 1
    print("Freeze guard OK: لا تحديثات ولا نشر بدون موافقة صريحة.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
