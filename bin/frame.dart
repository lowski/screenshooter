// ignore_for_file: avoid_print

import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:screenshooter/src/framing/frame_provider.dart';
import 'package:screenshooter/src/framing/image_magick.dart';
import 'package:screenshooter/src/framing/screenshot_frame.dart';
import 'package:screenshooter/src/framing/utils.dart';
import 'package:screenshooter/src/host/args.dart';

const _defaultFrameSelectors = ['white', 'silver', 'starlight'];

void main(List<String> argv) async {
  final args = ScreenshotArgs(argv);
  final cfg = ScreenshotFrameConfig.fromConfigFiles();

  print('Downloading frames...');
  final provider = MetaFrameProvider(
    '${Platform.environment['HOME']}/.cache/screenshooter-device-frames',
  );
  await provider.download();
  print('Done.');

  final deviceNames = args.devices.keys;
  final locales =
      args.configuration.locales?.map((e) => e.toLanguageTag()) ?? ['en-US'];

  int screenshotsTotal = 0;
  int screenshotsDone = 0;

  for (final (i, deviceName) in deviceNames.indexed) {
    print(
        'Framing screenshots for device "$deviceName" (${i + 1} / ${deviceNames.length} devices)...');
    final deviceId = args.devices[deviceName]!;

    // find the correct frame image
    final overlay = await provider.findBestMatch([
      deviceName,
      ...(cfg.frameSelectors ?? _defaultFrameSelectors)
          .map((e) => e.toLowerCase()),
    ]);

    // We can pre-load the frame here, because it is the same for all
    // screenshots of this device.
    final frame = await ImageMagickScreenshotFrame.fromFile(overlay);

    // Same for the size of the screenshot
    final generalPath = args.path
        .replaceAll('{locale}', '*')
        .replaceAll('{name}', '*')
        .replaceAll('{device}', deviceId);
    final screenshotsForDevice = Glob(generalPath).listSync();
    if (screenshotsForDevice.isEmpty) {
      print('No screenshots found for device "$deviceName".');
      continue;
    }
    screenshotsTotal = screenshotsForDevice.length * deviceNames.length;
    final screenshotSize = await getImageSize(screenshotsForDevice.first.path);

    for (final locale in locales) {
      String path = args.path
          .replaceAll('{locale}', locale)
          .replaceAll('{name}', '*')
          .replaceAll('{device}', deviceId);

      final glob = Glob(path);

      for (final file in glob.listSync()) {
        await frame.applyImageMagick(
          file.path,
          title: findTitle(
            cfg: cfg,
            basename: file.basename,
            locale: locale,
          ),
          screenshotSize: screenshotSize,
          frameConfig: cfg,
        );
        screenshotsDone++;
        print('[$screenshotsDone/$screenshotsTotal] "${file.path}" done');
      }
    }
  }
}
