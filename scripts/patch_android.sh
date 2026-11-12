#!/usr/bin/env bash
set -e

echo "Applying Android build patches: compileSdk 36 & disabling broken AGP lintVital tasks..."

# 0. Remove any legacy init scripts that could conflict
rm -f "$HOME/.gradle/init.d/01-mirrors.gradle" || true

# 1. Ensure download.flutter.io is in android/settings.gradle.kts if present
if [ -f "android/settings.gradle.kts" ]; then
  if ! grep -q "download.flutter.io" android/settings.gradle.kts; then
    sed -i '/repositories {/a \        maven { url = java.net.URI.create("https://storage.googleapis.com/download.flutter.io") }' android/settings.gradle.kts || true
  fi
fi

# 2. Patch android/gradle.properties
if [ -f "android/gradle.properties" ]; then
  cat << 'EOF' >> android/gradle.properties
android.compileSdk=36
org.gradle.daemon=false
systemProp.org.gradle.internal.http.socketTimeout=120000
systemProp.org.gradle.internal.http.connectionTimeout=120000
systemProp.http.keepAlive=false
EOF
fi

# 3. Patch compileSdk = 36 and lintOptions in android/app/build.gradle & android/app/build.gradle.kts
if [ -f "android/app/build.gradle" ]; then
  sed -i 's/compileSdk = flutter.compileSdkVersion/compileSdk = 36/g' android/app/build.gradle || true
  sed -i 's/compileSdkVersion flutter.compileSdkVersion/compileSdkVersion 36/g' android/app/build.gradle || true
  sed -i 's/targetSdk = flutter.targetSdkVersion/targetSdk = 36/g' android/app/build.gradle || true
  sed -i 's/targetSdkVersion flutter.targetSdkVersion/targetSdkVersion 36/g' android/app/build.gradle || true
  cat << 'EOF' >> android/app/build.gradle

android {
    lintOptions {
        checkReleaseBuilds false
        abortOnError false
    }
}
EOF
fi

if [ -f "android/app/build.gradle.kts" ]; then
  sed -i 's/compileSdk = flutter.compileSdkVersion/compileSdk = 36/g' android/app/build.gradle.kts || true
  sed -i 's/targetSdk = flutter.targetSdkVersion/targetSdk = 36/g' android/app/build.gradle.kts || true
  cat << 'EOF' >> android/app/build.gradle.kts

android {
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}
EOF
fi

# 4. Force all subprojects (like file_picker, url_launcher_android) to use compileSdkVersion 36 and disable lintVital tasks
if [ -f "android/build.gradle" ]; then
  cat << 'EOF' >> android/build.gradle

allprojects {
    tasks.configureEach { task ->
        if (task.name.contains("lintVital") || task.name.contains("LintVital")) {
            task.enabled = false
        }
    }
}

subprojects {
    def configProject = { p ->
        if (p.hasProperty("android")) {
            p.android {
                compileSdkVersion 36
                lintOptions {
                    checkReleaseBuilds false
                    abortOnError false
                }
            }
        }
    }
    if (state.executed) {
        configProject(project)
    } else {
        afterEvaluate {
            configProject(project)
        }
    }
}
EOF
fi

if [ -f "android/build.gradle.kts" ]; then
  cat << 'EOF' >> android/build.gradle.kts

allprojects {
    tasks.configureEach { task ->
        if (task.name.contains("lintVital") || task.name.contains("LintVital")) {
            task.enabled = false
        }
    }
}

subprojects {
    val configProject: Project.() -> Unit = {
        val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        android?.compileSdkVersion(36)
        android?.lintOptions {
            isCheckReleaseBuilds = false
            isAbortOnError = false
        }
    }
    if (state.executed) {
        configProject()
    } else {
        afterEvaluate {
            configProject()
        }
    }
}
EOF
fi

echo "Android patches applied successfully."
