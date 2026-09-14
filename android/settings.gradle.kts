pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Укажите версию AGP 8.7.0 вместо 9.x:
    id("com.android.application") version "9.0.1" apply false
    // Указываем версию Kotlin для Gradle/Flutter, но НЕ применяем к проекту (apply false)
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
