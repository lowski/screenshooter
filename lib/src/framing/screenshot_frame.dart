import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';
import 'package:screenshooter/src/framing/utils.dart';

import '../host/args.dart';
import '../host/utils.dart';
import 'image_magick.dart';

class ScreenshotFrameMask {
  final Image mask;
  final math.Rectangle<int> edges;

  ScreenshotFrameMask(this.mask, this.edges);

  Future<void> save(String path) async {
    await encodePngFile(path, mask);
  }
}

class ScreenshotFrame {
  final Image frame;
  Image? _frame;
  Image? _mask;
  math.Rectangle<int>? _edges;

  ScreenshotFrame(this.frame);

  static Future<ScreenshotFrame> fromFile(String framePath) async {
    final frame = await decodeImageFile(framePath);
    return ScreenshotFrame(frame!);
  }

  void _calculateMask(int width, int height) {
    _frame = trim(frame);

    _edges = getInnerScreenEdges(frame);

    // resize the frame such that the screen is the same size as the screenshot
    _frame = copyResize(
      _frame!,
      width: _frame!.width * width ~/ _edges!.width,
      height: _frame!.height * height ~/ _edges!.height,
    );

    final (mask, edges) = getScreenMask(_frame!);
    _mask = mask;
    _edges = edges;
  }

  /// Apply the frame to the screenshot. The screenshot is scaled to fit the
  /// screen in the frame.
  ///
  /// The calculation of the mask and frame is cached, so this method can be
  /// called for multiple screenshots.
  ///
  /// Returns a new image, that does not have the same dimensions as the
  /// screenshot.
  Image apply(Image screenshot) {
    if (_frame == null || _mask == null || _edges == null) {
      _calculateMask(screenshot.width, screenshot.height);
    }
    assert(
      _frame != null && _mask != null && _edges != null,
      'Frame not calculated. Something went wrong.',
    );
    final masked = compositeImage(
      Image.from(_mask!),
      screenshot,
      dstX: _edges!.left,
      dstY: _edges!.top,
      mask: _mask!,
    );
    return compositeImage(masked, _frame!);
  }
}

class ImageMagickScreenshotFrame {
  final Image frame;
  final String framePath;
  Image? _frame;
  Image? _mask;
  math.Rectangle<int>? _edges;

  ScreenshotFrameMask get mask => ScreenshotFrameMask(_mask!, _edges!);

  String? _maskTempPath;

  ImageMagickScreenshotFrame(this.frame, {this.framePath = ''});

  static Future<ImageMagickScreenshotFrame> fromFile(String framePath) async {
    final frame = await decodePngFile(framePath);
    return ImageMagickScreenshotFrame(frame!, framePath: framePath);
  }

  ScreenshotFrameMask calculateMask(int width, int height) {
    _frame = frame;

    _edges = getInnerScreenEdges(frame);

    // resize the frame such that the screen is the same size as the screenshot
    _frame = copyResize(
      _frame!,
      width: _frame!.width * width ~/ _edges!.width,
      height: _frame!.height * height ~/ _edges!.height,
    );

    final (mask, edges) = getScreenMask(_frame!);
    _mask = mask;
    _edges = edges;

    // temporarily store the mask to disk for use with image magick
    _maskTempPath = './${framePath.split('/').last}-mask.tmp.png';
    this.mask.save(_maskTempPath!);

    return this.mask;
  }

  Future<void> dispose() async {
    if (_maskTempPath != null) {
      await File(_maskTempPath!).delete();
    }
  }

