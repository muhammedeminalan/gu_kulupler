import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release imzası (Google Play yükleme anahtarı): `android/key.properties` (git dışı) anahtar deposunu
// gösterir; anahtar deposunun kendisi REPO DIŞINDADIR (ör. ~/.secrets/). Dosya yoksa release derlemesi
// debug anahtarıyla imzalanır (yerel `flutter run --release`); Play bu derlemeyi kabul etmez.
//   storePassword=…  keyPassword=…  keyAlias=upload  storeFile=/Users/<sen>/.secrets/gu-kulupler-upload.jks
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) load(FileInputStream(keystorePropertiesFile))
}
val hasReleaseKey = keystorePropertiesFile.exists()

android {
    namespace = "com.gukulupler.gu_kulupler"
    // permission_handler_android 14.x en az 37 ister (AAR metadata); targetSdk değişmez.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // T-23 (PLAN §5.6.2): flutter_local_notifications 10+ çekirdek kitaplık
        // desugaring'i ister (zamanlanmış bildirimler).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.gukulupler.gu_kulupler"
        // Sürüm adı / kodu pubspec.yaml `version: x.y.z+N`'den gelir.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseKey) {
                    signingConfigs.getByName("release")
                } else {
                    logger.warn("key.properties yok: release derlemesi DEBUG anahtarıyla imzalanıyor (Play kabul etmez).")
                    signingConfigs.getByName("debug")
                }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // T-23: flutter_local_notifications 22.3.x README sürümü.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
