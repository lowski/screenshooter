import 'package:screenshooter/src/host/screenshot_host.dart';

void main(List<String> argv) async {
  await ScreenshotHost(argv: argv).run();
}
