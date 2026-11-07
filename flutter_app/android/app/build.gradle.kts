plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "org.myapp.vn_currency"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "org.myapp.vn_currency"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 고정 서명: 열쇠 파일과 비밀번호는 저장소에 두지 않고 GitHub Secret으로만 넣는다.
    // CI가 ANDROID_KEYSTORE_BASE64 를 upload-keystore.p12 로 풀어 두고
    // ANDROID_KEYSTORE_PASSWORD 를 넘겨준다. 둘 중 하나라도 없으면 디버그 서명.
    val keystoreFile = file("upload-keystore.p12")
    val keystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
        ?.takeIf { it.isNotBlank() && keystoreFile.exists() }

    signingConfigs {
        if (keystorePassword != null) {
            create("release") {
                storeFile = keystoreFile
                storeType = "PKCS12"
                storePassword = keystorePassword
                keyAlias = "upload"
                keyPassword = keystorePassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (keystorePassword != null) "release" else "debug")
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
