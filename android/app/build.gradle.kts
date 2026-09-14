plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("ru.cian.rustore-publish-gradle-plugin") version "0.5.6"
}

import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import java.util.Properties
import java.io.FileInputStream
import ru.cian.rustore.publish.AppTypes
import ru.cian.rustore.publish.BuildFormat
import ru.cian.rustore.publish.DeveloperContacts
import ru.cian.rustore.publish.MobileServicesType
import ru.cian.rustore.publish.PublishType
import ru.cian.rustore.publish.ReleaseNote

// --- 1. Объявляем и загружаем keystoreProperties DO блока android ---
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

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
            val keyPath = keystoreProperties.getProperty("storeFilePath") 
                ?: System.getenv("KEYSTORE_FILE_PATH") 
                ?: "keystore.jks"
            storeFile = file(keyPath)

            storePassword = keystoreProperties.getProperty("storePassword") 
                ?: System.getenv("KEYSTORE_PASSWORD")

            keyAlias = keystoreProperties.getProperty("keyAlias") 
                ?: System.getenv("KEY_ALIAS")

            keyPassword = keystoreProperties.getProperty("keyPassword") 
                ?: System.getenv("KEY_PASSWORD")
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
                val vName = variant.versionName
                output.outputFileName = "$appName-v$vName.apk"
            }
        }
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

            val releaseNotesFile = layout.buildDirectory.file("tmp/release-notes-ru.txt").get().asFile
            releaseNotesFile.parentFile.mkdirs()
            releaseNotesFile.writeText("Автоматическая сборка приложения CiderOff.")

            buildFormat = BuildFormat.APK
            
            // Динамически берем версию из flutter.versionName
            val currentVersionName = flutter.versionName
            buildFile = layout.buildDirectory.file("outputs/apk/release/CiderOff-v$currentVersionName.apk").get().asFile.absolutePath

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