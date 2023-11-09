import 'dart:math' as math;

import 'package:image/image.dart';
import 'package:screenshooter/src/framing/utils.dart';

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
