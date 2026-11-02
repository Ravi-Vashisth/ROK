import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, dynamic>? args]) async {
      final String platform = (args?['platform'] as String?) ?? 'common';
      final File image = File('screenshots/$platform/$screenshotName.png');
      image.parent.createSync(recursive: true);
      await image.writeAsBytes(screenshotBytes);
      print('Host integration driver saved screenshot: ${image.path}');
      return true;
    },
  );
}
