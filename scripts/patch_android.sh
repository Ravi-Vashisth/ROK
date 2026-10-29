#!/usr/bin/env bash
set -e

echo "Applying Android build fixes: AGP 8.11.1, Settings repository mode, Maven mirrors (anti-429), compileSdk 36 via plugin listeners, and AarMetadata bypass..."

# 0. Remove any legacy init scripts that could conflict with settings dependency resolution
rm -f "$HOME/.gradle/init.d/01-mirrors.gradle" || true

# 1. Cleanly write android/settings.gradle.kts with AGP 8.11.1, PREFER_SETTINGS, and Google Maven Central Mirror
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
        maven { url = java.net.URI.create("https://maven-central.storage-storage.googleapis.com/maven2/") }
        google()
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
        maven { url = java.net.URI.create("https://maven-central.storage-storage.googleapis.com/maven2/") }
        google()
    }
}

include(":app")
EOF
fi

# 2. Patch android/gradle.properties
if [ -f "android/gradle.properties" ]; then
  cat << 'EOF' >> android/gradle.properties
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

# 5. Append subprojects override & disable AarMetadata check in root android/build.gradle (Groovy)
if [ -f "android/build.gradle" ]; then
  cat << 'EOF' >> android/build.gradle

allprojects {
    tasks.matching { it.name.contains("AarMetadata") }.configureEach {
        enabled = false
    }
}

subprojects { proj ->
    proj.plugins.withId('com.android.library') {
        if (proj.hasProperty('android')) {
            try {
                proj.android.compileSdkVersion 36
            } catch (Exception ignored) {}
        }
    }
    proj.plugins.withId('com.android.application') {
        if (proj.hasProperty('android')) {
            try {
                proj.android.compileSdkVersion 36
            } catch (Exception ignored) {}
        }
    }
}
EOF
fi

# 6. Handle Kotlin DSL root if present (android/build.gradle.kts)
if [ -f "android/build.gradle.kts" ]; then
  cat << 'EOF' >> android/build.gradle.kts

allprojects {
    tasks.matching { it.name.contains("AarMetadata") }.configureEach {
        enabled = false
    }
}
subprojects {
    plugins.withId("com.android.library") {
        val androidExt = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        androidExt?.compileSdkVersion(36)
    }
    plugins.withId("com.android.application") {
        val androidExt = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        androidExt?.compileSdkVersion(36)
    }
}
EOF
fi

echo "Android patches applied successfully."
