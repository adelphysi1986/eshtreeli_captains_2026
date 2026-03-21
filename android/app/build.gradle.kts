plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // ✅ ضروري
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.eshtreeli.captains"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.eshtreeli.captains"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 26
        versionName = "2.1.3"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }
}

dependencies {

    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
    implementation("com.google.firebase:firebase-analytics")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}
