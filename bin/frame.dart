// ignore_for_file: avoid_print

import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:screenshooter/src/framing/frame_provider.dart';
import 'package:screenshooter/src/framing/image_magick.dart';
import 'package:screenshooter/src/framing/screenshot_frame.dart';
import 'package:screenshooter/src/framing/utils.dart';
import 'package:screenshooter/src/host/args.dart';
import 'package:screenshooter/src/host/ios_simulator.dart';
import 'package:screenshooter/src/host/utils.dart';

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
    print('');
    print('Device: "$deviceName" (${i + 1}/${deviceNames.length})');
    final deviceId = args.devices[deviceName]!;

    final isTablet =
        deviceName.contains('iPad') || deviceId.toLowerCase().contains('ipad');
    final isLandscape = isTablet && args.tabletOrientation.isLandscape;

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

    // find the correct frame image
    final overlay = await _findBestOverlay(
      deviceName: deviceName,
      deviceId: deviceId,
      cfg: cfg,
      args: args,
      provider: provider,
    );
    print('Frame: ${overlay.split('/').last}.');

    // Pre-load the frame as it's the same for all screenshots of this device
    final frame = await ImageMagickScreenshotFrame.fromFile(overlay);

    CSize screenshotSize = await getImageSize(screenshotsForDevice.first.path);
    if (isLandscape) {
      screenshotSize = screenshotSize.flipped;
    }

    final frameFutures = <Future>[];

    for (final locale in locales) {
      final glob = Glob(args.path
          .replaceAll('{locale}', locale)
          .replaceAll('{name}', '*')
          .replaceAll('{device}', deviceId));

      for (final file in glob.listSync()) {
        String inputPath = file.path;
        final outputPath = inputPath.replaceAll(
            '.png', '${cfg.suffixFrame}${cfg.suffixText}.png');

        final frameFuture = frame.apply(
          inputPath,
          outputPath,
          title: findTitle(
            cfg: cfg,
            basename: file.basename,
            locale: locale,
          ),
          screenshotSize: screenshotSize,
          frameConfig: cfg,
          rotateLeft: isLandscape,
        );
        frameFutures.add(frameFuture);

        frameFuture.then((value) {
          screenshotsDone++;
          print('[✓] ${file.path} ($screenshotsDone/$screenshotsTotal total)');
        });
      }
    }

    Future.wait(frameFutures).then((value) => frame.dispose());
  }
}

Future<String> _findBestOverlay({
  required String deviceName,
  required String deviceId,
  required ScreenshotFrameConfig cfg,
  required ScreenshotArgs args,
  required FrameProvider provider,
}) {
  final overlayCriteria = <String>[
    if (deviceName.contains('iPad') ||
        deviceId.toLowerCase().contains('ipad')) ...[
      'tablets',
      args.tabletOrientation.isLandscape ? 'landscape' : 'portrait',
    ],
    ...(cfg.frameSelectors ?? _defaultFrameSelectors),
  ];

  if (cfg.deviceFrameNames.containsKey(deviceId)) {
    overlayCriteria.addAll(
      cfg.deviceFrameNames[deviceId]!.split(',').map(
            (e) => e.trim(),
          ),
    );
  } else {
    overlayCriteria.add(deviceName);
  }

  return provider.findBestMatch(overlayCriteria);
}
