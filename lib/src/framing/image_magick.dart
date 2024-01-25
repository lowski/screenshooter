import 'dart:core';

import '../host/utils.dart';

class _StringEnum {
  final String value;

  const _StringEnum(this.value);

  @override
  String toString() => value;
}

class MagickOptGravity extends _StringEnum {
  static const center = MagickOptGravity._('center');
  static const north = MagickOptGravity._('north');
  static const south = MagickOptGravity._('south');
  static const east = MagickOptGravity._('east');
  static const west = MagickOptGravity._('west');
  static const northEast = MagickOptGravity._('northeast');
  static const northWest = MagickOptGravity._('northwest');
  static const southEast = MagickOptGravity._('southeast');
  static const southWest = MagickOptGravity._('southwest');

  const MagickOptGravity._(super.value);
}

class MagickOptCompose extends _StringEnum {
  static const clear = MagickOptCompose._('clear');
  static const src = MagickOptCompose._('src');
  static const dst = MagickOptCompose._('dst');
  static const srcOver = MagickOptCompose._('srcOver');
  static const dstOver = MagickOptCompose._('dstOver');
  static const srcIn = MagickOptCompose._('srcIn');
  static const dstIn = MagickOptCompose._('dstIn');
  static const srcOut = MagickOptCompose._('srcOut');
  static const dstOut = MagickOptCompose._('dstOut');
  static const srcAtop = MagickOptCompose._('srcAtop');
  static const dstAtop = MagickOptCompose._('dstAtop');
  static const xor = MagickOptCompose._('xor');

  static const multiply = MagickOptCompose._('multiply');
  static const screen = MagickOptCompose._('screen');
  static const plus = MagickOptCompose._('plus');
  static const add = MagickOptCompose._('add');
  static const minus = MagickOptCompose._('minus');
  static const subtract = MagickOptCompose._('subtract');
  static const difference = MagickOptCompose._('difference');
  static const exclusion = MagickOptCompose._('exclusion');
  static const darken = MagickOptCompose._('darken');
  static const lighten = MagickOptCompose._('lighten');
  static const negate = MagickOptCompose._('negate');
  static const reflect = MagickOptCompose._('reflect');
  static const freeze = MagickOptCompose._('freeze');
  static const stamp = MagickOptCompose._('stamp');
  static const interpolate = MagickOptCompose._('interpolate');

  static const linearDodge = MagickOptCompose._('linearDodge');
  static const linearBurn = MagickOptCompose._('linearBurn');
  static const colorDodge = MagickOptCompose._('colorDodge');
  static const colorBurn = MagickOptCompose._('colorBurn');
  static const overlay = MagickOptCompose._('overlay');
  static const hardLight = MagickOptCompose._('hardLight');
  static const linearLight = MagickOptCompose._('linearLight');
  static const softBurn = MagickOptCompose._('softBurn');
  static const softDodge = MagickOptCompose._('softDodge');
  static const softLight = MagickOptCompose._('softLight');
  static const pegtopLight = MagickOptCompose._('pegtopLight');
  static const vividLight = MagickOptCompose._('vividLight');
  static const pinLight = MagickOptCompose._('pinLight');

  static const copy = MagickOptCompose._('copy');
  static const copyRed = MagickOptCompose._('copyRed');
  static const copyGreen = MagickOptCompose._('copyGreen');
  static const copyBlue = MagickOptCompose._('copyBlue');
  static const copyCyan = MagickOptCompose._('copyCyan');
  static const copyMagenta = MagickOptCompose._('copyMagenta');
  static const copyYellow = MagickOptCompose._('copyYellow');
  static const copyBlack = MagickOptCompose._('copyBlack');
  static const copyOpacity = MagickOptCompose._('copyOpacity');
  static const changeMask = MagickOptCompose._('changeMask');
  static const stereo = MagickOptCompose._('stereo');

  const MagickOptCompose._(super.value);
}

enum TextAlignment {
  left,
  center,
  right,
}

class MagickOp {
  final List<MagickOp> prev;
  final List<String> _args;

  List<String> get args => [
        ...prev.followedBy([this]).fold(
          [],
          (previousValue, e) => previousValue.followedBy(
            e._args,
          ),
        ),
      ];

  MagickOp(String cmd, [dynamic arg])
      : prev = [],
        _args = [
          if (cmd.isNotEmpty) '-$cmd',
          if (arg is List)
            ...arg.map((e) => e.toString())
          else if (arg != null)
            arg.toString(),
        ];

  MagickOp.chained(this.prev, this._args);

  MagickOp chain(MagickOp op) {
    return MagickOp.chained([...prev, this, ...op.prev], op._args);
  }

  MagickOp grouped() => MagickOp.chained(
        [MagickOp('', '('), ...prev, this],
        [')'],
      );

  Future<String> run(String? input, String output) async {
    // final time = DateTime.now();
    final args = [
      'magick',
      if (input != null) input,
      ...this.args,
      output,
    ];
    // print(args.map((e) => e.contains(' ') ? '"$e"' : e).join(' '));
    final result = await exec(args);
    // print('  [${DateTime.now().difference(time).inMilliseconds} ms] $args');
    return result.stdout;
  }

  MagickOp.resize({
    dynamic width,
    dynamic height,
    bool keepAspectRatio = false,
  }) : this('resize',
            '${width ?? ''}x${height ?? ''}${keepAspectRatio ? '^' : ''}');

