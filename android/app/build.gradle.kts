import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun dartDefine(name: String): String? {
    val encodedDefines = providers.gradleProperty("dart-defines").orNull
        ?: return null
    return encodedDefines
        .split(',')
        .mapNotNull { encoded ->
            runCatching {
                Base64.getDecoder().decode(encoded).toString(Charsets.UTF_8)
            }.getOrNull()
        }
        .firstNotNullOfOrNull { definition ->
            val separator = definition.indexOf('=')
            if (separator > 0 && definition.substring(0, separator) == name) {
                definition.substring(separator + 1)
            } else {
                null
            }
        }
}

android {
    namespace = "com.tripjournal.tripjournal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tripjournal.tripjournal"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // The `health` plugin requires minSdk 26 (Flutter's default is 24).
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // `--dart-define[-from-file]` is the single source used by both Dart's
        // fallback selector and the native Maps SDK manifest placeholder.
        manifestPlaceholders["GOOGLE_MAPS_ANDROID_KEY"] =
            dartDefine("GOOGLE_MAPS_ANDROID_KEY").orEmpty()
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Required by flutter_local_notifications (journal reminders) — the AAR
    // metadata check fails the build without this.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
