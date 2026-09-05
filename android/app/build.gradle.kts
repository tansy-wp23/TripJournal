import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesFile = rootProject.file("../.local/android-signing.properties")
val signingProperties = Properties().apply {
    if (signingPropertiesFile.exists()) {
        signingPropertiesFile.inputStream().use(::load)
    }
}
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

fun requiredSigningProperty(name: String): String {
    return signingProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: error("Missing $name in ${signingPropertiesFile.absolutePath}")
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
        applicationId = "com.tripjournal.tripjournal"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // The `health` plugin requires minSdk 26 (Flutter's default is 24).
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs.create("release") {
        if (releaseTaskRequested) {
            check(signingPropertiesFile.exists()) {
                "Release signing configuration is missing: ${signingPropertiesFile.absolutePath}"
            }
            storeFile = file(requiredSigningProperty("storeFile"))
            storePassword = requiredSigningProperty("storePassword")
            keyAlias = requiredSigningProperty("keyAlias")
            keyPassword = requiredSigningProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
