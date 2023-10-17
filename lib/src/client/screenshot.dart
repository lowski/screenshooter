import '../common.dart';
import '../ipc_message.dart';
import 'ipc_client.dart';

class Screenshot {
  final String name;
  final Future<void> Function() prepare;
  final Future<void> Function()? cleanup;
  final Duration? delay;

  Screenshot({
    required this.name,
    required this.prepare,
    this.cleanup,
    this.delay,
  });

  /// Take a screenshot. This will send a message to the screenshot server
  /// telling it to take a screenshot. We return only after the screenshot
  /// server has finished taking the screenshot.
  Future<void> take(ScreenshotLocale? locale) async {
    await prepare();
    await Future.delayed(delay ?? Duration.zero);
    await IpcClient.send(ScreenshotIpcMessage(
      name: name,
      locale: locale,
    ));
    await cleanup?.call();
  }
}
