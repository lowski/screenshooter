import 'dart:io';

import '../common.dart';
import 'flutter_process.dart';

Future<ProcessResult> exec(List<String> args) async {
  final result = await Process.run(args.first, args.skip(1).toList());
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    await stderr.flush();

    throw StateError('Failed to run command: ${args.join(' ')}');
  }
  return result;
}

// This is an extension because we don't want this in the public (client-side)
// API.
extension ScreenshotConfigurationExtension on ScreenshotConfiguration {
  /// Add the configuration to the process. Null values will be omitted.
  void addToProcess(FlutterProcess process) {
    if (username != null) process.define('SCREENSHOTS_USERNAME', username!);
    if (password != null) process.define('SCREENSHOTS_PASSWORD', password!);
    process.define('SCREENSHOT_MODE', 'true');
    if (locales != null) {
      process.define(
        'SCREENSHOT_LOCALES',
        locales!.map((l) => l.toLanguageTag()).join(','),
      );
    }
  }
}
