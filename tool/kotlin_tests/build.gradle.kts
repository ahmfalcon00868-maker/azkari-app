// مشروع Gradle مستقل لاختبار منطق الويدجت الأصلي (Kotlin/JVM) بلا Android SDK.
//
// يترجم *نفس* الملف الذي يُشحن في الـ APK:
//   android_custom/app/src/main/kotlin/com/flc/azkari/TasbihPressLog.kt
// مع ملف الاختبار:
//   android_custom/app/src/test/kotlin/com/flc/azkari/TasbihPressLogTest.kt
//
// التشغيل:  cd android && ./gradlew -p ../tool/kotlin_tests test
plugins {
    kotlin("jvm") version "2.2.20"
}

repositories {
    mavenCentral()
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}

kotlin {
    jvmToolchain(17)
}

sourceSets {
    main {
        kotlin.setSrcDirs(listOf("../../android_custom/app/src/main/kotlin"))
        kotlin.include("com/flc/azkari/TasbihPressLog.kt")
    }
    test {
        kotlin.setSrcDirs(listOf("../../android_custom/app/src/test/kotlin"))
        kotlin.include("com/flc/azkari/TasbihPressLogTest.kt")
    }
}

tasks.test {
    useJUnit()
    testLogging {
        events("passed", "failed", "skipped")
        showStandardStreams = false
    }
}
