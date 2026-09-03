plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("ru.cian.rustore-publish-gradle-plugin") version "0.5.6"
}

import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import ru.cian.rustore.publish.AppTypes
import ru.cian.rustore.publish.BuildFormat
import ru.cian.rustore.publish.DeveloperContacts
import ru.cian.rustore.publish.MobileServicesType
import ru.cian.rustore.publish.PublishType
import ru.cian.rustore.publish.ReleaseNote

@Suppress("DEPRECATION")
android {
    namespace = "ru.sandr.cideroff_app"
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
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

    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("KEYSTORE_FILE_PATH") ?: "keystore.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

// Конфигурация плагина ru.cian.rustore-publish-gradle-plugin
rustorePublish {
    instances {
        create("release") {
            // Динамическое создание временного файла credentials из переменных окружения
            val keyIdEnv = System.getenv("RUSTORE_CLIENT_ID") ?: ""
            val privateKeyEnv = System.getenv("RUSTORE_PRIVATE_KEY") ?: ""
            
            val credFile = layout.buildDirectory.file("tmp/rustore-credentials-release.json").get().asFile
            if (keyIdEnv.isNotEmpty() && privateKeyEnv.isNotEmpty()) {
                credFile.parentFile.mkdirs()
                credFile.writeText("""
                    {
                        "key_id": "$keyIdEnv",
                        "client_secret": "$privateKeyEnv"
                    }
                """.trimIndent())
                credentialsPath = credFile.absolutePath
            } else {
                credentialsPath = "$rootDir/rustore-credentials-release.json"
            }

            // Динамическое создание файла с заметками к релизу
            val releaseNotesFile = layout.buildDirectory.file("tmp/release-notes-ru.txt").get().asFile
            releaseNotesFile.parentFile.mkdirs()
            releaseNotesFile.writeText("Автоматическая сборка приложения CiderOff.")

            buildFormat = BuildFormat.APK
            buildFile = layout.buildDirectory.file("outputs/apk/release/CiderOff-v1.0.4.apk").get().asFile.absolutePath
            requestTimeout = 300
            mobileServicesType = MobileServicesType.UNKNOWN
            publishType = PublishType.INSTANTLY
            minAndroidVersion = "24"

            developerContacts = DeveloperContacts(
                email = "support@dvaplus.ru",
                website = "https://dvaplus.ru",
                vkCommunity = null
            )

            appType = AppTypes.MAIN

            releaseNotes = listOf(
                ReleaseNote(
                    lang = "ru-RU",
                    filePath = releaseNotesFile.absolutePath
                )
            )
        }
    }
}