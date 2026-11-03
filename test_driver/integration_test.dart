import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final envPlatform = Platform.environment['SCREENSHOT_PLATFORM'] ?? '';

  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
      String platform = envPlatform.trim();
      if (platform.isEmpty) {
        if (Platform.isWindows) {
          platform = 'windows';
        } else if (Platform.isLinux) {
          platform = 'android';
        } else if (Platform.isMacOS) {
          platform = 'macos';
        } else {
          platform = 'common';
        }
      }
      final File image = File('screenshots/$platform/$screenshotName.png');
      image.parent.createSync(recursive: true);
      await image.writeAsBytes(screenshotBytes);
      print('Host integration driver saved screenshot via onScreenshot: ${image.path}');
      return true;
    },
    responseDataCallback: (Map<String, dynamic>? data) async {
      if (data != null && data.containsKey('screenshots')) {
        final platform = (data['platform'] as String?)?.isNotEmpty == true
            ? data['platform'] as String
            : (envPlatform.trim().isNotEmpty ? envPlatform.trim() : 'common');
        final screenshots = data['screenshots'] as Map<String, dynamic>?;
        if (screenshots != null) {
          for (final entry in screenshots.entries) {
            final String name = entry.key;
            final String base64Str = entry.value.toString();
            final List<int> bytes = base64Decode(base64Str);
            final File file = File('screenshots/$platform/$name.png');
            file.parent.createSync(recursive: true);
            await file.writeAsBytes(bytes);
            print('Host integration driver saved screenshot via reportData: ${file.path}');
          }
        }
      }
    },
  );
}
