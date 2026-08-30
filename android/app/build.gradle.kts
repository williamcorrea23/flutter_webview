import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signing material has two sources, in this order:
//
//  1. The ENVIRONMENT, which is what CI uses. Environment variables carry
//     arbitrary bytes untouched, so a password containing a backslash, a `$`
//     or a backtick survives. Writing those same values into a .properties
//     file does not: the shell would re-scan them on the way in, and
//     java.util.Properties.load treats `\` as an escape on the way out. Both
//     corrupt the password silently, and the only symptom is a build that
//     fails much later with "keystore password was incorrect".
//  2. android/key.properties, which is gitignored and is the local developer
//     path.
//
// Neither present means no release key — see the buildTypes block below.
val envKeystorePath: String? = System.getenv("ANDROID_KEYSTORE_PATH")
val envKeystorePassword: String? = System.getenv("ANDROID_KEYSTORE_PASSWORD")
val envKeyAlias: String? = System.getenv("ANDROID_KEY_ALIAS")
val envKeyPassword: String? = System.getenv("ANDROID_KEY_PASSWORD")
val hasEnvSigning = !envKeystorePath.isNullOrBlank() &&
        !envKeystorePassword.isNullOrBlank() &&
        !envKeyAlias.isNullOrBlank() &&
        !envKeyPassword.isNullOrBlank()

val releaseKeystoreProperties = Properties()
val releaseKeystoreFile = rootProject.file("key.properties")
if (releaseKeystoreFile.exists()) {
    releaseKeystoreFile.inputStream().use { releaseKeystoreProperties.load(it) }
}

android {
    namespace = "co.supabap.android"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "co.supabap.android"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // The debug fallback is not laziness, it is what keeps the build
            // producing a file at all. With NO signingConfig, AGP names the
            // output app-release-UNSIGNED.apk, and flutter_tools then looks for
            // app-release.apk, fails to find it and exits with "Gradle build
            // failed to produce an .apk file". So on any machine or CI runner
            // without android/key.properties — which is gitignored, so that is
            // every fresh clone — `flutter build apk --release` failed outright
            // rather than producing an unsigned build to test with.
            //
            // A debug-signed release APK must never be published. The GitHub
            // Release step in .github/workflows/build-android.yml is gated on
            // the signing secrets actually being present for exactly that
            // reason; without them the workflow still uploads an artifact for
            // internal testing, and publishes nothing.
            signingConfig = when {
                hasEnvSigning -> signingConfigs.create("release") {
                    keyAlias = envKeyAlias
                    keyPassword = envKeyPassword
                    // Absolute in CI, so it is NOT resolved relative to
                    // android/app/ the way the key.properties path below is.
                    storeFile = file(envKeystorePath!!)
                    storePassword = envKeystorePassword
                }
                releaseKeystoreFile.exists() -> signingConfigs.create("release") {
                    keyAlias = releaseKeystoreProperties["keyAlias"] as String
                    keyPassword = releaseKeystoreProperties["keyPassword"] as String
                    // file() here is Project.file on the :app project, so this
                    // path is relative to android/app/ — which is why the
                    // committed local key.properties says ../../android.keystore.
                    storeFile = file(releaseKeystoreProperties["storeFile"] as String)
                    storePassword = releaseKeystoreProperties["storePassword"] as String
                }
                else -> {
                    logger.warn("No release signing material: signing with the DEBUG key. Do not distribute this build.")
                    signingConfigs.getByName("debug")
                }
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
