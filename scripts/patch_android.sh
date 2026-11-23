#!/usr/bin/env bash
set -e

echo "Applying Android build patches: compileSdk 36, idempotent Gradle rules, and OEM <queries> intents..."

# 0. Remove any legacy init scripts that could conflict
rm -f "$HOME/.gradle/init.d/01-mirrors.gradle" || true

# 1. Ensure download.flutter.io is in android/settings.gradle.kts if present
if [ -f "android/settings.gradle.kts" ]; then
  if ! grep -q "download.flutter.io" android/settings.gradle.kts; then
    sed -i '/repositories {/a \        maven { url = java.net.URI.create("https://storage.googleapis.com/download.flutter.io") }' android/settings.gradle.kts || true
  fi
fi

# 2. Patch android/gradle.properties idempotently
if [ -f "android/gradle.properties" ]; then
  if ! grep -q "BILLING_APP_GRADLE_PROPERTIES" android/gradle.properties; then
    {
      echo ""
      echo "# BILLING_APP_GRADLE_PROPERTIES"
      grep -q "^android.compileSdk=" android/gradle.properties || echo "android.compileSdk=36"
      grep -q "^org.gradle.daemon=" android/gradle.properties || echo "org.gradle.daemon=false"
      grep -q "^systemProp.org.gradle.internal.http.socketTimeout=" android/gradle.properties || echo "systemProp.org.gradle.internal.http.socketTimeout=120000"
      grep -q "^systemProp.org.gradle.internal.http.connectionTimeout=" android/gradle.properties || echo "systemProp.org.gradle.internal.http.connectionTimeout=120000"
      grep -q "^systemProp.http.keepAlive=" android/gradle.properties || echo "systemProp.http.keepAlive=false"
    } >> android/gradle.properties
  fi
fi

# 3. Patch compileSdk = 36 and lintOptions idempotently in android/app/build.gradle & build.gradle.kts
if [ -f "android/app/build.gradle" ]; then
  sed -i 's/compileSdk = flutter.compileSdkVersion/compileSdk = 36/g' android/app/build.gradle || true
  sed -i 's/compileSdkVersion flutter.compileSdkVersion/compileSdkVersion 36/g' android/app/build.gradle || true
  sed -i 's/targetSdk = flutter.targetSdkVersion/targetSdk = 36/g' android/app/build.gradle || true
  sed -i 's/targetSdkVersion flutter.targetSdkVersion/targetSdkVersion 36/g' android/app/build.gradle || true
  if ! grep -q "BILLING_APP_ANDROID_LINT_PATCH" android/app/build.gradle; then
    cat << 'EOF' >> android/app/build.gradle

// BILLING_APP_ANDROID_LINT_PATCH
android {
    lintOptions {
        checkReleaseBuilds false
        abortOnError false
    }
}
EOF
  fi
fi

if [ -f "android/app/build.gradle.kts" ]; then
  sed -i 's/compileSdk = flutter.compileSdkVersion/compileSdk = 36/g' android/app/build.gradle.kts || true
  sed -i 's/targetSdk = flutter.targetSdkVersion/targetSdk = 36/g' android/app/build.gradle.kts || true
  if ! grep -q "BILLING_APP_ANDROID_LINT_PATCH" android/app/build.gradle.kts; then
    cat << 'EOF' >> android/app/build.gradle.kts

// BILLING_APP_ANDROID_LINT_PATCH
android {
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}
EOF
  fi
fi

# 4. Force all subprojects (file_picker, url_launcher_android, etc.) to compileSdk 36 & disable lintVital idempotently
if [ -f "android/build.gradle" ]; then
  if ! grep -q "BILLING_APP_SUBPROJECT_SDK_PATCH" android/build.gradle; then
    cat << 'EOF' >> android/build.gradle

