plugins {
    id("com.android.application")
}

android {
    namespace = "com.mctooter.androidruntimetest"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.mctooter.androidruntimetest"
        minSdk = 29
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
}
