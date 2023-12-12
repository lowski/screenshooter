// ignore_for_file: avoid_print

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:screenshooter/src/framing/image_magick.dart';
import 'package:screenshooter/src/host/args.dart';
import 'package:screenshooter/src/host/ios_simulator.dart';

void main(List<String> argv) async {
  final args = ScreenshotArgs(argv);
  final cfg = ScreenshotFrameConfig.fromConfigFiles();

  final deviceIds = args.devices.values;
  final locales =
      args.configuration.locales?.map((e) => e.toLanguageTag()) ?? ['en-US'];

  final futures = <Future>[];

  for (final locale in locales) {
    final titles = cfg.titles?[locale] ?? {};
    for (final deviceId in deviceIds) {
      String path = args.path
          .replaceAll('{locale}', locale)
          .replaceAll('{name}', '*')
          .replaceAll('{device}', deviceId)
          .replaceAll('.png', '${cfg.suffixFrame}.png');

      final glob = Glob(path);

      for (final file in glob.listSync()) {
        // remove the locale and device id from the filename
        final basename =
            file.basename.replaceAll(locale, '').replaceAll(deviceId, '');

        final titleKey = titles.keys.firstWhere(
          (element) => basename.contains(element),
          orElse: () => '',
        );

        futures.add(applyText(
          path: file.path,
          title: titles[titleKey] ?? '',
          cfg: cfg,
        ));
      }
    }
  }

  await Future.wait(futures);
}

Future<void> applyText({
  required String path,
  required String title,
  required ScreenshotFrameConfig cfg,
}) async {
  final width = 100 - (cfg.paddingPercent ?? 0) * 2;

  final textHeight = await getTextHeight(
    text: title,
    font: cfg.font,
    fontSize: cfg.fontSize,
  );

  const spaceForText = 300;

  final size = await getImageSize(path);

  var op = MagickOp.background(cfg.background ?? 'white')
      .chain(MagickOp.gravity('south'))
      .chain(MagickOp.resize(width: '$width%'))
      // .chain(MagickOp.addSpaceTop(1.5 * textHeight))
      .chain(MagickOp.addSpaceTop(spaceForText))
      .chain(MagickOp.extent(width: size.width, height: size.height))
      .chain(
        MagickOp.text(
          text: title,
          color: cfg.fontColor ?? 'black',
          size: cfg.fontSize?.toInt() ?? 24,
          y: (spaceForText - textHeight) / 2,
          font: cfg.font,
        ),
      );
  await op.run(path, path);
  print('Done: $path');
}

Future<IosSimulatorSize> getImageSize(String path) async {
  final result = await MagickOp.format('%wx%h').run(path, 'info:');
  final parts = result.split('x');
  return IosSimulatorSize(
    double.parse(parts[0]),
    double.parse(parts[1]),
  );
}

Future<int> getTextHeight({
  required String text,
  String? font,
  num? fontSize,
}) async {
  var op = MagickOp('size', 'x');
  if (font != null) {
    op = op.chain(MagickOp.font(font));
  }
  if (fontSize != null) {
    op = op.chain(MagickOp.pointsize(fontSize.toInt()));
  }
  op = op.chain(MagickOp('', 'label:$text')).chain(MagickOp.format('%h'));

  return int.parse(await op.run(null, 'info:'));
}