// BILLING_APP_SUBPROJECT_SDK_PATCH
allprojects {
    tasks.configureEach { task ->
        if (task.name.toLowerCase().contains("lintvital")) {
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
fi

if [ -f "android/build.gradle.kts" ]; then
  if ! grep -q "BILLING_APP_SUBPROJECT_SDK_PATCH" android/build.gradle.kts; then
    cat << 'EOF' >> android/build.gradle.kts

// BILLING_APP_SUBPROJECT_SDK_PATCH
allprojects {
    tasks.configureEach {
        if (name.contains("lintVital", ignoreCase = true)) {
            enabled = false
        }
    }
}

subprojects {
    val configProject: Project.() -> Unit = {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                val method = androidExt.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                method.invoke(androidExt, 36)
            } catch (_: Exception) {}
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
fi

# 5. Idempotently inject Android 11-15 (API 30+) <queries> intents, OEM WhatsApp package visibility,
#    non-required telephony hardware feature (Wi-Fi tablets/ChromeOS), and allowBackup="false"
MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ]; then
  echo "Ensuring Android 11-15 <queries> OS intents, telephony feature flag, and allowBackup=\"false\" in $MANIFEST..."
  python3 - "$MANIFEST" << 'PYEOF'
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
ANDROID_NS = 'http://schemas.android.com/apk/res/android'
ANDROID_NAME = f'{{{ANDROID_NS}}}name'
ANDROID_SCHEME = f'{{{ANDROID_NS}}}scheme'
ANDROID_REQUIRED = f'{{{ANDROID_NS}}}required'
ANDROID_ALLOW_BACKUP = f'{{{ANDROID_NS}}}allowBackup'

ET.register_namespace('android', ANDROID_NS)
tree = ET.parse(path)
root = tree.getroot()

changed = False

app_el = root.find('application')
if app_el is not None and app_el.attrib.get(ANDROID_ALLOW_BACKUP) != 'false':
    app_el.set(ANDROID_ALLOW_BACKUP, 'false')
    changed = True

telephony_feature = None
for feature in root.findall('uses-feature'):
    if feature.attrib.get(ANDROID_NAME) == 'android.hardware.telephony':
        telephony_feature = feature
        break

if telephony_feature is None:
    telephony_feature = ET.Element('uses-feature')
    telephony_feature.set(ANDROID_NAME, 'android.hardware.telephony')
    telephony_feature.set(ANDROID_REQUIRED, 'false')
    # Insert before <application> to maintain clean manifest ordering
    app_index = list(root).index(app_el) if app_el is not None else len(list(root))
    root.insert(app_index, telephony_feature)
    changed = True
elif telephony_feature.attrib.get(ANDROID_REQUIRED) != 'false':
    telephony_feature.set(ANDROID_REQUIRED, 'false')
    changed = True

queries = root.find('queries')
if queries is None:
    queries = ET.SubElement(root, 'queries')
    changed = True

existing_intents = set()
for intent in queries.findall('intent'):
    action_el = intent.find('action')
    data_el = intent.find('data')
    if action_el is not None and data_el is not None:
        existing_intents.add((
            action_el.attrib.get(ANDROID_NAME, ''),
            data_el.attrib.get(ANDROID_SCHEME, ''),
        ))

existing_packages = {
    pkg.attrib.get(ANDROID_NAME, '')
    for pkg in queries.findall('package')
}

required_intents = [
    ('android.intent.action.VIEW', 'https'),
    ('android.intent.action.SENDTO', 'mailto'),
    ('android.intent.action.DIAL', 'tel'),
    ('android.intent.action.VIEW', 'sms'),
    ('android.intent.action.SENDTO', 'sms'),
    ('android.intent.action.SENDTO', 'smsto'),
]

required_packages = [
    'com.whatsapp',
    'com.whatsapp.w4b',
]

for action_name, scheme in required_intents:
    if (action_name, scheme) not in existing_intents:
        intent = ET.SubElement(queries, 'intent')
        action = ET.SubElement(intent, 'action')
        action.set(ANDROID_NAME, action_name)
        data = ET.SubElement(intent, 'data')
        data.set(ANDROID_SCHEME, scheme)
        changed = True

for pkg_name in required_packages:
    if pkg_name not in existing_packages:
        pkg = ET.SubElement(queries, 'package')
        pkg.set(ANDROID_NAME, pkg_name)
        changed = True

if changed:
    if hasattr(ET, 'indent'):
        ET.indent(tree, space='    ')
    tree.write(path, encoding='utf-8', xml_declaration=True)
PYEOF
fi

echo "Android patches applied successfully."
