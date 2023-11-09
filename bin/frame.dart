// ignore_for_file: avoid_print

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:image/image.dart';
import 'package:screenshooter/src/framing/frame_provider.dart';
import 'package:screenshooter/src/framing/screenshot_frame.dart';
import 'package:screenshooter/src/host/args.dart';

void main(List<String> argv) async {
  final args = ScreenshotArgs(argv);

  print('Downloading frames...');
  final provider = MetaFrameProvider('./meta-screenshot-frames');
  await provider.download();

  for (final e in args.devices.entries) {
    final deviceName = e.key;
    final deviceId = e.value;

    String path = args.path
        .replaceAll('{locale}', '*')
        .replaceAll('{name}', '*')
        .replaceAll('{device}', deviceId);

    final overlay = await provider.findBestMatch(
      [deviceName, 'white', 'silver', 'starlight'],
    );
    print('Using frame "${overlay.split('/').last}"...');
    final frame = await ScreenshotFrame.fromFile(overlay);

    final glob = Glob(path);

    for (final file in glob.listSync()) {
      decodeImageFile(file.path).then((value) async {
        await encodePngFile(
          '${file.path.replaceAll('.png', '')}_framed.png',
          frame.apply(value!),
        );
        print('Framed ${file.path}');
      });
    }
  }
}
