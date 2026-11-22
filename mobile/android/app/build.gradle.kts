import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Yayın imzası: android/key.properties (git'e girmez) yükleme anahtarını gösterir (docs/harita/yayin.md).
// Dosya yoksa release derlemesi debug anahtarıyla imzalanır: cihazda denenebilir, mağazaya yüklenemez.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.kampusbet.kampusbet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Uygulama kimliği mağazaya ilk yüklemeden sonra değiştirilemez (KARARLAR öneri 6-7: ad / kimlik kararı).
        applicationId = "com.kampusbet.kampusbet"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Sürüm pubspec.yaml'daki `version: x.y.z+n`'den gelir (n = versionCode, her yüklemede artmalı).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
            // R8 ek kuralları (eklentilerin JNI ile çağrılan sınıfları); release APK emülatörde denenmeli.
            proguardFiles("proguard-rules.pro")
        }
    }
}

if (!hasReleaseKey) {
    logger.warn("KampüsBet: android/key.properties yok; release derlemesi debug anahtarıyla imzalanıyor (mağazaya yüklenemez).")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
