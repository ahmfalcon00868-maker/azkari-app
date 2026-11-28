#!/usr/bin/env python3
"""يضيف/يزيل إعداد اختبارات Robolectric إلى وحدة Android في قالب Flutter.

السبب: قالب Flutter يولّد `android/app/build.gradle.kts` جديدًا في كل تشغيل، ولا
نريد تعديله في المستودع. لذلك نُعدّله وقت الاختبار فقط، ثم نُعيده كما كان قبل
بناء الـ APK (minSdk يعود 23 كما في الإصدار المُسلَّم).

الاستخدام:
    python3 tool/patch_android_gradle.py add android/app/build.gradle.kts
    python3 tool/patch_android_gradle.py restore android/app/build.gradle.kts
"""
from __future__ import annotations

import shutil
import sys

BACKUP_SUFFIX = ".robolectric-backup"

# نُجهّز حزمتَي SDK: 34 (المستخدمة في @Config) و35 (targetSdk الافتراضي للقالب)،
# حتى لا يعتمد الاختبار على أيّهما يختار Robolectric.
ANDROID_ALL = (
    "14-robolectric-10818077-i7",
    "15-robolectric-12650502-i7",
)

KTS_BLOCK = f'''

// ---- اختبارات تخزين Android الحقيقية (Robolectric) — يُضاف وقت CI فقط ----
val androidAllDeps by configurations.creating

android {{
    testOptions {{ unitTests.isIncludeAndroidResources = true }}
}}

dependencies {{
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.14.1")
    testImplementation("androidx.test:core:1.6.1")
    androidAllDeps("org.robolectric:android-all-instrumented:{ANDROID_ALL[0]}")
    androidAllDeps("org.robolectric:android-all-instrumented:{ANDROID_ALL[1]}")
}}

// نُنزّل حزمة android-all عبر Gradle (لديه إعادة محاولة) ثم نشغّل Robolectric في
// وضع offline، لأن جالب Robolectric الداخلي يفشل أحيانًا على الشبكة.
val robolectricDepsDir = layout.buildDirectory.dir("robolectric-deps")
val copyAndroidAll = tasks.register<Copy>("copyAndroidAll") {{
    // نُبقي أسماء الحزم كما هي: <artifactId>-<version>.jar هو ما يبحث عنه Robolectric.
    from(androidAllDeps)
    into(robolectricDepsDir)
}}

tasks.withType<Test>().configureEach {{
    dependsOn(copyAndroidAll)
    systemProperty("robolectric.offline", "true")
    systemProperty("robolectric.dependency.dir", robolectricDepsDir.get().asFile.absolutePath)
}}
// ---- نهاية إعداد Robolectric ----
'''

GROOVY_BLOCK = f'''

// ---- اختبارات تخزين Android الحقيقية (Robolectric) — يُضاف وقت CI فقط ----
android {{
    testOptions {{ unitTests.includeAndroidResources = true }}
}}

dependencies {{
    testImplementation "junit:junit:4.13.2"
    testImplementation "org.robolectric:robolectric:4.14.1"
    testImplementation "androidx.test:core:1.6.1"
    androidAllDeps "org.robolectric:android-all-instrumented:{ANDROID_ALL}"
}}

configurations {{ androidAllDeps }}

tasks.withType(Test).configureEach {{
    systemProperty "robolectric.offline", "true"
}}
'''


def add(path: str) -> int:
    shutil.copyfile(path, path + BACKUP_SUFFIX)
    block = KTS_BLOCK if path.endswith(".kts") else GROOVY_BLOCK
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(block)
    print(f"patched {path}")
    return 0


def restore(path: str) -> int:
    try:
        shutil.copyfile(path + BACKUP_SUFFIX, path)
    except FileNotFoundError:
        print(f"no backup for {path}; nothing to restore")
        return 1
    print(f"restored {path}")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[1] not in {"add", "restore"}:
        print(__doc__)
        return 2
    action, path = argv[1], argv[2]
    return add(path) if action == "add" else restore(path)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
