plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import com.android.build.gradle.internal.api.ApkVariantOutputImpl

android {
    namespace = "ru.sandr.cideroff_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Включаем desugaring для поддержки новых возможностей Java на старых устройствах
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ru.sandr.cideroff_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    
    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val output = this as? ApkVariantOutputImpl
            if (output != null) {
                val appName = "CiderOff"
                val versionName = variant.versionName
                output.outputFileName = "$appName-v$versionName.apk"
            }
        }
    }    
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Версия 2.1.5 перекрывает минимально требуемую 2.1.4 для flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}