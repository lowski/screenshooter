import 'dart:async';

import 'package:screenshooter/screenshooter.dart';

class ScreenshotSuite {
  final String name;
  final List<Screenshot> screenshots;
  final FutureOr<void> Function()? prepare;
  final FutureOr<void> Function(ScreenshotLocale locale)? prepareLocale;
  final FutureOr<void> Function(ScreenshotLocale locale)? cleanupLocale;
  final FutureOr<void> Function()? cleanup;

  /// Create a new screenshot suite with the given [name] and [screenshots].
  /// [name] should be unique.
  ///
  /// [prepare] will be called once before running the suite. It can be used to
  /// prepare the environment. It should probably be used to start the app.
  ///
  /// All screenshots will be run once for each locale. Before each of these
  /// runs [prepareLocale] will be called with the locale to use. Switching the
  /// locale is not handled automatically and must be done in this callback.
  ///
  /// [cleanup] will be called once after running the suite.
  ScreenshotSuite({
    required this.name,
    required this.screenshots,
    this.prepare,
    this.prepareLocale,
    this.cleanupLocale,
    this.cleanup,
  });

  /// Run this suite.
  Future<void> run() async {
    await IpcClient.sendInfo('Running suite "$name"');

    await prepare?.call();

    for (final locale in ScreenshotConfiguration.fromEnv.locales ?? [null]) {
      if (locale != null) {
        await IpcClient.sendInfo(
          'Running suite "$name" for locale "${locale.toLanguageTag()}"',
        );
        await prepareLocale?.call(locale);
      }

      for (final screenshot in screenshots) {
        await IpcClient.sendInfo('Taking screenshot "${screenshot.name}"');
        await screenshot.take(locale);
      }
    }

    await cleanup?.call();

    await IpcClient.send(ClientDoneIpcMessage());
  }
}
