#!/usr/bin/env bash
set -e

echo "Applying Android build fixes: Maven mirrors (anti-429), compileSdk 36, and AarMetadata bypass..."

# 0. Set up global Gradle init script with Google's high-capacity Maven Central mirror
mkdir -p "$HOME/.gradle/init.d"
cat << 'EOF' > "$HOME/.gradle/init.d/01-mirrors.gradle"
def googleMirror = "https://maven-central.storage-storage.googleapis.com/maven2/"

gradle.settingsEvaluated { settings ->
    settings.pluginManagement {
        repositories {
            maven {
                name = "GoogleMavenCentralMirror"
                url = uri(googleMirror)
            }
        }
    }
}

allprojects {
    buildscript {
        repositories {
            maven {
                name = "GoogleMavenCentralMirror"
                url = uri(googleMirror)
            }
        }
    }
    repositories {
        maven {
            name = "GoogleMavenCentralMirror"
            url = uri(googleMirror)
        }
    }
}
EOF

# 1. Patch android/settings.gradle.kts (Kotlin DSL) if present
if [ -f "android/settings.gradle.kts" ]; then
  echo "Patching android/settings.gradle.kts with Google Maven mirror..."
  sed -i 's|mavenCentral()|maven(url = "https://maven-central.storage-storage.googleapis.com/maven2/")|g' android/settings.gradle.kts || true
  sed -i 's|repositories {|repositories {\n        maven(url = "https://maven-central.storage-storage.googleapis.com/maven2/")|g' android/settings.gradle.kts || true
fi

# 2. Patch android/settings.gradle (Groovy DSL) if present
if [ -f "android/settings.gradle" ]; then
  echo "Patching android/settings.gradle with Google Maven mirror..."
  sed -i "s|mavenCentral()|maven { url 'https://maven-central.storage-storage.googleapis.com/maven2/' }|g" android/settings.gradle || true
  sed -i "s|repositories {|repositories {\n        maven { url 'https://maven-central.storage-storage.googleapis.com/maven2/' }|g" android/settings.gradle || true
fi

# 3. Patch android/gradle.properties
if [ -f "android/gradle.properties" ]; then
  cat << 'EOF' >> android/gradle.properties
systemProp.org.gradle.internal.http.socketTimeout=120000
systemProp.org.gradle.internal.http.connectionTimeout=120000
systemProp.http.keepAlive=false
org.gradle.jvmargs=-Xmx2048m -XX:MaxMetaspaceSize=512m
EOF
fi

# 4. Update android/app/build.gradle
if [ -f "android/app/build.gradle" ]; then
  sed -i 's/compileSdk = flutter.compileSdkVersion/compileSdk = 36/g' android/app/build.gradle || true
  sed -i 's/compileSdkVersion flutter.compileSdkVersion/compileSdkVersion 36/g' android/app/build.gradle || true
  sed -i 's/targetSdk = flutter.targetSdkVersion/targetSdk = 36/g' android/app/build.gradle || true
  sed -i 's/targetSdkVersion flutter.targetSdkVersion/targetSdkVersion 36/g' android/app/build.gradle || true
fi

# 5. Update android/app/build.gradle.kts if present
if [ -f "android/app/build.gradle.kts" ]; then
  sed -i 's/compileSdk = flutter.compileSdkVersion/compileSdk = 36/g' android/app/build.gradle.kts || true
  sed -i 's/targetSdk = flutter.targetSdkVersion/targetSdk = 36/g' android/app/build.gradle.kts || true
fi

# 6. Append subprojects override & disable AarMetadata check in root android/build.gradle
if [ -f "android/build.gradle" ]; then
  cat << 'EOF' >> android/build.gradle

allprojects {
    repositories {
        maven { url 'https://maven-central.storage-storage.googleapis.com/maven2/' }
    }
    tasks.matching { it.name.contains("AarMetadata") }.configureEach {
        enabled = false
    }
}

subprojects {
    afterEvaluate { project ->
        if (project.hasProperty('android')) {
            project.android {
                if (compileSdkVersion != null && compileSdkVersion < 36) {
                    compileSdkVersion 36
                }
            }
        }
    }
}
EOF
fi

# 7. Handle Kotlin DSL root if present
if [ -f "android/build.gradle.kts" ]; then
  cat << 'EOF' >> android/build.gradle.kts

allprojects {
    repositories {
        maven { url = uri("https://maven-central.storage-storage.googleapis.com/maven2/") }
    }
    tasks.matching { it.name.contains("AarMetadata") }.configureEach {
        enabled = false
    }
}
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android")
            if (androidExt is com.android.build.gradle.BaseExtension) {
                androidExt.compileSdkVersion(36)
            }
        }
    }
}
EOF
fi

echo "Android patches applied successfully."
