import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val stockfishNnueDirectory =
    rootProject.file("../third_party/stockfish/android/nnue")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val requireConfiguredKeystore by tasks.registering {
    doLast {
        if (!keystorePropertiesFile.exists()) {
            throw GradleException(
                "Missing android/key.properties. Create it from key.properties.example before building Android APKs or AABs."
            )
        }
        val missingKeys = listOf(
            "storeFile",
            "storePassword",
            "keyAlias",
            "keyPassword",
        ).filter { key -> keystoreProperties.getProperty(key).isNullOrBlank() }
        if (missingKeys.isNotEmpty()) {
            throw GradleException(
                "android/key.properties is missing required signing fields: ${missingKeys.joinToString(", ")}"
            )
        }
        val releaseStoreFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
        if (!releaseStoreFile.exists()) {
            throw GradleException(
                "Configured keystore does not exist: ${releaseStoreFile.absolutePath}"
            )
        }
    }
}

val sanitizeGeneratedPluginRegistrantForRelease by tasks.registering {
    doLast {
        val registrant = file(
            "src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java"
        )
        if (!registrant.exists()) return@doLast

        val source = registrant.readText()
        val integrationTestBlock = Regex(
            """
    try \{\s+flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\s+\} catch \(Exception e\) \{\s+Log\.e\(TAG, "Error registering plugin integration_test, dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin", e\);\s+\}
            """.trimIndent(),
            setOf(RegexOption.DOT_MATCHES_ALL),
        )
        val sanitized = source.replace(integrationTestBlock, "")
        if (sanitized != source) {
            registrant.writeText(sanitized)
        }
        if (registrant.readText().contains("IntegrationTestPlugin")) {
            throw GradleException(
                "GeneratedPluginRegistrant.java still references integration_test; release builds cannot include the test plugin."
            )
        }
    }
}

tasks.configureEach {
    if (name.startsWith("uploadCrashlyticsMappingFile")) {
        enabled = false
    }
    if (name == "compileReleaseJavaWithJavac" ||
        name == "compileProfileJavaWithJavac"
    ) {
        dependsOn(sanitizeGeneratedPluginRegistrantForRelease)
    }
    if (name == "validateSigningRelease" ||
        name == "packageRelease" ||
        name == "bundleRelease"
    ) {
        dependsOn(requireConfiguredKeystore)
    }
}

android {
    namespace = "com.chessnut.chessnutnext"
    compileSdk = 37
    ndkVersion = "28.2.13676358"

    buildFeatures {
        aidl = true
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.chessnut.newchessnut"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    sourceSets {
        getByName("main") {
            assets.srcDir(stockfishNnueDirectory)
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.google.android.play:app-update:2.1.0")
}
