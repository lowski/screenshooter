// ignore_for_file: avoid_print

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:image/image.dart';
import 'package:screenshooter/src/framing/frame_provider.dart';
import 'package:screenshooter/src/framing/screenshot_frame.dart';
import 'package:screenshooter/src/host/args.dart';

const _defaultFrameSelectors = ['white', 'silver', 'starlight'];

void main(List<String> argv) async {
  final args = ScreenshotArgs(argv);
  final cfg = ScreenshotFrameConfig.fromConfigFiles();

  print('Downloading frames...');
  final provider = MetaFrameProvider('./meta-screenshot-frames');
  await provider.download();
  print('Done.');

  final futures = <Future>[];

  for (final e in args.devices.entries) {
    final deviceName = e.key;
    final deviceId = e.value;

    String path = args.path
        .replaceAll('{locale}', '*')
        .replaceAll('{name}', '*')
        .replaceAll('{device}', deviceId);

    final overlay = await provider.findBestMatch([
      deviceName,
      ...(cfg.frameSelectors ?? _defaultFrameSelectors)
          .map((e) => e.toLowerCase()),
    ]);
    final frame = await ScreenshotFrame.fromFile(overlay);
    print('Using frame "${overlay.split('/').last}"...');

    final glob = Glob(path);

    for (final file in glob.listSync()) {
      futures.add(decodePngFile(file.path).then((value) async {
        Image result = frame.apply(value!);

        await encodePngFile(
          '${file.path.replaceAll('.png', '')}${cfg.suffixFrame}.png',
          result,
        );
        print('Done: ${file.path}');
      }));
    }
    await Future.wait(futures);
    futures.clear();
  }
}