  Future<void> applyImageMagick(
    String screenshotPath,
    String outputPath, {
    String? title,
    bool addAutoLineBreaks = true,
    required CSize screenshotSize,
    ScreenshotFrameConfig? frameConfig,
    bool rotateLeft = false,
  }) async {
    if (_frame == null || _mask == null || _edges == null) {
      calculateMask(
        screenshotSize.width.toInt(),
        screenshotSize.height.toInt(),
      );
    }

    final mask = this.mask;

    // apply the screen mask to the screenshot
    final maskOp = MagickOp.background('none')
        .chain(MagickOp.rotate(rotateLeft ? -90 : 0))
        .chain(MagickOp.addSpaceTop(mask.edges.top))
        .chain(MagickOp.addSpaceLeft(mask.edges.left))
        .chain(MagickOp.gravity(MagickOptGravity.northWest))
        .chain(MagickOp.extent(
          width: mask.mask.width,
          height: mask.mask.height,
        ))
        .chain(MagickOp.input(_maskTempPath!))
        .chain(MagickOp.mask());

    // resize the frame so that the screenshot has the same size as the screen
    // in the frame
    final backgroundOp = MagickOp.input(framePath)
        .chain(MagickOp.gravity(MagickOptGravity.center))
        .chain(MagickOp.resize(
          width: mask.mask.width,
          height: mask.mask.height,
        ));

    var op = maskOp
        .chain(backgroundOp)
        .chain(MagickOp.compose(MagickOptCompose.srcOver))
        .chain(MagickOp.composite())
        .chain(MagickOp.trim());

    // add the title to the screenshot
    if (title != null) {
      if (frameConfig == null) {
        throw ArgumentError.value(
          frameConfig,
          'frameConfig',
          'must not be null if title is not null',
        );
      }

      screenshotSize ??= await getImageSize(screenshotPath);

      final textOp = await _applyText(
        targetSize: screenshotSize,
        title: title,
        frameConfig: frameConfig,
        addAutoLineBreaks: addAutoLineBreaks,
      );

      op = op.chain(textOp);
    }
    await op.run(screenshotPath, outputPath);
  }

  Future<MagickOp> _applyText({
    required CSize targetSize,
    required String title,
    required ScreenshotFrameConfig frameConfig,
    bool addAutoLineBreaks = true,
  }) async {
    final fontSize = frameConfig.fontSize ?? 24;

    CSize textSize = await getTextSize(
      text: title,
      font: frameConfig.font,
      fontSize: fontSize,
    );
    final textPadding = textSize.height;

    final scaleFactor = 1 - 2 * (frameConfig.paddingPercent ?? 0) / 100;
    final targetWidth = targetSize.width * scaleFactor;

    if (addAutoLineBreaks) {
      // split the title into two lines so that roughly the same number
      // of characters are on each line
      if (textSize.width > targetWidth) {
        title = _insertAutoLineBreak(title, title.length ~/ 2);
        textSize = await getTextSize(
          text: title,
          font: frameConfig.font,
          fontSize: fontSize,
        );
      }
    }

    final frameSize = await getImageSize(framePath, trim: true);
    CSize resizedFrameSize = frameSize * (targetWidth / frameSize.width);

    final textSpaceRequired = textSize.height + textPadding * 2;
    int textSpaceAvailable =
        (targetSize.height - resizedFrameSize.height).round();

    // Check if the frame is too big to fit onto the screenshot
    // If so we need to make the frame even smaller
    if (textSpaceRequired > textSpaceAvailable &&
        frameConfig.scaleDownFrameToFit) {
      final newHeight =
          resizedFrameSize.height - textSpaceRequired + textSpaceAvailable;
      resizedFrameSize =
          resizedFrameSize * (newHeight / resizedFrameSize.height);
      textSpaceAvailable =
          (targetSize.height - resizedFrameSize.height).round();
    }

    final spaceAbove = math.max(textSpaceAvailable, textSpaceRequired);

    return MagickOp.background(frameConfig.background ?? 'white')
        .chain(MagickOp.gravity(MagickOptGravity.south))
        .chain(MagickOp.resize(width: resizedFrameSize.width))
        .chain(MagickOp.extent(
          width: resizedFrameSize.width,
          height: resizedFrameSize.height + spaceAbove,
        ))
        .chain(MagickOp.text(
          text: title,
          font: frameConfig.font,
          fontSize: fontSize,
          color: frameConfig.fontColor ?? 'black',
          y: (spaceAbove - textSize.height) / 2,
        ))
        .chain(MagickOp.background(frameConfig.background ?? 'white'))
        .chain(MagickOp.extent(
          width: targetSize.width,
          height: targetSize.height,
        ));
  }

  /// Add a single line break as close to the [position] as possible.
  ///
  /// If [position] is in the middle of a word, the line break is inserted
  /// before or after the word, depending on which is closer to [position].
  ///
  /// If [position] is not given it defaults to the middle of [s].
  String _insertAutoLineBreak(String s, [int? position]) {
    int pointer = 0;

    position ??= s.length ~/ 2;

    while (s[position + pointer] != ' ' &&
        position + pointer > 0 &&
        position + pointer < s.length) {
      pointer = pointer < 0 ? -pointer : -pointer - 1; // -1, 1, -2, 2, ..
    }
    final firstLine = s.substring(0, position + pointer);
    final secondLine = s.substring(position + pointer + 1);
    return '$firstLine\n$secondLine';
  }
}
