import 'dart:core';

import '../host/utils.dart';

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
    final args = [
      'magick',
      if (input != null) input,
      ...this.args,
      output,
    ];
    // print(args.map((e) => e.contains(' ') ? '"$e"' : e).join(' '));
    final result = await exec(args);
    return result.stdout;
  }

  MagickOp.resize({
    dynamic width,
    dynamic height,
    bool keepAspectRatio = false,
  }) : this('resize',
            '${width ?? ''}x${height ?? ''}${keepAspectRatio ? '^' : ''}');

  MagickOp.background(String color) : this('background', color);

  MagickOp.gravity(String gravity) : this('gravity', gravity);

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

  MagickOp.compose(String compose) : this('compose', compose);

  MagickOp.composite() : this('composite');

  MagickOp.trim() : this('trim');

  MagickOp.input(String input) : this('', input);

  MagickOp.geometry({
    dynamic x,
    dynamic y,
  }) : this('geometry', ['+$x+$y']);

  factory MagickOp.addSpaceBelow(dynamic size) =>
      MagickOp.gravity('south').chain(
        MagickOp.splice(width: 0, height: size, x: 0, y: 0),
      );
  factory MagickOp.addSpaceLeft(dynamic size) => MagickOp.gravity('west').chain(
        MagickOp.splice(width: size, height: 0, x: 0, y: 0),
      );
  factory MagickOp.addSpaceRight(dynamic size) =>
      MagickOp.gravity('east').chain(
        MagickOp.splice(width: size, height: 0, x: 0, y: 0),
      );
  factory MagickOp.addSpaceTop(dynamic size) => MagickOp.gravity('north').chain(
        MagickOp.splice(width: 0, height: size, x: 0, y: 0),
      );

  factory MagickOp.text({
    required String text,
    String? font,
    int size = 24,
    String? color,
    dynamic x = 0,
    dynamic y = 0,
  }) {
    var op = MagickOp.gravity('north').chain(MagickOp.pointsize(size));

    if (font != null) {
      op = op.chain(MagickOp.font(font));
    }

    if (color != null) {
      op = op.chain(MagickOp.fill(color));
    }

    return op.chain(MagickOp.annotate(text: text, x: x, y: y));
  }

  factory MagickOp.mask() =>
      MagickOp.compose('DstIn').chain(MagickOp.composite());
}

Future<CSize> getTextSize({
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
  op = op.chain(MagickOp('', 'label:$text')).chain(MagickOp.format('%wx%h'));

  final result = await op.run(null, 'info:');
  final parts = result.split('x');
  return CSize(
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}

Future<CSize> getImageSize(String path) async {
  final result = await MagickOp.format('%wx%h').run(path, 'info:');
  final parts = result.split('x');
  final size = CSize(
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
  return size;
}
