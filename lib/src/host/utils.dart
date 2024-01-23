import 'dart:io';

import '../common.dart';
import 'flutter_process.dart';

Future<ProcessResult> exec(List<String> args) async {
  final result = await Process.run(args.first, args.skip(1).toList());
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    await stderr.flush();

    throw StateError('Failed to run command: ${args.join(' ')}');
  }
  return result;
}

// This is an extension because we don't want this in the public (client-side)
// API.
extension ScreenshotConfigurationExtension on ScreenshotConfiguration {
  /// Add the configuration to the process. Null values will be omitted.
  void addToProcess(FlutterProcess process) {
    if (username != null) process.define('SCREENSHOOTER_USERNAME', username!);
    if (password != null) process.define('SCREENSHOOTER_PASSWORD', password!);
    process.define('SCREENSHOOTER_MODE', 'active');
    process.define('SCREENSHOOTER_ACTIVE', 'true');
    if (locales != null) {
      process.define(
        'SCREENSHOOTER_LOCALES',
        locales!.map((l) => l.toLanguageTag()).join(','),
      );
    }
  }
}

/// Custom size to avoid importing possibly conflicting libraries.
class CSize {
  final int width;
  final int height;

  CSize(this.width, this.height);

  @override
  String toString() => '($width,$height)';
}

class Profiler {
  final String name;
  final Stopwatch _stopwatch;
  final List<(String, int)> _stages = [];

  int get totalMs =>
      _stages.fold(0, (prev, e) => e.$1 == 'DISCARD' ? prev : prev + e.$2);

  Profiler(this.name) : _stopwatch = Stopwatch()..start();

  void stage(String name) {
    _stopwatch.stop();
    if (_stages.isEmpty) {
      _stages.add((name, _stopwatch.elapsedMilliseconds));
    } else {
      _stages.add((name, _stopwatch.elapsedMilliseconds - _stages.last.$2));
    }
    _stopwatch.start();
  }

  void discard() {
    stage('DISCARD');
  }

  void stop() {
    _stopwatch.stop();
  }

  @override
  String toString() {
    stop();
    String sb = 'Profiler: $name';
    for (final (stage, ms) in _stages) {
      if (stage == 'DISCARD') continue;

      sb += '\n $stage: ${ms}ms';
    }
    sb += '\n Total: ${totalMs}ms';
    return sb;
  }
}