  MagickOp.background(String color) : this('background', color);

  MagickOp.gravity(MagickOptGravity gravity) : this('gravity', gravity.value);

  MagickOp.extent({
    required dynamic width,
    dynamic height,
  }) : this('extent', '${width ?? ''}x${height ?? ''}');

  MagickOp.splice({
    required dynamic width,
    required dynamic height,
    dynamic x,
    dynamic y,
  }) : this(
            'splice',
            x != null || y != null
                ? '${width ?? ''}x${height ?? ''}+${x ?? 0}+${y ?? 0}'
                : '${width ?? ''}x${height ?? ''}');

  MagickOp.pointsize(int size) : this('pointsize', size);

  MagickOp.font(String font) : this('font', font);

  MagickOp.annotate({
    required String text,
    dynamic x = 0,
    dynamic y = 0,
  }) : this('annotate', ['+$x+$y', text]);

  MagickOp.fill(String color) : this('fill', color);

  MagickOp.format(String format) : this('format', format);

  MagickOp.compose(MagickOptCompose compose) : this('compose', compose.value);

  MagickOp.composite() : this('composite');

  MagickOp.trim() : this('trim');

  MagickOp.input(String input) : this('', input);

  MagickOp.geometry({
    dynamic x,
    dynamic y,
  }) : this('geometry', ['+$x+$y']);

  MagickOp.rotate(num degrees) : this('rotate', degrees);

  factory MagickOp.addSpaceBelow(dynamic size) =>
      MagickOp.gravity(MagickOptGravity.south).chain(
        MagickOp.splice(width: 0, height: size, x: 0, y: 0),
      );
  factory MagickOp.addSpaceLeft(dynamic size) =>
      MagickOp.gravity(MagickOptGravity.west).chain(
        MagickOp.splice(width: size, height: 0, x: 0, y: 0),
      );
  factory MagickOp.addSpaceRight(dynamic size) =>
      MagickOp.gravity(MagickOptGravity.east).chain(
        MagickOp.splice(width: size, height: 0, x: 0, y: 0),
      );
  factory MagickOp.addSpaceTop(dynamic size) =>
      MagickOp.gravity(MagickOptGravity.north).chain(
        MagickOp.splice(width: 0, height: size, x: 0, y: 0),
      );

  /// Adds text to the image.
  ///
  /// [alignment] is the alignment of the text within the text block itself.
  ///
  /// [anchor] is the alignment of the text block within the image.
  ///
  /// [x] and [y] are the offsets of the text block within the image relative to
  /// the given [anchor].
  factory MagickOp.text({
    required String text,
    String? font,
    num? fontSize,
    String? color,
    dynamic x = 0,
    dynamic y = 0,
    TextAlignment alignment = TextAlignment.center,
    MagickOptGravity? anchor,
  }) {
    var op = MagickOp.background('transparent');

    if (fontSize != null) {
      op = op.chain(MagickOp.pointsize(fontSize.toInt()));
    }

    if (font != null) {
      op = op.chain(MagickOp.font(font));
    }

    if (color != null) {
      op = op.chain(MagickOp.fill(color));
    }

    final gravity = switch (alignment) {
      TextAlignment.left => MagickOptGravity.northWest,
      TextAlignment.center => MagickOptGravity.north,
      TextAlignment.right => MagickOptGravity.northEast,
    };

    op = op
        .chain(MagickOp.gravity(gravity))
        .chain(MagickOp('', 'label:$text'))
        .chain(MagickOp.trim())
        .grouped()
        .chain(MagickOp.gravity(anchor ?? gravity))
        .chain(MagickOp.geometry(x: '+$x', y: '+$y'))
        .chain(MagickOp.compose(MagickOptCompose.srcAtop))
        .chain(MagickOp.composite());

    return op;
  }

  factory MagickOp.mask() =>
      MagickOp.compose(MagickOptCompose.dstIn).chain(MagickOp.composite());
}

final _textSizeCache = <int, CSize>{};

/// Get the size of a text.
///
/// The result is cached.
Future<CSize> getTextSize({
  required String text,
  String? font,
  num? fontSize,
}) async {
  final hash = '$text|$font|$fontSize'.hashCode;
  if (_textSizeCache.containsKey(hash)) {
    return _textSizeCache[hash]!;
  }

  var op = MagickOp('size', 'x');
  if (font != null) {
    op = op.chain(MagickOp.font(font));
  }
  if (fontSize != null) {
    op = op.chain(MagickOp.pointsize(fontSize.toInt()));
  }
  op = op
      .chain(MagickOp('', 'label:$text'))
      .chain(MagickOp.format('%wx%h'))
      .chain(MagickOp.trim());

  final parts = (await op.run(null, 'info:')).split('x');
  final result = CSize(
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
  _textSizeCache[hash] = result;
  return result;
}

final _imageSizeCache = <int, CSize>{};

/// Get the size of an image.
///
/// The result is cached.
Future<CSize> getImageSize(String path, {bool trim = false}) async {
  final hash = '$path|$trim'.hashCode;
  if (_imageSizeCache.containsKey(hash)) {
    return _imageSizeCache[hash]!;
  }

  var op = MagickOp.format('%wx%h');
  if (trim) {
    op = op.chain(MagickOp.trim());
  }

  final parts = (await op.run(path, 'info:')).split('x');
  final result = CSize(
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
  _imageSizeCache[hash] = result;
  return result;
}
