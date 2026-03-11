plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.daryan.prayer"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.daryan.prayer"
        minSdk = flutter.minSdkVersion                     // use fixed minSdk
        targetSdk = 34
        versionCode = 3
        versionName = "1.0.3"
        multiDexEnabled = true
    }

    buildTypes {
        release {
    isMinifyEnabled = false
    shrinkResources = false    // ✅ use "isShrinkResources" not "shrinkResources"
    signingConfig = signingConfigs.getByName("debug")
}
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}
