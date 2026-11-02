import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
      String platform = (args?['platform'] as String?) ?? '';
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
      print('Host integration driver saved screenshot: ${image.path}');
      return true;
    },
  );
}
