import java.security.KeyStore
import java.security.MessageDigest
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
// Release builds require the registered Play upload key. Debug builds do not.
val envKeystorePath: String? = System.getenv("ANDROID_KEYSTORE_PATH")
val envKeystorePassword: String? = System.getenv("ANDROID_KEYSTORE_PASSWORD")
val envKeyAlias: String? = System.getenv("ANDROID_KEY_ALIAS")
val envKeyPassword: String? = System.getenv("ANDROID_KEY_PASSWORD")
val hasEnvSigning = !envKeystorePath.isNullOrBlank() &&
        !envKeystorePassword.isNullOrBlank() &&
        !envKeyAlias.isNullOrBlank() &&
        !envKeyPassword.isNullOrBlank()
val hasAnyEnvSigning = listOf(envKeystorePath, envKeystorePassword, envKeyAlias, envKeyPassword)
    .any { !it.isNullOrBlank() }

val releaseKeystoreProperties = Properties()
val releaseKeystoreFile = rootProject.file("key.properties")
if (releaseKeystoreFile.exists()) {
    releaseKeystoreFile.inputStream().use { releaseKeystoreProperties.load(it) }
}

val playReleaseProperties = Properties().apply {
    rootProject.file("play-release.properties").inputStream().use { load(it) }
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
        // Must remain identical to the existing Master ABAP Play listing.
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
            // No debug-key fallback: verifyPlayRelease rejects missing or
            // incompatible signing material before a release can be packaged.
            signingConfig = when {
                hasEnvSigning -> signingConfigs.create("release") {
                    keyAlias = envKeyAlias
                    keyPassword = envKeyPassword
                    // Absolute in CI, so it is NOT resolved relative to
                    // android/app/ the way the key.properties path below is.
                    storeFile = file(envKeystorePath!!)
                    storePassword = envKeystorePassword
                }
                !hasAnyEnvSigning && releaseKeystoreFile.exists() -> signingConfigs.create("release") {
                    keyAlias = releaseKeystoreProperties.getProperty("keyAlias")
                    keyPassword = releaseKeystoreProperties.getProperty("keyPassword")
                    // file() here is Project.file on the :app project, so this
                    // path is relative to android/app/ — which is why the
                    // local key.properties can use ../../upload-keystore.jks.
                    storeFile = releaseKeystoreProperties.getProperty("storeFile")?.let { file(it) }
                    storePassword = releaseKeystoreProperties.getProperty("storePassword")
                }
                else -> null
            }
        }
    }
}

val verifyPlayRelease by tasks.registering {
    group = "verification"
    description = "Checks Master ABAP package, version and the registered Play upload certificate."
    doLast {
        check(android.defaultConfig.applicationId == playReleaseProperties.getProperty("applicationId")) {
            "Release package must match the existing Master ABAP Play listing."
        }
        val minimumVersionCode = playReleaseProperties.getProperty("minimumVersionCode").toInt()
        check((android.defaultConfig.versionCode ?: 0) >= minimumVersionCode) {
            "Use versionCode >= $minimumVersionCode according to the recorded Play baseline. Recheck the Console before uploading."
        }
        check(!hasAnyEnvSigning || hasEnvSigning) {
            "Incomplete ANDROID_KEYSTORE_* / ANDROID_KEY_* environment. All four signing values are required."
        }
        val signing = android.buildTypes.getByName("release").signingConfig
            ?: throw GradleException("Play release signing is missing. Configure the registered upload key in android/key.properties or the environment.")
        val keystoreFile = signing.storeFile
        val storePassword = signing.storePassword
        val alias = signing.keyAlias
        val keyPassword = signing.keyPassword
        check(keystoreFile?.isFile == true && !storePassword.isNullOrBlank() &&
                !alias.isNullOrBlank() && !keyPassword.isNullOrBlank()) {
            "Play release requires an existing keystore, storePassword, keyAlias and keyPassword."
        }
        val keystore = KeyStore.getInstance(keystoreFile!!, storePassword.toCharArray())
        check(keystore.isKeyEntry(alias)) { "The configured alias must contain a private upload key, not just a certificate." }
        val certificate = keystore.getCertificate(alias)
            ?: throw GradleException("No upload certificate found for the configured alias.")
        val fingerprint = MessageDigest.getInstance("SHA-256").digest(certificate.encoded)
            .joinToString(":") { "%02X".format(it.toInt() and 0xff) }
        val expected = playReleaseProperties.getProperty("uploadCertificateSha256")
        check(fingerprint == expected) {
            "Wrong Play upload key. Expected SHA-256 $expected; found $fingerprint. Configure the original upload keystore. Do not upload this build or replace the expected fingerprint with an unregistered key."
        }
        check(keystore.getKey(alias, keyPassword.toCharArray()) != null) { "Upload private key could not be loaded." }
        logger.lifecycle("Play release verified: ${android.defaultConfig.applicationId}, versionCode ${android.defaultConfig.versionCode}, upload SHA-256 $fingerprint")
    }
}

tasks.configureEach {
    if (name == "preReleaseBuild" || name == "validateSigningRelease") {
        dependsOn(verifyPlayRelease)
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
