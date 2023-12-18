import 'dart:math' as math;

import 'package:image/image.dart';

import '../host/args.dart';

enum HDirection {
  left,
  right,
}

enum VDirection {
  up,
  down,
}

int findHorizontalEdge(
  Image img,
  HDirection direction,
) {
  final centerY = (img.height / 2).round();
  for (int x = (img.width / 2).round();
      (direction == HDirection.left ? x >= 0 : x < img.width);
      (direction == HDirection.left ? x-- : x++)) {
    if (img.getPixel(x, centerY).a == 255) {
      return (direction == HDirection.left ? x + 1 : x - 1);
    }
  }
  throw Exception('Could not find horizontal edge (direction: $direction)');
}

int findVerticalEdge(
  Image img,
  VDirection direction,
  int leftEdge,
  int rightEdge, {
  bool findInnermostEdge = false,
}) {
  final centerY = (img.height / 2).round();
  // find the height of the screen in the overlay

  // how to find the top edge?
  // we do this by going up from the center until we find a non-transparent pixel
  // we go back down and then we go left pixel-wise and each step we try to go up if we can

  // we start at the center

  int x = (img.width / 2).round();
  int y = centerY;
  int minLeftY = findInnermostEdge
      ? (direction == VDirection.up ? 0 : img.height)
      : centerY;

  Function moveTowardEdge, moveAwayFromEdge;

  /// Returns the value that is further away from the center
  int Function(int, int) moreExtreme;

  switch (direction) {
    case VDirection.up:
      moveTowardEdge = () => y--;
      moveAwayFromEdge = () => y++;
      moreExtreme = findInnermostEdge ? math.max : math.min;
      break;
    case VDirection.down:
      moveTowardEdge = () => y++;
      moveAwayFromEdge = () => y--;
      moreExtreme = findInnermostEdge ? math.min : math.max;
      break;
  }

  int yTowardEdge() => y + (direction == VDirection.up ? -1 : 1);

  while (x > leftEdge) {
    // go one pixel left
    x--;
    if (img.getPixel(x, y).a != 0) {
      // move down until we are on a transparent pixel
      while (img.getPixel(x, y).a != 0) {
        moveAwayFromEdge();
      }
    } else {
      // we are on a transparent pixel, so we go up until we are on a non-transparent pixel
      while (img.getPixel(x, yTowardEdge()).a == 0) {
        moveTowardEdge();
      }
    }
    minLeftY = moreExtreme(y, minLeftY);
    // img.setPixelRgba(x, y, 255, 0, 0, 255);
  }
  // we have found the minimum y value on the left side of the center, now we do the same on the right side
  x = (img.width / 2).round();
  y = centerY;
  int minRightY = findInnermostEdge
      ? (direction == VDirection.up ? 0 : img.height)
      : centerY;

  while (x < rightEdge) {
    // go one pixel right
    x++;
    if (img.getPixel(x, y).a == 255) {
      // move down until we are on a transparent pixel
      while (img.getPixel(x, y).a == 255) {
        moveAwayFromEdge();
      }
    } else {
      // we are on a transparent pixel, so we go up until we are on a non-transparent pixel
      while (img.getPixel(x, yTowardEdge()).a < 255) {
        moveTowardEdge();
      }
    }
    minRightY = moreExtreme(y, minRightY);
    // img.setPixelRgba(x, y, 255, 0, 0, 255);
  }

  return moreExtreme(minLeftY, minRightY);
}

/// Returns the edges of the screen in the image.
///
/// In this context the "screen" is the connected area of transparent pixels
/// in the center of the image.
math.Rectangle<int> getInnerScreenEdges(Image image) {
  final leftEdge = findHorizontalEdge(image, HDirection.left);
  final rightEdge = findHorizontalEdge(image, HDirection.right);

  final topEdge = findVerticalEdge(
    image,
    VDirection.up,
    leftEdge,
    rightEdge,
  );
  final bottomEdge = findVerticalEdge(
    image,
    VDirection.down,
    leftEdge,
    rightEdge,
  );

  return math.Rectangle<int>.fromPoints(
    math.Point(leftEdge, topEdge),
    math.Point(rightEdge, bottomEdge),
  );
}

(Image, math.Rectangle<int>) getScreenMask(Image img) {
  Image mask = Image.from(img);

  final bg = ColorRgba8(0, 0, 0, 0);
  final color = ColorRgba8(255, 255, 255, 255);
  fill(mask, color: bg);

  final edges = getInnerScreenEdges(img);

  final innerMostTopEdge = findVerticalEdge(
    img,
    VDirection.up,
    edges.left,
    edges.right,
    findInnermostEdge: true,
  );

  final innerMostBottomEdge = findVerticalEdge(
    img,
    VDirection.down,
    edges.left,
    edges.right,
    findInnermostEdge: true,
  );

  mask = fillRect(
    mask,
    x1: edges.left,
    y1: innerMostTopEdge,
    x2: edges.right,
    y2: innerMostBottomEdge,
    color: color,
  );

  int currentLeftEdge = edges.left;
  int currentRightEdge = edges.right;

  for (int y = innerMostTopEdge; y >= edges.top; y--) {
    // adjust edges
    while (img.getPixel(currentLeftEdge, y).a == 255) {
      currentLeftEdge++;
    }
    while (img.getPixel(currentRightEdge, y).a == 255) {
      currentRightEdge--;
    }
    // fill row
    for (int x = currentLeftEdge; x <= currentRightEdge; x++) {
      if (img.getPixel(x, y).a < 255) {
        mask.setPixel(x, y, color);
      }
    }
  }

  currentLeftEdge = edges.left;
  currentRightEdge = edges.right;

  for (int y = innerMostBottomEdge; y <= edges.bottom; y++) {
    // adjust edges
    while (img.getPixel(currentLeftEdge, y).a == 255) {
      currentLeftEdge++;
    }
    while (img.getPixel(currentRightEdge, y).a == 255) {
      currentRightEdge--;
    }
    // fill row
    for (int x = currentLeftEdge; x <= currentRightEdge; x++) {
      if (img.getPixel(x, y).a < 255) {
        mask.setPixel(x, y, color);
      }
    }
  }

  return (mask, edges);
}

/// Find the title for the screenshot with the given [basename].
String findTitle({
  required ScreenshotFrameConfig cfg,
  required String basename,
  required String locale,
  String? deviceId,
}) {
  final titles = cfg.titles?[locale] ?? {};

  if (titles.isEmpty) {
    return '';
  }

  basename = basename.replaceAll(locale, '').replaceAll(deviceId ?? '', '');

  final titleKey = titles.keys.firstWhere(
    (element) => basename.contains(element),
    orElse: () => '',
  );

  return titles[titleKey] ?? '';
}
