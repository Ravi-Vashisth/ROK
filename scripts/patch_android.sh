#!/usr/bin/env bash
set -e

echo "Applying Android build fixes: AGP 8.11.1, Settings repository mode, standard Google & MavenCentral repositories, root compileSdkVersion extra property, and AarMetadata bypass..."

# 0. Remove any legacy init scripts that could conflict with settings dependency resolution
rm -f "$HOME/.gradle/init.d/01-mirrors.gradle" || true

# 1. Cleanly write android/settings.gradle.kts with AGP 8.11.1, PREFER_SETTINGS, google() & mavenCentral()
if [ -d "android" ]; then
  cat << 'EOF' > android/settings.gradle.kts
pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
    }
}

include(":app")
EOF
fi

# 2. Patch android/gradle.properties
if [ -f "android/gradle.properties" ]; then
  cat << 'EOF' >> android/gradle.properties
android.compileSdk=36
systemProp.org.gradle.internal.http.socketTimeout=120000
systemProp.org.gradle.internal.http.connectionTimeout=120000
systemProp.http.keepAlive=false
org.gradle.jvmargs=-Xmx2048m -XX:MaxMetaspaceSize=512m
EOF
fi

# 3. Update android/app/build.gradle
if [ -f "android/app/build.gradle" ]; then
  sed -i 's/compileSdk = flutter.compileSdkVersion/compileSdk = 36/g' android/app/build.gradle || true
  sed -i 's/compileSdkVersion flutter.compileSdkVersion/compileSdkVersion 36/g' android/app/build.gradle || true
  sed -i 's/targetSdk = flutter.targetSdkVersion/targetSdk = 36/g' android/app/build.gradle || true
  sed -i 's/targetSdkVersion flutter.targetSdkVersion/targetSdkVersion 36/g' android/app/build.gradle || true
fi

# 4. Update android/app/build.gradle.kts if present
if [ -f "android/app/build.gradle.kts" ]; then
  sed -i 's/compileSdk = flutter.compileSdkVersion/compileSdk = 36/g' android/app/build.gradle.kts || true
  sed -i 's/targetSdk = flutter.targetSdkVersion/targetSdk = 36/g' android/app/build.gradle.kts || true
fi

# 5. Append root extra compileSdkVersion & disable AarMetadata check in root android/build.gradle (Groovy)
if [ -f "android/build.gradle" ]; then
  cat << 'EOF' >> android/build.gradle

buildscript {
    ext {
        compileSdkVersion = 36
        targetSdkVersion = 36
    }
}

allprojects {
    ext {
        compileSdkVersion = 36
        targetSdkVersion = 36
    }
    tasks.matching { it.name.contains("AarMetadata") }.configureEach {
        enabled = false
    }
}
EOF
fi

# 6. Handle Kotlin DSL root if present (android/build.gradle.kts)
if [ -f "android/build.gradle.kts" ]; then
  cat << 'EOF' >> android/build.gradle.kts

extra["compileSdkVersion"] = 36
extra["targetSdkVersion"] = 36

allprojects {
    extra["compileSdkVersion"] = 36
    extra["targetSdkVersion"] = 36
    tasks.matching { it.name.contains("AarMetadata") }.configureEach {
        enabled = false
    }
}
EOF
fi

echo "Android patches applied successfully."
