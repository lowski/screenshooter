import '../ipc_message.dart';
import 'ipc_client.dart';
import 'screenshot.dart';

class ScreenshotSuite {
  final String name;
  final List<Screenshot> screenshots;
  final Future<void> Function()? prepare;
  final Future<void> Function()? cleanup;

  ScreenshotSuite({
    required this.name,
    required this.screenshots,
    this.prepare,
    this.cleanup,
  });

  /// Run this suite.
  Future<void> run() async {
    await IpcClient.sendInfo('Running suite "$name"');

    await prepare?.call();

    for (final screenshot in screenshots) {
      await IpcClient.sendInfo('Taking screenshot "${screenshot.name}"');
      await screenshot.take();
    }

    await cleanup?.call();

    await IpcClient.send(ClientDoneIpcMessage());
  }
}
